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

echo "Modifying Brave desktop file..."

BRAVE_DESKTOP_FILE="brave-browser.desktop"
BRAVE_SOURCE_DIR="/usr/share/applications"
USER_DIR="$HOME/.local/share/applications"
ARGUMENT="--enable-blink-features=MiddleClickAutoscroll"

if [[ ! -f "$BRAVE_SOURCE_DIR/$BRAVE_DESKTOP_FILE" ]]; then
    echo "Error: $BRAVE_DESKTOP_FILE not found in $BRAVE_SOURCE_DIR"
    exit 1
fi

mkdir -p "$USER_DIR"

if [[ ! -f "$USER_DIR/$BRAVE_DESKTOP_FILE" ]]; then
    cp "$BRAVE_SOURCE_DIR/$BRAVE_DESKTOP_FILE" "$USER_DIR/$BRAVE_DESKTOP_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to copy $BRAVE_DESKTOP_FILE to $USER_DIR"
        exit 1
    fi
    echo "Copied $BRAVE_DESKTOP_FILE to $USER_DIR"
fi

BRAVE_BACKUP_FILE="$USER_DIR/$BRAVE_DESKTOP_FILE.bak"
cp "$USER_DIR/$BRAVE_DESKTOP_FILE" "$BRAVE_BACKUP_FILE"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create backup of $BRAVE_DESKTOP_FILE"
    exit 1
fi
echo "Created backup at $BRAVE_BACKUP_FILE"

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

VESKTOP_DESKTOP_FILE="dev.vencord.Vesktop.desktop"
VESKTOP_SOURCE_DIR="$HOME/.local/share/flatpak/exports/share/applications"

if [[ ! -f "$VESKTOP_SOURCE_DIR/$VESKTOP_DESKTOP_FILE" ]]; then
    echo "Error: $VESKTOP_DESKTOP_FILE not found in $VESKTOP_SOURCE_DIR"
    exit 1
fi

if [[ ! -f "$USER_DIR/$VESKTOP_DESKTOP_FILE" ]]; then
    cp "$VESKTOP_SOURCE_DIR/$VESKTOP_DESKTOP_FILE" "$USER_DIR/$VESKTOP_DESKTOP_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to copy $VESKTOP_DESKTOP_FILE to $USER_DIR"
        exit 1
    fi
    echo "Copied $VESKTOP_DESKTOP_FILE to $USER_DIR"
fi

VESKTOP_BACKUP_FILE="$USER_DIR/$VESKTOP_DESKTOP_FILE.bak"
cp "$USER_DIR/$VESKTOP_DESKTOP_FILE" "$VESKTOP_BACKUP_FILE"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create backup of $VESKTOP_DESKTOP_FILE"
    exit 1
fi
echo "Created backup at $VESKTOP_BACKUP_FILE"

if grep -q -- "$ARGUMENT" "$USER_DIR/$VESKTOP_DESKTOP_FILE"; then
    echo "The $ARGUMENT is already present in the Exec line for Vesktop"
else
    sed -i "/^Exec=/ s/@@u %U @@/$ARGUMENT @@u %U @@/" "$USER_DIR/$VESKTOP_DESKTOP_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to modify Exec line in $VESKTOP_DESKTOP_FILE"
        exit 1
    fi
    echo "Successfully added $ARGUMENT to the Exec line in $USER_DIR/$VESKTOP_DESKTOP_FILE"
    echo "New Exec line:"
    grep "^Exec=" "$USER_DIR/$VESKTOP_DESKTOP_FILE"
fi

echo "Warning: Adding $ARGUMENT may cause Brave or Vesktop to crash on some systems (e.g., Bazzite Linux with KDE Wayland)."
echo "If Brave crashes, restore the backup by running:"
echo "  cp \"$BRAVE_BACKUP_FILE\" \"$USER_DIR/$BRAVE_DESKTOP_FILE\""
echo "If Vesktop crashes, restore the backup by running:"
echo "  cp \"$VESKTOP_BACKUP_FILE\" \"$USER_DIR/$VESKTOP_DESKTOP_FILE\""

echo "Installation and modification complete!"
exit 0
