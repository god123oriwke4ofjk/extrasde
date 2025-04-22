#!/bin/bash

if ! command -v yay &> /dev/null; then
    echo "yay is not installed. Installing yay..."
    sudo pacman -Syu --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay
fi

echo "Installing Brave..."
yay -S --noconfirm brave-bin

if ! command -v flatpak &> /dev/null; then
    echo "Flatpak is not installed. Installing flatpak..."
    sudo pacman -Syu --noconfirm flatpak
fi

if ! flatpak remotes | grep -q flathub; then
    echo "Flathub is not enabled. Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

echo "Installing Vesktop..."
flatpak install -y flathub dev.vencord.Vesktop

echo "Modifying Vesktop desktop file..."

DESKTOP_FILE="dev.vencord.Vesktop.desktop"
SOURCE_DIR="$HOME/.local/share/flatpak/exports/share/applications"
USER_DIR="$HOME/.local/share/applications"
ARGUMENT="--enable-blink-features=MiddleClickAutoscroll"

if [[ ! -f "$SOURCE_DIR/$DESKTOP_FILE" ]]; then
    echo "Error: $DESKTOP_FILE not found in $SOURCE_DIR"
    exit 1
fi

mkdir -p "$USER_DIR"

if [[ ! -f "$USER_DIR/$DESKTOP_FILE" ]]; then
    cp "$SOURCE_DIR/$DESKTOP_FILE" "$USER_DIR/$DESKTOP_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to copy $DESKTOP_FILE to $USER_DIR"
        exit 1
    fi
    echo "Copied $DESKTOP_FILE to $USER_DIR"
fi

BACKUP_FILE="$USER_DIR/$DESKTOP_FILE.bak"
cp "$USER_DIR/$DESKTOP_FILE" "$BACKUP_FILE"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create backup of $DESKTOP_FILE"
    exit 1
fi
echo "Created backup at $BACKUP_FILE"

if grep -q -- "$ARGUMENT" "$USER_DIR/$DESKTOP_FILE"; then
    echo "The $ARGUMENT is already present in the Exec line"
else
    sed -i "/^Exec=/ s/@@u %U @@/$ARGUMENT @@u %U @@/" "$USER_DIR/$DESKTOP_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to modify Exec line in $DESKTOP_FILE"
        exit 1
    fi
    echo "Successfully added $ARGUMENT to the Exec line in $USER_DIR/$DESKTOP_FILE"
    echo "New Exec line:"
    grep "^Exec=" "$USER_DIR/$DESKTOP_FILE"
fi

echo "Warning: Adding $ARGUMENT may cause Vesktop to crash on some systems (e.g., Bazzite Linux with KDE Wayland)."
echo "If Vesktop crashes, restore the backup by running:"
echo "  cp \"$BACKUP_FILE\" \"$USER_DIR/$DESKTOP_FILE\""

echo "Installation and modification complete!"
exit 0
