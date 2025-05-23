#!/bin/bash

set -e

usage() {
    echo "Usage: $0 [-nv] [-dkms] [-hypr] [-undo [hypr] [dkms] [nv]] [-h | -help]"
    echo "Options:"
    echo "  -nv        Skip Nouveau driver checks and blacklisting"
    echo "  -dkms      Skip nvidia-dkms checks and uninstallation"
    echo "  -hypr      Skip Hyprland configuration for NVIDIA"
    echo "  -undo      Undo all changes made by this script (Nouveau, DKMS, Hyprland, DRM)"
    echo "  -undo hypr Undo only Hyprland configuration"
    echo "  -undo dkms Undo only nvidia-dkms uninstallation"
    echo "  -undo nv   Undo only Nouveau blacklisting and NVIDIA DRM settings"
    echo "  -h, -help  Display this help message and exit"
    echo ""
    echo "This script installs and configures the NVIDIA proprietary driver, blacklists Nouveau (unless -nv is used),"
    echo "and configures Hyprland for NVIDIA (unless -hypr is used). Use -undo to revert changes. Must be run as root."
    exit 0
}

SKIP_NOUVEAU=false
SKIP_DKMS=false
SKIP_HYPRLAND=false
UNDO_MODE=false
UNDO_ACTIONS=("nouveau" "dkms" "hyprland" "drm") 

while [[ $# -gt 0 ]]; do
    case "$1" in
        -nv)
            SKIP_NOUVEAU=true
            shift
            ;;
        -dkms)
            SKIP_DKMS=true
            shift
            ;;
        -hypr)
            SKIP_HYPRLAND=true
            shift
            ;;
        -undo)
            UNDO_MODE=true
            UNDO_ACTIONS=() 
            shift
            while [[ $# -gt 0 && "$1" != -* ]]; do
                case "$1" in
                    hypr)
                        UNDO_ACTIONS+=("hyprland")
                        shift
                        ;;
                    dkms)
                        UNDO_ACTIONS+=("dkms")
                        shift
                        ;;
                    nv)
                        UNDO_ACTIONS+=("nouveau" "drm")
                        shift
                        ;;
                    *)
                        echo "Error: Unknown undo option: $1"
                        usage
                        ;;
                esac
            done
            if [[ ${#UNDO_ACTIONS[@]} -eq 0 ]]; then
                UNDO_ACTIONS=("nouveau" "dkms" "hyprland" "drm")
            fi
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
    if [[ "$SKIP_DKMS" == true ]]; then
        echo "Skipping nvidia-dkms checks and uninstallation due to -dkms option."
        return 0
    fi

    if pacman -Qs nvidia-dkms > /dev/null; then
        echo "nvidia-dkms is installed. Uninstalling..."
        pacman -Rns --noconfirm nvidia-dkms
        echo "nvidia-dkms has been uninstalled."
    else
        echo "nvidia-dkms is not installed. No action needed."
    fi
}

configure_hyprland() {
    if [[ "$SKIP_HYPRLAND" == true ]]; then
        echo "Skipping Hyprland configuration due to -hypr option."
        return 0
    fi

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

undo_nouveau() {
    local blacklist_file="/etc/modprobe.d/blacklist-nouveau.conf"
    if [[ -f "$blacklist_file" ]]; then
        echo "Removing Nouveau blacklist file: $blacklist_file..."
        rm -f "$blacklist_file"
        if [[ $? -eq 0 ]]; then
            echo "Nouveau blacklist removed successfully."
        else
            echo "Error: Failed to remove $blacklist_file."
            exit 1
        fi
    else
        echo "No Nouveau blacklist file found. Skipping."
    fi
}

undo_nvidia_drm() {
    local nvidia_conf="/etc/modprobe.d/nvidia.conf"
    if [[ -f "$nvidia_conf" ]]; then
        echo "Removing NVIDIA DRM configuration from $nvidia_conf..."
        sed -i '/nvidia-drm modeset=1/d' "$nvidia_conf"
        if [[ ! -s "$nvidia_conf" ]]; then
            echo "NVIDIA DRM config file is empty. Removing $nvidia_conf..."
            rm -f "$nvidia_conf"
        fi
        echo "Updating initramfs after removing NVIDIA DRM settings..."
        mkinitcpio -P
    else
        echo "No NVIDIA DRM configuration found. Skipping."
    fi
}

undo_dkms() {
    if ! pacman -Qs nvidia-dkms > /dev/null; then
        echo "Reinstalling nvidia-dkms..."
        pacman -S --noconfirm nvidia-dkms
        if [[ $? -eq 0 ]]; then
            echo "nvidia-dkms reinstalled successfully."
        else
            echo "Error: Failed to reinstall nvidia-dkms."
            exit 1
        fi
    else
        echo "nvidia-dkms is already installed. No action needed."
    fi
}

undo_hyprland() {
    local config_file="/home/$SUDO_USER/.config/hypr/hyprland.conf"
    local line_to_remove="env = ELECTRON_OZONE_PLATFORM_HINT,auto"

    if [[ ! -f "$config_file" ]]; then
        echo "Hyprland config file $config_file does not exist. Skipping."
        return 0
    fi

    if grep -Fx "$line_to_remove" "$config_file" > /dev/null; then
        echo "Removing line '$line_to_remove' from $config_file..."
        sed -i "/^${line_to_remove}$/d" "$config_file"
        if [[ $? -eq 0 ]]; then
            echo "Line removed successfully."
        else
            echo "Error: Failed to remove line from $config_file."
            exit 1
        fi
    else
        echo "Line '$line_to_remove' not found in $config_file. No changes made."
    fi

    if [[ ! -s "$config_file" ]]; then
        echo "Hyprland config file is empty. Removing $config_file..."
        rm -f "$config_file"
    fi

    if [[ -d "$(dirname "$config_file")" && -z "$(ls -A "$(dirname "$config_file")")" ]]; then
        echo "Hyprland config directory is empty. Removing $(dirname "$config_file")..."
        rmdir "$(dirname "$config_file")"
    fi

    echo "Hyprland configuration undo completed."
}

perform_undo() {
    echo "Performing undo actions: ${UNDO_ACTIONS[*]}..."

    for action in "${UNDO_ACTIONS[@]}"; do
        case "$action" in
            nouveau)
                undo_nouveau
                ;;
            drm)
                undo_nvidia_drm
                ;;
            dkms)
                undo_dkms
                ;;
            hyprland)
                undo_hyprland
                ;;
        esac
    done

    echo "Undo completed. Please reboot your system to apply changes."
    exit 0
}

echo "Starting NVIDIA driver check and installation script..."

if [[ "$UNDO_MODE" == true ]]; then
    perform_undo
fi

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
