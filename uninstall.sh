#!/bin/bash

USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo "Error: Could not determine username."; exit 1; }

# Directories
ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
USERPREFS_CONF="/home/$USER/.config/hypr/userprefs.conf"
LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
FIREFOX_PROFILE_DIR="$HOME/.mozilla/firefox"
PROFILE_INI="$FIREFOX_PROFILE_DIR/profiles.ini"
DYNAMIC_BROWSER_SCRIPT="$SCRIPT_DIR/dynamic-browser.sh"
SUDOERS_FILE="/etc/sudoers.d/hyde-vpn"

# Initialize undo log
UNDO_LOG="/home/$USER/.local/lib/hyde/undo.log"
touch "$UNDO_LOG" || { echo "Error: Failed to create $UNDO_LOG"; exit 1; }
echo "[$(date)] New undo session" >> "$UNDO_LOG"

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Install log file $LOG_FILE not found. Nothing to undo."
    exit 1
fi

# Function to check if file exists and is non-empty
check_file() {
    local file="$1"
    [ -f "$file" ] && [ -s "$file" ] && return 0
    return 1
}

# Revert sudoers changes
if grep -q -E "CREATED_SUDOERS:|MODIFIED_SUDOERS:" "$LOG_FILE"; then
    if check_file "$SUDOERS_FILE"; then
        echo "Removing sudoers file: $SUDOERS_FILE"
        sudo rm -f "$SUDOERS_FILE" || { echo "Error: Failed to remove $SUDOERS_FILE"; exit 1; }
        echo "UNDO: Removed $SUDOERS_FILE" >> "$UNDO_LOG"
    fi
    # Restore backed-up sudoers if exists
    backup_file=$(ls -t "$BACKUP_DIR/sudoers_hyde-vpn."* 2>/dev/null | head -n1)
    if check_file "$backup_file"; then
        echo "Restoring backed-up sudoers: $backup_file to $SUDOERS_FILE"
        sudo cp "$backup_file" "$SUDOERS_FILE" || { echo "Error: Failed to restore $SUDOERS_FILE"; exit 1; }
        sudo chmod 0440 "$SUDOERS_FILE" || { echo "Error: Failed to set permissions on $SUDOERS_FILE"; exit 1; }
        if ! sudo visudo -c -f "$SUDOERS_FILE" >/dev/null 2>&1; then
            echo "Error: Restored sudoers file is invalid"
            sudo rm -f "$SUDOERS_FILE"
            exit 1
        fi
        echo "UNDO: Restored $SUDOERS_FILE from $backup_file" >> "$UNDO_LOG"
    fi
else
    echo "Skipping: No sudoers modifications found in log."
fi

# Revert installed packages
grep "INSTALLED_PACKAGE:" "$LOG_FILE" | while read -r line; do
    package=$(echo "$line" | cut -d' ' -f2-)
    echo "Removing installed package: $package"
    if [ $package = "osu" ]; then
        command="osu-wine --remove"
        if ! command -v osu-wine &>/dev/null; then
            echo "Error: osu-wine not found"
        else
            echo "y" | $command
        fi
        if [ $? -eq 0 ]; then
            echo "UNDO: Removed package $package" >> "$UNDO_LOG"
            echo "Osu succesfully removed osu"
        else
            echo "Error: Failed to remove osu-wine"
        fi    
    else  
        sudo pacman -Rns --noconfirm "$package" 2>/dev/null || echo "Warning: Failed to remove package $package"
        echo "UNDO: Removed package $package" >> "$UNDO_LOG"
    fi
done

# Revert created or replaced scripts
grep -E "CREATED_SCRIPT:|REPLACED_SCRIPT:" "$LOG_FILE" | while read -r line; do
    script_path=$(echo "$line" | cut -d' ' -f3- | cut -d' ' -f3)
    script_name=$(basename "$script_path")
    if check_file "$script_path"; then
        echo "Removing script: $script_path"
        rm -f "$script_path" || { echo "Error: Failed to remove $script_path"; exit 1; }
        echo "UNDO: Removed script $script_path" >> "$UNDO_LOG"
    else
        echo "Skipping: Script $script_path already removed or never created."
    fi
    # Restore backed-up script if exists
    backup_file=$(ls -t "$BACKUP_DIR/$script_name."* 2>/dev/null | head -n1)
    if check_file "$backup_file"; then
        echo "Restoring backed-up script: $backup_file to $script_path"
        cp "$backup_file" "$script_path" || { echo "Error: Failed to restore $script_path"; exit 1; }
        chmod +x "$script_path" || { echo "Error: Failed to make $script_path executable"; exit 1; }
        echo "UNDO: Restored $script_path from $backup_file" >> "$UNDO_LOG"
    fi
done

# Revert moved or replaced SVG files
grep -E "MOVED_SVG:|REPLACED_SVG:" "$LOG_FILE" | while read -r line; do
    svg_file=$(echo "$line" | cut -d' ' -f3- | cut -d' ' -f3)
    svg_name=$(basename "$svg_file")
    if check_file "$svg_file"; then
        echo "Removing SVG: $svg_file"
        rm -f "$svg_file" || { echo "Error: Failed to remove $svg_file"; exit 1; }
        echo "UNDO: Removed SVG $svg_file" >> "$UNDO_LOG"
    else
        echo "Skipping: SVG $svg_file already removed or never moved."
    fi
    # Restore backed-up SVG if exists
    backup_file=$(ls -t "$BACKUP_DIR/$svg_name."* 2>/dev/null | head -n1)
    if check_file "$backup_file"; then
        echo "Restoring backed-up SVG: $backup_file to $svg_file"
        cp "$backup_file" "$svg_file" || { echo "Error: Failed to restore $svg_file"; exit 1; }
        echo "UNDO: Restored $svg_file from $backup_file" >> "$UNDO_LOG"
    fi
done

# Revert Firefox autoscrolling
if grep -q "MODIFIED_FIREFOX_AUTOSCROLL:" "$LOG_FILE"; then
    if [ -f "$PROFILE_INI" ]; then
        PROFILE_PATH=$(awk -F'=' '/\[Install[0-9A-F]+\]/{p=1; path=""} p&&/Default=/{path=$2} p&&/^$/{print path; p=0} END{if(path) print path}' "$PROFILE_INI" | head -n1)
        if [ -z "$PROFILE_PATH" ]; then
            PROFILE_PATH=$(awk -F'=' '/\[Profile[0-9]+\]/{p=1; path=""; def=0} p&&/Path=/{path=$2} p&&/Default=1/{def=1} p&&/^$/{if(def==1) print path; p=0} END{if(def==1) print path}' "$PROFILE_INI" | head -n1)
        fi
        if [ -n "$PROFILE_PATH" ]; then
            FIREFOX_PREFS_FILE="$FIREFOX_PROFILE_DIR/$PROFILE_PATH/prefs.js"
            if check_file "$FIREFOX_PREFS_FILE"; then
                if grep -q 'user_pref("general.autoScroll", true)' "$FIREFOX_PREFS_FILE"; then
                    # Find the latest backup
                    backup_file=$(ls -t "$BACKUP_DIR/prefs.js."* 2>/dev/null | head -n1)
                    if check_file "$backup_file"; then
                        echo "Restoring Firefox prefs.js: $backup_file to $FIREFOX_PREFS_FILE"
                        pkill -9 firefox 2>/dev/null
                        cp "$backup_file" "$FIREFOX_PREFS_FILE" || { echo "Error: Failed to restore $FIREFOX_PREFS_FILE"; exit 1; }
                        echo "UNDO: Restored $FIREFOX_PREFS_FILE from $backup_file" >> "$UNDO_LOG"
                    else
                        echo "Warning: No backup found for $FIREFOX_PREFS_FILE. Cannot revert autoscrolling."
                    fi
                else
                    echo "Skipping: Firefox autoscrolling not enabled in $FIREFOX_PREFS_FILE."
                fi
            else
                echo "Warning: Firefox prefs.js not found at $FIREFOX_PREFS_FILE. Skipping autoscrolling revert."
            fi
        else
            echo "Warning: Could not find default profile in profiles.ini. Skipping autoscrolling revert."
        fi
    else
        echo "Warning: profiles.ini not found at $PROFILE_INI. Skipping autoscrolling revert."
    fi
else
    echo "Skipping: No Firefox autoscrolling modifications found in log."
fi

# Revert userprefs.conf modifications
if grep -q "MODIFIED_USERPREFS:" "$LOG_FILE"; then
    backup_file=$(ls -t "$BACKUP_DIR/userprefs.conf."* 2>/dev/null | head -n1)
    if check_file "$backup_file"; then
        echo "Restoring userprefs.conf: $backup_file to $USERPREFS_CONF"
        cp "$backup_file" "$USERPREFS_CONF" || { echo "Error: Failed to restore $USERPREFS_CONF"; exit 1; }
        echo "UNDO: Restored $USERPREFS_CONF from $backup_file" >> "$UNDO_LOG"
    else
        echo "Warning: No backup found for $USERPREFS_CONF. Cannot revert modifications."
    fi
fi

# Revert userprefs.conf creation
if grep -q "CREATED_CONFIG:.*$USERPREFS_CONF" "$LOG_FILE"; then
    if check_file "$USERPREFS_CONF"; then
        echo "Removing created userprefs.conf: $USERPREFS_CONF"
        rm -f "$USERPREFS_CONF" || { echo "Error: Failed to remove $USERPREFS_CONF"; exit 1; }
        echo "UNDO: Removed $USERPREFS_CONF" >> "$UNDO_LOG"
    else
        echo "Skipping: $USERPREFS_CONF already removed or never created."
    fi
fi

# Revert keybindings.conf modifications
if grep -q "MODIFIED_KEYBINDINGS:" "$LOG_FILE"; then
    backup_file=$(ls -t "$BACKUP_DIR/keybindings.conf."* 2>/dev/null | head -n1)
    if check_file "$backup_file"; then
        echo "Restoring keybindings.conf: $backup_file to $KEYBINDINGS_CONF"
        cp "$backup_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to restore $KEYBINDINGS_CONF"; exit 1; }
        echo "UNDO: Restored $KEYBINDINGS_CONF from $backup_file" >> "$UNDO_LOG"
    else
        echo "Warning: No backup found for $KEYBINDINGS_CONF. Attempting to remove added bindings."
        temp_file=$(mktemp)
        SLEEP_BIND_LINE="bindd = \$mainMod, I, \$d toggle sleep inhibition , exec, \$scrPath/toggle-sleep.sh # toggle sleep inhibition"
        VPN_LINES="\$d=[\$ut|Vpn Commands]
bindd = \$mainMod Alt, V, \$d toggle vpn , exec, \$scrPath/vpn-toggle.sh # toggle vpn
bindd = \$mainMod Alt, C, \$d change vpn location , exec, \$scrPath/vpn-toggle.sh change # change vpn server"
        awk -v sleep_line="$SLEEP_BIND_LINE" -v vpn_lines="$VPN_LINES" '
            BEGIN { in_vpn=0 }
            $0 == sleep_line { next }
            $0 ~ /^\$d=\[\$ut\|Vpn Commands\]/ { in_vpn=1; next }
            in_vpn && $0 ~ /^bindd = \$mainMod Alt, [VC],/ { next }
            in_vpn && $0 !~ /^[[:space:]]*$/ { in_vpn=0 }
            { print }
        ' "$KEYBINDINGS_CONF" > "$temp_file"
        mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; exit 1; }
        echo "UNDO: Removed sleep and VPN bindings from $KEYBINDINGS_CONF" >> "$UNDO_LOG"
    fi
fi

# Revert dynamic-browser.sh exec-once in userprefs.conf
if grep -q "MODIFIED_CONFIG:.*exec-once=$DYNAMIC_BROWSER_SCRIPT" "$LOG_FILE"; then
    if check_file "$USERPREFS_CONF"; then
        temp_file=$(mktemp)
        grep -v "exec-once=$DYNAMIC_BROWSER_SCRIPT" "$USERPREFS_CONF" > "$temp_file"
        mv "$temp_file" "$USERPREFS_CONF" || { echo "Error: Failed to update $USERPREFS_CONF"; exit 1; }
        echo "UNDO: Removed exec-once=$DYNAMIC_BROWSER_SCRIPT from $USERPREFS_CONF" >> "$UNDO_LOG"
    else
        echo "Skipping: $USERPREFS_CONF does not exist, no exec-once to remove."
    fi
fi

# Clean up backup directory if empty
if [ -d "$BACKUP_DIR" ] && [ -z "$(ls -A "$BACKUP_DIR")" ]; then
    rmdir "$BACKUP_DIR" && echo "Removed empty backup directory $BACKUP_DIR"
fi

# Preserve pre-existing files by not deleting $SCRIPT_DIR or $ICON_DIR
echo "Undo completed. Pre-existing files in $SCRIPT_DIR and $ICON_DIR preserved."
echo "UNDO: Completed undo process" >> "$UNDO_LOG"
