#!/bin/bash

EXTENSIONS=(
    "ublock-origin|uBlock0@raymondhill.net|https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon-607454-latest.xpi"
)
TEMP_DIR="/tmp"
FIREFOX_PROFILE_DIR="$HOME/.mozilla/firefox"
PROFILE_INI="$FIREFOX_PROFILE_DIR/profiles.ini"
USER=$(whoami)
MAX_RETRIES=3  
RETRY_DELAY=2  
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

for EXT in "${EXTENSIONS[@]}"; do
    EXT_NAME=$(echo "$EXT" | cut -d'|' -f1)
    EXT_ID=$(echo "$EXT" | cut -d'|' -f2)
    EXT_URL=$(echo "$EXT" | cut -d'|' -f3)
    XPI_FILE="$TEMP_DIR/$EXT_NAME.xpi"

    if [ -f "$EXTENSIONS_DIR/$EXT_ID.xpi" ] || ([ -f "$EXTENSIONS_JSON" ] && grep -q "$EXT_ID" "$EXTENSIONS_JSON"); then
        echo "$EXT_NAME is already installed in $EXTENSIONS_DIR or registered in $EXTENSIONS_JSON."
        continue
    fi

    echo "Downloading $EXT_NAME extension from $EXT_URL..."
    unset WGETRC
    wget -O "$XPI_FILE" "$EXT_URL" --quiet --user-agent="Mozilla/5.0"
    WGET_STATUS=$?
    if [ $WGET_STATUS -ne 0 ]; then
        echo "Warning: wget failed with status $WGET_STATUS. Attempting with curl..."
        if ! command -v curl &> /dev/null; then
            echo "Error: curl is not installed and wget failed. Please install curl or fix wget."
            exit 1
        fi
        curl -L -o "$XPI_FILE" "$EXT_URL" --silent --user-agent "Mozilla/5.0"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to download the $EXT_NAME extension with curl."
            exit 1
        fi
    fi

    if [ ! -f "$XPI_FILE" ]; then
        echo "Error: Downloaded file not found at $XPI_FILE."
        exit 1
    fi

    echo "Verifying $EXT_NAME .xpi file integrity..."
    if ! unzip -t "$XPI_FILE" &> /dev/null; then
        echo "Error: The downloaded $EXT_NAME .xpi file is corrupted or invalid."
        exit 1
    fi

    echo "Attempting to install $EXT_NAME extension via Firefox, monitoring $EXTENSIONS_DIR..."
    pkill -9 firefox 2>/dev/null
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        echo "Attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES..."
        firefox --no-remote -P "$PROFILE_PATH" "file://$XPI_FILE" >/dev/null 2>&1 &
        FIREFOX_PID=$!

        for ((i=0; i<MONITOR_DURATION*2; i++)); do
            if [ -f "$EXTENSIONS_DIR/$EXT_ID.xpi" ]; then
                echo "$EXT_NAME extension detected in $EXTENSIONS_DIR/$EXT_ID.xpi."
                kill $FIREFOX_PID 2>/dev/null
                wait $FIREFOX_PID 2>/dev/null
                break 2
            fi
            if [ -f "$EXTENSIONS_JSON" ] && grep -q "$EXT_ID" "$EXTENSIONS_JSON"; then
                echo "$EXT_NAME extension registered in $EXTENSIONS_JSON."
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

        if [ -f "$EXTENSIONS_DIR/$EXT_ID.xpi" ] || ([ -f "$EXTENSIONS_JSON" ] && grep -q "$EXT_ID" "$EXTENSIONS_JSON"); then
            echo "$EXT_NAME extension detected after attempt $((RETRY_COUNT + 1))."
            break
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "$EXT_NAME extension not detected. Waiting $RETRY_DELAY seconds before retry..."
            sleep $RETRY_DELAY
        fi
    done

    if [ ! -f "$EXTENSIONS_DIR/$EXT_ID.xpi" ] && { [ ! -f "$EXTENSIONS_JSON" ] || ! grep -q "$EXT_ID" "$EXTENSIONS_JSON"; }; then
        echo "Warning: $EXT_NAME extension not found in $EXTENSIONS_DIR or $EXTENSIONS_JSON after $MAX_RETRIES attempts."
        echo "Copying $EXT_NAME extension to staging directory $STAGING_DIR/$EXT_ID.xpi..."
        cp "$XPI_FILE" "$STAGING_DIR/$EXT_ID.xpi"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to copy $EXT_NAME extension to $STAGING_DIR."
            exit 1
        fi
        chmod 644 "$STAGING_DIR/$EXT_ID.xpi"
        chown "$USER:$USER" "$STAGING_DIR/$EXT_ID.xpi"

        echo "Copying $EXT_NAME extension to $EXTENSIONS_DIR/$EXT_ID.xpi as fallback..."
        cp "$XPI_FILE" "$EXTENSIONS_DIR/$EXT_ID.xpi"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to copy $EXT_NAME extension to $EXTENSIONS_DIR."
            exit 1
        fi
        chmod 644 "$EXTENSIONS_DIR/$EXT_ID.xpi"
        chown "$USER:$USER" "$EXTENSIONS_DIR/$EXT_ID.xpi"
    fi

    rm "$XPI_FILE"
done

if [ -f "$EXTENSIONS_JSON" ]; then
    echo "Checking extensions.json..."
    for EXT in "${EXTENSIONS[@]}"; do
        EXT_NAME=$(echo "$EXT" | cut -d'|' -f1)
        EXT_ID=$(echo "$EXT" | cut -d'|' -f2)
        if grep -q "$EXT_ID" "$EXTENSIONS_JSON"; then
            echo "$EXT_NAME found in extensions.json."
        else
            echo "Warning: $EXT_NAME not found in extensions.json. It may not persist after restart."
        fi
    done
else
    echo "Warning: extensions.json not found in $FULL_PROFILE_DIR."
fi

ALL_INSTALLED=true
for EXT in "${EXTENSIONS[@]}"; do
    EXT_NAME=$(echo "$EXT" | cut -d'|' -f1)
    EXT_ID=$(echo "$EXT" | cut -d'|' -f2)
    if [ ! -f "$EXTENSIONS_DIR/$EXT_ID.xpi" ] && [ ! -f "$STAGING_DIR/$EXT_ID.xpi" ] && { [ ! -f "$EXTENSIONS_JSON" ] || ! grep -q "$EXT_ID" "$EXTENSIONS_JSON"; }; then
        echo "Warning: $EXT_NAME extension not installed correctly."
        ALL_INSTALLED=false
    fi
done

if [ "$ALL_INSTALLED" = true ]; then
    echo "Success: All extensions installed to $EXTENSIONS_DIR, $STAGING_DIR, or registered in $EXTENSIONS_JSON."
    echo "Please restart Firefox to load the extensions."
    echo "If any extension is deleted, check troubleshooting steps."
else
    echo "Error: One or more extensions failed to install."
    exit 1
fi

FIREFOX_VERSION=$(firefox --version 2>/dev/null || echo "Unknown")
echo "Firefox version: $FIREFOX_VERSION"

exit 0
