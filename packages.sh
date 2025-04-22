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
flatpak install -y vesktop

echo "Installation complete!"