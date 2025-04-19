#!/bin/bash

USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo "Error: Could not determine username."; exit 1; }

ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"

mkdir -p "$ICON_DIR" || { echo "Error: Failed to create $ICON_DIR"; exit 1; }
mkdir -p "$SCRIPT_DIR" || { echo "Error: Failed to create $SCRIPT_DIR"; exit 1; }
mkdir -p "$(dirname "$KEYBINDINGS_CONF")" || { echo "Error: Failed to create $(dirname "$KEYBINDINGS_CONF")"; exit 1; }
mkdir -p "$BACKUP_DIR" || { echo "Error: Failed to create $BACKUP_DIR"; exit 1; }

touch "$LOG_FILE" || { echo "Error: Failed to create $LOG_FILE"; exit 1; }
echo "[$(date)] New installation session" >> "$LOG_FILE"

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
# File: ~/.local/lib/hyde/toggle-sleep.sh

scrDir=\$(dirname \"\$(realpath \"\$0\")\") 
# shellcheck disable=SC1091
source \"\$scrDir/globalcontrol.sh\" || { echo \"Error: Failed to source globalcontrol.sh\"; exit 1; }

STATE_FILE=\"\$HOME/.config/hypr/sleep-inhibit.state\"
IDLE_DAEMON=\"hypridle\" # Change to \"swayidle\" if you use swayidle
ICONS_DIR=\"\$HOME/.local/share/icons\" # Define ICONS_DIR explicitly

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

BIND_LINE="bindd = \$mainMod, I, \$d toggle sleep inhibition , exec, \$scrPath/toggle-sleep.sh # toggle sleep inhibition"
if grep -Fx "$BIND_LINE" "$KEYBINDINGS_CONF" > /dev/null; then
    echo "Skipping: '$BIND_LINE' already exists in $KEYBINDINGS_CONF"
else
    UTILITIES_START='$d=[$ut]'
    SCREEN_CAPTURE_START='$d=[$ut|Screen Capture]'
    temp_file=$(mktemp)
    cp "$KEYBINDINGS_CONF" "$BACKUP_DIR/keybindings.conf.$(date +%s)" || { echo "Error: Failed to backup $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
    if ! grep -q "$UTILITIES_START" "$KEYBINDINGS_CONF"; then
        echo "Warning: Utilities section ($UTILITIES_START) not found in $KEYBINDINGS_CONF. Appending at the end."
        echo -e "\n$UTILITIES_START\n$BIND_LINE" >> "$KEYBINDINGS_CONF" || { echo "Error: Failed to append to $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
    else
        if grep -q "$SCREEN_CAPTURE_START" "$KEYBINDINGS_CONF"; then
            awk -v bind_line="$BIND_LINE" -v util_start="$UTILITIES_START" -v sc_start="$SCREEN_CAPTURE_START" '
                BEGIN { found_util=0 }
                $0 ~ util_start { found_util=1 }
                $0 ~ sc_start && found_util { print bind_line "\n"; found_util=0 }
                { print }
            ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        else
            awk -v bind_line="$BIND_LINE" -v util_start="$UTILITIES_START" '
                BEGIN { found_util=0 }
                $0 ~ util_start { found_util=1 }
                !found_util { print }
                found_util && !/^[[:space:]]*$/ && !/^\$/ && !/^bind/ { print bind_line "\n"; found_util=0; print; next }
                found_util && /^$/ { print bind_line "\n"; found_util=0 }
                { print }
            ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        fi
        mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        echo "Added '$BIND_LINE' to $KEYBINDINGS_CONF"
        echo "MODIFIED_KEYBINDINGS: Added bindd line" >> "$LOG_FILE"
    fi
fi

echo "Script execution completed successfully."
