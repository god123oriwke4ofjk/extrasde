#!/bin/bash

if ! command -v flatpak &> /dev/null; then
    echo "Flatpak is not installed. Installing flatpak..."
    sudo pacman -Syu --noconfirm flatpak
fi

if ! flatpak remotes | grep -q flathub; then
    echo "Flathub is not enabled. Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

echo "Installing Discord..."
flatpak install -y flathub com.discordapp.Discord

echo "Installation complete!"