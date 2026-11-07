
#!/data/data/com.termux/files/usr/bin/bash

clear

cd "$(dirname "$0")" || exit 1

APP_DIR="$(pwd -P)"
HTTP_DIR="/storage/emulated/0/FTPshare"
HFS_CWD="$HOME/.hfs_httpserver_android"
HFS_PUBLIC_CWD="$HOME/.hfs_httpserver_public"

echo
echo "httpserver_android Setup / Update"
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
echo "Creating/checking shared HTTP folder..."

if ! mkdir -p "$HTTP_DIR"; then
    echo
    echo "Error: cannot create FTPshare:"
    echo "$HTTP_DIR"
    echo "Please grant Termux storage access and run setup again."
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

echo "Shared folder: $HTTP_DIR"
echo

echo "Installing/checking Node.js and OpenSSL..."

# Keep any existing Node.js installation; avoid replacing it unnecessarily.
if ! command -v node >/dev/null 2>&1; then
    if ! pkg install -y nodejs-lts; then
        echo
        echo "Error: Node.js installation failed."
        echo
        read -p "Press Enter to continue..."
        exit 1
    fi
fi

if ! pkg install -y openssl; then
    echo
    echo "Error: OpenSSL installation failed."
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

hash -r

if ! command -v npm >/dev/null 2>&1; then
    echo
    echo "Installing npm..."

    if ! pkg install -y npm; then
        echo
        echo "Error: npm installation failed."
        echo
        read -p "Press Enter to continue..."
        exit 1
    fi
fi

echo
echo "Installing/updating HFS 3..."

if ! npm install -g hfs@latest; then
    echo
    echo "Error: HFS 3 installation failed."
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

hash -r

echo
echo "Checking HFS 3..."

if ! command -v node >/dev/null 2>&1 || ! command -v hfs >/dev/null 2>&1; then
    echo
    echo "Error: Node.js or HFS 3 is not available."
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

echo "HFS 3 is available."
echo

echo "Checking backup tools..."
echo

if ! command -v tar >/dev/null 2>&1; then
    echo "Installing tar..."
    echo

    if ! pkg install -y tar; then
        echo
        echo "Error: tar installation failed."
        echo
        read -p "Press Enter to continue..."
        exit 1
    fi
fi

echo "Backup tools are available."
echo

echo "Creating/checking HFS configuration folders..."

if ! mkdir -p "$HFS_CWD"; then
    echo
    echo "Error: cannot create private HFS configuration folder:"
    echo "$HFS_CWD"
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

if ! mkdir -p "$HFS_PUBLIC_CWD"; then
    echo
    echo "Error: cannot create public HFS configuration folder:"
    echo "$HFS_PUBLIC_CWD"
    echo
    read -p "Press Enter to continue..."
    exit 1
fi

echo "HFS configuration folders are available."
echo

echo "Setting script permissions..."

chmod +x "$APP_DIR/httpserver.sh" 2>/dev/null
chmod +x "$APP_DIR/httpserver_setup.sh" 2>/dev/null
chmod +x "$APP_DIR/httpserver_termuxshortcut.sh" 2>/dev/null

echo
echo "Checking project files..."

missing=0

if [ ! -f "$APP_DIR/httpserver.sh" ]; then
    echo "- Missing: httpserver.sh"
    missing=1
fi

if [ ! -f "$APP_DIR/httpserver_setup.sh" ]; then
    echo "- Missing: httpserver_setup.sh"
    missing=1
fi

if [ ! -f "$APP_DIR/httpserver_termuxshortcut.sh" ]; then
    echo "- Missing: httpserver_termuxshortcut.sh"
    missing=1
fi

if [ ! -d "$HTTP_DIR" ]; then
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
echo "Shared HTTP folder:"
echo "$HTTP_DIR"
echo
echo "Backup file location:"
echo "$APP_DIR/hfs_backup.tar.gz"
echo
echo "Start the server by launching:"
echo "$APP_DIR/httpserver.sh"
echo
echo "The server runs on port 8000."
echo "Browse / Upload: http://<ANDROID_IP>:8000/"
echo "On this phone: http://127.0.0.1:8000/"
echo "Press CTRL+C to stop it."
echo
read -p "Press Enter to continue..."

