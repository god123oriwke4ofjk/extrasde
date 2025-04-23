#!/bin/bash

# Script to set up Hebrew fonts on Arch Linux (Hyprland or other environments)
# Installs Noto Fonts and Microsoft fonts for system, Flatpak, and Snap apps,
# configures FontConfig, refreshes caches, and reloads Hyprland if necessary
# Includes checks for fresh installs and existing configurations

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log functions
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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "This script should not be run as root. Run as a regular user."
fi

# Check if on Arch Linux
if ! grep -qi "arch" /etc/os-release; then
    log_error "This script is designed for Arch Linux. Exiting."
fi

# Check if pacman is available
if ! command -v pacman &>/dev/null; then
    log_error "pacman not found. This script requires Arch Linux's package manager."
fi

# Check and install yay (AUR helper) if not present
install_yay() {
    if ! command -v yay &>/dev/null; then
        log_info "Installing yay (AUR helper)..."
        sudo pacman -S --needed git base-devel || log_error "Failed to install dependencies for yay."
        git clone https://aur.archlinux.org/yay.git /tmp/yay || log_error "Failed to clone yay repository."
        cd /tmp/yay
        makepkg -si --noconfirm || log_error "Failed to build and install yay."
        cd -
        rm -rf /tmp/yay
        log_info "yay installed successfully."
    else
        log_info "yay is already installed."
    fi
}

# Install system-wide fonts
install_system_fonts() {
    log_info "Installing system-wide Hebrew-supporting fonts (noto-fonts, ttf-ms-fonts)..."
    sudo pacman -S --needed noto-fonts || log_error "Failed to install noto-fonts."
    yay -S --needed ttf-ms-fonts || log_error "Failed to install ttf-ms-fonts."
    log_info "System-wide fonts installed successfully."
}

# Install fonts for Flatpak apps
install_flatpak_fonts() {
    if command -v flatpak &>/dev/null; then
        log_info "Flatpak detected. Installing fonts for Flatpak apps..."
        # Copy system fonts to Flatpak's user font directory
        local flatpak_font_dir="$HOME/.local/share/fonts"
        mkdir -p "$flatpak_font_dir" || log_error "Failed to create $flatpak_font_dir."
        
        # Copy Noto Fonts and Microsoft fonts to Flatpak font directory
        log_info "Copying Noto Fonts to $flatpak_font_dir..."
        cp -r /usr/share/fonts/noto/* "$flatpak_font_dir/" 2>/dev/null || log_warning "Some Noto Fonts could not be copied."
        
        log_info "Copying Microsoft Fonts to $flatpak_font_dir..."
        cp -r /usr/share/fonts/TTF/* "$flatpak_font_dir/" 2>/dev/null || log_warning "Some Microsoft Fonts could not be copied."
        
        # Refresh Flatpak font cache
        log_info "Refreshing Flatpak font cache..."
        fc-cache -fv "$flatpak_font_dir" || log_warning "Failed to refresh Flatpak font cache."
        
        # Create Flatpak-specific FontConfig configuration
        local flatpak_config_dir="$HOME/.var/app"
        if [ -d "$flatpak_config_dir" ]; then
            for app_dir in "$flatpak_config_dir"/*; do
                if [ -d "$app_dir" ]; then
                    local app_id=$(basename "$app_dir")
                    local app_fontconfig_dir="$app_dir/config/fontconfig"
                    local app_fonts_conf="$app_fontconfig_dir/fonts.conf"
                    
                    log_info "Creating FontConfig for Flatpak app $app_id..."
                    mkdir -p "$app_fontconfig_dir" || log_warning "Failed to create $app_fontconfig_dir."
                    
                    if [ -f "$app_fonts_conf" ]; then
                        log_warning "Existing $app_fonts_conf found. Backing it up..."
                        cp "$app_fonts_conf" "$app_fonts_conf.bak" || log_warning "Failed to back up $app_fonts_conf."
                    fi
                    
                    cat << EOF > "$app_fonts_conf"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <!-- Set preferred fonts for Hebrew in Flatpak app -->
    <dir>$flatpak_font_dir</dir>
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
            <family> △
            Times New Roman</family>
            <family>DejaVu Serif</family>
        </prefer>
    </alias>
    <!-- Improve font rendering -->
    <match target="font">
        <edit name="antialias" mode="assign">
            <bool>true</bool>
        </edit>
        <edit name="hinting" mode="assign">
            <bool>true</bool>
        </edit>
        <edit name="hintstyle" mode="assign">
            <const>hintslight</const>
        </edit>
        <edit name="rgba" mode="assign">
            <const>rgb</const>
        </edit>
    </match>
</fontconfig>
EOF
                    log_info "FontConfig created for Flatpak app $app_id at $app_fonts_conf."
                fi
            done
        else
            log_info "No Flatpak apps detected in $flatpak_config_dir."
        fi
    else
        log_info "Flatpak not installed. Skipping Flatpak font installation."
    fi
}

# Install fonts for Snap apps
install_snap_fonts() {
    if command -v snap &>/dev/null; then
        log_info "Snap detected. Installing fonts for Snap apps..."
        # Copy system fonts to Snap's user font directory
        local snap_font_dir="$HOME/.local/share/fonts"
        mkdir -p "$snap_font_dir" || log_error "Failed to create $snap_font_dir."
        
        # Copy Noto Fonts and Microsoft fonts to Snap font directory
        log_info "Copying Noto Fonts to $snap_font_dir..."
        cp -r /usr/share/fonts/noto/* "$snap_font_dir/" 2>/dev/null || log_warning "Some Noto Fonts could not be copied."
        
        log_info "Copying Microsoft Fonts to $snap_font_dir..."
        cp -r /usr/share/fonts/TTF/* "$snap_font_dir/" 2>/dev/null || log_warning "Some Microsoft Fonts could not be copied."
        
        # Refresh Snap font cache
        log_info "Refreshing Snap font cache..."
        fc-cache -fv "$snap_font_dir" || log_warning "Failed to refresh Snap font cache."
        
        # Create Snap-specific FontConfig configuration
        local snap_config_dir="$HOME/snap"
        if [ -d "$snap_config_dir" ]; then
            for snap_app in "$snap_config_dir"/*; do
                if [ -d "$snap_app" ]; then
                    local app_id=$(basename "$snap_app")
                    # Snap apps use a 'current' symlink to the active version
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
                        cp "$app_fonts_conf" "$app_fonts_conf.bak" || log_warning "Failed to back up $app_fonts_conf."
                    fi
                    
                    cat << EOF > "$app_fonts_conf"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <!-- Set preferred fonts for Hebrew in Snap app -->
    <dir>$snap_font_dir</dir>
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
    <!-- Improve font rendering -->
    <match target="font">
        <edit name="antialias" mode="assign">
            <bool>true</bool>
        </edit>
        <edit name="hinting" mode="assign">
            <bool>true</bool>
        </edit>
        <edit name="hintstyle" mode="assign">
            <const>hintslight</const>
        </edit>
        <edit name="rgba" mode="assign">
            <const>rgb</const>
        </edit>
    </match>
</fontconfig>
EOF
                    log_info "FontConfig created for Snap app $app_id at $app_fonts_conf."
                fi
            done
        else
            log_info "No Snap apps detected in $snap_config_dir."
        fi
    else
        log_info "Snap not installed. Skipping Snap font installation."
    fi
}

# Verify font installation
verify_fonts() {
    log_info "Verifying system-wide Hebrew font installation..."
    if fc-list | grep -qi "Noto Sans Hebrew"; then
        log_info "Noto Sans Hebrew found."
    else
        log_warning "Noto Sans Hebrew not found. Attempting to reinstall noto-fonts..."
        sudo pacman -S --needed noto-fonts || log_error "Failed to reinstall noto-fonts."
    fi
    if fc-list | grep -qi "Arial"; then
        log_info "Arial found."
    else
        log_warning "Arial not found. Attempting to reinstall ttf-ms-fonts..."
        yay -S --needed ttf-ms-fonts || log_error "Failed to reinstall ttf-ms-fonts."
    fi

    # Verify Flatpak/Snap fonts
    if [ -d "$HOME/.local/share/fonts" ]; then
        log_info "Verifying Flatpak/Snap font installation..."
        if ls "$HOME/.local/share/fonts" | grep -qi "NotoSansHebrew"; then
            log_info "Noto Sans Hebrew found in Flatpak/Snap fonts."
        else
            log_warning "Noto Sans Hebrew not found in Flatpak/Snap fonts. Re-copying..."
            cp -r /usr/share/fonts/noto/* "$HOME/.local/share/fonts/" 2>/dev/null || log_warning "Failed to re-copy Noto Fonts."
            fc-cache -fv "$HOME/.local/share/fonts" || log_warning "Failed to refresh Flatpak/Snap font cache."
        fi
    fi
}

# Create system-wide FontConfig configuration
create_system_fontconfig() {
    local fontconfig_dir="$HOME/.config/fontconfig"
    local fontconfig_file="$fontconfig_dir/fonts.conf"

    log_info "Checking for existing system-wide FontConfig configuration..."
    if [ -f "$fontconfig_file" ]; then
        log_warning "Existing $fontconfig_file found. Backing it up..."
        cp "$fontconfig_file" "$fontconfig_file.bak" || log_error "Failed to back up $fontconfig_file."
    fi

    log_info "Creating system-wide FontConfig configuration for Hebrew fonts..."
    mkdir -p "$fontconfig_dir" || log_error "Failed to create $fontconfig_dir."
    cat << EOF > "$fontconfig_file"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <!-- Set preferred fonts for Hebrew -->
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
    <!-- Improve font rendering -->
    <match target="font">
        <edit name="antialias" mode="assign">
            <bool>true</bool>
        </edit>
        <edit name="hinting" mode="assign">
            <bool>true</bool>
        </edit>
        <edit name="hintstyle" mode="assign">
            <const>hintslight</const>
        </edit>
        <edit name="rgba" mode="assign">
            <const>rgb</const>
        </edit>
    </match>
</fontconfig>
EOF
    log_info "System-wide FontConfig configuration created at $fontconfig_file."
}

# Refresh system-wide font cache
refresh_font_cache() {
    log_info "Refreshing system-wide font cache..."
    fc-cache -fv || log_error "Failed to refresh system-wide font cache."
    log_info "System-wide font cache refreshed successfully."
}

# Verify font selection
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

    # Verify Flatpak font selection
    if [ -d "$HOME/.var/app" ]; then
        for app_dir in "$HOME/.var/app"/*; do
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

    # Verify Snap font selection
    if [ -d "$HOME/snap" ]; then
        for snap_app in "$HOME/snap"/*; do
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

# Reload Hyprland if necessary
reload_hyprland() {
    if command -v hyprctl &>/dev/null && pgrep -x Hyprland >/dev/null; then
        log_info "Hyprland detected. Reloading Hyprland to apply font changes..."
        hyprctl reload || log_warning "Failed to reload Hyprland. Please log out and back in manually."
        log_info "Hyprland reloaded successfully."
    else
        log_info "Hyprland not detected or not running. Skipping reload."
        log_info "Please restart applications or log out/in to apply changes."
    fi
}

# Main function
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
}

# Run main function
main

exit 0
