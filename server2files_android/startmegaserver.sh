
#!/data/data/com.termux/files/usr/bin/bash

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"
HFS_CWD="$HOME/.hfs_httpserver_android"
FTP_DIR="/storage/emulated/0/FTPshare"
CONFIG_FILE="$APP_DIR/portmanager_android/config.json"

RUN_DIR="$HOME/.startmegaserver"
STATE_FILE="$RUN_DIR/state"
LOG_DIR="$HOME/.startmegaserver_logs"

pause_screen() {
    echo
    read -r -p "Press Enter to continue..."
}

# Read the process start time to avoid acting on a reused PID.
process_start_time() {
    local pid="$1" stat rest

    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    [ -r "/proc/$pid/stat" ] || return 1

    IFS= read -r stat < "/proc/$pid/stat" || return 1

    rest="${stat##*) }"
    set -- $rest

    [ "${1:-}" != "Z" ] || return 1
    [[ "${20:-}" =~ ^[0-9]+$ ]] || return 1

    printf '%s\n' "${20}"
}

is_our_process() {
    local current

    [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ ]] || return 1

    current="$(process_start_time "$1")" || return 1

    [ "$current" = "$2" ] && kill -0 "$1" 2>/dev/null
}

stop_process() {
    local name="$1"
    local pid="$2"
    local started="$3"

    if is_our_process "$pid" "$started"; then

        if kill -TERM "$pid" 2>/dev/null; then
            echo "$name: stop signal sent."
        else
            echo "Warning: could not stop $name."
        fi

    else
        echo "$name: already stopped (or PID no longer matches)."
    fi
}

read_port_config() {
    if [ ! -f "$CONFIG_FILE" ] || ! jq -e '
        (.destination_ip | type == "string") and
        (.destination_port | type == "number") and
        (.external_port | type == "number") and
        (.protocol == "TCP" or .protocol == "UDP") and
        (.timer | type == "number")
    ' "$CONFIG_FILE" >/dev/null 2>&1; then

        echo "Error: missing or invalid Portmanager config.json."
        echo "Configure Portmanager first."
        return 1
    fi

    CFG_IP="$(jq -r '.destination_ip' "$CONFIG_FILE")"
    CFG_DEST_PORT="$(jq -r '.destination_port' "$CONFIG_FILE")"
    CFG_EXTERNAL_PORT="$(jq -r '.external_port' "$CONFIG_FILE")"
    CFG_PROTOCOL="$(jq -r '.protocol' "$CONFIG_FILE")"
    CFG_TIMER="$(jq -r '.timer' "$CONFIG_FILE")"

    if [ "$CFG_DEST_PORT" != "8000" ] || [ "$CFG_PROTOCOL" != "TCP" ]; then
        echo "Error: Portmanager must target TCP port 8000 for HTTP."
        echo "Current target: $CFG_IP:$CFG_DEST_PORT ($CFG_PROTOCOL)"
        return 1
    fi

    return 0
}

start_megaserver() {
    clear

    echo
    echo "MegaServer - Start"
    echo

    if [ -d "$RUN_DIR" ]; then
        echo "A MegaServer session is already recorded."
        echo "Use Stop MegaServer before starting again."
        pause_screen
        return
    fi

    if ! command -v hfs >/dev/null 2>&1 || \
       ! command -v node >/dev/null 2>&1 || \
       ! command -v python >/dev/null 2>&1 || \
       ! python -c 'import pyftpdlib' >/dev/null 2>&1 || \
       ! command -v upnpc >/dev/null 2>&1 || \
       ! command -v jq >/dev/null 2>&1; then

        echo "Error: a required tool is missing."
        echo "Run the Setup of HTTPserver, FTPserver or Portmanager first."
        pause_screen
        return
    fi

    if [ ! -f "$HFS_CWD/config.yaml" ]; then
        echo "Error: private HFS settings not found."
        echo "Start HTTPserver (Saved settings) once before using MegaServer."
        pause_screen
        return
    fi

    if ! read_port_config; then
        pause_screen
        return
    fi

    if ! mkdir -p "$FTP_DIR" "$LOG_DIR"; then
        echo "Error: cannot create the shared or log folder."
        pause_screen
        return
    fi

    # Prevent two sessions from starting MegaServer at once.
    if ! mkdir "$RUN_DIR" 2>/dev/null; then
        echo "Error: MegaServer is already being started."
        pause_screen
        return
    fi

    echo "Starting HTTP server (Saved settings)..."

    (
        cd "$APP_DIR/httpserver_android" || exit 1

        exec hfs --cwd "$HFS_CWD" --port 8000 --listen_interface 0.0.0.0 --open_browser_at_start false

    ) </dev/null >> "$LOG_DIR/http.log" 2>&1 &

    local hfs_pid=$!
    local hfs_started

    hfs_started="$(process_start_time "$hfs_pid")"

    echo "Starting local FTP server..."

    (
        cd "$APP_DIR/ftpserver_android" || exit 1

        exec python -m pyftpdlib -p 2121 -w -d "$FTP_DIR"

    ) </dev/null >> "$LOG_DIR/ftp.log" 2>&1 &

    local ftp_pid=$!
    local ftp_started

    ftp_started="$(process_start_time "$ftp_pid")"

    sleep 2

    if ! is_our_process "$hfs_pid" "$hfs_started" || \
       ! is_our_process "$ftp_pid" "$ftp_started"; then

        echo "Error: HTTP or FTP did not start correctly."
        echo "Check logs in: $LOG_DIR"

        stop_process "FTP" "$ftp_pid" "$ftp_started"
        stop_process "HTTP" "$hfs_pid" "$hfs_started"

        rmdir "$RUN_DIR" 2>/dev/null || true

        pause_screen
        return
    fi

    # Save process identities and port settings for Stop.
    printf '%s %s %s %s %s %s\n' \
        "$hfs_pid" "$hfs_started" "$ftp_pid" "$ftp_started" \
        "$CFG_EXTERNAL_PORT" "$CFG_PROTOCOL" > "$STATE_FILE"

    echo
    echo "Opening HTTP port: $CFG_EXTERNAL_PORT $CFG_PROTOCOL"
    echo "Destination: $CFG_IP:$CFG_DEST_PORT"
    echo "Timer: $CFG_TIMER seconds"
    echo

    if ! upnpc -e "portmanager_android" -a "$CFG_IP" "$CFG_DEST_PORT" \
            "$CFG_EXTERNAL_PORT" "$CFG_PROTOCOL" "$CFG_TIMER"; then

        echo
        echo "Error: UPnP opening failed. Stopping both servers."
        echo "If the port conflicts, use Portmanager to inspect or close it."

        stop_process "FTP" "$ftp_pid" "$ftp_started"
        stop_process "HTTP" "$hfs_pid" "$hfs_started"

        rm -f "$STATE_FILE"
        rmdir "$RUN_DIR" 2>/dev/null || true

    else

        echo
        echo "MegaServer started. HTTP and FTP are running."
        echo "HTTP: port 8000 (saved accounts and permissions)"
        echo "FTP:  port 2121 (local network)"
        echo "Logs: $LOG_DIR"
        echo "Use Stop MegaServer before closing Termux."

    fi

    pause_screen
}

stop_megaserver() {
    clear

    echo
    echo "MegaServer - Stop"
    echo

    if [ ! -f "$STATE_FILE" ]; then
        rmdir "$RUN_DIR" 2>/dev/null || true

        echo "No MegaServer session recorded."
        echo "Use the individual applications if a server was started separately."

        pause_screen
        return
    fi

    local hfs_pid hfs_started ftp_pid ftp_started port protocol

    read -r hfs_pid hfs_started ftp_pid ftp_started port protocol < "$STATE_FILE"

    # First, close the HTTP port.
    echo "Closing HTTP port: $port $protocol"

    if upnpc -d "$port" "$protocol"; then
        echo "Port closing request succeeded."
    else
        echo "Warning: port could not be closed (or was already closed)."
    fi

    # Then stop FTP and HTTP.
    echo

    stop_process "FTP" "$ftp_pid" "$ftp_started"
    stop_process "HTTP" "$hfs_pid" "$hfs_started"

    sleep 2

    if is_our_process "$ftp_pid" "$ftp_started" || \
       is_our_process "$hfs_pid" "$hfs_started"; then

        echo
        echo "Warning: a server is still running. Try Stop again."

    else

        rm -f "$STATE_FILE"
        rmdir "$RUN_DIR" 2>/dev/null || true

        echo
        echo "MegaServer stopped."

    fi

    pause_screen
}

while true; do
    clear

    echo
    echo "MegaServer"
    echo
    echo "1) Start MegaServer"
    echo
    echo "2) Stop MegaServer"
    echo
    echo "0) Back"
    echo

    read -r -p "Choose what to do: " choice || exit 0

    case "$choice" in

        1)
            start_megaserver
            ;;

        2)
            stop_megaserver
            ;;

        0)
            exit 0
            ;;

        *)
            echo
            echo "Invalid choice."
            sleep 1
            ;;

    esac
done

