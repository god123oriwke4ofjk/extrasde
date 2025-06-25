#!/bin/bash

USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo "Error: Could not determine username."; exit 1; }

SCRIPT_DIR="/home/$USER/.local/lib/hyde"
LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
FIREFOX_PROFILE_DIR="$HOME/.mozilla/firefox"
PROFILE_INI="$FIREFOX_PROFILE_DIR/profiles.ini"
ZEN_PROFILE_DIR="$HOME/.zen"
ZEN_PROFILE_INI="$ZEN_PROFILE_DIR/profiles.ini"
DYNAMIC_BROWSER_SCRIPT="$SCRIPT_DIR/dynamic-browser.sh"
CONFIG_DIR="$HOME/Extra/config"  # <--- modified path

NO_DYNAMIC=false

if [ "$1" = "nodynamic" ]; then
    NO_DYNAMIC=true
fi

mkdir -p "$(dirname "$LOG_FILE")" || { echo "Error: Failed to create directory for $LOG_FILE"; exit 1; }
mkdir -p "$SCRIPT_DIR" || { echo "Error: Failed to create $SCRIPT_DIR"; exit 1; }
mkdir -p "$BACKUP_DIR" || { echo "Error: Failed to create $BACKUP_DIR"; exit 1; }

if [ "$NO_DYNAMIC" = false ]; then
    declare -A scripts
    scripts["dynamic-browser.sh"]="$CONFIG_DIR/dynamic_browser.sh"
    for script_name in "${!scripts[@]}"; do
        src_script="${scripts[$script_name]}" 
        script_path="$SCRIPT_DIR/$script_name"
        if [ ! -f "$src_script" ]; then
            echo "Error: Source script $src_script not found."
            exit 1
        fi
        if [ -f "$script_path" ]; then
            echo "Warning: $script_path already exists."
            src_hash=$(sha256sum "$src_script" | cut -d' ' -f1)
            tgt_hash=$(sha256sum "$script_path" | cut -d' ' -f1)
            if [ "$src_hash" = "$tgt_hash" ]; then
                echo "$script_path has identical content, checking permissions."
                [ -x "$script_path" ] || { chmod +x "$script_path" || { echo "Error: Failed to make $script_path executable"; exit 1; }; echo "Made $script_path executable."; }
            else
                echo "$script_path has different content."
                read -p "Replace $script_path with content from $src_script? [y/N]: " replace_script
                if [[ "$replace_script" =~ ^[Yy]$ ]]; then
                    current_timestamp=$(date +%s)
                    cp "$script_path" "$BACKUP_DIR/$script_name.$current_timestamp" || { echo "Error: Failed to backup $script_path"; exit 1; }
                    cp "$src_script" "$script_path" || { echo "Error: Failed to copy $src_script to $script_path"; exit 1; }
                    chmod +x "$script_path" || { echo "Error: Failed to make $script_path executable"; exit 1; }
                    echo "Replaced and made $script_path executable."
                    echo "REPLACED_SCRIPT: $script_name -> $script_path" >> "$LOG_FILE"
                else
                    echo "Skipping replacement of $script_path."
                    [ -x "$script_path" ] || { chmod +x "$script_path" || { echo "Error: Failed to make $script_path executable"; exit 1; }; echo "Made $script_path executable."; }
                fi
            fi
        else
            cp "$src_script" "$script_path" || { echo "Error: Failed to copy $src_script to $script_path"; exit 1; }
            chmod +x "$script_path" || { echo "Error: Failed to make $script_path executable"; exit 1; }
            echo "Created and made $script_path executable."
            echo "CREATED_SCRIPT: $script_name -> $script_path" >> "$LOG_FILE"
        fi
        ls -l "$script_path"
    done

    if [ -f "$USERPREFS_CONF" ]; then
        current_timestamp=$(date +%s)
        cp "$USERPREFS_CONF" "$BACKUP_DIR/userprefs.conf.$current_timestamp" || { echo "Error: Failed to backup $USERPREFS_CONF"; exit 1; }
        echo "BACKUP_CONFIG: $USERPREFS_CONF -> $BACKUP_DIR/userprefs.conf.$current_timestamp" >> "$LOG_FILE"
        echo "Backed up $USERPREFS_CONF"
    fi
    if ! grep -q "exec-once=$DYNAMIC_BROWSER_SCRIPT" "$USERPREFS_CONF" 2>/dev/null; then
        echo "exec-once=$DYNAMIC_BROWSER_SCRIPT" >> "$USERPREFS_CONF" || { echo "Error: Failed to add dynamic-browser.sh to $USERPREFS_CONF"; exit 1; }
        echo "MODIFIED_CONFIG: $USERPREFS_CONF -> Added exec-once=$DYNAMIC_BROWSER_SCRIPT" >> "$LOG_FILE"
        echo "Configured dynamic-browser.sh to run on login"
    else
        echo "Skipping: dynamic-browser.sh already configured in $USERPREFS_CONF"
    fi
else
    echo "Skipping dynamic-browser.sh installation and configuration (nodynamic)"
fi

if command -v firefox >/dev/null 2>&1; then
    if [ ! -d "$FIREFOX_PROFILE_DIR" ] || [ ! -f "$PROFILE_INI" ]; then
        echo "Firefox profile directory or profiles.ini not found. Creating a new profile..."
        firefox --no-remote -CreateProfile default || { echo "Warning: Failed to create a new Firefox profile. Skipping autoscrolling."; }
        echo "CREATED_PROFILE: $FIREFOX_PROFILE_DIR/default" >> "$LOG_FILE"
    fi
    if [ -f "$PROFILE_INI" ]; then
        PROFILE_PATH=$(awk -F'=' '/\[Install[0-9A-F]+\]/{p=1; path=""} p&&/Default=/{path=$2} p&&/^$/{print path; p=0} END{if(path) print path}' "$PROFILE_INI" | head -n1)
        if [ -z "$PROFILE_PATH" ]; then
            PROFILE_PATH=$(awk -F'=' '/\[Profile[0-9]+\]/{p=1; path=""; def=0} p&&/Path=/{path=$2} p&&/Default=1/{def=1} p&&/^$/{if(def=1) print path; p=0} END{if(def=1) print path}' "$PROFILE_INI" | head -n1)
        fi
        if [ -n "$PROFILE_PATH" ]; then
            FIREFOX_PREFS_FILE="$FIREFOX_PROFILE_DIR/$PROFILE_PATH/prefs.js"
            if [ -f "$FIREFOX_PREFS_FILE" ]; then
                if grep -q 'user_pref("general.autoScroll", true)' "$FIREFOX_PREFS_FILE"; then
                    echo "Skipping: Firefox autoscrolling is already enabled."
                else
                    pkill -f firefox 2>/dev/null
                    echo 'user_pref("general.autoScroll", true);' >> "$FIREFOX_PREFS_FILE" || { echo "Error: Failed to modify $FIREFOX_PREFS_FILE"; exit 1; }
                    current_timestamp=$(date +%s)
                    cp "$FIREFOX_PREFS_FILE" "$BACKUP_DIR/prefs.js.$current_timestamp" || { echo "Warning: Failed to backup $FIREFOX_PREFS_FILE"; }
                    echo "Enabled Firefox autoscrolling in $FIREFOX_PREFS_FILE"
                    echo "MODIFIED_FIREFOX_AUTOSCROLL: Enabled general.autoScroll" >> "$LOG_FILE"
                fi
            else
                echo "Warning: Firefox prefs.js not found at $FIREFOX_PREFS_FILE. Skipping autoscrolling."
            fi
        else
            echo "Warning: Could not find default profile in profiles.ini. Skipping autoscrolling."
        fi
    else
        echo "Warning: profiles.ini not found at $PROFILE_INI. Skipping autoscrolling."
    fi
else
    echo "Warning: Firefox is not installed. Skipping autoscrolling configuration."
fi

if command -v zen >/dev/null 2>&1 || [ -x "/opt/zen-browser-bin/zen-bin" ]; then
    if [ ! -d "$ZEN_PROFILE_DIR" ] || [ ! -f "$ZEN_PROFILE_INI" ]; then
        echo "Zen Browser profile directory or profiles.ini not found. Creating a new profile..."
        /opt/zen-browser-bin/zen-bin --no-remote -CreateProfile default || { echo "Warning: Failed to create a new Zen Browser profile. Skipping autoscrolling."; }
        echo "CREATED_PROFILE: $ZEN_PROFILE_DIR/default" >> "$LOG_FILE"
    fi
    if [ -f "$ZEN_PROFILE_INI" ]; then
        ZEN_PROFILE_PATH=$(awk -F'=' '/\[Install[0-9A-F]+\]/{p=1; path=""} p&&/Default=/{path=$2} p&&/^$/{print path; p=0} END{if(path) print path}' "$ZEN_PROFILE_INI" | head -n1)
        if [ -z "$ZEN_PROFILE_PATH" ]; then
            ZEN_PROFILE_PATH=$(awk -F'=' '/\[Profile[0-9]+\]/{p=1; path=""; def=0} p&&/Path=/{path=$2} p&&/Default=1/{def=1} p&&/^$/{if(def=1) print path; p=0} END{if(def=1) print path}' "$ZEN_PROFILE_INI" | head -n1)
        fi
        if [ -n "$ZEN_PROFILE_PATH" ]; then
            ZEN_PREFS_FILE="$ZEN_PROFILE_DIR/$ZEN_PROFILE_PATH/prefs.js"
            if [ -f "$ZEN_PREFS_FILE" ]; then
                if grep -q 'user_pref("general.autoScroll", true)' "$ZEN_PREFS_FILE"; then
                    echo "Skipping: Zen Browser autoscrolling is already enabled."
                else
                    pkill -f zen-bin 2>/dev/null
                    echo 'user_pref("general.autoScroll", true);' >> "$ZEN_PREFS_FILE" || { echo "Error: Failed to modify $ZEN_PREFS_FILE"; exit 1; }
                    current_timestamp=$(date +%s)
                    cp "$ZEN_PREFS_FILE" "$BACKUP_DIR/prefs_zen.js.$current_timestamp" || { echo "Warning: Failed to backup $ZEN_PREFS_FILE"; }
                    echo "Enabled Zen Browser autoscrolling in $ZEN_PREFS_FILE"
                    echo "MODIFIED_ZEN_AUTOSCROLL: Enabled general.autoScroll" >> "$LOG_FILE"
                fi
            else
                echo "Warning: Zen Browser prefs.js not found at $ZEN_PREFS_FILE. Skipping autoscrolling."
            fi
        else
            echo "Warning: Could not find default profile in Zen Browser profiles.ini. Skipping autoscrolling."
        fi
    else
        echo "Warning: Zen Browser profiles.ini not found at $ZEN_PROFILE_INI. Skipping autoscrolling."
    fi
else
    echo "Warning: Zen Browser is not installed. Skipping configuration."
fi

echo "Browser configuration completed successfully."
exit 0
