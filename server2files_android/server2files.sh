
#!/data/data/com.termux/files/usr/bin/bash

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"

pause_screen() {
    echo
    read -r -p "Press Enter to continue..."
}

run_app() {
    local app_file="$1"

    if [ ! -f "$app_file" ]; then
        echo
        echo "Error: application script is missing:"
        echo "$app_file"
        pause_screen
        return 1
    fi

    bash "$app_file"
}

run_setup() {
    if [ ! -f "$APP_DIR/server2files_setup.sh" ]; then
        echo
        echo "Error: setup file is missing:"
        echo "$APP_DIR/server2files_setup.sh"
        pause_screen
        return 1
    fi

    bash "$APP_DIR/server2files_setup.sh"
}

# Keep the launcher alive when CTRL+C stops a child server.
# Each application still receives CTRL+C normally.
trap ':' INT

while true; do
    clear

    echo
    echo "server2files_android"
    echo
    echo
    echo "1) HTTPserver"
    echo
    echo "2) Portmanager"
    echo
    echo "3) FTPserver"
    echo
    echo "4) MegaServer"
    echo
    echo
    echo "9) Run Setup / Update"
    echo
    echo "0) Exit"
    echo

    if ! read -r -p "Choose what to do: " choice; then
        echo
        exit 0
    fi

    case "$choice" in

        1)
            run_app "$APP_DIR/httpserver_android/httpserver.sh"
            ;;

        2)
            run_app "$APP_DIR/portmanager_android/portmanager.sh"
            ;;

        3)
            run_app "$APP_DIR/ftpserver_android/ftpserver.sh"
            ;;

        4)
            run_app "$APP_DIR/startmegaserver.sh"
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

