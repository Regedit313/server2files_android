
#!/data/data/com.termux/files/usr/bin/bash

clear

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"

echo
echo "portmanager_android Setup / Update"
echo

echo "Updating Termux..."
echo

if ! pkg update -y; then
    echo
    echo "Error: Termux update failed."
    echo "Please check your internet connection and try again."
    echo
    read -r -p "Press Enter to continue..."
    exit 1
fi

if ! pkg upgrade -y; then
    echo
    echo "Error: Termux upgrade failed."
    echo "Please check your internet connection and try again."
    echo
    read -r -p "Press Enter to continue..."
    exit 1
fi

if [ ! -d "$HOME/storage/shared" ]; then
    echo
    echo "Setting up storage..."
    echo "If Android asks for permission, please allow it."
    echo

    if command -v termux-setup-storage >/dev/null 2>&1; then
        termux-setup-storage
    else
        echo
        echo "Warning: termux-setup-storage command was not found."
    fi
else
    echo
    echo "Storage is already configured."
fi

echo
echo "Installing/checking miniupnpc and jq..."
echo

if ! pkg install -y miniupnpc jq; then
    echo
    echo "Error: dependency installation failed."
    echo
    read -r -p "Press Enter to continue..."
    exit 1
fi

hash -r

echo
echo "Checking dependencies..."

if ! command -v upnpc >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo
    echo "Error: miniupnpc or jq is not available."
    echo
    read -r -p "Press Enter to continue..."
    exit 1
fi

echo "Required tools are available."
echo

echo "Setting script permissions..."

chmod +x "$APP_DIR/portmanager.sh" 2>/dev/null
chmod +x "$APP_DIR/portmanager_setup.sh" 2>/dev/null
chmod +x "$APP_DIR/portmanager_termuxshortcut.sh" 2>/dev/null

echo
echo "Checking project files..."

missing=0

if [ ! -f "$APP_DIR/portmanager.sh" ]; then
    echo "- Missing: portmanager.sh"
    missing=1
fi

if [ ! -f "$APP_DIR/portmanager_setup.sh" ]; then
    echo "- Missing: portmanager_setup.sh"
    missing=1
fi

if [ ! -f "$APP_DIR/portmanager_termuxshortcut.sh" ]; then
    echo "- Missing: portmanager_termuxshortcut.sh"
    missing=1
fi

if [ "$missing" -ne 0 ]; then
    echo
    echo "Warning: one or more project files are missing."
fi

echo
echo "Installation completed."
echo
echo "The configuration file is created after initial configuration."
echo
echo "Start the application by launching:"
echo "$APP_DIR/portmanager.sh"
echo

read -r -p "Press Enter to continue..."
