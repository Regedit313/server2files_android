
#!/data/data/com.termux/files/usr/bin/bash

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"
CONFIG_FILE="$APP_DIR/config.json"

pause_screen() {
    echo
    read -r -p "Press Enter to continue..."
}

check_installation() {
    command -v upnpc >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1
    return 0
}

run_setup() {
    if [ ! -f "$APP_DIR/portmanager_setup.sh" ]; then
        echo
        echo "Error: setup file is missing:"
        echo "$APP_DIR/portmanager_setup.sh"
        pause_screen
        return 1
    fi

    bash "$APP_DIR/portmanager_setup.sh"
}

initial_check() {
    clear

    echo
    echo "portmanager_android"
    echo
    echo "Checking installation..."

    if ! check_installation; then
        echo
        echo "miniupnpc or jq is missing."
        echo "Running first-time setup automatically..."
        echo

        run_setup
    else
        echo "Installation OK."
    fi

    if ! check_installation; then
        echo
        echo "Error: required tools are not available."
        echo "Run portmanager_setup.sh when Internet is available."
        pause_screen
        return 1
    fi

    return 0
}

# ========================================
# INPUT VALIDATION
# ========================================

valid_ip() {
    local address="$1" octet
    local -a parts

    [[ "$address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

    IFS='.' read -r -a parts <<< "$address"

    for octet in "${parts[@]}"; do
        [[ "$octet" =~ ^(0|[1-9][0-9]{0,2})$ ]] || return 1
        (( 10#$octet <= 255 )) || return 1
    done

    return 0
}

valid_port() {
    [[ "$1" =~ ^[0-9]{1,5}$ ]] || return 1
    (( 10#$1 >= 1 && 10#$1 <= 65535 ))
}

valid_timer() {
    [[ "$1" =~ ^[0-9]{1,6}$ ]] || return 1
    (( 10#$1 <= 604800 ))
}

# ========================================
# JSON CONFIGURATION
# ========================================

load_config() {
    [ -f "$CONFIG_FILE" ] || return 1

    if ! jq -e '
        (.destination_ip | type == "string") and
        (.destination_port | type == "number") and
        (.external_port | type == "number") and
        (.protocol == "TCP" or .protocol == "UDP") and
        (.timer | type == "number")
    ' "$CONFIG_FILE" >/dev/null 2>&1; then
        return 1
    fi

    CFG_IP="$(jq -r '.destination_ip' "$CONFIG_FILE")"
    CFG_DEST_PORT="$(jq -r '.destination_port' "$CONFIG_FILE")"
    CFG_EXTERNAL_PORT="$(jq -r '.external_port' "$CONFIG_FILE")"
    CFG_PROTOCOL="$(jq -r '.protocol' "$CONFIG_FILE")"
    CFG_TIMER="$(jq -r '.timer' "$CONFIG_FILE")"

    valid_ip "$CFG_IP" &&
    valid_port "$CFG_DEST_PORT" &&
    valid_port "$CFG_EXTERNAL_PORT" &&
    valid_timer "$CFG_TIMER"
}

save_config() {
    local ip="$1"
    local dest_port="$2"
    local external_port="$3"
    local protocol="$4"
    local timer="$5"
    local temp_file

    if ! temp_file="$(mktemp "$APP_DIR/.portmanager.XXXXXX")"; then
        echo "Error: cannot create temporary config file."
        return 1
    fi

    if jq -n \
        --arg ip "$ip" \
        --argjson dest_port "$dest_port" \
        --argjson external_port "$external_port" \
        --arg protocol "$protocol" \
        --argjson timer "$timer" \
        '{
            destination_ip: $ip,
            destination_port: $dest_port,
            external_port: $external_port,
            protocol: $protocol,
            timer: $timer
        }' > "$temp_file" && \
        mv -f "$temp_file" "$CONFIG_FILE"; then

        echo
        echo "Configuration saved."
        return 0
    fi

    rm -f "$temp_file"

    echo "Error: cannot save configuration."
    return 1
}

# ========================================
# CONFIGURATION INPUTS
# ========================================

prompt_ip() {
    local value

    while true; do
        echo

        read -r -p "Enter destination IP (0 to cancel): " value || return 1

        [ "$value" = "0" ] && return 1

        if valid_ip "$value"; then
            INPUT_VALUE="$value"
            return 0
        fi

        echo "Invalid IPv4 address."
        echo "Example: 192.168.1.55"
    done
}

prompt_port() {
    local label="$1"
    local value

    while true; do
        echo

        read -r -p "Enter $label (0 to cancel): " value || return 1

        [ "$value" = "0" ] && return 1

        if valid_port "$value"; then
            INPUT_VALUE="$((10#$value))"
            return 0
        fi

        echo "Invalid port."
        echo "Enter a number between 1 and 65535."
    done
}

prompt_protocol() {
    local choice

    while true; do
        echo
        echo "1) TCP"
        echo "2) UDP"
        echo "0) Cancel"
        echo

        read -r -p "Choose protocol: " choice || return 1

        case "$choice" in

            1)
                INPUT_VALUE="TCP"
                return 0
                ;;

            2)
                INPUT_VALUE="UDP"
                return 0
                ;;

            0)
                return 1
                ;;

            *)
                echo "Invalid choice."
                ;;

        esac
    done
}

prompt_timer() {
    local choice seconds

    while true; do
        echo
        echo "1) 1 hour (3600 seconds)"
        echo "2) Custom duration (seconds)"
        echo "3) Unlimited (request 0 seconds)"
        echo "0) Cancel"
        echo

        read -r -p "Choose timer: " choice || return 1

        case "$choice" in

            1)
                INPUT_VALUE="3600"
                return 0
                ;;

            2)
                while true; do
                    echo

                    read -r -p "Seconds (1-604800, 0 to cancel): " seconds || return 1

                    [ "$seconds" = "0" ] && break

                    if valid_timer "$seconds"; then
                        INPUT_VALUE="$((10#$seconds))"
                        return 0
                    fi

                    echo "Invalid duration."
                    echo "Maximum: 604800 seconds (7 days)."
                done
                ;;

            3)
                INPUT_VALUE="0"
                return 0
                ;;

            0)
                return 1
                ;;

            *)
                echo "Invalid choice."
                ;;

        esac
    done
}

show_summary() {
    echo "$CFG_EXTERNAL_PORT $CFG_PROTOCOL > $CFG_IP:$CFG_DEST_PORT"

    if [ "$CFG_TIMER" = "0" ]; then
        echo "Timer: Unlimited"
    else
        echo "Timer: ${CFG_TIMER}s"
    fi
}

# ========================================
# FIRST-TIME CONFIGURATION
# ========================================

first_configuration() {
    local ip dest_port external_port protocol timer confirm

    clear

    echo
    echo "portmanager_android"
    echo
    echo "Initial configuration"
    echo "Enter the settings one by one."
    echo

    echo "Step 1/5 - Destination IP"

    prompt_ip || return
    ip="$INPUT_VALUE"

    echo
    echo "Step 2/5 - Destination port"

    prompt_port "destination port" || return
    dest_port="$INPUT_VALUE"

    echo
    echo "Step 3/5 - External port"

    prompt_port "external port" || return
    external_port="$INPUT_VALUE"

    echo
    echo "Step 4/5 - Protocol"

    prompt_protocol || return
    protocol="$INPUT_VALUE"

    echo
    echo "Step 5/5 - Timer"

    prompt_timer || return
    timer="$INPUT_VALUE"

    clear

    echo
    echo "portmanager_android"
    echo
    echo "Review configuration:"
    echo
    echo "$external_port $protocol > $ip:$dest_port"

    if [ "$timer" = "0" ]; then
        echo "Timer: Unlimited"
    else
        echo "Timer: ${timer}s"
    fi

    echo
    echo "1) Save configuration"
    echo "0) Cancel"
    echo

    read -r -p "Choose what to do: " confirm || return

    if [ "$confirm" = "1" ]; then
        save_config "$ip" "$dest_port" "$external_port" "$protocol" "$timer"
        pause_screen
    fi
}

first_run_menu() {
    while ! load_config; do
        clear

        echo
        echo "portmanager_android"
        echo

        if [ -f "$CONFIG_FILE" ]; then
            echo "Configuration file is invalid."
            echo "You can create a new configuration."
        else
            echo "No configuration found."
            echo "Initial configuration required."
        fi

        echo
        echo "1) Start configuration"
        echo
        echo "0) Exit"
        echo

        read -r -p "Choose what to do: " choice || exit 0

        case "$choice" in

            1)
                first_configuration
                ;;

            0)
                clear
                exit 0
                ;;

            *)
                echo "Invalid choice."
                sleep 1
                ;;

        esac
    done
}

# ========================================
# UPnP FUNCTIONS
# ========================================

open_port() {
    clear

    echo
    echo "portmanager_android"
    echo

    show_summary

    echo
    echo "Opening port..."
    echo

    if upnpc -e "portmanager_android" -a "$CFG_IP" "$CFG_DEST_PORT" "$CFG_EXTERNAL_PORT" "$CFG_PROTOCOL" "$CFG_TIMER"; then

        echo
        echo "Port mapping request succeeded."

    else

        echo
        echo "Error: port mapping failed."
        echo "Check Wi-Fi, UPnP IGD and router settings."

    fi

    pause_screen
}

close_port() {
    clear

    echo
    echo "portmanager_android"
    echo

    show_summary

    echo
    echo "Closing configured port..."
    echo

    if upnpc -d "$CFG_EXTERNAL_PORT" "$CFG_PROTOCOL"; then

        echo
        echo "Port closing request succeeded."

    else

        echo
        echo "Error: could not close the configured port."

    fi

    pause_screen
}

show_port_status() {
    clear

    echo
    echo "portmanager_android"
    echo
    echo "UPnP port status"
    echo

    if ! upnpc -l; then
        echo
        echo "Error: unable to query router."
    fi

    pause_screen
}

# ========================================
# CONFIGURE MENU
# ========================================

configure_menu() {
    local choice

    while true; do
        load_config || return 1

        clear

        echo
        echo "portmanager_android"
        echo
        echo "========================================"
        echo "Configure"
        echo "========================================"
        echo

        show_summary

        echo
        echo "1) Destination IP"
        echo
        echo "2) Destination port"
        echo
        echo "3) External port"
        echo
        echo "4) Protocol (TCP / UDP)"
        echo
        echo "5) Timer"
        echo
        echo "0) Back"
        echo

        read -r -p "Choose what to do: " choice || return

        case "$choice" in

            1)
                if prompt_ip; then
                    save_config "$INPUT_VALUE" "$CFG_DEST_PORT" "$CFG_EXTERNAL_PORT" "$CFG_PROTOCOL" "$CFG_TIMER"
                    pause_screen
                fi
                ;;

            2)
                if prompt_port "destination port"; then
                    save_config "$CFG_IP" "$INPUT_VALUE" "$CFG_EXTERNAL_PORT" "$CFG_PROTOCOL" "$CFG_TIMER"
                    pause_screen
                fi
                ;;

            3)
                if prompt_port "external port"; then
                    save_config "$CFG_IP" "$CFG_DEST_PORT" "$INPUT_VALUE" "$CFG_PROTOCOL" "$CFG_TIMER"
                    pause_screen
                fi
                ;;

            4)
                if prompt_protocol; then
                    save_config "$CFG_IP" "$CFG_DEST_PORT" "$CFG_EXTERNAL_PORT" "$INPUT_VALUE" "$CFG_TIMER"
                    pause_screen
                fi
                ;;

            5)
                if prompt_timer; then
                    save_config "$CFG_IP" "$CFG_DEST_PORT" "$CFG_EXTERNAL_PORT" "$CFG_PROTOCOL" "$INPUT_VALUE"
                    pause_screen
                fi
                ;;

            0)
                return
                ;;

            *)
                echo
                echo "Invalid choice."
                sleep 1
                ;;

        esac
    done
}

# ========================================
# MAIN MENU
# ========================================

initial_check || exit 1

first_run_menu

while true; do

    if ! load_config; then
        first_run_menu
    fi

    clear

    echo
    echo "portmanager_android"
    echo

    show_summary

    echo
    echo
    echo "1) Open port"
    echo
    echo "2) Close port"
    echo
    echo "3) Show port status"
    echo
    echo
    echo "4) Configure"
    echo
    echo
    echo "9) Run Setup / Update"
    echo
    echo "0) Exit"
    echo
    echo

    read -r -p "Choose what to do: " choice || exit 0

    case "$choice" in

        1)
            open_port
            ;;

        2)
            close_port
            ;;

        3)
            show_port_status
            ;;

        4)
            configure_menu
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
