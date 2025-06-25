#!/bin/bash
USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo "Error: Could not determine username."; exit 1; }
LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
BRAVE_DESKTOP_FILE="com.brave.Browser.desktop"
VESKTOP_DESKTOP_FILE="dev.vencord.Vesktop.desktop"
BRAVE_SOURCE_DIR="$HOME/.local/share/flatpak/exports/share/applications"
USER_DIR="$HOME/.local/share/applications"
VESKTOP_SOURCE_DIR="$HOME/.local/share/flatpak/exports/share/applications"
ARGUMENT="--enable-blink-features=MiddleClickAutoscroll"
EXTENSION_URL="https://github.com/jangxx/netflix-1080p/releases/download/v1.32.0/netflix-1080p-1.32.0.crx"
EXTENSION_DIR="$HOME/.var/app/com.brave.Browser/config/brave-extensions/netflix-1080p"
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
INSTALL_OSU=false
INSTALL_LTS=false
NETFLIX=false
NOCLIP=false
OSU_ONLY=false
HYPRSHELL_ONLY=false
help_function() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  osu           Install osu! via osu-winello"
    echo "  lts           Install Linux LTS kernel and headers"
    echo "  -netflix      Install Brave via Flatpak and Netflix 1080p extension"
    echo "  --noclip      Skip GPU Screen Recorder installation and configuration"
    echo "  osuonly       Install only osu! and skip all other installations"
    echo "  -hyprshell    Install and configure hyprshell only"
    echo "  -h, -help     Display this help message and exit"
    exit 0
}
for arg in "$@"; do
    case "$arg" in
        osu) INSTALL_OSU=true ;;
 lts) INSTALL_LTS=true ;;
        -netflix) NETFLIX=true ;;
        -noclip) NOCLIP=true ;;
        -osuonly) OSU_ONLY=true ;;
        -hyprshell) HYPRSHELL_ONLY=true ;;
        -outsudo) USE_YAD_SUDO=true ;;
        -h|-help) help_function ;;
        *) echo "Warning: Unknown argument '$arg' ignored" ;;
    esac
done
[ "$EUID" -eq 0 ] && { echo "Error: This script must not be run as root."; exit 1; }
if ! grep -qi "arch" /etc/os-release; then
    echo "Error: This script is designed for Arch Linux."
    exit 1
fi
sudo_yad() {
    if [[ "$USE_YAD_SUDO" == true ]]; then
        if sudo -n true 2>/dev/null; then
            sudo "$@"
            return $?
        else
            yad --title="Sudo Password Required" --window-icon=system-lock-screen \
                --text="Enter your sudo password to continue:" \
                --entry --hide-text --width=300 --center \
                --button="OK:0" --button="Cancel:1" | sudo -S -v "$@"
            return $?
        fi
    else
        sudo "$@"
        return $?
    fi
}
[ "$EUID" -eq "0" ] && { echo "Error: This script must not be run as root."; exit 1; }
if ! grep -qi "arch" /etc/os-release; then
    echo "Error: This script is designed for Arch Linux."
    exit 1
fi
command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found. This script requires Arch Linux."; exit 1; }
ping -c 1 8.8.8.8 >/dev/null 2>&1 || curl -s --head --connect-timeout 5 https://google.com >/dev/null 2>&1 || {
    echo "Error: No internet connection."
    exit 1
}
command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found. This script requires Arch Linux."; exit 1; }
ping -c 1 8.8.8.8 >/dev/null 2>&1 || curl -s --head --connect-timeout 5 https://google.com >/dev/null 2>&1 || { echo "Error: No internet connection."; exit 1; }
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Error: Failed to create $(dirname "$LOG_FILE")"; exit 1; }
mkdir -p "$BACKUP_DIR" || { echo "Error: Failed to create $BACKUP_DIR"; exit 1; }
touch "$LOG_FILE" || { echo "Error: Failed to create $LOG_FILE"; exit 1; }
echo "[$(date)] New installation session (brave-vesktop, noclip: $NOCLIP, osuonly: $OSU_ONLY, hyprshell_only: $HYPRSHELL_ONLY, outsudo: $USE_YAD_SUDO" >> "$LOG_FILE"
setup_hyprshell() {
    echo "Installing hyprshell"
    if yay -Ss ^hyprshell$ | grep -q ^hyprshell$; then
        echo "Skipping: hyprshell already installed"
    else
        yay -S --noconfirm hyprshell || { echo "Error: Failed to install hyprshell"; exit 1; }
        echo "INSTALLED_PACKAGE: hyprshell" >> "$LOG_FILE"
        echo "Installed hyprshell"
    fi
    echo "Configuring hyprshell"
    mkdir -p ~/.config/hyprshell/ || { echo "Error: Failed to create ~/.config/hyprshell/"; exit 1; }
    cat > ~/.config/hyprshell/config.toml << 'EOF'
layerrules = true
kill_bind = "ctrl+shift+alt, h"
[windows]
scale = 8.5
workspaces_per_row = 5
strip_html_from_workspace_title = true
[windows.overview.open]
key = "Tab"
modifier = "super"
[windows.overview.navigate]
forward = "tab"
[windows.overview.navigate.reverse]
mod = "shift"
[windows.overview.other]
filter_by = []
hide_filtered = false
[windows.switch.open]
modifier = "alt"
[windows.switch.navigate]
forward = "tab"
[windows.switch.navigate.reverse]
mod = "shift"
[windows.switch.other]
filter_by = []
hide_filtered = true
EOF
    echo "CREATED_FILE: ~/.config/hyprshell/config.toml" >> "$LOG_FILE"
    echo "Created hyprshell config.toml"
    cat > ~/.config/hyprshell/style.css << 'EOF'
:root {
    --border-color: rgba(90, 90, 120, 0.4);
    --border-color-active: rgba(239, 9, 9, 0.9);
    --bg-color: rgba(20, 20, 20, 0.9);
    --bg-color-hover: rgba(40, 40, 50, 1);
    --border-radius: 12px;
    --border-size: 3px;
    --border-style: solid;
    --border-style-secondary: dashed;
    --text-color: rgba(245, 245, 245, 1);
    --window-padding: 2px;
}
.monitor {}
.workspace {}
.client {}
.client-image {}
.launcher {}
.launcher-input {}
.launcher-results {}
.launcher-item {}
.launcher-exec {}
.launcher-key {}
.launcher-plugins {}
.launcher-plugin {}
EOF
    echo "CREATED_FILE: ~/.config/hyprshell/style.css" >> "$LOG_FILE"
    echo "Created hyprshell style.css"
    USERPREFS_FILE="$HOME/.config/hypr/userprefs.conf"
    mkdir -p "$(dirname "$USERPREFS_FILE")"
    touch "$USERPREFS_FILE"
    if ! grep -Fxq "exec-once = hyprshell run &" "$USERPREFS_FILE"; then
        echo "exec-once = hyprshell run &" >> "$USERPREFS_FILE"
        echo "MODIFIED_CONFIG: Added hyprshell run to $USERPREFS_FILE" >> "$LOG_FILE"
        echo "Added 'exec-once = hyprshell run &' to $USERPREFS_FILE"
    else
        echo "Skipping: 'exec-once = hyprshell run &' already exists in $USERPREFS_FILE"
    fi
}
if ! command -v yay >/dev/null 2>&1; then
    sudo_yad pacman -Syu --noconfirm git base-devel || { echo "Error: Failed to install git and base-devel"; exit 1; }
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
if $HYPRSHELL_ONLY; then
    setup_hyprshell
    echo "Script Finished (hyprshell mode)"
    exit 0
fi
if $OSU_ONLY; then
    if [[ ! -d "$HOME/.local/share/osu-wine" ]]; then
        echo "Installing osu"
        git clone https://github.com/NelloKudo/osu-winello.git /tmp/osu || { echo "Error: Failed to clone osu repository"; exit 1; }
        cd /tmp/osu || { echo "Error: Failed to change to /tmp/osu"; exit 1; }
        chmod +x ./osu-winello.sh || { echo "Error: failed to grant permission to osu-winello.sh"; exit 1; }
        echo "1" | ./osu-winello.sh
        cd - || exit 1
        rm -rf /tmp/osu
        echo "INSTALLED_PACKAGE: osu" >> "$LOG_FILE"
        echo "Installed osu"
    else
        echo "Skipped: osu-wine is already installed"
    fi
    echo "Script Finished (osuonly mode)"
    exit 0
fi
sudo_yad pacman -Syy --noconfirm
echo "Installing pacman packages"
PACMAN_PACKAGES="xclip ydotool nano wget unzip wine steam proton mpv ffmpeg gnome-software pinta libreoffice yad duf feh nomacs kwrite spotify"
if $INSTALL_LTS; then
    PACMAN_PACKAGES="$PACMAN_PACKAGES linux-lts linux-lts-headers"
fi
for pkg in $PACMAN_PACKAGES; do
    if ! pacman -Qs "$pkg" >/dev/null 2>&1; then
        sudo_yad pacman -Syu --noconfirm "$pkg" || { echo "Error: Failed to install $pkg"; exit 1; }
        echo "INSTALLED_PACKAGE: $pkg" >> "$LOG_FILE"
        echo "Installed $pkg"
    else
        echo "Skipping: $pkg already installed"
    fi
done
echo "Installing yay packages"
YAY_PACKAGES="qemu-full hyprshell-debug hyprshell"
if $NETFLIX; then
    YAY_PACKAGES="$YAY_PACKAGES netflix"
fi
hyprshell_installed=false
for pkg in $YAY_PACKAGES; do
    if ! yay -Qs "$pkg" >/dev/null 2>&1; then
        if [ "$pkg" = "hyprshell" ]; then
          hyprshell_installed=true
        fi
        yay -S --noconfirm "$pkg" || { echo "Error: Failed to install $pkg"; exit 1; }
        echo "INSTALLED_PACKAGE: $pkg" >> "$LOG_FILE"
        echo "Installed $pkg"
    else
        echo "Skipping: $pkg already installed"
    fi
done
if [ "$hyprshell_installed" = "true" ]; then
  setup_hyprshell
fi
if $INSTALL_OSU; then
    if [[ ! -d "$HOME/.local/share/osu-wine" ]]; then
        echo "Installing osu"
        git clone https://github.com/NelloKudo/osu-winello.git /tmp/osu || { echo "Error: Failed to clone osu repository"; exit 1; }
        cd /tmp/osu || { echo "Error: Failed to change to /tmp/osu"; exit 1; }
        chmod +x ./osu-winello.sh || { echo "Error: failed to grant permission to osu-winello.sh"; exit 1; }
        echo "1" | ./osu-winello.sh
        cd - || exit 1
        rm -rf /tmp/osu
        echo "INSTALLED_PACKAGE: osu" >> "$LOG_FILE"
        echo "Installed osu"
    else
        echo "Skipped: osu-wine is already installed"
    fi
else
    echo "Skipping: osu installation (osu parameter not provided)"
fi
if ! command -v flatpak >/dev/null 2>&1; then
    sudo_yad pacman -Syu --noconfirm flatpak || { echo "Error: Failed to install flatpak"; exit 1; }
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
FLATPAK_PACKAGES=("dev.vencord.Vesktop" "org.vinegarhq.Sober" "com.brave.Browser")
if [ "$NOCLIP" = false ]; then
    FLATPAK_PACKAGES+=("com.dec05eba.gpu_screen_recorder")
fi
for pkg in "${FLATPAK_PACKAGES[@]}"; do
    if ! flatpak list | grep -q "$pkg"; then
        if [ "$pkg" = "com.dec05eba.gpu_screen_recorder" ]; then
            flatpak install --system -y com.dec05eba.gpu_screen_recorder || { echo "Error: Failed to install GPU SCREEN RECORDER"; exit 1; }
        else
            flatpak install --user -y flathub "$pkg" || { echo "Error: Failed to install $pkg"; exit 1; }
        fi
        echo "INSTALLED_FLATPAK: $pkg" >> "$LOG_FILE"
        echo "Installed $pkg"
    else
        echo "Skipping: $pkg already installed"
    fi
done
if $NETFLIX; then
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
else
    echo "Skipping: Netflix-related setup (Brave and extension) not performed (-netflix parameter not provided)"
fi
echo "Setting up steam"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo "Enabling multilib repository..."
    sudo_yad sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /etc/pacman.conf
    sudo_yad pacman -Syy
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
        if [[ -f "$config" ]]; then
            echo "Found Steam config at $config. Enabling Steam Play..."
            cp "$config" "$config.bak"
            sed -i '/"SteamPlay"/,/}/ s/"EnableForAll"\s*"\w*"/"EnableForAll" "1"/' "$config"
            sed -i '/"SteamPlay"/,/}/ s/"DesiredVersion"\s*".*"/"DesiredVersion" "${proton_version}""/' "$config"
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
if [ "$NOCLIP" = false ] && flatpak list | grep -q com.dec05eba.gpu_screen_recorder; then
    sudo_yad ydotool &
    echo "Generating gpu-screen-recorder config files"
    flatpak run com.dec05eba.gpu_screen_recorder &
    sleep 1
    window=$(hyprctl clients -j | jq -r '.[] | select(.class=="gpu-screen-recorder") | .address')
    if [[ -n "$window" ]]; then
        hyprctl dispatch focuswindow address:$window
        echo "Focused gpu-screen-recorder window"
        sleep 1
        sudo_yad ydotool mousemove 500 400 click 1
        echo "Clicked on the window"
        sleep 1
        ~/.local/lib/hyde/dontkillsteam.sh || { echo "Error: Failed to execute dontkillsteam.sh"; exit 1; }
    else
        echo "Window not found."
    fi
    echo "Editing gpu-screen-recorder config"
    CONFIG_FILE="/home/$USER/.var/app/com.dec05eba.gpu_screen_recorder/config/gpu-screen-recorder/config"
    sleep 1
    if [ -f "$CONFIG_FILE" ]; then
        sed -i 's/main.use_new_ui false/main.use_new_ui true/' "$CONFIG_FILE"
        if [[ $? -eq 0 ]]; then
            echo "Successfully changed main.use_new_ui to true in $CONFIG_FILE"
        else
            echo "Error: Failed to modify main.use_new_ui in $CONFIG_FILE"
            exit 1
        fi
    else
        echo "Warning: $CONFIG_FILE not found. Cannot modify main.use_new_ui."
    fi
elif [ "$NOCLIP" = true ]; then
    echo "Skipping: gpu-screen-recorder setup (--noclip specified)"
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
echo "Setting up image viewers"
xdg-mime default feh.desktop image/png image/jpeg image/bmp image/webp
echo "Set feh as default for PNG, JPEG, BMP, and WEBP" >> "$LOG_FILE"
echo "Set feh as default for PNG, JPEG, BMP, and WEBP"
xdg-mime default nomacs.desktop image/gif
echo "Set nomacs as default for GIF" >> "$LOG_FILE"
echo "Set nomacs as default for GIF"
echo "Checking default applications for image formats..."
xdg-mime query default image/png >> "$LOG_FILE"
xdg-mime query default image/gif >> "$LOG_FILE"
xdg-mime query default image/png
xdg-mime query default image/gif
echo "feh is set as default for images (PNG, JPEG, BMP, WEBP), and nomacs for GIFs."
echo "Setting KWrite as the default text editor"
xdg-mime default org.kde.kwrite.desktop text/plain
xdg-mime default org.kde.kwrite.desktop application/x-shellscript
xdg-mime default org.kde.kwrite.desktop application/json
xdg-mime default org.kde.kwrite.desktop application/x-pacman-package
if ! grep -q "kwrite" ~/.bashrc; then
    echo 'export EDITOR=kwrite' >> ~/.bashrc
    echo 'export VISUAL=kwrite' >> ~/.bashrc
    echo "Set kwrite as default EDITOR and VISUAL in .bashrc"
else
    echo "Skipping: kwrite already set as EDITOR/VISUAL"
fi
echo "KWrite has been installed and set as the default editor"
echo "DEFAULT_EDITOR: kwrite" >> "$LOG_FILE"
echo "Script Finished"
exit 0
