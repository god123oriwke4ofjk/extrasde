#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo -e "${RED}[ERROR]${NC} Could not determine username."; exit 1; }

LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
FONT_DIR="$HOME/.local/share/fonts"
SYSTEM_FONTCONFIG_DIR="$HOME/.config/fontconfig"
SYSTEM_FONTCONFIG_FILE="$SYSTEM_FONTCONFIG_DIR/fonts.conf"
FLATPAK_CONFIG_DIR="$HOME/.var/app"
SNAP_CONFIG_DIR="$HOME/snap"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

[ "$EUID" -eq 0 ] && log_error "This script should not be run as root. Run as a regular user."
grep -qi "arch" /etc/os-release || log_error "This script is designed for Arch Linux."
command -v pacman >/dev/null 2>&1 || log_error "pacman not found. This script requires Arch Linux's package manager."
command -v fc-cache >/dev/null 2>&1 || log_error "fontconfig not found. Please install fontconfig."
ping -c 1 archlinux.org >/dev/null 2>&1 || log_error "No internet connection."

mkdir -p "$(dirname "$LOG_FILE")" || log_error "Failed to create $(dirname "$LOG_FILE")"
mkdir -p "$BACKUP_DIR" || log_error "Failed to create $BACKUP_DIR"
touch "$LOG_FILE" || log_error "Failed to create $LOG_FILE"
echo "[$(date)] New installation session (fonts)" >> "$LOG_FILE"

install_yay() {
    if ! command -v yay >/dev/null 2>&1; then
        log_info "Installing yay (AUR helper)..."
        sudo pacman -S --needed git base-devel || log_error "Failed to install dependencies for yay."
        git clone https://aur.archlinux.org/yay.git /tmp/yay || log_error "Failed to clone yay repository."
        cd /tmp/yay
        makepkg -si --noconfirm || log_error "Failed to build and install yay."
        cd -
        rm -rf /tmp/yay
        echo "INSTALLED_PACKAGE: yay" >> "$LOG_FILE"
        log_info "yay installed successfully."
    else
        log_info "yay is already installed."
    fi
}

install_system_fonts() {
    log_info "Installing system-wide Hebrew-supporting fonts (noto-fonts, ttf-ms-fonts)..."
    if ! pacman -Qs noto-fonts >/dev/null 2>&1; then
        sudo pacman -S --needed noto-fonts || log_error "Failed to install noto-fonts."
        echo "INSTALLED_PACKAGE: noto-fonts" >> "$LOG_FILE"
        log_info "noto-fonts installed."
    else
        log_info "noto-fonts already installed."
    fi
    if ! yay -Qs ttf-ms-fonts >/dev/null 2>&1; then
        yay -S --needed ttf-ms-fonts || log_error "Failed to install ttf-ms-fonts."
        echo "INSTALLED_PACKAGE: ttf-ms-fonts" >> "$LOG_FILE"
        log_info "ttf-ms-fonts installed."
    else
        log_info "ttf-ms-fonts already installed."
    fi
}

install_flatpak_fonts() {
    if command -v flatpak >/dev/null 2>&1; then
        log_info "Flatpak detected. Installing fonts for Flatpak apps..."
        mkdir -p "$FONT_DIR" || log_error "Failed to create $FONT_DIR."
        
        if ! ls "$FONT_DIR" | grep -qi "NotoSansHebrew"; then
            log_info "Copying Noto Fonts to $FONT_DIR..."
            cp -r /usr/share/fonts/noto/* "$FONT_DIR/" 2>/dev/null || log_warning "Some Noto Fonts could not be copied."
            echo "COPIED_FONTS: noto-fonts -> $FONT_DIR" >> "$LOG_FILE"
        else
            log_info "Noto Fonts already present in $FONT_DIR."
        fi
        if ! ls "$FONT_DIR" | grep -qi "Arial"; then
            log_info "Copying Microsoft Fonts to $FONT_DIR..."
            cp -r /usr/share/fonts/TTF/* "$FONT_DIR/" 2>/dev/null || log_warning "Some Microsoft Fonts could not be copied."
            echo "COPIED_FONTS: ttf-ms-fonts -> $FONT_DIR" >> "$LOG_FILE"
        else
            log_info "Microsoft Fonts already present in $FONT_DIR."
        fi
        
        log_info "Refreshing Flatpak font cache..."
        fc-cache -fv "$FONT_DIR" || log_warning "Failed to refresh Flatpak font cache."
        
        if [ -d "$FLATPAK_CONFIG_DIR" ]; then
            for app_dir in "$FLATPAK_CONFIG_DIR"/*; do
                if [ -d "$app_dir" ]; then
                    local app_id=$(basename "$app_dir")
                    local app_fontconfig_dir="$app_dir/config/fontconfig"
                    local app_fonts_conf="$app_fontconfig_dir/fonts.conf"
                    
                    log_info "Creating FontConfig for Flatpak app $app_id..."
                    mkdir -p "$app_fontconfig_dir" || log_warning "Failed to create $app_fontconfig_dir."
                    
                    if [ -f "$app_fonts_conf" ]; then
                        log_warning "Existing $app_fonts_conf found. Backing it up..."
                        cp "$app_fonts_conf" "$BACKUP_DIR/flatpak-$app_id-fonts.conf.$(date +%s)" || log_warning "Failed to back up $app_fonts_conf."
                        echo "BACKUP_FONTCONFIG: $app_fonts_conf -> $BACKUP_DIR/flatpak-$app_id-fonts.conf.$(date +%s)" >> "$LOG_FILE"
                    fi
                    
                    cat << EOF > "$app_fonts_conf"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <dir>$FONT_DIR</dir>
    <alias>
        <family>sans-serif</family>
        <prefer>
            <family>Noto Sans Hebrew</family>
            <family>Arial</family>
            <family>DejaVu Sans</family>
        </prefer>
    </alias>
    <alias>
        <family>serif</family>
        <prefer>
            <family>Noto Serif Hebrew</family>
            <family>Times New Roman</family>
            <family>DejaVu Serif</family>
        </prefer>
    </alias>
    <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
    </match>
</fontconfig>
EOF
                    echo "CREATED_FONTCONFIG: $app_fonts_conf" >> "$LOG_FILE"
                    log_info "FontConfig created for Flatpak app $app_id at $app_fonts_conf."
                fi
            done
        else
            log_info "No Flatpak apps detected in $FLATPAK_CONFIG_DIR."
        fi
    else
        log_info "Flatpak not installed. Skipping Flatpak font installation."
    fi
}

install_snap_fonts() {
    if command -v snap >/dev/null 2>&1; then
        log_info "Snap detected. Installing fonts for Snap apps..."
        mkdir -p "$FONT_DIR" || log_error "Failed to create $FONT_DIR."
        
        if ! ls "$FONT_DIR" | grep -qi "NotoSansHebrew"; then
            log_info "Copying Noto Fonts to $FONT_DIR..."
            cp -r /usr/share/fonts/noto/* "$FONT_DIR/" 2>/dev/null || log_warning "Some Noto Fonts could not be copied."
            echo "COPIED_FONTS: noto-fonts -> $FONT_DIR" >> "$LOG_FILE"
        else
            log_info "Noto Fonts already present in $FONT_DIR."
        fi
        if ! ls "$FONT_DIR" | grep -qi "Arial"; then
            log_info "Copying Microsoft Fonts to $FONT_DIR..."
            cp -r /usr/share/fonts/TTF/* "$FONT_DIR/" 2>/dev/null || log_warning "Some Microsoft Fonts could not be copied."
            echo "COPIED_FONTS: ttf-ms-fonts -> $FONT_DIR" >> "$LOG_FILE"
        else
            log_info "Microsoft Fonts already present in $FONT_DIR."
        fi
        
        log_info "Refreshing Snap font cache..."
        fc-cache -fv "$FONT_DIR" || log_warning "Failed to refresh Snap font cache."
        
        if [ -d "$SNAP_CONFIG_DIR" ]; then
            for snap_app in "$SNAP_CONFIG_DIR"/*; do
                if [ -d "$snap_app" ]; then
                    local app_id=$(basename "$snap_app")
                    local app_version_dir
                    app_version_dir=$(readlink -f "$snap_app/current" 2>/dev/null)
                    if [ -z "$app_version_dir" ]; then
                        log_warning "No 'current' symlink found for Snap app $app_id. Skipping."
                        continue
                    fi
                    local app_fontconfig_dir="$app_version_dir/.config/fontconfig"
                    local app_fonts_conf="$app_fontconfig_dir/fonts.conf"
                    
                    log_info "Creating FontConfig for Snap app $app_id..."
                    mkdir -p "$app_fontconfig_dir" || log_warning "Failed to create $app_fontconfig_dir."
                    
                    if [ -f "$app_fonts_conf" ]; then
                        log_warning "Existing $app_fonts_conf found. Backing it up..."
                        cp "$app_fonts_conf" "$BACKUP_DIR/snap-$app_id-fonts.conf.$(date +%s)" || log_warning "Failed to back up $app_fonts_conf."
                        echo "BACKUP_FONTCONFIG: $app_fonts_conf -> $BACKUP_DIR/snap-$app_id-fonts.conf.$(date +%s)" >> "$LOG_FILE"
                    fi
                    
                    cat << EOF > "$app_fonts_conf"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <dir>$FONT_DIR</dir>
    <alias>
        <family>sans-serif</family>
        <prefer>
            <family>Noto Sans Hebrew</family>
            <family>Arial</family>
            <family>DejaVu Sans</family>
        </prefer>
    </alias>
    <alias>
        <family>serif</family>
        <prefer>
            <family>Noto Serif Hebrew</family>
            <family>Times New Roman</family>
            <family>DejaVu Serif</family>
        </prefer>
    </alias>
    <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
    </match>
</fontconfig>
EOF
                    echo "CREATED_FONTCONFIG: $app_fonts_conf" >> "$LOG_FILE"
                    log_info "FontConfig created for Snap app $app_id at $app_fonts_conf."
                fi
            done
        else
            log_info "No Snap apps detected in $SNAP_CONFIG_DIR."
        fi
    else
        log_info "Snap not installed. Skipping Snap font installation."
    fi
}

verify_fonts() {
    log_info "Verifying system-wide Hebrew font installation..."
    if fc-list | grep -qi "Noto Sans Hebrew"; then
        log_info "Noto Sans Hebrew found."
    else
        log_warning "Noto Sans Hebrew not found. Attempting to reinstall noto-fonts..."
        sudo pacman -S --needed noto-fonts || log_error "Failed to reinstall noto-fonts."
        echo "INSTALLED_PACKAGE: noto-fonts" >> "$LOG_FILE"
    fi
    if fc-list | grep -qi "Arial"; then
        log_info "Arial found."
    else
        log_warning "Arial not found. Attempting to reinstall ttf-ms-fonts..."
        yay -S --needed ttf-ms-fonts || log_error "Failed to reinstall ttf-ms-fonts."
        echo "INSTALLED_PACKAGE: ttf-ms-fonts" >> "$LOG_FILE"
    fi

    if [ -d "$FONT_DIR" ]; then
        log_info "Verifying Flatpak/Snap font installation..."
        if ls "$FONT_DIR" | grep -qi "NotoSansHebrew"; then
            log_info "Noto Sans Hebrew found in Flatpak/Snap fonts."
        else
            log_warning "Noto Sans Hebrew not found in Flatpak/Snap fonts. Re-copying..."
            cp -r /usr/share/fonts/noto/* "$FONT_DIR/" 2>/dev/null || log_warning "Failed to re-copy Noto Fonts."
            echo "COPIED_FONTS: noto-fonts -> $FONT_DIR" >> "$LOG_FILE"
            fc-cache -fv "$FONT_DIR" || log_warning "Failed to refresh Flatpak/Snap font cache."
        fi
    fi
}

create_system_fontconfig() {
    log_info "Checking for existing system-wide FontConfig configuration..."
    if [ -f "$SYSTEM_FONTCONFIG_FILE" ]; then
        log_warning "Existing $SYSTEM_FONTCONFIG_FILE found. Backing it up..."
        cp "$SYSTEM_FONTCONFIG_FILE" "$BACKUP_DIR/fonts.conf.$(date +%s)" || log_error "Failed to back up $SYSTEM_FONTCONFIG_FILE."
        echo "BACKUP_FONTCONFIG: $SYSTEM_FONTCONFIG_FILE -> $BACKUP_DIR/fonts.conf.$(date +%s)" >> "$LOG_FILE"
    fi

    log_info "Creating system-wide FontConfig configuration for Hebrew fonts..."
    mkdir -p "$SYSTEM_FONTCONFIG_DIR" || log_error "Failed to create $SYSTEM_FONTCONFIG_DIR."
    cat << EOF > "$SYSTEM_FONTCONFIG_FILE"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <alias>
        <family>sans-serif</family>
        <prefer>
            <family>Noto Sans Hebrew</family>
            <family>Arial</family>
            <family>DejaVu Sans</family>
        </prefer>
    </alias>
    <alias>
        <family>serif</family>
        <prefer>
            <family>Noto Serif Hebrew</family>
            <family>Times New Roman</family>
            <family>DejaVu Serif</family>
        </prefer>
    </alias>
    <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
    </match>
</fontconfig>
EOF
    echo "CREATED_FONTCONFIG: $SYSTEM_FONTCONFIG_FILE" >> "$LOG_FILE"
    log_info "System-wide FontConfig configuration created at $SYSTEM_FONTCONFIG_FILE."
}

refresh_font_cache() {
    log_info "Refreshing system-wide font cache..."
    fc-cache -fv || log_error "Failed to refresh system-wide font cache."
    log_info "System-wide font cache refreshed successfully."
}

verify_font_selection() {
    log_info "Verifying system-wide font selection..."
    local selected_font
    selected_font=$(fc-match sans-serif)
    log_info "Current system-wide sans-serif font: $selected_font"
    if [[ "$selected_font" =~ "NotoSansHebrew" || "$selected_font" =~ "Arial" ]]; then
        log_info "System-wide Hebrew font selection looks good."
    else
        log_warning "Unexpected system-wide sans-serif font: $selected_font. Expected Noto Sans Hebrew or Arial."
        log_warning "Check for conflicting FontConfig files in /etc/fonts/conf.d/ or ~/.config/fontconfig/conf.d/."
    fi

    if [ -d "$FLATPAK_CONFIG_DIR" ]; then
        for app_dir in "$FLATPAK_CONFIG_DIR"/*; do
            if [ -d "$app_dir" ]; then
                local app_id=$(basename "$app_dir")
                log_info "Checking font selection for Flatpak app $app_id..."
                if [ -f "$app_dir/config/fontconfig/fonts.conf" ]; then
                    log_info "FontConfig file found for $app_id. Assuming correct font selection."
                else
                    log_warning "No FontConfig file found for $app_id. Hebrew fonts may not work."
                fi
            fi
        done
    fi

    if [ -d "$SNAP_CONFIG_DIR" ]; then
        for snap_app in "$SNAP_CONFIG_DIR"/*; do
            if [ -d "$snap_app" ]; then
                local app_id=$(basename "$snap_app")
                local app_version_dir
                app_version_dir=$(readlink -f "$snap_app/current" 2>/dev/null)
                if [ -n "$app_version_dir" ]; then
                    local app_fonts_conf="$app_version_dir/.config/fontconfig/fonts.conf"
                    log_info "Checking font selection for Snap app $app_id..."
                    if [ -f "$app_fonts_conf" ]; then
                        log_info "FontConfig file found for $app_id. Assuming correct font selection."
                    else
                        log_warning "No FontConfig file found for $app_id. Hebrew fonts may not work."
                    fi
                fi
            fi
        done
    fi
}

reload_hyprland() {
    if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null; then
        log_info "Hyprland detected. Reloading Hyprland to apply font changes..."
        hyprctl reload || log_warning "Failed to reload Hyprland. Please log out and back in manually."
        log_info "Hyprland reloaded successfully."
    else
        log_info "Hyprland not detected or not running. Skipping reload."
        log_info "Please restart applications or log out/in to apply changes."
    fi
}

main() {
    log_info "Starting Hebrew font setup for Arch Linux (system, Flatpak, Snap)..."
    install_yay
    install_system_fonts
    install_flatpak_fonts
    install_snap_fonts
    verify_fonts
    create_system_fontconfig
    refresh_font_cache
    verify_font_selection
    reload_hyprland
    log_info "Hebrew font setup completed successfully!"
    log_info "Hebrew fonts should now work in browsers, Discord (Flatpak or native), Snap apps (e.g., Netflix), and other apps."
    log_info "If issues persist, share the output of 'fc-match sans-serif' and 'fc-list | grep -i hebrew'."
    echo "LOGGED_ACTIONS: Completed fonts installation" >> "$LOG_FILE"
}

main

exit 0
