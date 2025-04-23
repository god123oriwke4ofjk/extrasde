#!/bin/bash

# Directory to store VPNGate configs and state
VPN_DIR="$HOME/.vpngate"
STATE_FILE="$VPN_DIR/vpn_state"
CONFIG_FILE="$VPN_DIR/vpngate.ovpn"

# Ensure the script is not run as root
if [ "$EUID" -eq 0 ]; then
    echo "Please do not run this script as root."
    exit 1
fi

# Function to install dependencies
install_dependencies() {
    echo "Installing OpenVPN and dependencies..."
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm openvpn curl
}

# Function to download a VPNGate config
download_vpngate_config() {
    echo "Downloading VPNGate configuration..."
    mkdir -p "$VPN_DIR"
    # Fetch server list from VPNGate and extract an OpenVPN config URL
    CONFIG_URL=$(curl -s 'http://www.vpngate.net/api/iphone/' | grep -v '*' | cut -d',' -f15 | grep '.ovpn' | shuf -n 1)
    if [ -z "$CONFIG_URL" ]; then
        echo "Failed to retrieve VPNGate config. Check your internet connection."
        exit 1
    }
    # Download the config file
    curl -s "$CONFIG_URL" -o "$CONFIG_FILE"
    if [ ! -s "$CONFIG_FILE" ]; then
        echo "Downloaded config is empty or invalid."
        exit 1
    }
}

# Function to start VPN
start_vpn() {
    echo "Starting VPN..."
    sudo openvpn --config "$CONFIG_FILE" --daemon --writepid "$VPN_DIR/vpn.pid"
    sleep 5 # Wait for connection
    if pgrep -F "$VPN_DIR/vpn.pid" >/dev/null; then
        echo "VPN is running."
        echo "on" > "$STATE_FILE"
    else
        echo "Failed to start VPN. Check OpenVPN logs."
        exit 1
    }
}

# Function to stop VPN
stop_vpn() {
    echo "Stopping VPN..."
    if [ -f "$VPN_DIR/vpn.pid" ]; then
        sudo kill -SIGTERM "$(cat "$VPN_DIR/vpn.pid")"
        rm -f "$VPN_DIR/vpn.pid"
        echo "VPN stopped."
        echo "off" > "$STATE_FILE"
    else
        echo "No VPN process found."
    fi
}

# Check if dependencies are installed
if ! command -v openvpn >/dev/null || ! command -v curl >/dev/null; then
    install_dependencies
fi

# Check if VPN config exists, download if not
if [ ! -f "$CONFIG_FILE" ]; then
    download_vpngate_config
fi

# Check VPN state and toggle
if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "on" ]; then
    stop_vpn
else
    start_vpn
fi
