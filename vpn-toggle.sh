#!/bin/bash

scrDir=\$(dirname \"\$(realpath \"\$0\")\") 
source \"\$scrDir/globalcontrol.sh\" ||

VPN_DIR="$HOME/.vpngate"
STATE_FILE="$VPN_DIR/vpn_state"
CONFIG_FILE="$VPN_DIR/vpngate.ovpn"
API_CACHE="$VPN_DIR/server_list.csv"
NOTIFY_ID=1001 # Unique ID for replacing notifications

# Ensure the script is not run as root
if [ "$EUID" -eq 0 ]; then
    echo "Please do not run this script as root."
    exit 1
fi

# Function to install dependencies
install_dependencies() {
    echo "Installing OpenVPN, curl, and libnotify..."
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm openvpn curl libnotify
}

# Function to show animated notification
show_animated_notification() {
    local message="$1" # e.g., "VPN Starting" or "VPN Changing"
    local pid_file="$2" # File to store animation PID
    # Start animation loop in background
    (
        while true; do
            notify-send -a "VPNGate" -r "$NOTIFY_ID" "$message." ""
            sleep 0.5
            notify-send -a "VPNGate" -r "$NOTIFY_ID" "$message.." ""
            sleep 0.5
            notify-send -a "VPNGate" -r "$NOTIFY_ID" "$message..." ""
            sleep 0.5
        done
    ) &
    # Store animation PID
    echo $! > "$pid_file"
}

# Function to stop animated notification
stop_animated_notification() {
    local pid_file="$1"
    if [ -f "$pid_file" ]; then
        kill "$(cat "$pid_file")" 2>/dev/null
        rm -f "$pid_file"
    fi
}

# Function to download a VPNGate config and server info
download_vpngate_config() {
    echo "Downloading VPNGate configuration..."
    mkdir -p "$VPN_DIR"
    # Fetch server list from VPNGate
    if ! curl -s 'http://www.vpngate.net/api/iphone/' > "$API_CACHE"; then
        echo "Error: curl failed to fetch VPNGate API. Check network or API availability."
        notify-send -a "VPNGate" "VPN Error" "Failed to fetch VPNGate API"
        exit 1
    fi
    # Check if API response is empty or too small
    if [ ! -s "$API_CACHE" ]; then
        echo "Error: API response is empty."
        notify-send -a "VPNGate" "VPN Error" "API response is empty"
        exit 1
    fi
    # Debug: Log response size and first few lines
    echo "Debug: API response size: $(wc -l < "$API_CACHE") lines"
    echo "Debug: First few lines of API response:"
    head -n 5 "$API_CACHE"
    # Extract a random server line with base64 config
    CONFIG_LINE=$(grep -v '*' "$API_CACHE" | grep -v '^#' | shuf -n 1)
    if [ -z "$CONFIG_LINE" ]; then
        echo "Error: No valid server configs found in API response."
        notify-send -a "VPNGate" "VPN Error" "No valid server configs found"
        exit 1
    fi
    # Extract server details and base64 config
    SERVER_IP=$(echo "$CONFIG_LINE" | cut -d',' -f2)
    COUNTRY=$(echo "$CONFIG_LINE" | cut -d',' -f7)
    CITY=$(echo "$CONFIG_LINE" | cut -d',' -f6 | cut -d'_' -f1) # Clean city name
    BASE64_CONFIG=$(echo "$CONFIG_LINE" | cut -d',' -f15)
    if [ -z "$BASE64_CONFIG" ]; then
        echo "Error: No base64 config data found in API response."
        notify-send -a "VPNGate" "VPN Error" "No base64 config data found"
        exit 1
    fi
    # Decode base64 config and save to file
    echo "$BASE64_CONFIG" | base64 -d > "$CONFIG_FILE"
    if [ ! -s "$CONFIG_FILE" ]; then
        echo "Error: Decoded config is empty or invalid."
        notify-send -a "VPNGate" "VPN Error" "Decoded config is empty"
        exit 1
    fi
    # Debug: Verify config file
    echo "Debug: Config file created at $CONFIG_FILE, size: $(wc -c < "$CONFIG_FILE") bytes"
    # Store server info for notification
    echo "$SERVER_IP,$CITY,$COUNTRY" > "$VPN_DIR/server_info"
}

# Function to get server location for notification
get_server_location() {
    if [ -f "$VPN_DIR/server_info" ]; then
        SERVER_INFO=$(cat "$VPN_DIR/server_info")
        CITY=$(echo "$SERVER_INFO" | cut -d',' -f2)
        COUNTRY=$(echo "$SERVER_INFO" | cut -d',' -f3)
        echo "$CITY, $COUNTRY"
    else
        echo "Unknown Location"
    fi
}

# Function to start VPN
start_vpn() {
    echo "Starting VPN..."
    # Show animated "VPN Starting..." notification
    show_animated_notification "VPN Starting" "$VPN_DIR/anim.pid"
    sudo openvpn --config "$CONFIG_FILE" --daemon --writepid "$VPN_DIR/vpn.pid"
    sleep 5 # Wait for connection
    # Stop animation
    stop_animated_notification "$VPN_DIR/anim.pid"
    if pgrep -F "$VPN_DIR/vpn.pid" >/dev/null; then
        echo "VPN is running."
        echo "on" > "$STATE_FILE"
        LOCATION=$(get_server_location)
        notify-send -a "VPNGate" -r "$NOTIFY_ID" "VPN Connected" "Connected to $LOCATION"
    else
        echo "Failed to start VPN. Check OpenVPN logs."
        notify-send -a "VPNGate" -r "$NOTIFY_ID" "VPN Error" "Failed to connect to VPN"
        exit 1
    fi
}

# Function to stop VPN
stop_vpn() {
    local silent="$1" # If "silent", skip disconnection notification
    echo "Stopping VPN..."
    if [ -f "$VPN_DIR/vpn.pid" ]; then
        sudo kill -SIGTERM "$(cat "$VPN_DIR/vpn.pid")"
        rm -f "$VPN_DIR/vpn.pid"
        echo "VPN stopped."
        echo "off" > "$STATE_FILE"
        if [ "$silent" != "silent" ]; then
            notify-send -a "VPNGate" -r "$NOTIFY_ID" "VPN Disconnected" "VPN has been disconnected"
        fi
    else
        echo "No VPN process found."
        if [ "$silent" != "silent" ]; then
            notify-send -a "VPNGate" -r "$NOTIFY_ID" "VPN Error" "No VPN process found"
        fi
    fi
}

# Function to change VPN server
change_vpn_server() {
    echo "Changing VPN server..."
    # Show animated "VPN Changing Lect..." notification
    show_animated_notification "VPN Changing" "$VPN_DIR/anim.pid"
    # Stop current VPN if running, silently
    if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "on" ]; then
        stop_vpn "silent"
    fi
    # Remove existing config to force new download
    rm -f "$CONFIG_FILE" "$VPN_DIR/server_info"
    # Download and start new VPN
    download_vpngate_config
    # Stop animation
    stop_animated_notification "$VPN_DIR/anim.pid"
    start_vpn
}

# Check if dependencies are installed
if ! command -v openvpn >/dev/null || ! command -v curl >/dev/null || ! command -v notify-send >/dev/null; then
    install_dependencies
fi

# Handle script arguments
case "$1" in
    change)
        change_vpn_server
        ;;
    *)
        # Default toggle behavior
        if [ ! -f "$CONFIG_FILE" ]; then
            download_vpngate_config
        fi
        if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "on" ]; then
            stop_vpn
        else
            start_vpn
        fi
        ;;
esac
