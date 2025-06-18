#!/bin/bash

USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo "Error: Could not determine username."; exit 1; }

ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
USERPREFS_CONF="/home/$USER/.config/hypr/userprefs.conf"
LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
SUDOERS_FILE="/etc/sudoers.d/hyde-vpn"
SCRIPT_BASEDIR="$(dirname "$(realpath "$0")")"
ICONS_SRC_DIR="$SCRIPT_BASEDIR/icons"
CONFIG_DIR="$SCRIPT_BASEDIR/config"
KEYBINDS_SRC_DIR="$CONFIG_DIR/keybinds"
EXTRA_KEYBINDS_SRC_DIR="/home/$USER/Extra/config/keybinds"

BROWSER_ONLY=false
KEYBIND_ONLY=false
SUDOERS_ONLY=false
KEYBOARD_ONLY=false
NO_DYNAMIC=false
LOG_ONLY=false
OUTSUDO=false
HELP=false
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
        -outsudo)
            OUTSUDO=true
            shift
            ;;
        -h|-help)
            HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$HELP" = true ]; then
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo "Options:"
    echo "  --browser [nodynamic]  Configure browser-related settings using browsers.sh."
    echo "                        Use 'nodynamic' to skip dynamic-browser.sh installation."
    echo "  --keybind             Configure keybindings for Hyprland (e.g., VPN toggle)."
    echo "  --sudoers             Configure sudoers file for NOPASSWD access to openvpn and killall."
    echo "  --kb                  Configure keyboard layout (us,il) in Hyprland userprefs."
    echo "  -log                  Log actions to $LOG_FILE without performing them."
    echo "  -outsudo              Use a GUI (yad) prompt for sudo instead of CLI."
    echo "  -h, -help             Display this help message and exit."
    exit 0
fi

if [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; then
    BROWSER_ONLY=true
    KEYBIND_ONLY=true
    SUDOERS_ONLY=true
    KEYBOARD_ONLY=true
fi

if [ "$SUDOERS_ONLY" = true ] || [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; then
    if [ "$OUTSUDO" = true ]; then
        if ! pacman -Qs yad >/dev/null 2>&1; then
            echo "Installing yad for GUI sudo prompt..."
            sudo pacman -S --noconfirm yad || { echo "Error: Failed to install yad"; exit 1; }
            echo "INSTALLED_PACKAGE: yad" >> "$LOG_FILE"
            echo "Installed yad"
        else
            echo "Skipping: yad already installed"
        fi
        SUDO_PASS=$(yad --title='Sudo Authentication' --text='Enter your password for sudo access:' --entry --hide-text --button='OK:0' --button='Cancel:1' --width=300 --center --on-top --class='sudo-prompt' --window-icon='dialog-password' 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$SUDO_PASS" ]; then
            echo "Error: Sudo authentication canceled or failed."
            exit 1
        fi
        echo "$SUDO_PASS" | sudo -S -v || { echo "Error: Sudo authentication failed."; exit 1; }
        hyprctl dispatch focuswindow class:sudo-prompt 2>/dev/null || true
        SUDO_CMD="echo \"$SUDO_PASS\" | sudo -S"
    else
        sudo -v || { echo "Error: Sudo authentication failed."; exit 1; }
        SUDO_CMD="sudo"
    fi
else
    SUDO_CMD="sudo"
fi

if [ "$LOG_ONLY" = true ]; then
    mkdir -p "$(dirname "$LOG_FILE")" || { echo "Error: Failed to create directory for $LOG_FILE"; exit 1; }
    touch "$LOG_FILE" || { echo "Error: Failed to create $LOG_FILE"; exit 1; }
    echo "[$(date)] New installation session (Browser only: $BROWSER_ONLY, Keybind only: $KEYBIND_ONLY, Sudoers only: $SUDOERS_ONLY, Keyboard only: $KEYBOARD_ONLY, No dynamic: $NO_DYNAMIC, Log only: $LOG_ONLY, Outsudo: $OUTSUDO)" >> "$LOG_FILE"
    
    if [ "$SUDOERS_ONLY" = true ] || { [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; }; then
        echo "CREATED_SUDOERS: $SUDOERS_FILE" >> "$LOG_FILE"
    fi

    if [ "$KEYBIND_ONLY" = true ] || { [ "$BROWSER_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; }; then
        echo "BACKUP_CONFIG: $KEYBINDINGS_CONF -> $BACKUP_DIR/keybindings.conf.bak" >> "$LOG_FILE"
        echo "DEBUG: Updated or added VPN and window switcher bindings in Utilities section" >> "$LOG_FILE"
        echo "MODIFIED_KEYBINDINGS: Updated or added VPN and window switcher bindings in Utilities section" >> "$LOG_FILE"
        echo "DEBUG: Updated or added game launcher binding" >> "$LOG_FILE"
        echo "MODIFIED_KEYBINDINGS: Updated or added game launcher binding" >> "$LOG_FILE"
        echo "DEBUG: Updated or added zoom binding" >> "$LOG_FILE"
        echo "MODIFIED_KEYBINDINGS: Updated or added zoom binding" >> "$LOG_FILE"
        if [ -d "$KEYBINDS_SRC_DIR" ]; then
            for file in "$KEYBINDS_SRC_DIR"/*; do
                if [ -f "$file" ]; then
                    target_file="$SCRIPT_DIR/$(basename "$file")"
                    echo "COPIED_KEYBIND: $(basename "$file") -> $target_file" >> "$LOG_FILE"
                fi
            done
        fi
        if [ -d "$EXTRA_KEYBINDS_SRC_DIR" ]; then
            for file in "$EXTRA_KEYBINDS_SRC_DIR"/*; do
                if [ -f "$file" ]; then
                    target_file="$SCRIPT_DIR/$(basename "$file")"
                    echo "COPIED_KEYBIND: $(basename "$file") -> $target_file" >> "$LOG_FILE"
                fi
            done
        fi
    fi

    if [ "$BROWSER_ONLY" = true ]; then
        echo "CALLED_BROWSER_SCRIPT: browsers.sh with nodynamic=$NO_DYNAMIC" >> "$LOG_FILE"
    fi

    if [ "$KEYBOARD_ONLY" = true ] || { [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ]; }; then
        echo "CREATED_CONFIG: $USERPREFS_CONF" >> "$LOG_FILE"
        echo "MODIFIED_USERPREFS: Set kb_layout = us,il in input block" >> "$LOG_FILE"
    fi

    if [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; then
        echo "INSTALLED_PACKAGE: jq" >> "$LOG_FILE"
        echo "INSTALLED_PACKAGE: yad" >> "$LOG_FILE"
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
echo "[$(date)] New installation session (Browser only: $BROWSER_ONLY, Keybind only: $KEYBIND_ONLY, Sudoers only: $SUDOERS_ONLY, Keyboard only: $KEYBOARD_ONLY, No dynamic: $NO_DYNAMIC, Log only: $LOG_ONLY, Outsudo: $OUTSUDO)" >> "$LOG_FILE"

if [ "$SUDOERS_ONLY" = true ] || { [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; }; then
    echo "Configuring sudoers requires sudo privileges."
    if [ ! -f "$SUDOERS_FILE" ]; then
        echo "Configuring sudoers to allow NOPASSWD for openvpn and killall..."
        $SUDO_CMD bash -c "cat > '$SUDOERS_FILE' << 'EOF'
$USER ALL=(ALL) NOPASSWD: /usr/bin/openvpn
$USER ALL=(ALL) NOPASSWD: /usr/bin/killall openvpn
EOF" || { echo "Error: Failed to create $SUDOERS_FILE"; exit 1; }
        $SUDO_CMD chmod 0440 "$SUDOERS_FILE" || { echo "Error: Failed to set permissions on $SUDOERS_FILE"; exit 1; }
        $SUDO_CMD visudo -c -f "$SUDOERS_FILE" >/dev/null 2>&1 || { echo "Error: Invalid sudoers configuration in $SUDOERS_FILE"; $SUDO_CMD rm -f "$SUDOERS_FILE"; exit 1; }
        echo "CREATED_SUDOERS: $SUDOERS_FILE" >> "$LOG_FILE"
        echo "Created $SUDOERS_FILE for $USER"
    else
        if ! grep -q "$USER ALL=(ALL) NOPASSWD: /usr/bin/openvpn" "$SUDOERS_FILE" || ! grep -q "$USER ALL=(ALL) NOPASSWD: /usr/bin/killall openvpn" "$SUDOERS_FILE"; then
            echo "Updating existing sudoers file..."
            current_timestamp=$(date +%s)
            $SUDO_CMD cp "$SUDOERS_FILE" "$BACKUP_DIR/sudoers_hyde-vpn.$current_timestamp" || { echo "Error: Failed to backup $SUDOERS_FILE"; exit 1; }
            $SUDO_CMD bash -c "cat > '$SUDOERS_FILE' << 'EOF'
$USER ALL=(ALL) NOPASSWD: /usr/bin/openvpn
$USER ALL=(ALL) NOPASSWD: /usr/bin/killall openvpn
EOF" || { echo "Error: Failed to update $SUDOERS_FILE"; exit 1; }
            $SUDO_CMD chmod 0440 "$SUDOERS_FILE" || { echo "Error: Failed to set permissions on $SUDOERS_FILE"; exit 1; }
            $SUDO_CMD visudo -c -f "$SUDOERS_FILE" >/dev/null 2>&1 || { echo "Error: Invalid sudoers configuration in $SUDOERS_FILE"; $SUDO_CMD rm -f "$SUDOERS_FILE"; exit 1; }
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

    if [ -d "$EXTRA_KEYBINDS_SRC_DIR" ]; then
        copied_files=0
        replace_files=()
        for file in "$EXTRA_KEYBINDS_SRC_DIR"/*; do
            if [ -f "$file" ]; then
                target_file="$SCRIPT_DIR/$(basename "$file")"
                if [ -f "$target_file" ]; then
                    src_hash=$(sha256sum "$file" | cut -d' ' -f1)
                    tgt_hash=$(sha256sum "$target_file" | cut -d' ' -f1)
                    if [ "$src_hash" = "$tgt_hash" ]; then
                        echo "Skipping $(basename "$file"): identical file already exists at $target_file"
                        [ -x "$target_file" ] || { chmod +x "$target_file" || { echo "Error: Failed to make $target_file executable"; exit 1; }; echo "Made $target_file executable."; }
                    else
                        echo "Found $(basename "$file"): same name but different content at $target_file"
                        replace_files+=("$file")
                    fi
                else
                    cp "$file" "$SCRIPT_DIR/" || { echo "Error: Failed to copy $(basename "$file")"; exit 1; }
                    chmod +x "$target_file" || { echo "Error: Failed to make $target_file executable"; exit 1; }
                    echo "Copied and made executable $(basename "$file") to $SCRIPT_DIR/"
                    echo "COPIED_KEYBIND: $(basename "$file") -> $target_file" >> "$LOG_FILE"
                    ((copied_files++))
                fi
            fi
        done
        if [ ${#replace_files[@]} -gt 0 ]; then
            echo "The following keybind files have the same name but different content in $SCRIPT_DIR:"
            for file in "${replace_files[@]}"; do
                echo "- $(basename "$file")"
            done
            read -p "Replace these files in $SCRIPT_DIR? [y/N]: " replace_choice
            if [[ "$replace_choice" =~ ^[Yy]$ ]]; then
                for file in "${replace_files[@]}"; do
                    target_file="$SCRIPT_DIR/$(basename "$file")"
                    current_timestamp=$(date +%s)
                    cp "$target_file" "$BACKUP_DIR/$(basename "$file").$current_timestamp" || { echo "Error: Failed to backup $target_file"; exit 1; }
                    cp "$file" "$SCRIPT_DIR/" || { echo "Error: Failed to replace $(basename "$file")"; exit 1; }
                    chmod +x "$target_file" || { echo "Error: Failed to make $target_file executable"; exit 1; }
                    echo "Replaced and made executable $(basename "$file") in $SCRIPT_DIR/"
                    echo "REPLACED_KEYBIND: $(basename "$file") -> $target_file" >> "$LOG_FILE"
                    ((copied_files++))
                done
            else
                echo "Skipping replacement of non-identical keybind files."
            fi
        fi
        [ "$copied_files" -eq 0 ] && echo "No new or replaced keybind files were copied."
    else
        echo "Warning: Extra keybinds directory $EXTRA_KEYBINDS_SRC_DIR not found. Skipping keybind file copying."
    fi

    VPN_LINE="bindd = \$mainMod Alt, V, \$d toggle vpn, exec, \$scrPath/vpn.sh toggle # toggle vpn"
    WINDOW_SWITCHER_LINE="bindd = \$mainMod, TAB, \$d window switcher, exec, \$scrPath/windowSwitcher.sh # open window switcher"
    GAME_LAUNCHER_LINE="bindd = \$mainMod Shift, G, \$d open game launcher , exec, \$scrPath/gamelauncher.sh"
    GAME_LAUNCHER_MODIFIED="bindd = \$mainMod Shift, G, \$d open game launcher , exec, \$scrPath/gamelauncher.sh 5"
    ZOOM_LINE="bindd = \$mainMod Shift, Z, \$d toggle zoom, exec, hypr-zoom # toggle zoom"

    temp_file=$(mktemp)
    modified=false

    UTILITIES_START='$d=[$ut]'
    if ! grep -q "$UTILITIES_START" "$KEYBINDINGS_CONF"; then
        echo "Appending Utilities section to $KEYBINDINGS_CONF"
        echo -e "\n$UTILITIES_START\n$VPN_LINE\n$WINDOW_SWITCHER_LINE" >> "$KEYBINDINGS_CONF" || { echo "Error: Failed to append to $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        echo "DEBUG: Appended Utilities section with VPN and window switcher bindings" >> "$LOG_FILE"
        echo "MODIFIED_KEYBINDINGS: Added Utilities section with VPN and window switcher bindings" >> "$LOG_FILE"
        modified=true
    else
        if grep -q "bindd = \$mainMod Alt, V," "$KEYBINDINGS_CONF"; then
            echo "Replacing existing VPN binding in $KEYBINDINGS_CONF"
            sed -e "s|^bindd = \$mainMod Alt, V,.*|$VPN_LINE|" "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to modify $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            echo "DEBUG: Replaced VPN binding" >> "$LOG_FILE"
            echo "MODIFIED_KEYBINDINGS: Updated VPN binding" >> "$LOG_FILE"
            modified=true
        else
            echo "Appending VPN binding to Utilities section in $KEYBINDINGS_CONF"
            awk -v vpn_line="$VPN_LINE" -v util_start="$UTILITIES_START" '
                BEGIN { found_util=0 }
                $0 ~ util_start { found_util=1; print; next }
                found_util && /^[[:space:]]*$/ { print vpn_line "\n"; found_util=0; print; next }
                found_util && /^\$d=/ { print vpn_line "\n"; found_util=0; print; next }
                found_util && !/^[[:space:]]*$/ && !/^bind/ { print vpn_line "\n"; found_util=0; print; next }
                { print }
                END { if (found_util) print vpn_line }
            ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF with awk"; rm -f "$temp_file"; exit 1; }
            mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            echo "DEBUG: Appended VPN binding to Utilities section" >> "$LOG_FILE"
            echo "MODIFIED_KEYBINDINGS: Added VPN binding to Utilities section" >> "$LOG_FILE"
            modified=true
        fi

        temp_file=$(mktemp)
        if grep -q "bindd = \$mainMod, TAB," "$KEYBINDINGS_CONF"; then
            echo "Replacing existing window switcher binding in $KEYBINDINGS_CONF"
            sed -e "s|^bindd = \$mainMod, TAB,.*|$WINDOW_SWITCHER_LINE|" "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to modify $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            echo "DEBUG: Replaced window switcher binding" >> "$LOG_FILE"
            echo "MODIFIED_KEYBINDINGS: Updated window switcher binding" >> "$LOG_FILE"
            modified=true
        else
            echo "Appending window switcher binding to Utilities section in $KEYBINDINGS_CONF"
            awk -v ws_line="$WINDOW_SWITCHER_LINE" -v util_start="$UTILITIES_START" '
                BEGIN { found_util=0 }
                $0 ~ util_start { found_util=1; print; next }
                found_util && /^[[:space:]]*$/ { print ws_line "\n"; found_util=0; print; next }
                found_util && /^\$d=/ { print ws_line "\n"; found_util=0; print; next }
                found_util && !/^[[:space:]]*$/ && !/^bind/ { print ws_line "\n"; found_util=0; print; next }
                { print }
                END { if (found_util) print ws_line }
            ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF with awk"; rm -f "$temp_file"; exit 1; }
            mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            echo "DEBUG: Appended window switcher binding to Utilities section" >> "$LOG_FILE"
            echo "MODIFIED_KEYBINDINGS: Added window switcher binding to Utilities section" >> "$LOG_FILE"
            modified=true
        fi
    fi

    temp_file=$(mktemp)
    if grep -q "bindd = \$mainMod Shift, G," "$KEYBINDINGS_CONF"; then
        echo "Replacing existing game launcher binding in $KEYBINDINGS_CONF"
        sed -e "s|^bindd = \$mainMod Shift, G,.*|$GAME_LAUNCHER_MODIFIED|" "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to modify $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        echo "DEBUG: Replaced game launcher binding to gamelauncher.sh 5" >> "$LOG_FILE"
        echo "MODIFIED_KEYBINDINGS: Updated game launcher binding to gamelauncher.sh 5" >> "$LOG_FILE"
        modified=true
    else
        echo "Appending game launcher binding to $KEYBINDINGS_CONF"
        echo -e "\n$GAME_LAUNCHER_MODIFIED" >> "$KEYBINDINGS_CONF" || { echo "Error: Failed to append game launcher binding to $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        echo "DEBUG: Appended game launcher binding" >> "$LOG_FILE"
        echo "MODIFIED_KEYBINDINGS: Added game launcher binding" >> "$LOG_FILE"
        modified=true
    fi

    temp_file=$(mktemp)
    if grep -q "bindd = \$mainMod Shift, Z," "$KEYBINDINGS_CONF"; then
        echo "Replacing existing zoom binding in $KEYBINDINGS_CONF"
        sed -e "s|^bindd = \$mainMod Shift, Z,.*|$ZOOM_LINE|" "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to modify $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        echo "DEBUG: Replaced zoom binding" >> "$LOG_FILE"
        echo "MODIFIED_KEYBINDINGS: Updated zoom binding" >> "$LOG_FILE"
        modified=true
    else
        echo "Appending zoom binding to $KEYBINDINGS_CONF"
        echo -e "\n$ZOOM_LINE" >> "$KEYBINDINGS_CONF" || { echo "Error: Failed to append zoom binding to $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        echo "DEBUG: Appended zoom binding" >> "$LOG_FILE"
        echo "MODIFIED_KEYBINDINGS: Added zoom binding" >> "$LOG_FILE"
        modified=true
    fi

    rm -f "$temp_file"

    if [ "$modified" = true ]; then
        echo "Updated $KEYBINDINGS_CONF with necessary changes"
    fi
fi

if [ "$BROWSER_ONLY" = true ]; then
    BROWSER_SCRIPT="$SCRIPT_BASEDIR/browsers.sh"
    if [ ! -f "$BROWSER_SCRIPT" ]; then
        echo "Error: $BROWSER_SCRIPT not found."
        exit 1
    fi
    if [ "$NO_DYNAMIC" = true ]; then
        bash "$BROWSER_SCRIPT" nodynamic || { echo "Error: Failed to run browsers.sh"; exit 1; }
    else
        bash "$BROWSER_SCRIPT" || { echo "Error: Failed to run browsers.sh"; exit 1; }
    fi
    echo "CALLED_BROWSER_SCRIPT: browsers.sh with nodynamic=$NO_DYNAMIC" >> "$LOG_FILE"
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
        if awk '/^[[:space:]]*input[[:space:]]*{/,/^[[:space:]]*}/ {if ($0 ~ /^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*us,il/) found=1} END {exit !found}' "$USERPREFS_CONF" 2>/dev/null; then
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
        $SUDO_CMD pacman -S --noconfirm jq || { echo "Error: Failed to install jq"; exit 1; }
        echo "INSTALLED_PACKAGE: jq" >> "$LOG_FILE"
        echo "Installed jq"
    else
        echo "Skipping: jq already installed"
    fi
    copied_files=0
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
                    mv "$file" "$ICON_DIR/" || { echo "Error: Failed to copy $(basename "$file")"; exit 1; }
                    echo "Copied $(basename "$file") to $ICON_DIR/"
                    echo "MOVED_SVG: $(basename "$file") -> $target_file" >> "$LOG_FILE"
                    ((copied_files++))
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
                cp "$target_file" "$BACKUP_DIR/$(basename "$file")" || { echo "Error: Failed to backup $target_file"; exit 1; }
                mv "$file" "$ICON_DIR/" || { echo "Error: Failed to replace $(basename "$file")"; exit 1; }
                echo "Replaced $(basename "$file") in $ICON_DIR/"
                echo "REPLACED_SVG: $(basename "$file") -> $target_file" >> "$LOG_FILE"
                ((copied_files++))
            done
        else
            echo "Skipping replacement of non-identical files."
        fi
    fi
    [ "$copied_files" -eq 0 ] && [ -d "$ICONS_SRC_DIR" ] && echo "No new or replaced .svg files were copied."
fi

if [ "$BROWSER_ONLY" = false ] && [ "$KEYBIND_ONLY" = false ] && [ "$SUDOERS_ONLY" = false ] && [ "$KEYBOARD_ONLY" = false ]; then
    current_timestamp=$(date +%s)
    touch "$BACKUP_DIR/backup_session_$current_timestamp" || { echo "Error: Failed to create backup session marker"; exit 1; }
    echo "Created backup session marker for run at $current_timestamp"
fi

echo "Script execution completed successfully."
