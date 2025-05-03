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
SCRIPT_BASEDIR="$(dirname "$(realpath "$0")")"
ICONS_SRC_DIR="$SCRIPT_BASEDIR/icons"
CONFIG_DIR="$SCRIPT_BASEDIR/config"
KEYBINDS_SRC_DIR="$CONFIG_DIR/keybinds"
SUDOERS_FILE="/etc/sudoers.d/hyde-vpn"

# Prompt for sudo password upfront
echo "This script requires sudo privileges to install dependencies and configure sudoers."
sudo -v || { echo "Error: Sudo authentication failed."; exit 1; }

# Validate system requirements
command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found. This script requires Arch Linux."; exit 1; }
ping -c 1 archlinux.org >/dev/null 2>&1 || { echo "Error: No internet connection."; exit 1; }

# Create necessary directories
mkdir -p "$ICON_DIR" || { echo "Error: Failed to create $ICON_DIR"; exit 1; }
mkdir -p "$SCRIPT_DIR" || { echo "Error: Failed to create $SCRIPT_DIR"; exit 1; }
mkdir -p "$(dirname "$KEYBINDINGS_CONF")" || { echo "Error: Failed to create $(dirname "$KEYBINDINGS_CONF")"; exit 1; }
mkdir -p "$(dirname "$USERPREFS_CONF")" || { echo "Error: Failed to create $(dirname "$USERPREFS_CONF")"; exit 1; }
mkdir -p "$BACKUP_DIR" || { echo "Error: Failed to create $BACKUP_DIR"; exit 1; }

# Initialize log file
touch "$LOG_FILE" || { echo "Error: Failed to create $LOG_FILE"; exit 1; }
echo "[$(date)] New installation session" >> "$LOG_FILE"

# Configure sudoers for openvpn and kill
if [ ! -f "$SUDOERS_FILE" ]; then
    echo "Configuring sudoers to allow NOPASSWD for openvpn and kill..."
    sudo bash -c "cat > '$SUDOERS_FILE' << 'EOF'
$USER ALL=(ALL) NOPASSWD: /usr/bin/openvpn
$USER ALL=(ALL) NOPASSWD: /bin/kill
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
    if ! grep -q "$USER ALL=(ALL) NOPASSWD: /usr/bin/openvpn" "$SUDOERS_FILE" || ! grep -q "$USER ALL=(ALL) NOPASSWD: /bin/kill" "$SUDOERS_FILE"; then
        echo "Updating existing sudoers file..."
        sudo cp "$SUDOERS_FILE" "$BACKUP_DIR/sudoers_hyde-vpn.$current_timestamp" || { echo "Error: Failed to backup $SUDOERS_FILE"; exit 1; }
        sudo bash -c "cat > '$SUDOERS_FILE' << 'EOF'
$USER ALL=(ALL) NOPASSWD: /usr/bin/openvpn
$USER ALL=(ALL) NOPASSWD: /bin/kill
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

# Delete backups from the previous run
current_timestamp=$(date +%s)
if [ -d "$BACKUP_DIR" ]; then
    # Find the second-most-recent backup session marker
    prev_backup=$(ls -t "$BACKUP_DIR/backup_session_"* 2>/dev/null | head -n2 | tail -n1)
    if [ -n "$prev_backup" ]; then
        prev_timestamp=$(basename "$prev_backup" | sed 's/backup_session_//')
        echo "Removing backups from previous run ($prev_timestamp)..."
        # Delete backups with the previous timestamp
        find "$BACKUP_DIR" -type f -name "*.$prev_timestamp" -delete || { echo "Warning: Failed to delete some previous backups"; }
        # Delete the previous session marker
        rm -f "$prev_backup" || { echo "Warning: Failed to delete previous backup session marker"; }
        echo "Removed previous backups."
    else
        echo "No previous backup session found. Skipping cleanup."
    fi
fi

# Install jq if not present
if ! pacman -Qs jq >/dev/null 2>&1; then
    sudo pacman -S --noconfirm jq || { echo "Error: Failed to install jq"; exit 1; }
    echo "INSTALLED_PACKAGE: jq" >> "$LOG_FILE"
    echo "Installed jq"
else
    echo "Skipping: jq already installed"
fi

# Install scripts from config/
declare -A scripts
scripts["dynamic-browser.sh"]="$CONFIG_DIR/dynamic_browser.sh"
scripts["toggle-sleep.sh"]="$KEYBINDS_SRC_DIR/toggle-sleep.sh"
scripts["vpnScript.sh"]="$KEYBINDS_SRC_DIR/vpnScript.sh"

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

# Configure dynamic-browser.sh in userprefs.conf
if [ -f "$USERPREFS_CONF" ]; then
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

# Move .svg files from icons/ directory
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

# Configure keybindings
if [ ! -f "$KEYBINDINGS_CONF" ]; then
    echo "Error: $KEYBINDINGS_CONF does not exist. Creating an empty file."
    touch "$KEYBINDINGS_CONF" || { echo "Error: Failed to create $KEYBINDINGS_CONF"; exit 1; }
fi

[ ! -w "$KEYBINDINGS_CONF" ] && { echo "Error: $KEYBINDINGS_CONF is not writable."; exit 1; }

# Define keybinding lines
SLEEP_BIND_LINE="bindd = \$mainMod, I, \$d toggle sleep inhibition , exec, \$scrPath/toggle-sleep.sh # toggle sleep inhibition"
VPN_LINES="\
\$d=[\$ut|Vpn Commands]
bindd = \$mainMod Alt, V, \$d toggle vpn , exec, \$scrPath/vpnScript.sh # toggle vpn
bindd = \$mainMod Alt, C, \$d change vpn location , exec, \$scrPath/vpnScript.sh change # change vpn server"
APP_LINES="\
\$l=Launcher
\$d=[\$l|Apps]
bindd = \$mainMod, T, \$d terminal emulator , exec, \$TERMINAL
bindd = \$mainMod, E, \$d file explorer , exec, \$EXPLORER
bindd = \$mainMod, C, \$d text editor , exec, \$EDITOR
bindd = \$mainMod, B, \$d web browser , exec, \$BROWSER
bindd = Control Shift, Escape, \$d system monitor , exec, \$scrPath/sysmonlaunch.sh
bindd = \$mainMod, R, \$d screen recorder , exec, flatpak run com.dec05eba.gpu_screen_recorder # launch screen recorder"

# Check if all keybindings already exist
if grep -Fx "$SLEEP_BIND_LINE" "$KEYBINDINGS_CONF" > /dev/null && \
   grep -F "$VPN_LINES" "$KEYBINDINGS_CONF" > /dev/null && \
   grep -F "bindd = \$mainMod, R, \$d screen recorder , exec, flatpak run com.dec05eba.gpu_screen_recorder # launch screen recorder" "$KEYBINDINGS_CONF" > /dev/null; then
    echo "Skipping: Sleep, VPN, and App bindings (including screen recorder) already exist in $KEYBINDINGS_CONF"
else
    UTILITIES_START='$d=[$ut]'
    SCREEN_CAPTURE_START='$d=[$ut|Screen Capture]'
    LAUNCHER_START='$l=Launcher'
    APPS_START='$d=[$l|Apps]'
    temp_file=$(mktemp)
    cp "$KEYBINDINGS_CONF" "$BACKUP_DIR/keybindings.conf.$current_timestamp" || { echo "Error: Failed to backup $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
    echo "BACKUP_CONFIG: $KEYBINDINGS_CONF -> $BACKUP_DIR/keybindings.conf.$current_timestamp" >> "$LOG_FILE"

    # If Launcher section doesn't exist, append all bindings
    if ! grep -q "$LAUNCHER_START" "$KEYBINDINGS_CONF"; then
        echo "Warning: Launcher section ($LAUNCHER_START) not found in $KEYBINDINGS_CONF. Appending all bindings."
        if ! grep -q "$UTILITIES_START" "$KEYBINDINGS_CONF"; then
            echo -e "\n$UTILITIES_START\n$SLEEP_BIND_LINE\n$VPN_LINES\n\n$APP_LINES" >> "$KEYBINDINGS_CONF" || { echo "Error: Failed to append to $KEY jadings_CONF"; rm -f "$temp_file"; exit 1; }
        else
            echo -e "\n$APP_LINES" >> "$KEYBINDINGS_CONF" || { echo "Error: Failed to append to $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        fi
        echo "Added sleep, VPN, and app bindings (including screen recorder) to $KEYBINDINGS_CONF"
        echo "MODIFIED_KEYBINDINGS: Added sleep, VPN, and app bindings" >> "$LOG_FILE"
    else
        # Launcher section exists, check for Apps subsection
        if ! grep -q "$APPS_START" "$KEYBINDINGS_CONF"; then
            # Apps subsection doesn't exist, add it under Launcher
            awk -v app_lines="$APP_LINES" -v launcher_start="$LAUNCHER_START" '
                BEGIN { found_launcher=0 }
                $0 ~ launcher_start { found_launcher=1; print; next }
                found_launcher && !/^[[:space:]]*$/ && !/^\$/ && !/^bind/ { print app_lines "\n"; found_launcher=0 }
                found_launcher && /^$/ { print app_lines "\n"; found_launcher=0 }
                { print }
            ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            echo "Added app bindings (including screen recorder) to $KEYBINDINGS_CONF"
            echo "MODIFIED_KEYBINDINGS: Added app bindings" >> "$LOG_FILE"
        else
            # Apps subsection exists, check if screen recorder binding is missing
            if ! grep -F "bindd = \$mainMod, R, \$d screen recorder , exec, flatpak run com.dec05eba.gpu_screen_recorder # launch screen recorder" "$KEYBINDINGS_CONF" > /dev/null; then
                awk -v app_line="bindd = \$mainMod, R, \$d screen recorder , exec, flatpak run com.dec05eba.gpu_screen_recorder # launch screen recorder" -v apps_start="$APPS_START" '
                    BEGIN { found_apps=0 }
                    $0 ~ apps_start { found_apps=1; print; next }
                    found_apps && !/^[[:space:]]*$/ && !/^\$/ && !/^bind/ { print app_line "\n"; found_apps=0 }
                    found_apps && /^$/ { print app_line "\n"; found_apps=0 }
                    { print }
                ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
                mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
                echo "Added screen recorder binding to $KEYBINDINGS_CONF"
                echo "MODIFIED_KEYBINDINGS: Added screen recorder binding" >> "$LOG_FILE"
            fi
        fi

        # Ensure sleep and VPN bindings are added if missing
        if ! grep -Fx "$SLEEP_BIND_LINE" "$KEYBINDINGS_CONF" > /dev/null || ! grep -F "$VPN_LINES" "$KEYBINDINGS_CONF" > /dev/null; then
            temp_file=$(mktemp)
            cp "$KEYBINDINGS_CONF" "$BACKUP_DIR/keybindings.conf.$current_timestamp" || { echo "Error: Failed to backup $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            if ! grep -q "$UTILITIES_START" "$KEYBINDINGS_CONF"; then
                echo -e "\n$UTILITIES_START\n$SLEEP_BIND_LINE\n$VPN_LINES" >> "$KEYBINDINGS_CONF" || { echo "Error: Failed to append to $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
            else
                if grep -q "$SCREEN_CAPTURE_START" "$KEYBINDINGS_CONF"; then
                    awk -v sleep_line="$SLEEP_BIND_LINE" -v vpn_lines="$VPN_LINES" -v util_start="$UTILITIES_START" -v sc_start="$SCREEN_CAPTURE_START" '
                        BEGIN { found_util=0; added=0 }
                        $0 ~ util_start { found_util=1 }
                        $0 ~ sleep_line && found_util && !added { print; print vpn_lines; added=1; next }
                        $0 ~ sc_start && found_util && !added { print vpn_lines "\n"; added=1 }
                        { print }
                    ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
                else
                    awk -v sleep_line="$SLEEP_BIND_LINE" -v vpn_lines="$VPN_LINES" -v util_start="$UTILITIES_START" '
                        BEGIN { found_util=0; added=0 }
                        !found_util { print }
                        $0 ~ util_start { found_util=1 }
                        found_util && $0 ~ sleep_line && !added { print; print vpn_lines; added=1; next }
                        found_util && !/^[[:space:]]*$/ && !/^\$/ && !/^bind/ && !added { print vpn_lines "\n"; added=1; print; next }
                        found_util && /^$/ && !added { print vpn_lines "\n"; added=1 }
                        { print }
                    ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
                fi
                mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
                echo "Added sleep and VPN bindings to $KEYBINDINGS_CONF"
                echo "MODIFIED_KEYBINDINGS: Added sleep and VPN bindings" >> "$LOG_FILE"
            fi
        fi
    fi
fi

# Configure userprefs.conf for kb_layout
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

# Configure Firefox autoscrolling
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
                    pkill -9 firefox 2>/dev/null
                    temp_file=$(mktemp)
                    cp "$FIREFOX_PREFS_FILE" "$BACKUP_DIR/prefs.js.$current_timestamp" || { echo "Warning: Failed to backup $FIREFOX_PREFS_FILE. Skipping autoscrolling."; rm -f "$temp_file"; continue; }
                    if grep -q 'user_pref("general.autoScroll", false)' "$FIREFOX_PREFS_FILE"; then
                        sed 's/user_pref("general.autoScroll", false)/user_pref("general.autoScroll", true)/' "$FIREFOX_PREFS_FILE" > "$temp_file" || { echo "Warning: Failed to modify $FIREFOX_PREFS_FILE. Skipping autoscrolling."; rm -f "$temp_file"; continue; }
                    else
                        echo 'user_pref("general.autoScroll", true);' >> "$temp_file" || { echo "Warning: Failed to append to $FIREFOX_PREFS_FILE. Skipping autoscrolling."; rm -f "$temp_file"; continue; }
                        cat "$FIREFOX_PREFS_FILE" >> "$temp_file"
                    fi
                    mv "$temp_file" "$FIREFOX_PREFS_FILE" || { echo "Warning: Failed to update $FIREFOX_PREFS_FILE. Skipping autoscrolling."; rm -f "$temp_file"; continue; }
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

# Create backup session marker
touch "$BACKUP_DIR/backup_session_$current_timestamp" || { echo "Error: Failed to create backup session marker"; exit 1; }
echo "Created backup session marker for run at $current_timestamp"

echo "Script execution completed successfully."
