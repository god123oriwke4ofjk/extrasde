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
EXTENSION_URL="https://github.com/jangxx/netflix-1080p/releases/download/v1.32.2/netflix-1080p-1.32.2.crx"
EXTENSION_DIR="$HOME/.config/brave-extensions/netflix-1080p"
EXTENSION_ID="mdlbikciddolbenfkgggdegphnhmnfcg"
VESKTOP_CONFIG_FILE="/home/$USER/.var/app/dev.vencord.Vesktop/config/vesktop/settings.json"
VESKTOP_CSS_FILE="/home/$USER/.var/app/dev.vencord.Vesktop/config/vesktop/settings/quickCss.css"
VESKTOP_VENCORD_SETTINGS="/home/$USER/.var/app/dev.vencord.Vesktop/config/vesktop/settings/settings.json"
HEBREW_FONT="David Libre"
FONT_PACKAGE="ttf-david-libre"

[ "$EUID" -eq 0 ] && { echo "Error: This script must not be run as root."; exit 1; }

command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found. This script requires Arch Linux."; exit 1; }

ping -c 1 archlinux.org >/dev/null 2>&1 || { echo "Error: No internet connection."; exit 1; }

mkdir -p "$(dirname "$LOG_FILE")" || { echo "Error: Failed to create $(dirname "$LOG_FILE")"; exit 1; }
mkdir -p "$BACKUP_DIR" || { echo "Error: Failed to create $BACKUP_DIR"; exit 1; }
touch "$LOG_FILE" || { echo "Error: Failed to create $LOG_FILE"; exit 1; }
echo "[$(date)] New installation session (brave-vesktop)" >> "$LOG_FILE"

if ! command -v yay >/dev/null 2>&1; then
    sudo pacman -Syu --noconfirm git base-devel || { echo "Error: Failed to install git and base-devel"; exit 1; }
    git clone https://aur.archlinux.org/yay.git /tmp/yay || { echo "Error: Failed to clone yay repository"; exit 1; }
    cd /tmp/yay || { echo "Error: Failed to change to /tmp/yay"; exit 1; }
    makepkg -si --noconfirm || { echo "Error: Failed to build and install yay"; exit 1; }
    cd - || exit 1
    rm -rf /tmp/yay
    echo "INSTALLED_PACKAGE: yay" >> "$LOG_FILE"
    echo "Installed yay"
else
    echo "Skipping: yay already installed"
fi

sudo pacman -Syu --noconfirm wget unzip jq || { echo "Error: Failed to install wget, unzip, and jq"; exit 1; }
echo "INSTALLED_PACKAGE: wget" >> "$LOG_FILE"
echo "INSTALLED_PACKAGE: unzip" >> "$LOG_FILE"
echo "INSTALLED_PACKAGE: jq" >> "$LOG_FILE"
echo "Installed wget, unzip, and jq"

if ! pacman -Qs "$FONT_PACKAGE" >/dev/null 2>&1; then
    sudo pacman -Syu --noconfirm "$FONT_PACKAGE" || { echo "Error: Failed to install $FONT_PACKAGE"; exit 1; }
    echo "INSTALLED_PACKAGE: $FONT_PACKAGE" >> "$LOG_FILE"
    echo "Installed $FONT_PACKAGE"
else
    echo "Skipping: $FONT_PACKAGE already installed"
fi

if ! yay -Qs brave-bin >/dev/null 2>&1; then
    yay -S --noconfirm brave-bin || { echo "Error: Failed to install brave-bin"; exit 1; }
    echo "INSTALLED_PACKAGE: brave-bin" >> "$LOG_FILE"
    echo "Installed brave-bin"
else
    echo "Skipping: brave-bin already installed"
fi

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
    cp "$USER_DIR/$BRAVE_DESKTOP_FILE" "$BACKUP_DIR/$BRAVE_DESKTOP_FILE.$(date +%s)" || { echo "Error: Failed to backup $BRAVE_DESKTOP_FILE"; exit 1; }
    echo "BACKUP_DESKTOP: $BRAVE_DESKTOP_FILE -> $BACKUP_DIR/$BRAVE_DESKTOP_FILE.$(date +%s)" >> "$LOG_FILE"
    echo "Created backup of $BRAVE_DESKTOP_FILE"
fi

if grep -q -- "--load-extension=$EXTENSION_DIR" "$USER_DIR/$BRAVE_DESKTOP_FILE"; then
    sed -i "s| --load-extension=$EXTENSION_DIR||" "$USER_DIR/$BRAVE_DESKTOP_FILE" || { echo "Error: Failed to clean invalid extension flag"; exit 1; }
    echo "Removed invalid --load-extension flag from $BRAVE_DESKTOP_FILE"
fi

if [ -d "$EXTENSION_DIR" ]; then
    rm -rf "$EXTENSION_DIR" || { echo "Error: Failed to remove $EXTENSION_DIR"; exit 1; }
    echo "Removed invalid extension directory $EXTENSION_DIR"
fi

if grep -q -- "$ARGUMENT" "$USER_DIR/$BRAVE_DESKTOP_FILE"; then
    echo "Skipping: $ARGUMENT already present in $BRAVE_DESKTOP_FILE"
else
    sed -i "/^Exec=/ s|$| $ARGUMENT|" "$USER_DIR/$BRAVE_DESKTOP_FILE" || { echo "Error: Failed to modify Exec line in $BRAVE_DESKTOP_FILE"; exit 1; }
    echo "MODIFIED_DESKTOP: $BRAVE_DESKTOP_FILE -> Added $ARGUMENT" >> "$LOG_FILE"
    echo "Added $ARGUMENT to $BRAVE_DESKTOP_FILE"
    echo "New Exec line:"
    grep "^Exec=" "$USER_DIR/$BRAVE_DESKTOP_FILE"
fi

mkdir -p "$EXTENSION_DIR" || { echo "Error: Failed to create $EXTENSION_DIR"; exit 1; }
wget -q --no-config -O /tmp/netflix-1080p.crx "$EXTENSION_URL" || { echo "Error: Failed to download extension from $EXTENSION_URL"; exit 1; }
unzip -o /tmp/netflix-1080p.crx -d "$EXTENSION_DIR" || { echo "Error: Failed to unzip extension"; exit 1; }
[ ! -f "$EXTENSION_DIR/manifest.json" ] && { echo "Error: Failed to unpack extension to $EXTENSION_DIR (manifest.json missing)"; exit 1; }
rm -f /tmp/netflix-1080p.crx
echo "CREATED_EXTENSION: $EXTENSION_DIR" >> "$LOG_FILE"
echo "Installed Netflix 1080p extension to $EXTENSION_DIR"

if grep -q -- "--load-extension=$EXTENSION_DIR" "$USER_DIR/$BRAVE_DESKTOP_FILE"; then
    echo "Skipping: Extension already loaded in $BRAVE_DESKTOP_FILE"
else
    sed -i "/^Exec=/ s|$| --load-extension=$EXTENSION_DIR|" "$USER_DIR/$BRAVE_DESKTOP_FILE" || { echo "Error: Failed to add extension to $BRAVE_DESKTOP_FILE"; exit 1; }
    echo "MODIFIED_DESKTOP: $BRAVE_DESKTOP_FILE -> Added --load-extension=$EXTENSION_DIR" >> "$LOG_FILE"
    echo "Added extension to $BRAVE_DESKTOP_FILE"
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
    cp "$VESKTOP_SOURCE_DIR/$VESKTOP_DESKTOP_FILE" "$USER_DIR/$VESKTOP_DESKTOP_FILE" || { echo "Error: Failed to copy(Environment) $VESKTOP_DESKTOP_FILE to $USER_DIR"; exit 1; }
    echo "CREATED_DESKTOP: $VESKTOP_DESKTOP_FILE -> $USER_DIR/$VESKTOP_DESKTOP_FILE" >> "$LOG_FILE"
    echo "Copied $VESKTOP_DESKTOP_FILE to $USER_DIR"
else
    echo "Skipping: $VESKTOP_DESKTOP_FILE already exists in $USER_DIR"
fi

if [ -f "$USER_DIR/$VESKTOP_DESKTOP_FILE" ]; then
    cp "$USER_DIR/$VESKTOP_DESKTOP_FILE" "$BACKUP_DIR/$VESKTOP_DESKTOP_FILE.$(date +%s)" || { echo "Error: Failed to backup $VESKTOP_DESKTOP_FILE"; exit 1; }
    echo "BACKUP_DESKTOP: $VESKTOP_DESKTOP_FILE -> $BACKUP_DIR/$VESKTOP_DESKTOP_FILE.$(date +%s)" >> "$LOG_FILE"
    echo "Created backup of $VESKTOP_DESKTOP_FILE"
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

# Disable Vesktop hardware acceleration
if [ -f "$VESKTOP_CONFIG_FILE" ]; then
    cp "$VESKTOP_CONFIG_FILE" "$BACKUP_DIR/settings.json.$(date +%s)" || { echo "Error: Failed to backup $VESKTOP_CONFIG_FILE"; exit 1; }
    echo "BACKUP_CONFIG: $VESKTOP_CONFIG_FILE -> $BACKUP_DIR/settings.json.$(date +%s)" >> "$LOG_FILE"
    echo "Created backup of $VESKTOP_CONFIG_FILE"
    jq '.hardwareAcceleration = false' "$VESKTOP_CONFIG_FILE" > temp.json && mv temp.json "$VESKTOP_CONFIG_FILE" || { echo "Error: Failed to disable hardware acceleration in $VESKTOP_CONFIG_FILE"; exit 1; }
    echo "MODIFIED_CONFIG: $VESKTOP_CONFIG_FILE -> Disabled hardware acceleration" >> "$LOG_FILE"
    echo "Disabled hardware acceleration in Vesktop"
else
    echo "Warning: $VESKTOP_CONFIG_FILE not found. Hardware acceleration not modified."
    echo "LOGGED_WARNING: $VESKTOP_CONFIG_FILE not found for hardware acceleration" >> "$LOG_FILE"
fi

# Ensure useQuickCss is enabled in Vencord settings
if [ -f "$VESKTOP_VENCORD_SETTINGS" ]; then
    cp "$VESKTOP_VENCORD_SETTINGS" "$BACKUP_DIR/vencord_settings.json.$(date +%s)" || { echo "Error: Failed to backup $VESKTOP_VENCORD_SETTINGS"; exit 1; }
    echo "BACKUP_CONFIG: $VESKTOP_VENCORD_SETTINGS -> $BACKUP_DIR/vencord_settings.json.$(date +%s)" >> "$LOG_FILE"
    echo "Created backup of $VESKTOP_VENCORD_SETTINGS"
    jq '.useQuickCss = true' "$VESKTOP_VENCORD_SETTINGS" > temp.json && mv temp.json "$VESKTOP_VENCORD_SETTINGS" || { echo "Error: Failed to enable useQuickCss in $VESKTOP_VENCORD_SETTINGS"; exit 1; }
    echo "MODIFIED_CONFIG: $VESKTOP_VENCORD_SETTINGS -> Enabled useQuickCss" >> "$LOG_FILE"
    echo "Enabled useQuickCss in Vencord settings"
else
    echo "Warning: $VESKTOP_VENCORD_SETTINGS not found. Cannot ensure useQuickCss is enabled."
    echo "LOGGED_WARNING: $VESKTOP_VENCORD_SETTINGS not found for useQuickCss" >> "$LOG_FILE"
fi

# Change Hebrew font via quickCss.css
mkdir -p "$(dirname "$VESKTOP_CSS_FILE")" || { echo "Error: Failed to create $(dirname "$VESKTOP_CSS_FILE")"; exit 1; }
if [ -f "$VESKTOP_CSS_FILE" ]; then
    cp "$VESKTOP_CSS_FILE" "$BACKUP_DIR/quickCss.css.$(date +%s)" || { echo "Error: Failed to backup $VESKTOP_CSS_FILE"; exit 1; }
    echo "BACKUP_CONFIG: $VESKTOP_CSS_FILE -> $BACKUP_DIR/quickCss.css.$(date +%s)" >> "$LOG_FILE"
    echo "Created backup of $VESKTOP_CSS_FILE"
fi
echo "* { font-family: \"$HEBREW_FONT\", Arial, sans-serif !important; }" >> "$VESKTOP_CSS_FILE" || { echo "Error: Failed to modify $VESKTOP_CSS_FILE"; exit 1; }
echo ":lang(he) { font-family: \"$HEBREW_FONT\", sans-serif; }" >> "$VESKTOP_CSS_FILE" || { echo "Error: Failed to modify $VESKTOP_CSS_FILE"; exit 1; }
echo "MODIFIED_CONFIG: $VESKTOP_CSS_FILE -> Set Hebrew font to $HEBREW_FONT" >> "$LOG_FILE"
echo "Set Hebrew font to $HEBREW_FONT in Vesktop"

echo "Warning: Adding $ARGUMENT may cause Brave or Vesktop to crash on some systems (e.g., Bazzite Linux with KDE Wayland)."
echo "If Brave crashes, restore the backup manually or run the undo script."
echo "If Vesktop crashes, restore the backup manually or run the undo script."
echo "Installation and modification complete!"
echo "LOGGED_ACTIONS: Completed brave-vesktop installation, disabled hardware acceleration, set Hebrew font" >> "$LOG_FILE"
exit 0
