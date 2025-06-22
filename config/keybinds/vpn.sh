#!/bin/bash

set -e

AUTH_FILE="$HOME/.config/vpn/auth.txt"
SERVERS_DIR="$HOME/.config/vpn/servers"
SOURCE_SERVERS_DIR="$HOME/Extra/config/servers"
SCRAPER_SCRIPT="$HOME/Extra/config/vpnbook-password-scraper.sh"
ICON_DIR="$HOME/.local/share/icons/Wallbash-Icon"
LOCK_FILE="$HOME/.config/vpn/scraper.lock"
NOTIF_ID=1000
INSTALL_SCRIPT="$HOME/Extra/install.sh"
VPNBOOK_PASS_DIR="$HOME/Extra/config/vpnbook-password"
VPNBOOK_PASS_FILE="$VPNBOOK_PASS_DIR/vpn_password.txt"
VPNBOOK_GIT_URL="https://github.com/ERM073/vpnbook-password"
INSTALL_LOG="$HOME/.local/lib/hyde/install.log"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_sudoers_log() {
    if [[ -f "$INSTALL_LOG" ]] && grep -q "CREATED_SUDOERS: /etc/sudoers.d/hyde-vpn" "$INSTALL_LOG"; then
        echo "Sudoers configuration confirmed via $INSTALL_LOG."
    else
        echo "Error: Sudoers configuration not found in $INSTALL_LOG. Running $INSTALL_SCRIPT --sudoers..."
        notify-send -u critical -i "$ICON_DIR/error.svg" "Configuring Sudoers" "Running install.sh --sudoers to set up passwordless sudo..."
        if ! bash "$INSTALL_SCRIPT" -outsudo --sudoers; then
            echo "Error: Failed to run $INSTALL_SCRIPT -outsudo --sudoers."
            notify-send -u critical -i "$ICON_DIR/error.svg" "Sudoers Setup Failed" "Failed to configure passwordless sudo."
            exit 1
        fi
        if [[ ! -f "$INSTALL_LOG" ]] || ! grep -q "CREATED_SUDOERS: /etc/sudoers.d/hyde-vpn" "$INSTALL_LOG"; then
            echo "Error: Sudoers configuration still not confirmed after running install.sh."
            notify-send -u critical -i "$ICON_DIR/error.svg" "Sudoers Setup Failed" "Sudoers configuration not found in $INSTALL_LOG after running install.sh."
            exit 1
        fi
        echo "Sudoers configured successfully."
        notify-send -u normal -i "$ICON_DIR/vpn.svg" "Sudoers Configured" "Passwordless sudo configured successfully."
    fi
}

update_auth_file() {
    if [[ ! -d "$VPNBOOK_PASS_DIR" ]]; then
        echo "Cloning vpnbook-password repository..."
        mkdir -p "$HOME/Extra/config"
        git clone "$VPNBOOK_GIT_URL" "$VPNBOOK_PASS_DIR" || {
            echo "Error: Failed to clone vpnbook-password repository."
            notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Failed to clone vpnbook-password repository."
            exit 1
        }
    fi
    if [[ ! -f "$VPNBOOK_PASS_FILE" ]]; then
        echo "Error: Password file $VPNBOOK_PASS_FILE not found."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Password file $VPNBOOK_PASS_FILE not found."
        exit 1
    fi
    local password
    password=$(cat "$VPNBOOK_PASS_FILE")
    if [[ -z "$password" ]]; then
        echo "Error: Password file $VPNBOOK_PASS_FILE is empty."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Password file $VPNBOOK_PASS_FILE is empty."
        exit 1
    fi
    mkdir -p "$(dirname "$AUTH_FILE")"
    echo -e "vpnbook\n$password" > "$AUTH_FILE"
    chmod 600 "$AUTH_FILE" 2>/dev/null
    echo "Authentication file $AUTH_FILE created/updated."
}

is_vpn_running() {
    pgrep openvpn >/dev/null 2>&1
}

is_scraper_running() {
    [[ -f "$LOCK_FILE" ]]
}

get_random_server() {
    local folder
    folder=$(ls -d "$SERVERS_DIR"/*/ | shuf -n 1)
    find "$folder" -name "*.ovpn" | shuf -n 1
}

get_current_server() {
    local pid
    pid=$(pgrep openvpn)
    if [[ -n "$pid" ]]; then
        local cmdline
        cmdline=$(cat /proc/"$pid"/cmdline 2>/dev/null | tr '\0' ' ')
        echo "$cmdline" | grep -o -- "--config [^ ]*" | cut -d' ' -f2
    fi
}

send_connecting_notification() {
    local pid=$1
    local dots=("." ".." "...")
    local icons=("loading1.svg" "loading2.svg" "loading3.svg" "loading4.svg" "loading5.svg")
    local dot_index=0
    local icon_index=0
    local start_time=$(date +%s)
    local timeout=15
    while kill -0 "$pid" 2>/dev/null; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        if [[ $elapsed -ge $timeout ]]; then
            sudo /usr/bin/killall openvpn 2>/dev/null
            notify-send -u critical -i "$ICON_DIR/error.svg" -r "$NOTIF_ID" "VPN Connection Failed" "Connection timed out after 15 seconds."
            exit 1
        fi
        notify-send -u normal -i "$ICON_DIR/${icons[icon_index]}" -r "$NOTIF_ID" "VPN Connecting${dots[dot_index]}" "Attempting to connect to VPN..."
        dot_index=$(( (dot_index + 1) % 3 ))
        icon_index=$(( (icon_index + 1) % 5 ))
        sleep 0.2
    done
}

run_scraper() {
    touch "$LOCK_FILE"
    notify-send -u critical -i "$ICON_DIR/error.svg" "Scraping New Credentials" "Authentication failed. Scraping new credentials, please wait..."
    bash "$SCRAPER_SCRIPT" && {
        chmod 600 "$AUTH_FILE" 2>/dev/null
        rm -f "$LOCK_FILE"
        notify-send -u normal -i "$ICON_DIR/vpn.svg" "Credentials Updated" "New VPN credentials have been scraped successfully."
    } || {
        rm -f "$LOCK_FILE"
        notify-send -u critical -i "$ICON_DIR/error.svg" "Scraper Error" "Failed to scrape new credentials."
        exit 1
    }
}

map_country() {
    local input
    input=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$input" in
        us|usa|unitedstates) echo "usa";;
        fr|france) echo "france";;
        uk|england|greatbritain) echo "england";;
        *) echo "$input";;
    esac
}

connect_to_server() {
    local server=$1
    update_auth_file
    local temp_log=$(mktemp)
    sudo openvpn --config "$server" --auth-user-pass "$AUTH_FILE" --daemon --log "$temp_log" &
    local vpn_pid=$!
    send_connecting_notification "$vpn_pid" &
    local notif_pid=$!
    wait "$vpn_pid" 2>/dev/null
    kill "$notif_pid" 2>/dev/null
    if grep -q "AUTH_FAILED" "$temp_log" 2>/dev/null; then
        echo "Authentication failed. Triggering credential scraper..."
        rm -f "$temp_log"
        run_scraper &
        notify-send -u critical -i "$ICON_DIR/error.svg" -r "$NOTIF_ID" "VPN Connection Failed" "Authentication failed. Scraping new credentials..."
        exit 1
    fi
    rm -f "$temp_log"
    if is_vpn_running; then
        local server_name=$(basename "$server" .ovpn)
        notify-send -u normal -i "$ICON_DIR/vpn.svg" -r "$NOTIF_ID" "VPN Connected" "Connected to $server_name."
        echo "VPN connected successfully."
    else
        echo "Error: Failed to connect to VPN."
        notify-send -u critical -i "$ICON_DIR/error.svg" -r "$NOTIF_ID" "VPN Connection Failed" "Failed to connect to $server."
        exit 1
    fi
}

connect_vpn() {
    check_sudoers_log
    if is_scraper_running; then
        echo "Error: Credential scraper is running."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Please wait until credential scraping is complete."
        exit 1
    fi
    if is_vpn_running; then
        echo "Error: VPN is already connected."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Disconnect the current VPN before connecting to a new one."
        exit 1
    fi
    if [[ ! -d "$SERVERS_DIR" ]]; then
        echo "Error: Servers directory $SERVERS_DIR not found."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Servers directory $SERVERS_DIR not found."
        exit 1
    fi
    if [[ -z "$1" ]]; then
        echo "Error: Missing argument for connect. Usage: vpn.sh connect {random|<country>|<country_code>|<server_name>}"
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Missing argument for connect. Use random, country, country code, or server name."
        exit 1
    fi
    if [[ "$1" == "random" ]]; then
        local server
        server=$(get_random_server)
        if [[ -z "$server" ]]; then
            echo "Error: No .ovpn files found in $SERVERS_DIR."
            notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "No .ovpn files found in $SERVERS_DIR."
            exit 1
        fi
        echo "Connecting to VPN using $server..."
        connect_to_server "$server"
    else
        local country_dir
        country_dir=$(map_country "$1")
        if [[ -d "$SERVERS_DIR/$country_dir" ]]; then
            local servers
            servers=$(find "$SERVERS_DIR/$country_dir" -name "*.ovpn")
            if [[ -z "$servers" ]]; then
                echo "Error: No .ovpn files found in $SERVERS_DIR/$country_dir."
                notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "No servers found for $country_dir."
                exit 1
            fi
            local server
            server=$(echo "$servers" | shuf -n 1)
            echo "Connecting to VPN using $server..."
            connect_to_server "$server"
        else
            local server
            server=$(find "$SERVERS_DIR" -name "$1" -type f)
            if [[ -n "$server" ]]; then
                echo "Connecting to VPN using $server..."
                connect_to_server "$server"
            else
                echo "Error: Invalid country, country code, or server name: $1"
                notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Invalid country, country code, or server name: $1"
                exit 1
            fi
        fi
    fi
}

change_vpn() {
    check_sudoers_log
    if is_scraper_running; then
        echo "Error: Credential scraper is running."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Please wait until credential scraping is complete."
        exit 1
    fi
    if ! is_vpn_running; then
        echo "Error: No active VPN connection to change."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "No active VPN connection to change."
        exit 1
    fi
    if [[ ! -d "$SERVERS_DIR" ]]; then
        echo "Error: Servers directory $SERVERS_DIR not found."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Servers directory $SERVERS_DIR not found."
        exit 1
    fi
    if [[ -z "$1" ]]; then
        echo "Error: Missing argument for change. Usage: vpn.sh change {random|<country>|<country_code>|<server_name>}"
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Missing argument for change. Use random, country, country code, or server name."
        exit 1
    fi
    local current_server
    current_server=$(get_current_server)
    sudo /usr/bin/killall openvpn
    notify-send -u normal -i "$ICON_DIR/vpn.svg" "VPN Disconnected" "VPN connection has been terminated."
    echo "VPN disconnected."
    if [[ "$1" == "random" ]]; then
        local server
        while true; do
            server=$(get_random_server)
            if [[ -z "$server" ]]; then
                echo "Error: No .ovpn files found in $SERVERS_DIR."
                notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "No .ovpn files found in $SERVERS_DIR."
                exit 1
            fi
            if [[ "$server" != "$current_server" ]]; then
                break
            fi
        done
        echo "Changing VPN to $server..."
        connect_to_server "$server"
    else
        local country_dir
        country_dir=$(map_country "$1")
        if [[ -d "$SERVERS_DIR/$country_dir" ]]; then
            local servers
            servers=$(find "$SERVERS_DIR/$country_dir" -name "*.ovpn")
            if [[ -z "$servers" ]]; then
                echo "Error: No .ovpn files found in $SERVERS_DIR/$country_dir."
                notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "No servers found for $country_dir."
                exit 1
            fi
            local server
            if [[ $(echo "$servers" | wc -l) -eq 1 ]]; then
                server="$servers"
            else
                server=$(echo "$servers" | grep -v "$current_server" | shuf -n 1)
                if [[ -z "$server" ]]; then
                    server=$(echo "$servers" | shuf -n 1)
                fi
            fi
            echo "Changing VPN to $server..."
            connect_to_server "$server"
        else
            local server
            server=$(find "$SERVERS_DIR" -name "$1" -type f)
            if [[ -n "$server" ]]; then
                if [[ "$server" == "$current_server" ]]; then
                    echo "Error: Already connected to $1."
                    notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Already connected to $1."
                    exit 1
                fi
                echo "Changing VPN to $server..."
                connect_to_server "$server"
            else
                echo "Error: Invalid country, country code, or server name: $1"
                notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Invalid country, country code, or server name: $1"
                exit 1
            fi
        fi
    fi
}

toggle_vpn() {
    check_sudoers_log
    if is_scraper_running; then
        echo "Error: Credential scraper is running."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Please wait until credential scraping is complete."
        exit 1
    fi
    if is_vpn_running; then
        echo "Disconnecting VPN..."
        sudo /usr/bin/killall openvpn
        notify-send -u normal -i "$ICON_DIR/vpn.svg" "VPN Disconnected" "VPN connection has been terminated."
        echo "VPN disconnected."
    else
        connect_vpn random
    fi
}

disconnect_vpn() {
    check_sudoers_log
    if is_vpn_running; then
        echo "Disconnecting VPN..."
        sudo /usr/bin/killall openvpn
        notify-send -u normal -i "$ICON_DIR/vpn.svg" "VPN Disconnected" "VPN connection has been terminated."
        echo "VPN disconnected."
    else
        echo "VPN is not connected."
        notify-send -u normal -i "$ICON_DIR/vpn.svg" "VPN Not Connected" "No active VPN connection."
    fi
}

list_servers() {
    if [[ ! -d "$SERVERS_DIR" ]]; then
        echo "Error: Servers directory $SERVERS_DIR not found."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "Servers directory $SERVERS_DIR not found."
        exit 1
    fi
    local found=false
    echo "Available VPN servers:"
    for location in "$SERVERS_DIR"/*; do
        if [[ -d "$location" ]]; then
            local loc_name=$(basename "$location")
            for server in "$location"/*.ovpn; do
                if [[ -f "$server" ]]; then
                    found=true
                    echo "Location: $loc_name, Server: $(basename "$server")"
                fi
            done
        fi
    done
    if [ "$found" = false ]; then
        echo "No .ovpn files found in $SERVERS_DIR."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Error" "No .ovpn files found in $SERVERS_DIR."
        exit 1
    fi
    notify-send -u normal -i "$ICON_DIR/vpn.svg" "VPN Servers Listed" "Available VPN servers have been listed in the terminal."
}

setup_vpn() {
    check_sudoers_log
    if is_scraper_running; then
        echo "Error: Credential scraper is running."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Setup Error" "Please wait until credential scraping is complete."
        exit 1
    fi
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
    if ! command_exists notify-send; then
        echo "Installing libnotify for notifications..."
        sudo pacman -S --noconfirm libnotify
    else
        echo "libnotify is already installed."
    fi
    update_auth_file
    mkdir -p "$SERVERS_DIR"
    echo "Synchronizing servers from $SOURCE_SERVERS_DIR to $SERVERS_DIR..."
    rm -rf "$SERVERS_DIR"/*
    cp -r "$SOURCE_SERVERS_DIR"/* "$SERVERS_DIR"/
    if [[ $? -eq 0 ]]; then
        echo "Servers synchronized successfully."
    else
        echo "Error: Failed to synchronize servers from $SOURCE_SERVERS_DIR."
        notify-send -u critical -i "$ICON_DIR/error.svg" "VPN Setup Error" "Failed to synchronize servers from $SOURCE_SERVERS_DIR."
        exit 1
    fi
    echo "Setup complete."
    notify-send -u normal -i "$ICON_DIR/vpn.svg" "VPN Setup Complete" "Dependencies and servers configured successfully."
}

case "$1" in
    toggle)
        toggle_vpn
        ;;
    disconnect)
        disconnect_vpn
        ;;
    list)
        list_servers
        ;;
    connect)
        connect_vpn "$2"
        ;;
    change)
        change_vpn "$2"
        ;;
    setup)
        setup_vpn
        ;;
    *)
        echo "Usage: $0 {toggle|disconnect|list|connect|change|setup}"
        echo "  toggle: Connects or disconnects a random VPNBook server."
        echo "  disconnect: Disconnects the VPN if connected, else outputs not connected."
        echo "  list: Lists all available VPN servers and their locations."
        echo "  connect {random|<country>|<country_code>|<server_name>}: Connects to a random server, a random server in the specified country, or a specific server."
        echo "  change {random|<country>|<country_code>|<server_name>}: Changes the current VPN connection to a different server or country."
        echo "  setup: Installs dependencies, fetches VPN credentials, and syncs servers."
        exit 1
        ;;
esac

exit 0
