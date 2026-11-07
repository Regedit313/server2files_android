
#!/data/data/com.termux/files/usr/bin/bash

clear

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"
FTP_DIR="/storage/emulated/0/FTPshare"

echo
echo "ftpserver_android Setup / Update"
echo

echo "Updating Termux..."
echo

if ! pkg update -y; then
    echo
    echo "Error: Termux update failed."
    echo "Please check your internet connection and try again."
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

if ! pkg upgrade -y; then
    echo
    echo "Error: Termux upgrade failed."
    echo "Please check your internet connection and try again."
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

if [ ! -d ~/storage/shared ]; then
    echo
    echo "Setting up storage..."
    echo "If Android asks for permission, please allow it."
    echo

    if command -v termux-setup-storage >/dev/null 2>&1; then
        termux-setup-storage
    else
        echo
        echo "Warning: termux-setup-storage command was not found."
        echo "Storage access may not be configured correctly."
    fi
else
    echo
    echo "Storage is already configured."
fi

echo
echo "Creating/checking shared FTP folder..."

if ! mkdir -p "$FTP_DIR"; then
    echo
    echo "Error: cannot create FTPshare:"
    echo "$FTP_DIR"
    echo "Please grant Termux storage access and run setup again."
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

echo "Shared folder: $FTP_DIR"
echo

echo "Installing Python..."

if ! pkg install -y python; then
    echo
    echo "Error: Python installation failed."
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

hash -r

echo
echo "Installing/updating pyftpdlib..."

if ! python -m pip install -U pyftpdlib; then
    echo
    echo "Error: pyftpdlib installation failed."
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

echo
echo "Checking pyftpdlib..."

if ! python -c 'import pyftpdlib'; then
    echo
    echo "Error: pyftpdlib is not available."
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

echo "pyftpdlib is available."
echo

echo "Setting script permissions..."

chmod +x "$APP_DIR/ftpserver.sh" 2>/dev/null
chmod +x "$APP_DIR/ftpserver_setup.sh" 2>/dev/null
chmod +x "$APP_DIR/ftpserver_termuxshortcut.sh" 2>/dev/null

echo
echo "Checking project files..."

missing=0

if [ ! -f "$APP_DIR/ftpserver.sh" ]; then
    echo "- Missing: ftpserver.sh"
    missing=1
fi

if [ ! -f "$APP_DIR/ftpserver_setup.sh" ]; then
    echo "- Missing: ftpserver_setup.sh"
    missing=1
fi

if [ ! -f "$APP_DIR/ftpserver_termuxshortcut.sh" ]; then
    echo "- Missing: ftpserver_termuxshortcut.sh"
    missing=1
fi

if [ ! -d "$FTP_DIR" ]; then
    echo "- Missing: FTPshare"
    missing=1
fi

if [ "$missing" -ne 0 ]; then
    echo
    echo "Warning: one or more project files/folders are missing."
    echo
fi

echo
echo "Installation completed."
echo
echo "Shared FTP folder:"
echo "$FTP_DIR"
echo
echo "Start the server by launching:"
echo "$APP_DIR/ftpserver.sh"
echo
echo "The server runs on port 2121."
echo "Press CTRL+C to stop it."
echo
read -p "Press Enter to continue..."
