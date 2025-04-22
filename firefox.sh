#!/bin/bash


EXTENSION_URL="https://addons.mozilla.org/firefox/downloads/latest/netflux/addon-1582031-latest.xpi"
EXTENSION_ID="support@netflux.me"  
TEMP_DIR="/tmp"
XPI_FILE="$TEMP_DIR/netflux.xpi"
FIREFOX_PROFILE_DIR="$HOME/.mozilla/firefox"
PROFILE_INI="$FIREFOX_PROFILE_DIR/profiles.ini"
USER=$(whoami)
MAX_RETRIES=3  
RETRY_DELAY=5  
MONITOR_DURATION=60  
CHECK_INTERVAL=0.5  

if ! command -v firefox &> /dev/null; then
    echo "Error: Firefox is not installed. Please install Firefox first."
    exit 1
fi

if [ ! -d "$FIREFOX_PROFILE_DIR" ]; then
    echo "Firefox profile directory not found at $FIREFOX_PROFILE_DIR."
    echo "Creating a new Firefox profile..."
    firefox --no-remote -CreateProfile default
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create a new Firefox profile."
        exit 1
    fi
fi

if [ ! -f "$PROFILE_INI" ]; then
    echo "profiles.ini not found at $PROFILE_INI."
    echo "Creating a new Firefox profile..."
    firefox --no-remote -CreateProfile default
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create a new Firefox profile."
        exit 1
    fi
fi

PROFILE_PATH=$(awk -F'=' '/\[Install[0-9A-F]+\]/{p=1; path=""} p&&/Default=/{path=$2} p&&/^$/{print path; p=0} END{if(path) print path}' "$PROFILE_INI" | head -n1)
if [ -z "$PROFILE_PATH" ]; then
    PROFILE_PATH=$(awk -F'=' '/\[Profile[0-9]+\]/{p=1; path=""; def=0} p&&/Path=/{path=$2} p&&/Default=1/{def=1} p&&/^$/{if(def==1) print path; p=0} END{if(def==1) print path}' "$PROFILE_INI" | head -n1)
fi

if [ -z "$PROFILE_PATH" ]; then
    echo "Error: Could not find default profile in profiles.ini."
    echo "Contents of profiles.ini:"
    cat "$PROFILE_INI"
    exit 1
fi

FULL_PROFILE_DIR="$FIREFOX_PROFILE_DIR/$PROFILE_PATH"
EXTENSIONS_DIR="$FULL_PROFILE_DIR/extensions"
STAGING_DIR="$FULL_PROFILE_DIR/extensions.staging"
EXTENSIONS_JSON="$FULL_PROFILE_DIR/extensions.json"

if [ ! -d "$FULL_PROFILE_DIR" ]; then
    echo "Error: Profile directory $FULL_PROFILE_DIR does not exist."
    echo "Creating a new Firefox profile..."
    firefox --no-remote -CreateProfile default
    PROFILE_PATH=$(awk -F'=' '/\[Install[0-9A-F]+\]/{p=1; path=""} p&&/Default=/{path=$2} p&&/^$/{print path; p=0} END{if(path) print path}' "$PROFILE_INI" | head -n1)
    if [ -z "$PROFILE_PATH" ]; then
        echo "Error: Failed to create or find a default profile."
        exit 1
    fi
    FULL_PROFILE_DIR="$FIREFOX_PROFILE_DIR/$PROFILE_PATH"
    EXTENSIONS_DIR="$FULL_PROFILE_DIR/extensions"
    STAGING_DIR="$FULL_PROFILE_DIR/extensions.staging"
    EXTENSIONS_JSON="$FULL_PROFILE_DIR/extensions.json"
fi

mkdir -p "$EXTENSIONS_DIR" "$STAGING_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create directories at $EXTENSIONS_DIR or $STAGING_DIR."
    exit 1
fi

echo "Downloading Netflux extension from $EXTENSION_URL..."
unset WGETRC
wget -O "$XPI_FILE" "$EXTENSION_URL" --quiet --user-agent="Mozilla/5.0"
WGET_STATUS=$?
if [ $WGET_STATUS -ne 0 ]; then
    echo "Warning: wget failed with status $WGET_STATUS. Attempting with curl..."
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is not installed and wget failed. Please install curl or fix wget."
        exit 1
    fi
    curl -L -o "$XPI_FILE" "$EXTENSION_URL" --silent --user-agent "Mozilla/5.0"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download the extension with curl."
        exit 1
    fi
fi

if [ ! -f "$XPI_FILE" ]; then
    echo "Error: Downloaded file not found at $XPI_FILE."
    exit 1
fi

echo "Verifying .xpi file integrity..."
if ! unzip -t "$XPI_FILE" &> /dev/null; then
    echo "Error: The downloaded .xpi file is corrupted or invalid."
    exit 1
fi

echo "Attempting to install extension via Firefox, monitoring $EXTENSIONS_DIR..."
pkill -9 firefox 2>/dev/null
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "Attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES..."
    firefox --no-remote -P "$PROFILE_PATH" "file://$XPI_FILE" >/dev/null 2>&1 &
    FIREFOX_PID=$!

    for ((i=0; i<MONITOR_DURATION*2; i++)); do
        if [ -f "$EXTENSIONS_DIR/$EXTENSION_ID.xpi" ]; then
            echo "Extension detected in $EXTENSIONS_DIR/$EXTENSION_ID.xpi."
            kill $FIREFOX_PID 2>/dev/null
            wait $FIREFOX_PID 2>/dev/null
            break 2
        fi
        if [ -f "$EXTENSIONS_JSON" ] && grep -q "$EXTENSION_ID" "$EXTENSIONS_JSON"; then
            echo "Extension registered in $EXTENSIONS_JSON."
            kill $FIREFOX_PID 2>/dev/null
            wait $FIREFOX_PID 2>/dev/null
            break 2
        fi
        if ! ps -p $FIREFOX_PID > /dev/null; then
            echo "Firefox closed prematurely."
            break
        fi
        sleep $CHECK_INTERVAL
    done

    if ps -p $FIREFOX_PID > /dev/null; then
        echo "Firefox still running after monitoring period. Closing..."
        kill $FIREFOX_PID 2>/dev/null
        wait $FIREFOX_PID 2>/dev/null
    fi

    if [ -f "$EXTENSIONS_DIR/$EXTENSION_ID.xpi" ] || ([ -f "$EXTENSIONS_JSON" ] && grep -q "$EXTENSION_ID" "$EXTENSIONS_JSON"); then
        echo "Extension detected after attempt $((RETRY_COUNT + 1))."
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo "Extension not detected. Waiting $RETRY_DELAY seconds before retry..."
        sleep $RETRY_DELAY
    fi
done

if [ ! -f "$EXTENSIONS_DIR/$EXTENSION_ID.xpi" ] && { [ ! -f "$EXTENSIONS_JSON" ] || ! grep -q "$EXTENSION_ID" "$EXTENSIONS_JSON"; }; then
    echo "Warning: Extension not found in $EXTENSIONS_DIR or $EXTENSIONS_JSON after $MAX_RETRIES attempts."
    echo "Copying extension to staging directory $STAGING_DIR/$EXTENSION_ID.xpi..."
    cp "$XPI_FILE" "$STAGING_DIR/$EXTENSION_ID.xpi"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy extension to $STAGING_DIR."
        exit 1
    fi
    chmod 644 "$STAGING_DIR/$EXTENSION_ID.xpi"
    chown "$USER:$USER" "$STAGING_DIR/$EXTENSION_ID.xpi"

    echo "Copying extension to $EXTENSIONS_DIR/$EXTENSION_ID.xpi as fallback..."
    cp "$XPI_FILE" "$EXTENSIONS_DIR/$EXTENSION_ID.xpi"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy extension to $EXTENSIONS_DIR."
        exit 1
    fi
    chmod 644 "$EXTENSIONS_DIR/$EXTENSION_ID.xpi"
    chown "$USER:$USER" "$EXTENSIONS_DIR/$EXTENSION_ID.xpi"
fi

rm "$XPI_FILE"

if [ -f "$EXTENSIONS_JSON" ]; then
    echo "Checking extensions.json for Netflux..."
    if grep -q "$EXTENSION_ID" "$EXTENSIONS_JSON"; then
        echo "Netflux found in extensions.json."
    else
        echo "Warning: Netflux not found in extensions.json. It may not persist after restart."
    fi
else
    echo "Warning: extensions.json not found in $FULL_PROFILE_DIR."
fi

if [ -f "$EXTENSIONS_DIR/$EXTENSION_ID.xpi" ] || [ -f "$STAGING_DIR/$EXTENSION_ID.xpi" ] || ([ -f "$EXTENSIONS_JSON" ] && grep -q "$EXTENSION_ID" "$EXTENSIONS_JSON"); then
    echo "Success: Netflux extension installed to $EXTENSIONS_DIR/$EXTENSION_ID.xpi, $STAGING_DIR/$EXTENSION_ID.xpi, or registered in $EXTENSIONS_JSON."
    echo "Please restart Firefox to load the extension."
    echo "If the extension is deleted, check troubleshooting steps."
else
    echo "Error: Extension installation failed."
    exit 1
fi

FIREFOX_VERSION=$(firefox --version 2>/dev/null || echo "Unknown")
echo "Firefox version: $FIREFOX_VERSION"

exit 0
