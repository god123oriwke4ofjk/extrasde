#!/bin/bash

set -e

AUTH_FILE="$HOME/.config/vpn/auth.txt"
SERVERS_DIR="$HOME/.config/vpn/servers"
SOURCE_SERVERS_DIR="$HOME/Extra/config/servers"
SCRAPER_SCRIPT="$HOME/Extra/config/vpnbook-password-scraper.sh"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_vpn_running() {
    pgrep openvpn >/dev/null 2>&1
}

get_random_server() {
    local folder
    folder=$(ls -d "$SERVERS_DIR"/*/ | shuf -n 1)
    find "$folder" -name "*.ovpn" | shuf -n 1
}

toggle_vpn() {
    if is_vpn_running; then
        echo "Disconnecting VPN..."
        sudo killall openvpn
        echo "VPN disconnected."
    else
        if [[ ! -f "$AUTH_FILE" ]]; then
            echo "Error: Authentication file $AUTH_FILE not found."
            exit 1
        fi
        if [[ ! -d "$SERVERS_DIR" ]]; then
            echo "Error: Servers directory $SERVERS_DIR not found."
            exit 1
        fi
        local server
        server=$(get_random_server)
        if [[ -z "$server" ]]; then
            echo "Error: No .ovpn files found in $SERVERS_DIR."
            exit 1
        fi
        echo "Connecting to VPN using $server..."
        sudo openvpn --config "$server" --auth-user-pass "$AUTH_FILE" --daemon
        sleep 2 
        if is_vpn_running; then
            echo "VPN connected successfully."
        else
            echo "Error: Failed to connect to VPN."
            exit 1
        fi
    fi
}

setup_vpn() {
    echo "Checking and installing dependencies..."

    sudo pacman -Syu --noconfirm

    if ! command_exists openvpn; then
        echo "Installing openvpn..."
        sudo pacman -S --noconfirm openvpn
    else
        echo "openvpn is already installed."
    fi

    if ! command_exists nm-openvpn; then
        echo "Installing networkmanager-openvpn..."
        sudo pacman -S --noconfirm networkmanager-openvpn
    else
        echo "networkmanager-openvpn is already installed."
    fi

    if [[ ! -f "$AUTH_FILE" ]]; then
        echo "Running vpnbook-password-scraper.sh to create auth.txt..."
        bash "$SCRAPER_SCRIPT"
        if [[ ! -f "$AUTH_FILE" ]]; then
            echo "Error: vpnbook-password-scraper.sh failed to create $AUTH_FILE."
            exit 1
        fi
        chmod 600 "$AUTH_FILE"
        echo "auth.txt created at $AUTH_FILE."
    else
        echo "auth.txt already exists at $AUTH_FILE."
    fi

    mkdir -p "$SERVERS_DIR"

    echo "Synchronizing servers from $SOURCE_SERVERS_DIR to $SERVERS_DIR..."
    rm -rf "$SERVERS_DIR"/*
    cp -r "$SOURCE_SERVERS_DIR"/* "$SERVERS_DIR"/
    if [[ $? -eq 0 ]]; then
        echo "Servers synchronized successfully."
    else
        echo "Error: Failed to synchronize servers from $SOURCE_SERVERS_DIR."
        exit 1
    fi

    echo "Setup complete."
}

case "$1" in
    toggle)
        toggle_vpn
        ;;
    setup)
        setup_vpn
        ;;
    *)
        echo "Usage: $0 {toggle|setup}"
        echo "  toggle: Connects or disconnects a random VPNBook server."
        echo "  setup: Installs dependencies, runs vpnbook-password-scraper.sh if needed, and syncs servers."
        exit 1
        ;;
esac

exit 0
