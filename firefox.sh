#!/bin/bash

USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo "Error: Could not determine username."; exit 1; }

LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
EXTENSIONS=(
    "ublock-origin|uBlock0@raymondhill.net|https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon-607454-latest.xpi"
)
TEMP_DIR="/tmp"
FIREFOX_PROFILE_DIR="$HOME/.mozilla/firefox"
PROFILE_INI="$FIREFOX_PROFILE_DIR/profiles.ini"
MAX_RETRIES=3
RETRY_DELAY=2
MONITOR_DURATION=60
CHECK_INTERVAL=0.5

command -v firefox >/dev/null 2>&1 || { echo "Error: Firefox is not installed. Please install Firefox first."; exit 1; }
{ command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1; } || { echo "Error: Neither wget nor curl is installed."; exit 1; }
ping -c 1 mozilla.org >/dev/null 2>&1 || { echo "Error: No internet connection."; exit 1; }

mkdir -p "$(dirname "$LOG_FILE")" || { echo "Error: Failed to create $(dirname "$LOG_FILE")"; exit 1; }
mkdir -p "$BACKUP_DIR" || { echo "Error: Failed to create $BACKUP_DIR"; exit 1; }
touch "$LOG_FILE" || { echo "Error: Failed to create $LOG_FILE"; exit 1; }
echo "[$(date)] New installation session (firefox-extensions)" >> "$LOG_FILE"

if [ ! -d "$FIREFOX_PROFILE_DIR" ]; then
    echo "Firefox profile directory not found at $FIREFOX_PROFILE_DIR. Creating a new profile..."
    firefox --no-remote -CreateProfile default || { echo "Error: Failed to create a new Firefox profile."; exit 1; }
    echo "CREATED_PROFILE: $FIREFOX_PROFILE_DIR/default" >> "$LOG_FILE"
fi

if [ ! -f "$PROFILE_INI" ]; then
    echo "profiles.ini not found at $PROFILE_INI. Creating a new profile..."
    firefox --no-remote -CreateProfile default || { echo "Error: Failed to create a new Firefox profile."; exit 1; }
    echo "CREATED_PROFILE: $FIREFOX_PROFILE_DIR/default" >> "$LOG_FILE"
fi

PROFILE_PATH=$(awk -F'=' '/\[Install[0-9A-F]+\]/{p=1; path=""} p&&/Default=/{path=$2} p&&/^$/{print path; p=0} END{if(path) print path}' "$PROFILE_INI" | head -n1)
if [ -z "$PROFILE_PATH" ]; then
    PROFILE_PATH=$(awk -F'=' '/\[Profile[0-9]+\]/{p=1; path=""; def=0} p&&/Path=/{path=$2} p&&/Default=1/{def=1} p&&/^$/{if(def==1) print path; p=0} END{if(def==1) print path}' "$PROFILE_INI" | head -n1)
fi

if [ -z "$PROFILE_PATH" ]; then
    echo "Error: Could not find default profile in profiles.ini."
    cat "$PROFILE_INI"
    exit 1
fi

FULL_PROFILE_DIR="$FIREFOX_PROFILE_DIR/$PROFILE_PATH"
EXTENSIONS_DIR="$FULL_PROFILE_DIR/extensions"
STAGING_DIR="$FULL_PROFILE_DIR/extensions.staging"
EXTENSIONS_JSON="$FULL_PROFILE_DIR/extensions.json"

if [ ! -d "$FULL_PROFILE_DIR" ]; then
    echo "Error: Profile directory $FULL_PROFILE_DIR does not exist. Creating a new profile..."
    firefox --no-remote -CreateProfile default || { echo "Error: Failed to create a new Firefox profile."; exit 1; }
    PROFILE_PATH=$(awk -F'=' '/\[Install[0-9A-F]+\]/{p=1; path=""} p&&/Default=/{path=$2} p&&/^$/{print path; p=0} END{if(path) print path}' "$PROFILE_INI" | head -n1)
    if [ -z "$PROFILE_PATH" ]; then
        echo "Error: Failed to create or find a default profile."
        exit 1
    fi
    FULL_PROFILE_DIR="$FIREFOX_PROFILE_DIR/$PROFILE_PATH"
    EXTENSIONS_DIR="$FULL_PROFILE_DIR/extensions"
    STAGING_DIR="$FULL_PROFILE_DIR/extensions.staging"
    EXTENSIONS_JSON="$FULL_PROFILE_DIR/extensions.json"
    echo "CREATED_PROFILE: $FULL_PROFILE_DIR" >> "$LOG_FILE"
fi

mkdir -p "$EXTENSIONS_DIR" "$STAGING_DIR" || { echo "Error: Failed to create directories at $EXTENSIONS_DIR or $STAGING_DIR."; exit 1; }

if [ -f "$EXTENSIONS_JSON" ]; then
    cp "$EXTENSIONS_JSON" "$BACKUP_DIR/extensions.json.$(date +%s)" || { echo "Error: Failed to backup $EXTENSIONS_JSON"; exit 1; }
    echo "BACKUP_JSON: $EXTENSIONS_JSON -> $BACKUP_DIR/extensions.json.$(date +%s)" >> "$LOG_FILE"
    echo "Backed up $EXTENSIONS_JSON"
fi

for EXT in "${EXTENSIONS[@]}"; do
    EXT_NAME=$(echo "$EXT" | cut -d'|' -f1)
    EXT_ID=$(echo "$EXT" | cut -d'|' -f2)
    EXT_URL=$(echo "$EXT" | cut -d'|' -f3)
    XPI_FILE="$TEMP_DIR/$EXT_NAME.xpi"

    if [ -f "$EXTENSIONS_DIR/$EXT_ID.xpi" ] || ([ -f "$EXTENSIONS_JSON" ] && grep -q "$EXT_ID" "$EXTENSIONS_JSON"); then
        echo "Skipping: $EXT_NAME is already installed in $EXTENSIONS_DIR or registered in $EXTENSIONS_JSON."
        continue
    fi

    echo "Downloading $EXT_NAME extension from $EXT_URL..."
    unset WGETRC
    if wget -O "$XPI_FILE" "$EXT_URL" --quiet --user-agent="Mozilla/5.0"; then
        echo "Downloaded $EXT_NAME with wget"
    else
        echo "Warning: wget failed. Attempting with curl..."
        command -v curl >/dev/null 2>&1 || { echo "Error: curl is not installed and wget failed."; exit 1; }
        curl -L -o "$XPI_FILE" "$EXT_URL" --silent --user-agent "Mozilla/5.0" || { echo "Error: Failed to download $EXT_NAME with curl."; exit 1; }
        echo "Downloaded $EXT_NAME with curl"
    fi

    [ ! -f "$XPI_FILE" ] && { echo "Error: Downloaded file not found at $XPI_FILE."; exit 1; }

    echo "Verifying $EXT_NAME .xpi file integrity..."
    unzip -t "$XPI_FILE" >/dev/null 2>&1 || { echo "Error: The downloaded $EXT_NAME .xpi file is corrupted or invalid."; exit 1; }

    echo "Attempting to install $EXT_NAME extension via Firefox..."
    pkill -9 firefox 2>/dev/null
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        echo "Attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES..."
        firefox --no-remote -P "$PROFILE_PATH" "file://$XPI_FILE" >/dev/null 2>&1 &
        FIREFOX_PID=$!

        for ((i=0; i<MONITOR_DURATION*2; i++)); do
            if [ -f "$EXTENSIONS_DIR/$EXT_ID.xpi" ]; then
                echo "INSTALLED_EXTENSION: $EXT_NAME -> $EXTENSIONS_DIR/$EXT_ID.xpi" >> "$LOG_FILE"
                echo "$EXT_NAME extension detected in $EXTENSIONS_DIR/$EXT_ID.xpi."
                kill $FIREFOX_PID 2>/dev/null
                wait $FIREFOX_PID 2>/dev/null
                break 2
            fi
            if [ -f "$EXTENSIONS_JSON" ] && grep -q "$EXT_ID" "$EXTENSIONS_JSON"; then
                echo "INSTALLED_EXTENSION: $EXT_NAME -> $EXTENSIONS_JSON ($EXT_ID)" >> "$LOG_FILE"
                echo "$EXT_NAME extension registered in $EXTENSIONS_JSON."
                kill $FIREFOX_PID 2>/dev/null
                wait $FIREFOX_PID 2>/dev/null
                break 2
            fi
            if ! ps -p $FIREFOX_PID >/dev/null; then
                echo "Firefox closed prematurely."
                break
            fi
            sleep $CHECK_INTERVAL
        done

        if ps -p $FIREFOX_PID >/dev/null; then
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
        echo "Warning: $EXT_NAME extension not installed via Firefox. Copying to staging and extensions directories..."
        cp "$XPI_FILE" "$STAGING_DIR/$EXT_ID.xpi" || { echo "Error: Failed to copy $EXT_NAME to $STAGING_DIR."; exit 1; }
        chmod 644 "$STAGING_DIR/$EXT_ID.xpi"
        chown "$USER:$USER" "$STAGING_DIR/$EXT_ID.xpi"
        echo "INSTALLED_EXTENSION: $EXT_NAME -> $STAGING_DIR/$EXT_ID.xpi" >> "$LOG_FILE"
        echo "Copied $EXT_NAME to $STAGING_DIR/$EXT_ID.xpi"

        cp "$XPI_FILE" "$EXTENSIONS_DIR/$EXT_ID.xpi" || { echo "Error: Failed to copy $EXT_NAME to $EXTENSIONS_DIR."; exit 1; }
        chmod 644 "$EXTENSIONS_DIR/$EXT_ID.xpi"
        chown "$USER:$USER" "$EXTENSIONS_DIR/$EXT_ID.xpi"
        echo "INSTALLED_EXTENSION: $EXT_NAME -> $EXTENSIONS_DIR/$EXT_ID.xpi" >> "$LOG_FILE"
        echo "Copied $EXT_NAME to $EXTENSIONS_DIR/$EXT_ID.xpi"
    fi

    rm -f "$XPI_FILE"
done

ALL_INSTALLED=true
for EXT in "${EXTENSIONS[@]}"; do
    EXT_NAME=$(echo "$EXT" | cut -d'|' -f1)
    EXT_ID=$(echo "$EXT" | cut -d'|' -f2)
    if [ ! -f "$EXTENSIONS_DIR/$EXT_ID.xpi" ] && [ ! -f "$STAGING_DIR/$EXT_ID.xpi" ] && { [ ! -f "$EXTENSIONS_JSON" ] || ! grep -q "$EXT_ID" "$EXTENSIONS_JSON"; }; then
        echo "Warning: $EXT_NAME extension not installed correctly."
        ALL_INSTALLED=false
    fi
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

if [ "$ALL_INSTALLED" = true ]; then
    echo "Success: All extensions installed to $EXTENSIONS_DIR, $STAGING_DIR, or registered in $EXTENSIONS_JSON."
    echo "Please restart Firefox to load the extensions."
    echo "LOGGED_ACTIONS: Completed firefox-extensions installation" >> "$LOG_FILE"
else
    echo "Error: One or more extensions failed to install."
    exit 1
fi

FIREFOX_VERSION=$(firefox --version 2>/dev/null || echo "Unknown")
echo "Firefox version: $FIREFOX_VERSION"

exit 0
