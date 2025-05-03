#!/bin/bash

set -e

set -x

cp ../config/servers ~/.config/vpn/servers

SUDO_USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
CONFIG_DIR="$SUDO_USER_HOME/.config/vpn/servers"
AUTH_FILE="$SUDO_USER_HOME/.config/vpn/auth.txt"
TEMP_DIR="/tmp/openvpn-configs"
OPENVPN_PACKAGE="openvpn"
UNZIP_PACKAGE="unzip"
CURL_PACKAGE="curl"
CONFIG_ZIP_URL="https://www.vpnbook.com/free-openvpn-account/vpnbook-openvpn-us16.zip"
CONFIG_ZIP="$TEMP_DIR/configs.zip"
LOG_FILE="/tmp/vpn_install.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_package() {
    if ! pacman -Qs "$1" >/dev/null; then
        log "Package $1 not found. Installing..."
        sudo pacman -S --noconfirm "$1" || {
            log "ERROR: Failed to install $1"
            exit 1
        }
    else
        log "Package $1 is already installed."
    fi
}

validate_zip() {
    log "Validating zip file $CONFIG_ZIP..."
    if [ -f "$CONFIG_ZIP" ]; then
        file_type=$(file -b "$CONFIG_ZIP")
        if [[ $file_type != "Zip archive data"* ]]; then
            log "ERROR: $CONFIG_ZIP is not a zip archive. File type: $file_type"
            head -n 10 "$CONFIG_ZIP" >> "$LOG_FILE"
            rm -f "$CONFIG_ZIP"
            return 1
        fi
        unzip -t "$CONFIG_ZIP" >/dev/null 2>>"$LOG_FILE" || {
            log "ERROR: $CONFIG_ZIP is not a valid zip archive."
            rm -f "$CONFIG_ZIP"
            return 1
        }
        log "Zip file is valid."
        return 0
    else
        log "No zip file found at $CONFIG_ZIP."
        return 1
    fi
}

download_configs() {
    log "Attempting to download VPNBook configuration files from $CONFIG_ZIP_URL..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "$CONFIG_ZIP_URL")
    if [ "$response" -ne 200 ]; then
        log "ERROR: URL $CONFIG_ZIP_URL returned HTTP status $response"
        log "Fallback: Manually download from [VPNBook Free VPN](https://www.vpnbook.com/freevpn)"
        log "Place the zip in $TEMP_DIR/configs.zip and rerun."
        exit 1
    fi
    curl -L -v -o "$CONFIG_ZIP" \
        --header "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:91.0) Gecko/20100101 Firefox/91.0" \
        --header "Accept: application/zip" \
        "$CONFIG_ZIP_URL" 2>>"$LOG_FILE" || {
        log "ERROR: Failed to download configuration files. HTTP status: $?"
        log "Check $LOG_FILE for detailed curl output."
        log "Fallback: Manually download from [VPNBook Free VPN](https://www.vpnbook.com/freevpn)"
        log "Place the zip in $TEMP_DIR/configs.zip and rerun."
        exit 1
    }
    validate_zip || {
        log "ERROR: Downloaded file is not a valid zip archive."
        exit 1
    }
}

update_ovpn_configs() {
    log "Updating .ovpn files with recommended settings..."
    for ovpn_file in "$CONFIG_DIR"/*.ovpn; do
        if [ -f "$ovpn_file" ]; then
            log "Processing $ovpn_file"
            if grep -q "^auth-user-pass" "$ovpn_file"; then
                log "Updating auth-user-pass in $ovpn_file"
                sed -i "s|^auth-user-pass.*|auth-user-pass $AUTH_FILE|" "$ovpn_file"
            else
                log "Adding auth-user-pass to $ovpn_file"
                echo "auth-user-pass $AUTH_FILE" >> "$ovpn_file"
            fi
            if grep -q "^verb 3" "$ovpn_file" && grep -q "^fast-io" "$ovpn_file"; then
                log "Inserting cipher AES-256-CBC between verb 3 and fast-io in $ovpn_file"
                sed -i '/^verb 3/a cipher AES-256-CBC' "$ovpn_file"
            else
                log "verb 3 or fast-io not found in $ovpn_file, appending cipher AES-256-CBC"
                echo "cipher AES-256-CBC" >> "$ovpn_file"
            fi
            grep -q "^comp-lzo no" "$ovpn_file" || echo "comp-lzo no" >> "$ovpn_file"
            grep -q "^auth-nocache" "$ovpn_file" || echo "auth-nocache" >> "$ovpn_file"
            grep -q "^verify-x509-name" "$ovpn_file" || echo "verify-x509-name server.vpnbook.com name" >> "$ovpn_file"
            grep -q "^data-ciphers" "$ovpn_file" || echo "data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305" >> "$ovpn_file"
        fi
    done
}

if [ "$(id -u)" != "0" ]; then
    log "This script must be run as root (use sudo)"
    exit 1
fi

if [ ! -f "$AUTH_FILE" ]; then
    log "ERROR: Authentication file $AUTH_FILE not found."
    log "Please create $AUTH_FILE with VPNBook username and password (one per line)."
    log "Get credentials from [VPNBook Free VPN](https://www.vpnbook.com/freevpn)."
    exit 1
fi
if [ $(wc -l < "$AUTH_FILE") -ne 2 ]; then
    log "ERROR: $AUTH_FILE must contain exactly two lines: username and password."
    log "Current format: $(cat "$AUTH_FILE")"
    log "Correct format example:"
    log "vpnbook"
    log "current_password"
    exit 1
fi

log "Starting VPN configuration script..."

log "Checking and installing required packages..."
check_package "$OPENVPN_PACKAGE"
check_package "$UNZIP_PACKAGE"
check_package "$CURL_PACKAGE"

log "Creating configuration directory at $CONFIG_DIR..."
mkdir -p "$CONFIG_DIR" || {
    log "ERROR: Failed to create directory $CONFIG_DIR"
    exit 1
}

log "Creating temporary directory at $TEMP_DIR..."
mkdir -p "$TEMP_DIR" || {
    log "ERROR: Failed to create directory $TEMP_DIR"
    exit 1
}

if validate_zip; then
    log "Using existing valid $CONFIG_ZIP."
else
    download_configs
fi

log "Extracting configuration files..."
unzip -o "$CONFIG_ZIP" -d "$TEMP_DIR" || {
    log "ERROR: Failed to extract $CONFIG_ZIP"
    log "Ensure the file is a valid zip archive."
    exit 1
}

log "Moving .ovpn files to $CONFIG_DIR..."
find "$TEMP_DIR" -type f -name "*.ovpn" -exec mv {} "$CONFIG_DIR/" \; || {
    log "ERROR: Failed to move .ovpn files"
    exit 1
}

update_ovpn_configs

log "Cleaning up temporary files..."
rm -rf "$TEMP_DIR" || {
    log "WARNING: Failed to clean up $TEMP_DIR"
}

log "Setting permissions for $CONFIG_DIR..."
chown -R "$SUDO_USER:$SUDO_USER" "$CONFIG_DIR" || {
    log "ERROR: Failed to set ownership for $CONFIG_DIR"
    exit 1
}
chmod -R 600 "$CONFIG_DIR"/*.ovpn || {
    log "ERROR: Failed to set permissions for .ovpn files"
    exit 1
}

log "Verifying .ovpn files in $CONFIG_DIR..."
if [ -n "$(ls -A "$CONFIG_DIR"/*.ovpn 2>/dev/null)" ]; then
    log "OpenVPN configuration files successfully installed in $CONFIG_DIR:"
    ls -l "$CONFIG_DIR"/*.ovpn | tee -a "$LOG_FILE"
else
    log "ERROR: No .ovpn files were found or installed."
    log "Check $LOG_FILE for details and ensure the zip file contains .ovpn files."
    exit 1
fi

log "Installation complete. You can connect using 'vpnScript.sh toggle'."
log "Ensure $AUTH_FILE contains the correct VPNBook username and password from [VPNBook Free VPN](https://www.vpnbook.com/freevpn)."
log "Debug logs are available in $LOG_FILE."
