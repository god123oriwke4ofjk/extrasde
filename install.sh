#!/bin/bash

USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo "Error: Could not determine username."; exit 1; }

ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
USERPREFS_CONF="/home/$USER/.config/hypr/userprefs.conf"
LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
FIREFOX_PROFILE_DIR="$HOME/.mozilla/firefox"
PROFILE_INI="$FIREFOX_PROFILE_DIR/profiles.ini"
ZEN_PROFILE_DIR="$HOME/.zen"
ZEN_PROFILE_INI="$ZEN_PROFILE_DIR/profiles.ini"
DYNAMIC_BROWSER_SCRIPT="$SCRIPT_DIR/dynamic-browser.sh"
SCRIPT_BASEDIR="$(dirname "$(realpath "$0")")"
ICONS_SRC_DIR="$SCRIPT_BASEDIR/icons"
CONFIG_DIR="$SCRIPT_BASEDIR/config"
KEYBINDS_SRC_DIR="$CONFIG_DIR/keybinds"
SUDOERS_FILE="/etc/sudoers.d/hyde-vpn"

BROWSER_ONLY=false
KEYBIND_ONLY=false
SUDOERS_ONLY=false
KEYBOARD_ONLY=false
NO_DYNAMIC=false
LOG_ONLY=false
while [[ "$1" =~ ^- ]]; do
    case $1 in
        --browser)
            BROWSER_ONLY=true
            if [[ "$2" == "nodynamic" ]]; then
                NO_DYNAMIC=true
                shift
            fi
            shift
            ;;
        --keybind)
            KEYBIND_ONLY=true
            shift
            ;;
        --sudoers)
            SUDOERS_ONLY=true
            shift
            ;;
        --kb)
            KEYBOARD_ONLY=true
            shift
            ;;
        -log)
            LOG_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; then
    BROWSER_ONLY=true
    KEYBIND_ONLY=true
    SUDOERS_ONLY=true
    KEYBOARD_ONLY=true
fi

if [ "$LOG_ONLY" = true ]; then
    mkdir -p "$(dirname "$LOG_FILE")" || { echo "Error: Failed to create directory for $LOG_FILE"; exit 1; }
    touch "$LOG_FILE" || { echo "Error: Failed to create $LOG_FILE"; exit 1; }
    echo "[$(date)] New installation session (Browser only: $BROWSER_ONLY, Keybind only: $KEYBIND_ONLY, Sudoers only: $SUDOERS_ONLY, Keyboard only: $KEYBOARD_ONLY, No dynamic: $NO_DYNAMIC, Log only: $LOG_ONLY)" >> "$LOG_FILE"
    
    if [ "$SUDOERS_ONLY" = true ] || { [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; }; then
        echo "CREATED_SUDOERS: $SUDOERS_FILE" >> "$LOG_FILE"
    fi

    if [ "$KEYBIND_ONLY" = true ] || { [ "$BROWSER_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; }; then
        echo "BACKUP_CONFIG: $KEYBINDINGS_CONF -> $BACKUP_DIR/keybindings.conf.bak" >> "$LOG_FILE"
        echo "DEBUG: Appended Utilities section with VPN binding" >> "$LOG_FILE"
        echo "MODIFIED_KEYBINDINGS: Added VPN binding to Utilities section" >> "$LOG_FILE"
        declare -A keybind_scripts
        keybind_scripts["vpn.sh"]="$CONFIG_DIR/vpn.sh"
        for script_name in "${!keybind_scripts[@]}"; do
            script_path="$SCRIPT_DIR/$script_name"
            echo "CREATED_SCRIPT: $script_name -> $script_path" >> "$LOG_FILE"
        done
    fi

    if [ "$BROWSER_ONLY" = true ] || { [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; }; then
        if [ "$NO_DYNAMIC" = false ]; then
            declare -A scripts
            scripts["dynamic-browser.sh"]="$CONFIG_DIR/dynamic_browser.sh"
            for script_name in "${!scripts[@]}"; do
                script_path="$SCRIPT_DIR/$script_name"
                echo "CREATED_SCRIPT: $script_name -> $script_path" >> "$LOG_FILE"
            done
            echo "BACKUP_CONFIG: $USERPREFS_CONF -> $BACKUP_DIR/userprefs.conf.$current_timestamp" >> "$LOG_FILE"
            echo "MODIFIED_CONFIG: $USERPREFS_CONF -> Added exec-once=$DYNAMIC_BROWSER_SCRIPT" >> "$LOG_FILE"
        fi
        echo "CREATED_PROFILE: $FIREFOX_PROFILE_DIR/default" >> "$LOG_FILE"
        echo "MODIFIED_FIREFOX_AUTOSCROLL: Enabled general.autoScroll" >> "$LOG_FILE"
        echo "CREATED_PROFILE: $ZEN_PROFILE_DIR/default" >> "$LOG_FILE"
        echo "MODIFIED_ZEN_AUTOSCROLL: Enabled general.autoScroll" >> "$LOG_FILE"
    fi

    if [ "$KEYBOARD_ONLY" = true ] || { [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ]; }; then
        echo "CREATED_CONFIG: $USERPREFS_CONF" >> "$LOG_FILE"
        echo "MODIFIED_USERPREFS: Set kb_layout = us,il in input block" >> "$LOG_FILE"
    fi

    if [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; then
        echo "INSTALLED_PACKAGE: jq" >> "$LOG_FILE"
        if [ -d "$ICONS_SRC_DIR" ]; then
            for file in "$ICONS_SRC_DIR"/*.svg; do
                if [ -f "$file" ]; then
                    target_file="$ICON_DIR/$(basename "$file")"
                    echo "MOVED_SVG: $(basename "$file") -> $target_file" >> "$LOG_FILE"
                fi
            done
        fi
        current_timestamp=$(date +%s)
        echo "Created backup session marker for run at $current_timestamp" >> "$LOG_FILE"
    fi
    exit 0
fi

mkdir -p "$SCRIPT_DIR" || { echo "Error: Failed to create $SCRIPT_DIR"; exit 1; }
mkdir -p "$BACKUP_DIR" || { echo "Error: Failed to create $BACKUP_DIR"; exit 1; }
mkdir -p "$(dirname "$USERPREFS_CONF")" || { echo "Error: Failed to create $(dirname "$USERPREFS_CONF")"; exit 1; }

touch "$LOG_FILE" || { echo "Error: Failed to create $LOG_FILE"; exit 1; }
echo "[$(date)] New installation session (Browser only: $BROWSER_ONLY, Keybind only: $KEYBIND_ONLY, Sudoers only: $SUDOERS_ONLY, Keyboard only: $KEYBOARD_ONLY, No dynamic: $NO_DYNAMIC, Log only: $LOG_ONLY)" >> "$LOG_FILE"

if [ "$SUDOERS_ONLY" = true ] || { [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; }; then
    echo "Configuring sudoers requires sudo privileges."
    sudo -v || { echo "Error: Sudo authentication failed."; exit 1; }
    if [ ! -f "$SUDOERS_FILE" ]; then
        echo "Configuring sudoers to allow NOPASSWD for openvpn and killall..."
        sudo bash -c "cat > '$SUDOERS_FILE' << 'EOF'
$USER ALL=(ALL) NOPASSWD: /usr/bin/openvpn
$USER ALL=(ALL) NOPASSWD: /usr/bin/killall openvpn
EOF" || { echo "Error: Failed to create $SUDOERS_FILE"; exit 1; }
        sudo chmod 0440 "$SUDOERS_FILE" || { echo "Error: Failed to set permissions on $SUDOERS_FILE"; exit 1; }
        if ! sudo visudo -c -f "$SUDOERS_FILE" >/dev/null 2>&1; then
            echo "Error: Invalid sudoers configuration in $SUDOERS_FILE"
            sudo rm -f "$SUDOERS_FILE"
            exit 1
        fi
        echo "CREATED_SUDOERS: $SUDOERS_FILE" >> "$LOG_FILE"
        echo "Created $SUDOERS_FILE for $USER"
    else
        if ! grep -q "$USER ALL=(ALL) NOPASSWD: /usr/bin/openvpn" "$SUDOERS_FILE" || ! grep -q "$USER ALL=(ALL) NOPASSWD: /usr/bin/killall openvpn" "$SUDOERS_FILE"; then
            echo "Updating existing sudoers file..."
            current_timestamp=$(date +%s)
            sudo cp "$SUDOERS_FILE" "$BACKUP_DIR/sudoers_hyde-vpn.$current_timestamp" || { echo "Error: Failed to backup $SUDOERS_FILE"; exit 1; }
            sudo bash -c "cat > '$SUDOERS_FILE' << 'EOF'
$USER ALL=(ALL) NOPASSWD: /usr/bin/openvpn
$USER ALL=(ALL) NOPASSWD: /usr/bin/killall openvpn
EOF" || { echo "Error: Failed to update $SUDOERS_FILE"; exit 1; }
            sudo chmod 0440 "$SUDOERS_FILE" || { echo "Error: Failed to set permissions on $SUDOERS_FILE"; exit 1; }
            if ! sudo visudo -c -f "$SUDOERS_FILE" >/dev/null 2>&1; then
                echo "Error: Invalid sudoers configuration in $SUDOERS_FILE"
                sudo rm -f "$SUDOERS_FILE"
                exit 1
            fi
            echo "MODIFIED_SUDOERS: $SUDOERS_FILE" >> "$LOG_FILE"
            echo "Updated $SUDOERS_FILE for $USER"
        else
            echo "Skipping: Sudoers already configured for $USER"
        fi
    fi
fi

if [ "$KEYBIND_ONLY" = true ] || { [ "$BROWSER_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; }; then
    if [ ! -f "$KEYBINDINGS_CONF" ]; then
        echo "Error: $KEYBINDINGS_CONF does not exist. Creating an empty file."
        touch "$KEYBINDINGS_CONF" || { echo "Error: Failed to create $KEYBINDINGS_CONF"; exit 1; }
    fi

    [ ! -w "$KEYBINDINGS_CONF" ] && { echo "Error: $KEYBINDINGS_CONF is not writable."; exit 1; }

    if [ -f "$KEYBINDINGS_CONF" ]; then
        find "$BACKUP_DIR" -type f -name "keybindings.conf.bak" -delete || { echo "Warning: Failed to delete previous keybindings.conf.bak"; }
        cp "$KEYBINDINGS_CONF" "$BACKUP_DIR/keybindings.conf.bak" || { echo "Error: Failed to backup $KEYBINDINGS_CONF to $BACKUP_DIR/keybindings.conf.bak"; exit 1; }
        echo "BACKUP_CONFIG: $KEYBINDINGS_CONF -> $BACKUP_DIR/keybindings.conf.bak" >> "$LOG_FILE"
        echo "Backed up $KEYBINDINGS_CONF to $BACKUP_DIR/keybindings.conf.bak"
    fi

    VPN_LINE="bindd = \$mainMod Alt, V, \$d toggle vpn, exec, \$scrPath/vpn.sh toggle # toggle vpn"

    if grep -Fx "$VPN_LINE" "$KEYBINDINGS_CONF" > /dev/null; then
        echo "Skipping: VPN binding already exists in $KEYBINDINGS_CONF"
    else
        UTILITIES_START='$d=[$ut]'
        temp_file=$(mktemp)

        if ! grep -q "$UTILITIES_START" "$KEYBINDINGS_CONF"; then
            echo "Appending Utilities section to $KEYBINDINGS_CONF"
            echo -e "\n$UTILITIES_START\n$VPN_LINE" >> "$KEYBINDINGS_CONF" || { echo "Error: Failed to append to $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            echo "DEBUG: Appended Utilities section with VPN binding" >> "$LOG_FILE"
            echo "MODIFIED_KEYBINDINGS: Added Utilities section with VPN binding" >> "$LOG_FILE"
        else
            awk -v vpn_line="$VPN_LINE" -v util_start="$UTILITIES_START" '
                BEGIN { found_util=0; added=0 }
                $0 ~ util_start { found_util=1; print; next }
                found_util && !added && /^[[:space:]]*$/ { print vpn_line "\n"; added=1; print; next }
                found_util && !added && /^\$d=/ { print vpn_line "\n"; added=1; print; next }
                found_util && !added && !/^[[:space:]]*$/ && !/^bind/ { print vpn_line "\n"; added=1; print; next }
                { print }
                END { if (found_util && !added) print vpn_line }
            ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF with awk"; rm -f "$temp_file"; exit 1; }
            mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            echo "Added VPN binding to Utilities section in $KEYBINDINGS_CONF"
            echo "DEBUG: Added VPN binding to Utilities section" >> "$LOG_FILE"
            echo "MODIFIED_KEYBINDINGS: Added VPN binding to Utilities section" >> "$LOG_FILE"
        fi
    fi

    declare -A keybind_scripts
    keybind_scripts["vpn.sh"]="$CONFIG_DIR/vpn.sh"
    for script_name in "${!keybind_scripts[@]}"; do
        src_script="${keybind_scripts[$script_name]}"
        script_path="$SCRIPT_DIR/$script_name"
        if [ ! -f "$src_script" ]; then
            echo "Warning: Source script $src_script not found. Skipping."
            continue
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
fi

if [ "$BROWSER_ONLY" = true ] || { [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; }; then
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
        echo "Skipping dynamic-browser.sh installation and configuration (--browser nodynamic)"
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
                PROFILE_PATH=$(awk -F'=' '/\[Profile[0-9]+\]/{p=1; path=""; def=0} p&&/Path=/{path=$2} p&&/Default=1/{def=1} p&&/^$/{if(def==1) print path; p=0} END{if(def==1) print path}' "$PROFILE_INI" | head -n1)
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
        echo "Warning: Zen Browser is not installed. Skipping autoscrolling configuration."
    fi
fi

if [ "$KEYBOARD_ONLY" = true ] || { [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ]; }; then
    if [ ! -f "$USERPREFS_CONF" ]; then
        echo "Warning: $USERPREFS_CONF does not exist. Creating with input block."
        cat << 'EOF' > "$USERPREFS_CONF"
input {
    kb_layout = us,il
}
EOF
        echo "CREATED_CONFIG: $USERPREFS_CONF" >> "$LOG_FILE"
        echo "Created $USERPREFS_CONF with kb_layout = us,il"
    else
        [ ! -w "$USERPREFS_CONF" ] && { echo "Error: $USERPREFS_CONF is not writable."; exit 1; }
        if awk '/^[[:space:]]*input[[:space:]]*{/,/^[[:space:]]*}/ {if ($0 ~ /^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*us,il/) found=1} END {exit !found}' "$USERPREFS_CONF"; then
            echo "Skipping: 'kb_layout = us,il' already set in input block of $USERPREFS_CONF"
        else
            temp_file=$(mktemp)
            cp "$USERPREFS_CONF" "$BACKUP_DIR/userprefs.conf.$current_timestamp" || { echo "Error: Failed to backup $USERPREFS_CONF"; rm -f "$temp_file"; exit 1; }
            if grep -q '^[[:space:]]*input[[:space:]]*{.*}' "$USERPREFS_CONF"; then
                awk '/^[[:space:]]*input[[:space:]]*{/ {print; print "    kb_layout = us,il"; next} 1' "$USERPREFS_CONF" > "$temp_file" || { echo "Error: Failed to modify $USERPREFS_CONF"; rm -f "$temp_file"; exit 1; }
            else
                cat << 'EOF' >> "$temp_file"
input {
    kb_layout = us,il
}
EOF
                cat "$USERPREFS_CONF" >> "$temp_file"
            fi
            mv "$temp_file" "$USERPREFS_CONF" || { echo "Error: Failed to update $USERPREFS_CONF"; rm -f "$temp_file"; exit 1; }
            echo "Modified $USERPREFS_CONF to set 'kb_layout = us,il' in input block"
            echo "MODIFIED_USERPREFS: Set kb_layout = us,il in input block" >> "$LOG_FILE"
        fi
    fi
fi

if [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; then
    echo "This script requires sudo privileges to install dependencies and configure additional settings."
    sudo -v || { echo "Error: Sudo authentication failed."; exit 1; }
    command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found. This script requires Arch Linux."; exit 1; }
    ping -c 1 archlinux.org >/dev/null 2>&1 || { echo "Error: No internet connection."; exit 1; }
    mkdir -p "$ICON_DIR" || { echo "Error: Failed to create $ICON_DIR"; exit 1; }
    mkdir -p "$(dirname "$KEYBINDINGS_CONF")" || { echo "Error: Failed to create $(dirname "$KEYBINDINGS_CONF")"; exit 1; }
    current_timestamp=$(date +%s)
    if [ -d "$BACKUP_DIR" ]; then
        prev_backup=$(ls -t "$BACKUP_DIR/backup_session_"* 2>/dev/null | head -n2 | tail -n1)
        if [ -n "$prev_backup" ]; then
            prev_timestamp=$(basename "$prev_backup" | sed 's/backup_session_//')
            echo "Removing backups from previous run ($prev_timestamp)..."
            find "$BACKUP_DIR" -type f -name "*.$prev_timestamp" -delete || { echo "Warning: Failed to delete some previous backups"; }
            rm -f "$prev_backup" || { echo "Warning: Failed to delete previous backup session marker"; }
            echo "Removed previous backups."
        else
            echo "No previous backup session found. Skipping cleanup."
        fi
    fi
    if ! pacman -Qs jq >/dev/null 2>&1; then
        sudo pacman -S --noconfirm jq || { echo "Error: Failed to install jq"; exit 1; }
        echo "INSTALLED_PACKAGE: jq" >> "$LOG_FILE"
        echo "Installed jq"
    else
        echo "Skipping: jq already installed"
    fi
    moved_files=0
    replace_files=()
    if [ -d "$ICONS_SRC_DIR" ]; then
        for file in "$ICONS_SRC_DIR"/*.svg; do
            if [ -f "$file" ]; then
                target_file="$ICON_DIR/$(basename "$file")"
                if [ -f "$target_file" ]; then
                    src_hash=$(sha256sum "$file" | cut -d' ' -f1)
                    tgt_hash=$(sha256sum "$target_file" | cut -d' ' -f1)
                    if [ "$src_hash" = "$tgt_hash" ]; then
                        echo "Skipping $(basename "$file"): identical file already exists at $target_file"
                    else
                        echo "Found $(basename "$file"): same name but different content at $target_file"
                        replace_files+=("$file")
                    fi
                else
                    mv "$file" "$ICON_DIR/" || { echo "Error: Failed to move $(basename "$file")"; exit 1; }
                    echo "Moved $(basename "$file") to $ICON_DIR/"
                    echo "MOVED_SVG: $(basename "$file") -> $target_file" >> "$LOG_FILE"
                    ((moved_files++))
                fi
            fi
        done
    else
        echo "Warning: Icons directory $ICONS_SRC_DIR not found. Skipping .svg file installation."
    fi
    if [ ${#replace_files[@]} -gt 0 ]; then
        echo "The following files have the same name but different content in $ICON_DIR:"
        for file in "${replace_files[@]}"; do
            echo "- $(basename "$file")"
        done
        read -p "Replace these files in $ICON_DIR? [y/N]: " replace_choice
        if [[ "$replace_choice" =~ ^[Yy]$ ]]; then
            for file in "${replace_files[@]}"; do
                target_file="$ICON_DIR/$(basename "$file")"
                cp "$target_file" "$BACKUP_DIR/$(basename "$file").$current_timestamp" || { echo "Error: Failed to backup $target_file"; exit 1; }
                mv "$file" "$ICON_DIR/" || { echo "Error: Failed to replace $(basename "$file")"; exit 1; }
                echo "Replaced $(basename "$file") in $ICON_DIR/"
                echo "REPLACED_SVG: $(basename "$file") -> $target_file" >> "$LOG_FILE"
                ((moved_files++))
            done
        else
            echo "Skipping replacement of non-identical files."
        fi
    fi
    [ "$moved_files" -eq 0 ] && [ -d "$ICONS_SRC_DIR" ] && echo "No new or replaced .svg files were moved."
fi

if [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; then
    current_timestamp=$(date +%s)
    touch "$BACKUP_DIR/backup_session_$current_timestamp" || { echo "Error: Failed to create backup session marker"; exit 1; }
    echo "Created backup session marker for run at $current_timestamp"
fi

echo "Script execution completed successfully."
