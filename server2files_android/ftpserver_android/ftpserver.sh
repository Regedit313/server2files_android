
#!/data/data/com.termux/files/usr/bin/bash

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"
FTP_DIR="/storage/emulated/0/FTPshare"

pause_screen() {
    echo
    read -r -p "Press Enter to continue..."
}

check_installation() {
    command -v python >/dev/null 2>&1 || return 1

    python -c 'import pyftpdlib' >/dev/null 2>&1 || return 1

    return 0
}

run_setup() {
    if [ ! -f "$APP_DIR/ftpserver_setup.sh" ]; then
        echo
        echo "Error: setup file is missing:"
        echo "$APP_DIR/ftpserver_setup.sh"
        pause_screen
        return 1
    fi

    bash "$APP_DIR/ftpserver_setup.sh"
}

check_storage() {
    if [ ! -d "$HOME/storage/shared" ]; then
        echo
        echo "Setting up Android storage..."
        echo "If Android asks for permission, please allow it."
        echo

        if command -v termux-setup-storage >/dev/null 2>&1; then
            termux-setup-storage
        else
            echo "Warning: termux-setup-storage command was not found."
        fi
    fi
}

initial_check() {
    clear

    echo
    echo "ftpserver_android"
    echo
    echo "Checking installation..."

    if ! check_installation; then
        echo
        echo "Python or pyftpdlib is missing."
        echo "Running first-time setup automatically..."
        echo

        if ! run_setup; then
            echo
            echo "Automatic setup did not complete."
            echo "You can retry with option 9 when Internet is available."
            pause_screen
        fi
    else
        echo "Installation OK."
    fi

    check_storage

    mkdir -p "$FTP_DIR" 2>/dev/null || true
}

start_server() {
    clear

    echo
    echo "ftpserver_android"
    echo

    if ! check_installation; then
        echo "Python or pyftpdlib is not installed."
        echo "Run Setup / Update (option 9)."
        pause_screen
        return
    fi

    if ! mkdir -p "$FTP_DIR"; then
        echo "Error: cannot create FTPshare folder."
        echo "Check Android storage permission."
        pause_screen
        return
    fi

    echo "Local IP address:"

    python -c "import socket;s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.connect(('8.8.8.8',80));print(s.getsockname()[0]);s.close()" \
        2>/dev/null || echo "IP unavailable (check local network)."

    echo
    echo "FTP port: 2121"
    echo
    echo "Shared folder:"
    echo "$FTP_DIR"
    echo
    echo "Press CTRL+C to stop the FTP server."
    echo

    exec python -m pyftpdlib -p 2121 -w -d "/storage/emulated/0/FTPshare"
}

stop_server() {
    clear

    echo
    echo "ftpserver_android"
    echo
    echo "========================================"
    echo "Stop FTP server"
    echo "========================================"
    echo
    echo "WARNING!"
    echo
    echo "Active FTP transfers may be interrupted."
    echo
    echo "1) Confirm and stop"
    echo
    echo "0) Cancel"
    echo

    read -r -p "Choose what to do: " confirm

    case "$confirm" in

        1)
            echo
            echo "Stopping FTP server..."
            echo

            if pkill -TERM -f 'python -m pyftpdlib'; then
                echo "FTP server stop signal sent."
            else
                echo "No FTP server found or stop failed."
            fi

            pause_screen
            ;;

        *)
            echo
            echo "Cancelled."
            pause_screen
            ;;

    esac
}

initial_check

while true; do
    clear

    echo
    echo "ftpserver_android"
    echo
    echo
    echo "1) Start FTP server"
    echo
    echo "2) Stop FTP server"
    echo
    echo
    echo "9) Run Setup / Update (required before first use)"
    echo
    echo "0) Exit"
    echo
    echo

    read -r -p "Choose what to do: " choice

    case "$choice" in

        1)
            start_server
            ;;

        2)
            stop_server
            ;;

        9)
            clear
            run_setup
            ;;

        0)
            clear
            exit 0
            ;;

        *)
            echo
            echo "Invalid choice."
            sleep 1
            ;;

    esac
done
