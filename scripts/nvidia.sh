#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

check_driver() {
    echo "Checking for active GPU driver..."

    if lsmod | grep -q "^nvidia"; then
        echo "NVIDIA driver is currently in use."
        return 1
    elif lsmod | grep -q "^nouveau"; then
        echo "Nouveau driver is currently in use."
        return 0
    else
        echo "No NVIDIA or Nouveau driver detected. Checking hardware..."

        if lspci | grep -i nvidia | grep -q "VGA\|3D"; then
            echo "NVIDIA GPU detected, but no driver is loaded. Assuming Nouveau (default)."
            return 0
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

    pacman -S --noconfirm nvidia nvidia-utils

    echo "Blacklisting Nouveau driver..."
    cat > /etc/modprobe.d/blacklist-nouveau.conf << EOL
blacklist nouveau
options nouveau modeset=0
EOL

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

echo "Starting NVIDIA driver check and installation script..."

manage_dkms

if check_driver; then
    install_nvidia
else
    echo "NVIDIA driver is already installed. No further action required."
fi

echo "Script completed. Please reboot your system to apply changes if the NVIDIA driver was installed."
exit 0
