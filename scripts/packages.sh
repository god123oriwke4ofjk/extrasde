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
STEAM_CONFIG="/home/$USER/.steam/steam/userdata/*/config/localconfig.vdf"

VESKTOP_PLUGINS_TO_ENABLE=(
    "ImageZoom"
    "MemberCount"
    "SpotifyCrack"
)

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

for pkg in xclip wget unzip linux-lts linux-lts-headers wine steam proton mpv ffmpeg; do
    if ! pacman -Qs "$pkg" >/dev/null 2>&1; then
        sudo pacman -Syu --noconfirm "$pkg" || { echo "Error: Failed to install $pkg"; exit 1; }
        echo "INSTALLED_PACKAGE: $pkg" >> "$LOG_FILE"
        echo "Installed $pkg"
    else
        echo "Skipping: $pkg already installed"
    fi
done

if ! yay -Qs brave-bin >/dev/null 2>&1; then
    yay -S --noconfirm brave-bin || { echo "Error: Failed to install brave-bin"; exit 1; }
    echo "INSTALLED_PACKAGE: brave-bin" >> "$LOG_FILE"
    echo "Installed brave-bin"
else
    echo "Skipping: brave-bin already installed"
fi

if [[ ! -d "$HOME/.local/share/osu-wine" ]]; then
    echo "Installing osu"
    git clone https://github.com/NelloKudo/osu-winello.git /tmp/osu || { echo "Error: Failed to clone osu repository"; exit 1;}
    cd /tmp/osu || { echo "Error: Failed to change to /tmp/osu"; exit 1; }
    chmod +x ./osu_winello.sh || { echo "Error: failed to grant permission to osu_winello.sh"; exit 1; }
    echo "1" | ./osu_winello.sh
    cd - || exit 1
    rm -rf /tmp/osu
    echo "INSTALLED_PACKAGE: osu" >> "$LOG_FILE"
    echo "Installed osu"
else
    echo "Skipped: osu-wine is already installed"
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

#STEAM
echo "Setting up steam"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo "Enabling multilib repository..."
    sudo sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /etc/pacman.conf
    sudo pacman -Syy
else
    echo "Multilib repository is already enabled."
fi

if ! pacman -Qs "proton-ge-custom" > /dev/null; then
    echo "Installing proton-ge-custom from AUR..."
    yay -S --noconfirm proton-ge-custom
else
    echo "proton-ge-custom already installed."
fi

echo "Configuring Steam Play..."
if [[ ! -d "$HOME/.steam/steam" ]]; then
    echo "Steam directory not found. Creating default Steam directory..."
    mkdir -p $HOME/.steam/steam
fi

if compgen -G "$STEAM_CONFIG" > /dev/null; then
    for config in $STEAM_CONFIG; do
        if [[ -f "$STEAM_CONFIG" ]]; then
            echo "Found Steam config at $config. Enabling Steam Play..."
            cp "$config" "$config.bak"
            sed -i '/"SteamPlay"/,/}/ s/"EnableForAll"\s*"\w*"/"EnableForAll" "1"/' "$config"
            sed -i '/"SteamPlay"/,/}/ s/"DesiredVersion"\s*".*"/"DesiredVersion" "'"${proton_version}"'"/' "$config"
        fi
    done
else
    echo "No Steam user data found yet. Setting up default configuration..."
    local userdata_dir="$HOME/.steam/steam/userdata/0/config"
    mkdir -p "$userdata_dir"
    cat << EOF > "$userdata_dir/localconfig.vdf"
"UserLocalConfigStore"
{
    "SteamPlay"
    {
        "EnableForAll" "1"
        "DesiredVersion" "$proton_version"
    }
}
EOF
    echo "Default Steam Play configuration created. Will apply after first login."
fi

echo "Finished setting up steam" 

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

for pkg in com.dec05eba.gpu_screen_recorder  dev.vencord.Vesktop  org.vinegarhq.Sober; do
    if ! flatpak list | grep -q "$pkg"; then
        flatpak install --user -y flathub "$pkg" || { echo "Error: Failed to install $pkg"; exit 1; }
        echo "INSTALLED_FLATPAK: $pkg" >> "$LOG_FILE"
        echo "Installed $pkg"
    else
        echo "Skipping: $pkg already installed"
    fi
done

if flatpak list | grep -q com.dec05eba.gpu_screen_recorder; then
    echo "Generating gpu-screen-recorder config files" 
    com.dec05eba.gpu_screen_recorder &
    sleep 1
    pkill com.dec05eba.gpu_screen_recorder
else
    echo "WARNING Cannot locate gpu-screen-recorder"
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

echo "SCript Finished"
exit 0
