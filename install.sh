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
DYNAMIC_BROWSER_SCRIPT="$SCRIPT_DIR/dynamic-browser.sh"

command -v pacman >/dev/null 2>&1 || { echo "Error: pacman not found. This script requires Arch Linux."; exit 1; }
ping -c 1 archlinux.org >/dev/null 2>&1 || { echo "Error: No internet connection."; exit 1; }

mkdir -p "$ICON_DIR" || { echo "Error: Failed to create $ICON_DIR"; exit 1; }
mkdir -p "$SCRIPT_DIR" || { echo "Error: Failed to create $SCRIPT_DIR"; exit 1; }
mkdir -p "$(dirname "$KEYBINDINGS_CONF")" || { echo "Error: Failed to create $(dirname "$KEYBINDINGS_CONF")"; exit 1; }
mkdir -p "$(dirname "$USERPREFS_CONF")" || { echo "Error: Failed to create $(dirname "$USERPREFS_CONF")"; exit 1; }
mkdir -p "$BACKUP_DIR" || { echo "Error: Failed to create $BACKUP_DIR"; exit 1; }

touch "$LOG_FILE" || { echo "Error: Failed to create $LOG_FILE"; exit 1; }
echo "[$(date)] New installation session" >> "$LOG_FILE"

if ! pacman -Qs jq >/dev/null 2>&1; then
    sudo pacman -S --noconfirm jq || { echo "Error: Failed to install jq"; exit 1; }
    echo "INSTALLED_PACKAGE: jq" >> "$LOG_FILE"
    echo "Installed jq"
else
    echo "Skipping: jq already installed"
fi

if [ -f "$DYNAMIC_BROWSER_SCRIPT" ]; then
    cp "$DYNAMIC_BROWSER_SCRIPT" "$BACKUP_DIR/dynamic-browser.sh.$(date +%s)" || { echo "Error: Failed to backup dynamic-browser.sh"; exit 1; }
    echo "REPLACED_SCRIPT: dynamic-browser.sh -> $DYNAMIC_BROWSER_SCRIPT" >> "$LOG_FILE"
    echo "Backed up and replaced dynamic-browser.sh"
else
    echo "CREATED_SCRIPT: dynamic-browser.sh -> $DYNAMIC_BROWSER_SCRIPT" >> "$LOG_FILE"
    echo "Created dynamic-browser.sh"
fi
cat << 'EOF' > "$DYNAMIC_BROWSER_SCRIPT"
#!/bin/bash

declare -A browsers=(
    ["firefox"]="firefox.desktop"
    ["brave"]="brave-browser.desktop"
    ["chromium"]="chromium.desktop"
    ["google-chrome"]="google-chrome.desktop"
    ["opera"]="opera.desktop"
    ["edge"]="microsoft-edge.desktop"
)

LOG_FILE="$HOME/.dynamic_browser.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

is_known_browser() {
    local process_name="$1"
    for browser in "${!browsers[@]}"; do
        if [[ "$process_name" == "$browser" ]]; then
            return 0
        fi
    done
    return 1
}

set_default_browser() {
    local desktop_file="$1"
    log_message "Setting default browser to $desktop_file"
    xdg-settings set default-web-browser "$desktop_file"
    if [[ $? -eq 0 ]]; then
        log_message "Successfully set $desktop_file as default browser"
    else
        log_message "Failed to set $desktop_file as default browser"
    fi
}

monitor_browsers() {
    log_message "Starting browser monitoring"
    
    while true; do
        active_window=$(hyprctl activewindow -j | jq -r '.class')
        if [[ -n "$active_window" ]]; then
            case "$active_window" in
                "firefox") process_name="firefox" ;;
                "Brave-browser") process_name="brave" ;;
                "chromium" | "Chromium") process_name="chromium" ;;
                "Google-chrome") process_name="google-chrome" ;;
                "opera" | "Opera") process_name="opera" ;;
                "microsoft-edge" | "Microsoft-edge") process_name="edge" ;;
                *) process_name="" ;;
            esac

            if [[ -n "$process_name" ]] && is_known_browser "$process_name"; then
                desktop_file="${browsers[$process_name]}"
                log_message "Detected browser: $process_name ($desktop_file)"
                set_default_browser "$desktop_file"
            fi
        fi
        sleep 1
    done
}

if [[ "$1" != "--bg" ]]; then
    log_message "Starting script in background"
    nohup "$0" --bg >> "$LOG_FILE" 2>&1 &
    exit 0
fi

monitor_browsers
EOF
chmod +x "$DYNAMIC_BROWSER_SCRIPT" || { echo "Error: Failed to make dynamic-browser.sh executable"; exit 1; }
echo "Made dynamic-browser.sh executable"

if [ -f "$USERPREFS_CONF" ]; then
    cp "$USERPREFS_CONF" "$BACKUP_DIR/userprefs.conf.$(date +%s)" || { echo "Error: Failed to backup $USERPREFS_CONF"; exit 1; }
    echo "BACKUP_CONFIG: $USERPREFS_CONF -> $BACKUP_DIR/userprefs.conf.$(date +%s)" >> "$LOG_FILE"
    echo "Backed up $USERPREFS_CONF"
fi
if ! grep -q "exec-once=$DYNAMIC_BROWSER_SCRIPT" "$USERPREFS_CONF" 2>/dev/null; then
    echo "exec-once=$DYNAMIC_BROWSER_SCRIPT" >> "$USERPREFS_CONF" || { echo "Error: Failed to add dynamic-browser.sh to $USERPREFS_CONF"; exit 1; }
    echo "MODIFIED_CONFIG: $USERPREFS_CONF -> Added exec-once=$DYNAMIC_BROWSER_SCRIPT" >> "$LOG_FILE"
    echo "Configured dynamic-browser.sh to run on login"
else
    echo "Skipping: dynamic-browser.sh already configured in $USERPREFS_CONF"
fi

moved_files=0
replace_files=()
for file in *.svg; do
    if [ -f "$file" ]; then
        target_file="$ICON_DIR/$(basename "$file")"
        if [ -f "$target_file" ]; then
            src_hash=$(sha256sum "$file" | cut -d' ' -f1)
            tgt_hash=$(sha256sum "$target_file" | cut -d' ' -f1)
            if [ "$src_hash" = "$tgt_hash" ]; then
                echo "Skipping $file: identical file already exists at $target_file"
            else
                echo "Found $file: same name but different content at $target_file"
                replace_files+=("$file")
            fi
        else
            mv "$file" "$ICON_DIR/" || { echo "Error: Failed to move $file"; exit 1; }
            echo "Moved $file to $ICON_DIR/"
            echo "MOVED_SVG: $file -> $target_file" >> "$LOG_FILE"
            ((moved_files++))
        fi
    else
        echo "Warning: No .svg files found in current directory, skipping."
        break
    fi
done

if [ ${#replace_files[@]} -gt 0 ]; then
    echo "The following files have the same name but different content in $ICON_DIR:"
    for file in "${replace_files[@]}"; do
        echo "- $file"
    done
    read -p "Replace these files in $ICON_DIR? [y/N]: " replace_choice
    if [[ "$replace_choice" =~ ^[Yy]$ ]]; then
        for file in "${replace_files[@]}"; do
            target_file="$ICON_DIR/$(basename "$file")"
            cp "$target_file" "$BACKUP_DIR/$(basename "$file").$(date +%s)" || { echo "Error: Failed to backup $target_file"; exit 1; }
            mv "$file" "$ICON_DIR/" || { echo "Error: Failed to replace $file"; exit 1; }
            echo "Replaced $file in $ICON_DIR/"
            echo "REPLACED_SVG: $file -> $target_file" >> "$LOG_FILE"
            ((moved_files++))
        done
    else
        echo "Skipping replacement of non-identical files."
    fi
fi
[ "$moved_files" -eq 0 ] && echo "No new or replaced .svg files were moved."

declare -A scripts
scripts["toggle-sleep.sh"]="\
#!/bin/bash
scrDir=\$(dirname \"\$(realpath \"\$0\")\") 
source \"\$scrDir/globalcontrol.sh\" || { echo \"Error: Failed to source globalcontrol.sh\"; exit 1; }
STATE_FILE=\"\$HOME/.config/hypr/sleep-inhibit.state\"
IDLE_DAEMON=\"hypridle\"
ICONS_DIR=\"\$HOME/.local/share/icons\"
inhibit_sleep() {
    pkill \"\$IDLE_DAEMON\"
    echo \"inhibited\" > \"\$STATE_FILE\"
    notify-send -a \"HyDE Alert\" -r 91190 -t 800 -i \"\${ICONS_DIR}/Wallbash-Icon/awake-toggle.svg\" \"Sleep Inhibited\"
}
restore_sleep() {
    pkill \"\$IDLE_DAEMON\"
    if [ \"\$IDLE_DAEMON\" = \"hypridle\" ]; then
        hypridle -c ~/.config/hypr/hypridle.conf &
    else
        swayidle -w \\
            timeout 300 'swaylock -f -c 000000' \\
            timeout 600 'hyprctl dispatch dpms off' \\
            resume 'hyprctl dispatch dpms on' \\
            timeout 900 'systemctl suspend' \\
            before-sleep 'swaylock -f -c 000000' &
    fi
    echo \"normal\" > \"\$STATE_FILE\"
    notify-send -a \"HyDE Alert\" -r 91190 -t 800 -i \"\${ICONS_DIR}/Wallbash-Icon/sleep_toggle.svg\" \"Sleep Restored\"
}
if [ -f \"\$STATE_FILE\" ] && [ \"\$(cat \"\$STATE_FILE\")\" = \"inhibited\" ]; then
    restore_sleep
else
    inhibit_sleep
fi
"
scripts["vpn-toggle.sh"]="\
#!/bin/bash
if [ \"\$1\" = \"change\" ]; then
    notify-send -a \"HyDE Alert\" -r 91191 -t 800 \"VPN Server Changed\"
else
    notify-send -a \"HyDE Alert\" -r 91191 -t 800 \"VPN Toggled\"
fi
"

for script_name in "${!scripts[@]}"; do
    script_path="$SCRIPT_DIR/$script_name"
    if [ -f "$script_path" ]; then
        echo "Warning: $script_path already exists."
        temp_file=$(mktemp)
        echo "${scripts[$script_name]}" > "$temp_file"
        src_hash=$(sha256sum "$temp_file" | cut -d' ' -f1)
        tgt_hash=$(sha256sum "$script_path" | cut -d' ' -f1)
        rm -f "$temp_file"
        if [ "$src_hash" = "$tgt_hash" ]; then
            echo "$script_path has identical content, checking permissions."
            [ -x "$script_path" ] || { chmod +x "$script_path" || { echo "Error: Failed to make $script_path executable"; exit 1; }; echo "Made $script_path executable."; }
        else
            echo "$script_path has different content."
            read -p "Replace $script_path with new content? [y/N]: " replace_script
            if [[ "$replace_script" =~ ^[Yy]$ ]]; then
                cp "$script_path" "$BACKUP_DIR/$script_name.$(date +%s)" || { echo "Error: Failed to backup $script_path"; exit 1; }
                echo "${scripts[$script_name]}" > "$script_path" || { echo "Error: Failed to write $script_path"; exit 1; }
                chmod +x "$script_path" || { echo "Error: Failed to make $script_path executable"; exit 1; }
                echo "Replaced and made $script_path executable."
                echo "REPLACED_SCRIPT: $script_name -> $script_path" >> "$LOG_FILE"
            else
                echo "Skipping replacement of $script_path."
                [ -x "$script_path" ] || { chmod +x "$script_path" || { echo "Error: Failed to make $script_path executable"; exit 1; }; echo "Made $script_path executable."; }
            fi
        fi
    else
        echo "${scripts[$script_name]}" > "$script_path" || { echo "Error: Failed to create $script_path"; exit 1; }
        chmod +x "$script_path" || { echo "Error: Failed to make $script_path executable"; exit 1; }
        echo "Created and made $script_path executable."
        echo "CREATED_SCRIPT: $script_name -> $script_path" >> "$LOG_FILE"
    fi
    ls -l "$script_path"
done

if [ ! -f "$KEYBINDINGS_CONF" ]; then
    echo "Error: $KEYBINDINGS_CONF does not exist. Creating an empty file."
    touch "$KEYBINDINGS_CONF" || { echo "Error: Failed to create $KEYBINDINGS_CONF"; exit 1; }
fi

[ ! -w "$KEYBINDINGS_CONF" ] && { echo "Error: $KEYBINDINGS_CONF is not writable."; exit 1; }

SLEEP_BIND_LINE="bindd = \$mainMod, I, \$d toggle sleep inhibition , exec, \$scrPath/toggle-sleep.sh # toggle sleep inhibition"
VPN_LINES="\
\$d=[\$ut|Vpn Commands]
bindd = \$mainMod Alt, V, \$d toggle vpn , exec, \$scrPath/vpn-toggle.sh # toggle vpn
bindd = \$mainMod Alt, C, \$d change vpn location , exec, \$scrPath/vpn-toggle.sh change # change vpn server"
if grep -Fx "$SLEEP_BIND_LINE" "$KEYBINDINGS_CONF" > /dev/null && grep -F "$VPN_LINES" "$KEYBINDINGS_CONF" > /dev/null; then
    echo "Skipping: Sleep and VPN bindings already exist in $KEYBINDINGS_CONF"
else
    UTILITIES_START='$d=[$ut]'
    SCREEN_CAPTURE_START='$d=[$ut|Screen Capture]'
    temp_file=$(mktemp)
    cp "$KEYBINDINGS_CONF" "$BACKUP_DIR/keybindings.conf.$(date +%s)" || { echo "Error: Failed to backup $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
    if ! grep -q "$UTILITIES_START" "$KEYBINDINGS_CONF"; then
        echo "Warning: Utilities section ($UTILITIES_START) not found in $KEYBINDINGS_CONF. Appending at the end."
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
                $0 ~ util_start { found_util=1 }
                !found_util { print }
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
        cp "$USERPREFS_CONF" "$BACKUP_DIR/userprefs.conf.$(date +%s)" || { echo "Error: Failed to backup $USERPREFS_CONF"; rm -f "$temp_file"; exit 1; }
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
                if pgrep firefox >/dev/null; then
                    echo "Warning: Firefox is running. Please close Firefox to modify autoscrolling settings. Skipping."
                else
                    if grep -q 'user_pref("general.autoScroll", true)' "$FIREFOX_PREFS_FILE"; then
                        echo "Skipping: Firefox autoscrolling is already enabled."
                    else
                        temp_file=$(mktemp)
                        cp "$FIREFOX_PREFS_FILE" "$BACKUP_DIR/prefs.js.$(date +%s)" || { echo "Warning: Failed to backup $FIREFOX_PREFS_FILE. Skipping autoscrolling."; rm -f "$temp_file"; continue; }
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

echo "Script execution completed successfully."
