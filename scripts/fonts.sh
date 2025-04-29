#!/bin/bash

USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo "Error: Could not determine username."; exit 1; }

LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
BRAVE_DESKTOP_FILE="brave-browser.desktop"
VESKTOP_DESKTOP_FILE="dev.vencord.Vesktop.desktop"
BRAVE_SOURCE_DIR="/usr/share/applications"
USER_DIR="$HOME/.local/share/applications"
VESKTOP_SOURCE_DIR="$HOME/.local/share/flatpak/exports/share/applications"
ARGUMENT="--enable-blink-features=MiddleClickAutoscroll"
EXTENSION_URL="https://github.com/jangxx/netflix-1080p/releases/download/v1.32.0/netflix-1080p-1.32.0.crx"
EXTENSION_DIR="$HOME/.config/brave-extensions/netflix-1080p"
EXTENSION_ID="mdlbikciddolbenfkgggdegphnhmnfcg"
VESKTOP_CONFIG_FILE="/home/$USER/.var/app/dev.vencord.Vesktop/config/vesktop/settings.json"
VESKTOP_CSS_FILE="/home/$USER/.var/app/dev.vencord.Vesktop/config/vesktop/settings/quickCss.css"
VESKTOP_VENCORD_SETTINGS="/home/$USER/.var/app/dev.vencord.Vesktop/config/vesktop/settings/settings.json"
FONT_NAME="Alef"  # Change this to your desired Hebrew font

[ "$EUID" -eq 0 ] && { echo "Error: This script must not be run as root."; exit 1; }

command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found. This script requires Arch Linux."; exit 1; }

ping -c 1 archlinux.org >/dev/null 2>&1 || { echo "Error: No internet connection."; exit 1; }

mkdir -p "$(dirname "$LOG_FILE")" || { echo "Error: Failed to create $(dirname "$LOG_FILE")"; exit 1; }
mkdir -p "$BACKUP_DIR" || { echo "Error: Failed to create $BACKUP_DIR"; exit 1; }
touch "$LOG_FILE" || { echo "Error: Failed to create $LOG_FILE"; exit 1; }
echo "[$(date)] New installation session (brave-vesktop)" >> "$LOG_FILE"

[ ! -f "$BRAVE_SOURCE_DIR/$BRAVE_DESKTOP_FILE" ] && { echo "Error: $BRAVE_DESKTOP_FILE not found in $BRAVE_SOURCE_DIR"; exit 1; }

mkdir -p "$USER_DIR" || { echo "Error: Failed to create $USER_DIR"; exit 1; }

if [ ! -f "$USER_DIR/$BRAVE_DESKTOP_FILE" ]; then
    cp "$BRAVE_SOURCE_DIR/$BRAVE_DESKTOP_FILE" "$USER_DIR/$BRAVE_DESKTOP_FILE" || { echo "Error: Failed to copy $BRAVE_DESKTOP_FILE to $USER_DIR"; exit 1; }
    echo "CREATED_DESKTOP: $BRAVE_DESKTOP_FILE -> $USER_DIR/$BRAVE_DESKTOP_FILE" >> "$LOG_FILE"
    echo "Copied $BRAVE_DESKTOP_FILE to $USER_DIR"
else
    echo "Skipping: $BRAVE_DESKTOP_FILE already exists in $USER_DIR"
fi

if [ -f "$USER_DIR/$BRAVE_DESKTOP_FILE" ]; then
    if ! ls "$BACKUP_DIR/$BRAVE_DESKTOP_FILE".* >/dev/null 2>&1; then
        cp "$USER_DIR/$BRAVE_DESKTOP_FILE" "$BACKUP_DIR/$BRAVE_DESKTOP_FILE.$(date +%s)" || { echo "Error: Failed to backup $BRAVE_DESKTOP_FILE"; exit 1; }
        echo "BACKUP_DESKTOP: $BRAVE_DESKTOP_FILE -> $BACKUP_DIR/$BRAVE_DESKTOP_FILE.$(date +%s)" >> "$LOG_FILE"
        echo "Created backup of $BRAVE_DESKTOP_FILE"
    else
        echo "Skipping: Backup of $BRAVE_DESKTOP_FILE already exists"
    fi
fi

if grep -q -- "--load-extension=$EXTENSION_DIR" "$USER_DIR/$BRAVE_DESKTOP_FILE"; then
    sed -i "s| --load-extension=$EXTENSION_DIR||" "$USER_DIR/$BRAVE_DESKTOP_FILE"
    echo "Removed invalid --load-extension flag from $BRAVE_DESKTOP_FILE"
fi

if [[ -d "$EXTENSION_DIR" ]]; then
    rm -rf "$EXTENSION_DIR"
    echo "Removed invalid extension directory $EXTENSION_DIR"
fi

if grep -q -- "$ARGUMENT" "$USER_DIR/$BRAVE_DESKTOP_FILE"; then
    echo "The $ARGUMENT is already present in the Exec line for Brave"
else
    sed -i "/^Exec=/ s|$| $ARGUMENT|" "$USER_DIR/$BRAVE_DESKTOP_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to modify Exec line in $BRAVE_DESKTOP_FILE"
        exit 1
    fi
    echo "Successfully added $ARGUMENT to the Exec line in $USER_DIR/$BRAVE_DESKTOP_FILE"
    echo "New Exec line:"
    grep "^Exec=" "$USER_DIR/$BRAVE_DESKTOP_FILE"
fi

mkdir -p "$EXTENSION_DIR"
wget --no-config -O /tmp/netflix-1080p.crx "$EXTENSION_URL"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download extension from $EXTENSION_URL"
    exit 1
fi
unzip -o /tmp/netflix-1080p.crx -d "$EXTENSION_DIR"
if [[ ! -f "$EXTENSION_DIR/manifest.json" ]]; then
    echo "Error: Failed to unpack extension to $EXTENSION_DIR (manifest.json missing)"
    exit 1
fi
rm /tmp/netflix-1080p.crx

if grep -q -- "--load-extension=$EXTENSION_DIR" "$USER_DIR/$BRAVE_DESKTOP_FILE"; then
    echo "The extension is already loaded in the Exec line for Brave"
else
    sed -i "/^Exec=/ s|$| --load-extension=$EXTENSION_DIR|" "$USER_DIR/$BRAVE_DESKTOP_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to add extension to $BRAVE_DESKTOP_FILE"
        exit 1
    fi
    echo "Successfully added extension to the Exec line in $USER_DIR/$BRAVE_DESKTOP_FILE"
    echo "New Exec line:"
    grep "^Exec=" "$USER_DIR/$BRAVE_DESKTOP_FILE"
fi

if ! command -v flatpak >/dev/null 2>&1; then
    sudo pacman -Syu --noconfirm flatpak || { echo "Error: Failed to install flatpak"; exit 1; }
    echo "INSTALLED_PACKAGE: flatpak" >> "$LOG_FILE"
    echo "Installed flatpak"
else
    echo "Skipping: flatpak already installed"
fi

if ! flatpak --user remotes | grep -q flathub; then
    flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || { echo "Error: Failed to add flathub repository"; exit 1; }
    echo "ADDED_FLATHUB: flathub" >> "$LOG_FILE"
    echo "Added flathub repository"
else
    echo "Skipping: flathub repository already added"
fi

if ! flatpak list | grep -q dev.vencord.Vesktop; then
    flatpak install --user -y flathub dev.vencord.Vesktop || { echo "Error: Failed to install Vesktop"; exit 1; }
    echo "INSTALLED_FLATPAK: dev.vencord.Vesktop" >> "$LOG_FILE"
    echo "Installed Vesktop"
else
    echo "Skipping: Vesktop already installed"
fi

[ ! -f "$VESKTOP_SOURCE_DIR/$VESKTOP_DESKTOP_FILE" ] && { echo "Error: $VESKTOP_DESKTOP_FILE not found in $VESKTOP_SOURCE_DIR"; exit 1; }

if [ ! -f "$USER_DIR/$VESKTOP_DESKTOP_FILE" ]; then
    cp "$VESKTOP_SOURCE_DIR/$VESKTOP_DESKTOP_FILE" "$USER_DIR/$VESKTOP_DESKTOP_FILE" || { echo "Error: Failed to copy $VESKTOP_DESKTOP_FILE to $USER_DIR"; exit 1; }
    echo "CREATED_DESKTOP: $VESKTOP_DESKTOP_FILE -> $USER_DIR/$VESKTOP_DESKTOP_FILE" >> "$LOG_FILE"
    echo "Copied $VESKTOP_DESKTOP_FILE to $USER_DIR"
else
    echo "Skipping: $VESKTOP_DESKTOP_FILE already exists in $USER_DIR"
fi

if [ -f "$USER_DIR/$VESKTOP_DESKTOP_FILE" ]; then
    if ! ls "$BACKUP_DIR/$VESKTOP_DESKTOP_FILE".* >/dev/null 2>&1; then
        cp "$USER_DIR/$VESKTOP_DESKTOP_FILE" "$BACKUP_DIR/$VESKTOP_DESKTOP_FILE.$(date +%s)" || { echo "Error: Failed to backup $VESKTOP_DESKTOP_FILE"; exit 1; }
        echo "BACKUP_DESKTOP: $VESKTOP_DESKTOP_FILE -> $BACKUP_DIR/$VESKTOP_DESKTOP_FILE.$(date +%s)" >> "$LOG_FILE"
        echo "Created backup of $VESKTOP_DESKTOP_FILE"
    else
        echo "Skipping: Backup of $VESKTOP_DESKTOP_FILE already exists"
    fi
fi

if grep -q -- "$ARGUMENT" "$USER_DIR/$VESKTOP_DESKTOP_FILE"; then
    echo "Skipping: $ARGUMENT already present in $VESKTOP_DESKTOP_FILE"
else
    sed -i "/^Exec=/ s/@@u %U @@/$ARGUMENT @@u %U @@/" "$USER_DIR/$VESKTOP_DESKTOP_FILE" || { echo "Error: Failed to modify Exec line in $VESKTOP_DESKTOP_FILE"; exit 1; }
    echo "MODIFIED_DESKTOP: $VESKTOP_DESKTOP_FILE -> Added $ARGUMENT" >> "$LOG_FILE"
    echo "Added $ARGUMENT to $VESKTOP_DESKTOP_FILE"
    echo "New Exec line:"
    grep "^Exec=" "$USER_DIR/$VESKTOP_DESKTOP_FILE"
fi

if [ -f "$VESKTOP_CONFIG_FILE" ]; then
    if ! jq '.hardwareAcceleration == false' "$VESKTOP_CONFIG_FILE" | grep -q true; then
        cp "$VESKTOP_CONFIG_FILE" "$BACKUP_DIR/settings.json.$(date +%s)" || { echo "Error: Failed to backup $VESKTOP_CONFIG_FILE"; exit 1; }
        echo "BACKUP_CONFIG: $VESKTOP_CONFIG_FILE -> $BACKUP_DIR/settings.json.$(date +%s)" >> "$LOG_FILE"
        echo "Created backup of $VESKTOP_CONFIG_FILE"
        jq '.hardwareAcceleration = false' "$VESKTOP_CONFIG_FILE" > temp.json && mv temp.json "$VESKTOP_CONFIG_FILE" || { echo "Error: Failed to disable hardware acceleration in $VESKTOP_CONFIG_FILE"; exit 1; }
        echo "MODIFIED_CONFIG: $VESKTOP_CONFIG_FILE -> Disabled hardware acceleration" >> "$LOG_FILE"
        echo "Disabled hardware acceleration in Vesktop"
    else
        echo "Skipping: Hardware acceleration already disabled in $VESKTOP_CONFIG_FILE"
    fi
else
    echo "Warning: $VESKTOP_CONFIG_FILE not found. Hardware acceleration not modified."
    echo "LOGGED_WARNING: $VESKTOP_CONFIG_FILE not found for hardware acceleration" >> "$LOG_FILE"
fi

# Ensure the desired Hebrew font is installed
if ! fc-list :lang=he | grep -qi "$FONT_NAME"; then
    yay -Syu --noconfirm ttf-alef || { echo "Error: Failed to install ttf-alef font"; exit 1; }
    fc-cache -f -v || { echo "Error: Failed to update font cache"; exit 1; }
    echo "INSTALLED_FONT: $FONT_NAME" >> "$LOG_FILE"
    echo "Installed $FONT_NAME font and updated font cache"
else
    echo "Skipping: $FONT_NAME font already installed"
fi

FONT_CSS="
\* Custom font for Vesktop \*
::placeholder, body, button, input, select, textarea {
    font-family: 'FONT_NAME', sans-serif;
    text-rendering: optimizeLegibility;
}
"

if [ -f "$VESKTOP_CSS_FILE" ]; then
    if ! grep -q "font-family: '$FONT_NAME'" "$VESKTOP_CSS_FILE"; then
        cp "$VESKTOP_CSS_FILE" "$BACKUP_DIR/quickCss.css.$(date +%s)" || { echo "Error: Failed to backup $VESKTOP_CSS_FILE"; exit 1; }
        echo "BACKUP_CSS: $VESKTOP_CSS_FILE -> $BACKUP_DIR/quickCss.css.$(date +%s)" >> "$LOG_FILE"
        echo "Created backup of $VESKTOP_CSS_FILE"
        echo "$FONT_CSS" >> "$VESKTOP_CSS_FILE" || { echo "Error: Failed to append font CSS to $VESKTOP_CSS_FILE"; exit 1; }
        echo "MODIFIED_CSS: $VESKTOP_CSS_FILE -> Added custom font CSS for $FONT_NAME" >> "$LOG_FILE"
        echo "Added custom font CSS to $VESKTOP_CSS_FILE"
    else
        echo "Skipping: Custom font CSS for $FONT_NAME already present in $VESKTOP_CSS_FILE"
    fi
else
    mkdir -p "$(dirname "$VESKTOP_CSS_FILE")" || { echo "Error: Failed to create directory for $VESKTOP_CSS_FILE"; exit 1; }
    echo "$FONT_CSS" > "$VESKTOP_CSS_FILE" || { echo "Error: Failed to create $VESKTOP_CSS_FILE with font CSS"; exit 1; }
    echo "CREATED_CSS: $VESKTOP_CSS_FILE -> Added custom font CSS for $FONT_NAME" >> "$LOG_FILE"
    echo "Created $VESKTOP_CSS_FILE with custom font CSS"
fi

echo "Installation and modification complete!"
exit 0
