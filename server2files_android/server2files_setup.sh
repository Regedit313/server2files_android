
#!/data/data/com.termux/files/usr/bin/bash

clear

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"

echo
echo "server2files_android Setup / Update"
echo
echo "Checking project files..."
echo

missing=0

for file in \
    "$APP_DIR/server2files.sh" \
    "$APP_DIR/server2files_setup.sh" \
    "$APP_DIR/server2files_termuxshortcut.sh" \
    "$APP_DIR/startmegaserver.sh" \
    "$APP_DIR/httpserver_android/httpserver.sh" \
    "$APP_DIR/httpserver_android/httpserver_setup.sh" \
    "$APP_DIR/portmanager_android/portmanager.sh" \
    "$APP_DIR/portmanager_android/portmanager_setup.sh" \
    "$APP_DIR/ftpserver_android/ftpserver.sh" \
    "$APP_DIR/ftpserver_android/ftpserver_setup.sh"; do

    if [ ! -f "$file" ]; then
        echo "- Missing: ${file#"$APP_DIR"/}"
        missing=1
    fi

done

echo
echo "Setting script permissions..."
echo

for file in \
    "$APP_DIR/server2files.sh" \
    "$APP_DIR/server2files_setup.sh" \
    "$APP_DIR/server2files_termuxshortcut.sh" \
    "$APP_DIR/startmegaserver.sh" \
    "$APP_DIR/httpserver_android/httpserver.sh" \
    "$APP_DIR/httpserver_android/httpserver_setup.sh" \
    "$APP_DIR/portmanager_android/portmanager.sh" \
    "$APP_DIR/portmanager_android/portmanager_setup.sh" \
    "$APP_DIR/ftpserver_android/ftpserver.sh" \
    "$APP_DIR/ftpserver_android/ftpserver_setup.sh"; do

    if [ -f "$file" ]; then
        chmod +x "$file" 2>/dev/null || true
    fi

done

if [ "$missing" -ne 0 ]; then
    echo "Warning: one or more project files are missing."
else
    echo "All required project files are present."
fi

echo
echo "No server dependencies are installed by this setup."
echo "Each application manages its own dependencies and updates."
echo
echo "Setup check completed."
echo
read -r -p "Press Enter to continue..."

