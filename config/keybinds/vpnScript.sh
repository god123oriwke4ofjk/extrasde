#!/bin/bash

# Determine the calling user's home directory and username
USER_NAME="$USER"
USER_HOME="$HOME"

# Paths based on the user's home directory
VPN_DIR="$USER_HOME/.config/vpn"
AUTH_FILE="$VPN_DIR/auth.txt"
SERVERS_DIR="$VPN_DIR/servers"
PID_FILE="/tmp/vpnbook.pid"
LOG_FILE="/tmp/vpnbook.log"

# Check if openvpn is installed
if ! command -v openvpn &> /dev/null; then
    echo "Error: openvpn is not installed. Please install it using 'sudo pacman -S openvpn'."
    exit 1
fi

# Check if servers directory exists
if [ ! -d "$SERVERS_DIR" ]; then
    echo "Error: Servers directory $SERVERS_DIR does not exist."
    exit 1
fi

# Check if auth file exists
if [ ! -f "$AUTH_FILE" ]; then
    echo "Error: Auth file $AUTH_FILE does not exist."
    exit 1
fi

# Fix auth.txt permissions
fix_auth_permissions() {
    if [ -f "$AUTH_FILE" ]; then
        chmod 600 "$AUTH_FILE"
        chown "$USER_NAME":"$USER_NAME" "$AUTH_FILE"
        echo "Fixed permissions for $AUTH_FILE."
    fi
}

# Function to check if VPN is running
is_vpn_running() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

# Function to start VPN
start_vpn() {
    # Select a random .ovpn file from servers directory
    OVPN_FILE=$(find "$SERVERS_DIR" -type f -name "*.ovpn" | shuf -n 1)
    if [ -z "$OVPN_FILE" ]; then
        echo "Error: No .ovpn files found in $SERVERS_DIR."
        exit 1
    fi
    echo "Attempting to connect using $OVPN_FILE"

    # Fix auth.txt permissions before connecting
    fix_auth_permissions

    # Clear previous log file
    sudo rm -f "$LOG_FILE"

    # Start OpenVPN in background with additional options
    sudo openvpn --config "$OVPN_FILE" \
                 --auth-user-pass "$AUTH_FILE" \
                 --auth-nocache \
                 --comp-lzo no \
                 --daemon \
                 --log "$LOG_FILE" \
                 --writepid "$PID_FILE"
    sleep 5 # Increased wait for connection to establish

    # Fix log file permissions
    if [ -f "$LOG_FILE" ]; then
        sudo chown "$USER_NAME":"$USER_NAME" "$LOG_FILE"
        sudo chmod 644 "$LOG_FILE"
    fi

    if is_vpn_running; then
        echo "VPN connected using $OVPN_FILE."
        notify-send "VPN Connected" "Connected to VPNBook using $(basename "$OVPN_FILE")" 2>/dev/null || true
    else
        echo "Error: Failed to connect VPN. Check $LOG_FILE for details."
        notify-send "VPN Error" "Failed to connect using $(basename "$OVPN_FILE"). Check $LOG_FILE" 2>/dev/null || true
        exit 1
    fi
}

# Function to stop VPN
stop_vpn() {
    if [ -f "$PID_FILE" ]; then
        sudo kill "$(cat "$PID_FILE")"
        rm -f "$PID_FILE"
        echo "VPN disconnected."
        notify-send "VPN Disconnected" "VPNBook connection terminated" 2>/dev/null || true
    else
        echo "VPN is not running."
        notify-send "VPN Status" "No VPN connection active" 2>/dev/null || true
    fi
}

# Toggle VPN
toggle_vpn() {
    if is_vpn_running; then
        stop_vpn
    else
        start_vpn
    fi
}

# Main script
case "$1" in
    toggle)
        toggle_vpn
        ;;
    *)
        echo "Usage: $0 toggle"
        exit 1
        ;;
esac
