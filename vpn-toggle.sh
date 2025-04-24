#!/bin/bash

scrDir=\$(dirname \"\$(realpath \"\$0\")\") 
source \"\$scrDir/globalcontrol.sh\" ||

VPN_DIR="$HOME/.vpngate"
STATE_FILE="$VPN_DIR/vpn_state"
CONFIG_FILE="$VPN_DIR/vpngate.ovpn"
API_CACHE="$VPN_DIR/server_list.csv"
NOTIFY_ID=1001

if [ "$EUID" -eq 0 ]; then
    echo "Please do not run this script as root."
    exit 1
fi

install_dependencies() {
    echo "Installing OpenVPN, curl, and libnotify..."
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm openvpn curl libnotify
}

show_animated_notification() {
    local message="$1"
    local pid_file="$2" 
    (
        while true; do
            notify-send -a \"Hyde Alert\" -i \"\${ICONS_DIR}/Wallbash-Icon/loading1.svg\" \"VPNGate\" -r "$NOTIFY_ID" "$message." ""
            sleep 0.175
            notify-send -a \"Hyde Alert\" -i \"\${ICONS_DIR}/Wallbash-Icon/loading2.svg\" \"VPNGate\" -r "$NOTIFY_ID" "$message." ""
            sleep 0.175
            notify-send -a \"Hyde Alert\" -i \"\${ICONS_DIR}/Wallbash-Icon/loading3.svg\" \"VPNGate\" -r "$NOTIFY_ID" "$message." ""
            sleep 0.175
            
            notify-send -a \"Hyde Alert\" -i \"\${ICONS_DIR}/Wallbash-Icon/loading4.svg\" \"VPNGate\" -r "$NOTIFY_ID" "$message.." ""
            sleep 0.175
            notify-send -a \"Hyde Alert\" -i \"\${ICONS_DIR}/Wallbash-Icon/loading1.svg\" \"VPNGate\" -r "$NOTIFY_ID" "$message.." ""
            sleep 0.175
            notify-send -a \"Hyde Alert\" -i \"\${ICONS_DIR}/Wallbash-Icon/loading2.svg\" \"VPNGate\" -r "$NOTIFY_ID" "$message.." ""
            sleep 0.175
    
            notify-send -a \"Hyde Alert\" -i \"\${ICONS_DIR}/Wallbash-Icon/loading3.svg\" \"VPNGate\" -r "$NOTIFY_ID" "$message..." ""
            sleep 0.175
            notify-send -a \"Hyde Alert\" -i \"\${ICONS_DIR}/Wallbash-Icon/loading4.svg\" \"VPNGate\" -r "$NOTIFY_ID" "$message..." ""
            sleep 0.175
            notify-send -a \"Hyde Alert\" -i \"\${ICONS_DIR}/Wallbash-Icon/loading5.svg\" \"VPNGate\" -r "$NOTIFY_ID" "$message..." ""
            sleep 0.175
        done
    ) &
    echo $! > "$pid_file"
}

stop_animated_notification() {
    local pid_file="$1"
    if [ -f "$pid_file" ]; then
        kill "$(cat "$pid_file")" 2>/dev/null
        rm -f "$pid_file"
    fi
}

download_vpngate_config() {
    echo "Downloading VPNGate configuration..."
    mkdir -p "$VPN_DIR"
    if ! curl -s 'http://www.vpngate.net/api/iphone/' > "$API_CACHE"; then
        echo "Error: curl failed to fetch VPNGate API. Check network or API availability."
        notify-send -a \"HyDE Alert\" -r 91190 -t 1100 -i \"\${ICONS_DIR}/Wallbash-Icon/error.svg\" "VPNGate" "VPN Error" "Failed to fetch VPNGate API"
        exit 1
    fi
    if [ ! -s "$API_CACHE" ]; then
        echo "Error: API response is empty."
        notify-send -a "VPNGate" "VPN Error" "API response is empty"
        exit 1
    fi
    echo "Debug: API response size: $(wc -l < "$API_CACHE") lines"
    echo "Debug: First few lines of API response:"
    head -n 5 "$API_CACHE"
    CONFIG_LINE=$(grep -v '*' "$API_CACHE" | grep -v '^#' | shuf -n 1)
    if [ -z "$CONFIG_LINE" ]; then
        echo "Error: No valid server configs found in API response."
        notify-send -a "VPNGate" "VPN Error" "No valid server configs found"
        exit 1
    fi
    SERVER_IP=$(echo "$CONFIG_LINE" | cut -d',' -f2)
    COUNTRY=$(echo "$CONFIG_LINE" | cut -d',' -f7)
    CITY=$(echo "$CONFIG_LINE" | cut -d',' -f6 | cut -d'_' -f1) 
    BASE64_CONFIG=$(echo "$CONFIG_LINE" | cut -d',' -f15)
    if [ -z "$BASE64_CONFIG" ]; then
        echo "Error: No base64 config data found in API response."
        notify-send -a "VPNGate" "VPN Error" "No base64 config data found"
        exit 1
    fi
    echo "$BASE64_CONFIG" | base64 -d > "$CONFIG_FILE"
    if [ ! -s "$CONFIG_FILE" ]; then
        echo "Error: Decoded config is empty or invalid."
        notify-send -a "VPNGate" "VPN Error" "Decoded config is empty"
        exit 1
    fi
    echo "Debug: Config file created at $CONFIG_FILE, size: $(wc -c < "$CONFIG_FILE") bytes"
    echo "$SERVER_IP,$CITY,$COUNTRY" > "$VPN_DIR/server_info"
}

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

start_vpn() {
    echo "Starting VPN..."
    show_animated_notification "VPN Starting" "$VPN_DIR/anim.pid"
    sudo openvpn --config "$CONFIG_FILE" --daemon --writepid "$VPN_DIR/vpn.pid"
    sleep 5 
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

stop_vpn() {
    local silent="$1" 
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

change_vpn_server() {
    echo "Changing VPN server..."
    show_animated_notification "VPN Changing" "$VPN_DIR/anim.pid"
    if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "on" ]; then
        stop_vpn "silent"
    fi
    rm -f "$CONFIG_FILE" "$VPN_DIR/server_info"
    download_vpngate_config
    stop_animated_notification "$VPN_DIR/anim.pid"
    start_vpn
}

if ! command -v openvpn >/dev/null || ! command -v curl >/dev/null || ! command -v notify-send >/dev/null; then
    install_dependencies
fi

case "$1" in
    change)
        change_vpn_server
        ;;
    *)
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
