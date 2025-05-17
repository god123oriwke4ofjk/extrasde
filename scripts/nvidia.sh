#!/bin/bash

set -e

usage() {
    echo "Usage: $0 [-nv] [-h | -help]"
    echo "Options:"
    echo "  -nv        Skip Nouveau driver checks and blacklisting"
    echo "  -h, -help  Display this help message and exit"
    echo ""
    echo "This script installs and configures the NVIDIA proprietary driver, blacklists Nouveau (unless -nv is used),"
    echo "and configures Hyprland for NVIDIA. Must be run as root."
    exit 0
}

SKIP_NOUVEAU=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -nv)
            SKIP_NOUVEAU=true
            shift
            ;;
        -h|-help)
            usage
            ;;
        *)
            echo "Error: Unknown option: $1"
            usage
            ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

check_driver() {
    echo "Checking for active GPU driver..."

    if lsmod | grep -q "^nvidia"; then
        echo "NVIDIA driver is currently in use."
        return 1
    elif [[ "$SKIP_NOUVEAU" == false ]] && lsmod | grep -q "^nouveau"; then
        echo "Nouveau driver is currently in use."
        return 0
    else
        echo "No NVIDIA or Nouveau driver detected. Checking hardware..."

        if lspci | grep -i nvidia | grep -q "VGA\|3D"; then
            if [[ "$SKIP_NOUVEAU" == false ]]; then
                echo "NVIDIA GPU detected, but no driver is loaded. Assuming Nouveau (default)."
                return 0
            else
                echo "NVIDIA GPU detected, but no driver is loaded. Proceeding with NVIDIA installation."
                return 0
            fi
        else
            echo "No NVIDIA GPU detected. Exiting."
            exit 1
        fi
    fi
}

enable_nvidia_drm() {
    local nvidia_conf="/etc/modprobe.d/nvidia.conf"
    echo "Configuring NVIDIA DRM..."

    if [[ -f "$nvidia_conf" ]] && grep -q "nvidia-drm modeset=1" "$nvidia_conf"; then
        echo "NVIDIA DRM is already enabled in $nvidia_conf. Skipping."
    else
        echo "Adding 'options nvidia-drm modeset=1' to $nvidia_conf..."
        echo "options nvidia-drm modeset=1" >> "$nvidia_conf"
    fi

    echo "Updating initramfs for NVIDIA DRM..."
    mkinitcpio -P
}

install_nvidia() {
    echo "Installing NVIDIA proprietary driver..."

    pacman -Syu --noconfirm

    pacman -S --noconfirm nvidia nvidia-utils libva-nvidia-driver

    if [[ "$SKIP_NOUVEAU" == false ]]; then
        echo "Blacklisting Nouveau driver..."
        cat > /etc/modprobe.d/blacklist-nouveau.conf << EOL
blacklist nouveau
options nouveau modeset=0
EOL
    else
        echo "Skipping Nouveau blacklisting due to -nv option."
    fi

    enable_nvidia_drm

    echo "NVIDIA driver installed successfully. Reboot required."
}

manage_dkms() {
    if pacman -Qs nvidia-dkms > /dev/null; then
        echo "nvidia-dkms is installed. Uninstalling..."
        pacman -Rns --noconfirm nvidia-dkms
        echo "nvidia-dkms has been uninstalled."
    else
        echo "nvidia-dkms is not installed. No action needed."
    fi
}

configure_hyprland() {
    echo "Configuring Hyprland for NVIDIA..."

    local config_file="/home/$SUDO_USER/.config/hypr/hyprland.conf"
    local line_to_add="env = ELECTRON_OZONE_PLATFORM_HINT,auto"

    if ! pacman -Qs hyprland > /dev/null; then
        echo "Hyprland is not installed. Skipping Hyprland configuration."
        return 0
    fi

    if [[ ! -f "$config_file" ]]; then
        echo "Creating $config_file..."
        mkdir -p "$(dirname "$config_file")"
        touch "$config_file"
        chown "$SUDO_USER:$SUDO_USER" "$config_file"
    fi

    if grep -Fx "$line_to_add" "$config_file" > /dev/null; then
        echo "Line '$line_to_add' already exists in $config_file. No changes made."
    else
        echo "$line_to_add" >> "$config_file"
        if [[ $? -eq 0 ]]; then
            echo "Successfully added '$line_to_add' to $config_file."
        else
            echo "Error: Failed to append line to $config_file."
            exit 1
        fi
    fi

    if grep -Fx "$line_to_add" "$config_file" > /dev/null; then
        echo "Verification: Line '$line_to_add' is now present in $config_file."
    else
        echo "Error: Verification failed. Line '$line_to_add' was not added."
        exit 1
    fi

    chown "$SUDO_USER:$SUDO_USER" "$config_file"
    echo "Hyprland configuration completed."
}

echo "Starting NVIDIA driver check and installation script..."

manage_dkms

if check_driver; then
    install_nvidia
    configure_hyprland
else
    echo "NVIDIA driver is already installed. Checking Hyprland configuration..."
    configure_hyprland
fi

echo "Script completed. Please reboot your system to apply changes if the NVIDIA driver was installed."
exit 0
