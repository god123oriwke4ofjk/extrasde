#!/bin/bash

# Ensure USER is set
USER=${USER:-$(whoami)}
if [ -z "$USER" ]; then
    echo "Error: Could not determine username."
    exit 1
fi

# Define paths
ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
TOGGLE_SLEEP="/home/$USER/.local/lib/hyde/toggle-sleep.sh"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"

# Create directories if they don't exist
mkdir -p "$ICON_DIR" || { echo "Error: Failed to create $ICON_DIR"; exit 1; }
mkdir -p "$(dirname "$TOGGLE_SLEEP")" || { echo "Error: Failed to create $(dirname "$TOGGLE_SLEEP")"; exit 1; }
mkdir -p "$(dirname "$KEYBINDINGS_CONF")" || { echo "Error: Failed to create $(dirname "$KEYBINDINGS_CONF")"; exit 1; }

# Move all .svg files from the current directory to ICON_DIR, skipping if already present
moved_files=0
for file in *.svg; do
    if [ -f "$file" ]; then
        target_file="$ICON_DIR/$(basename "$file")"
        if [ -f "$target_file" ]; then
            echo "Skipping $file: already exists at $target_file"
        else
            mv "$file" "$ICON_DIR/" || { echo "Error: Failed to move $file"; exit 1; }
            echo "Moved $file to $ICON_DIR/"
            ((moved_files++))
        fi
    else
        echo "Warning: No .svg files found in current directory, skipping."
        break
    fi
done
[ "$moved_files" -eq 0 ] && echo "No new .svg files were moved."

# Check if toggle-sleep.sh already exists
if [ -f "$TOGGLE_SLEEP" ]; then
    echo "Warning: $TOGGLE_SLEEP already exists."
    if [ -x "$TOGGLE_SLEEP" ]; then
        echo "$TOGGLE_SLEEP is already executable, skipping creation."
    else
        echo "$TOGGLE_SLEEP exists but is not executable, making it executable."
        chmod +x "$TOGGLE_SLEEP" || { echo "Error: Failed to make $TOGGLE_SLEEP executable"; exit 1; }
    fi
else
    cat > "$TOGGLE_SLEEP" << 'EOF'
#!/bin/bash
# File: ~/.local/lib/hyde/toggle-sleep.sh

scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
source "$scrDir/globalcontrol.sh" || { echo "Error: Failed to source globalcontrol.sh"; exit 1; }

STATE_FILE="$HOME/.config/hypr/sleep-inhibit.state"
IDLE_DAEMON="hypridle" # Change to "swayidle" if you use swayidle
ICONS_DIR="$HOME/.local/share/icons" # Define ICONS_DIR explicitly

inhibit_sleep() {
    pkill "$IDLE_DAEMON"
    echo "inhibited" > "$STATE_FILE"
    notify-send -a "HyDE Alert" -r 91190 -t 800 -i "${ICONS_DIR}/Wallbash-Icon/awake-toggle.svg" "Sleep Inhibited"
}

restore_sleep() {
    pkill "$IDLE_DAEMON"
    if [ "$IDLE_DAEMON" = "hypridle" ]; then
        hypridle -c ~/.config/hypr/hypridle.conf &
    else
        swayidle -w \
            timeout 300 'swaylock -f -c 000000' \
            timeout 600 'hyprctl dispatch dpms off' \
            resume 'hyprctl dispatch dpms on' \
            timeout 900 'systemctl suspend' \
            before-sleep 'swaylock -f -c 000000' &
    fi
    echo "normal" > "$STATE_FILE"
    notify-send -a "HyDE Alert" -r 91190 -t 800 -i "${ICONS_DIR}/Wallbash-Icon/sleep_toggle.svg" "Sleep Restored"
}

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "inhibited" ]; then
    restore_sleep
else
    inhibit_sleep
fi
EOF

    if [ ! -f "$TOGGLE_SLEEP" ]; then
        echo "Error: Failed to create $TOGGLE_SLEEP"
        exit 1
    fi

    chmod +x "$TOGGLE_SLEEP" || { echo "Error: Failed to make $TOGGLE_SLEEP executable"; exit 1; }
    echo "Created toggle sleep script at $TOGGLE_SLEEP"
fi

ls -l "$TOGGLE_SLEEP"

if [ ! -f "$KEYBINDINGS_CONF" ]; then
    echo "Error: $KEYBINDINGS_CONF does not exist. Creating an empty file."
    touch "$KEYBINDINGS_CONF" || { echo "Error: Failed to create $KEYBINDINGS_CONF"; exit 1; }
fi

if [ ! -w "$KEYBINDINGS_CONF" ]; then
    echo "Error: $KEYBINDINGS_CONF is not writable."
    exit 1
fi

BIND_LINE="bindd = \$mainMod, I, \$d toggle sleep inhibition , exec, \$scrPath/toggle-sleep.sh # toggle sleep inhibition"
if grep -Fx "$BIND_LINE" "$KEYBINDINGS_CONF" > /dev/null; then
    echo "Skipping: '$BIND_LINE' already exists in $KEYBINDINGS_CONF"
else
    UTILITIES_START='$d=[$ut]'
    SCREEN_CAPTURE_START='$d=[$ut|Screen Capture]'
    temp_file=$(mktemp)

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
                !found at the end."
        echo -e "\n$UTILITIES_START\n$BIND_LINE" >> "$KEYBINDINGS_CONF" || { echo "Error: Failed to append to $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
    else
        # Check if Screen Capture section exists to determine insertion point
        if grep -q "$SCREEN_CAPTURE_START" "$KEYBINDINGS_CONF"; then
            # Insert before Screen Capture section
            awk -v bind_line="$BIND_LINE" -v util_start="$UTILITIES_START" -v sc_start="$SCREEN_CAPTURE_START" '
                BEGIN { found_util=0 }
                $0 ~ util_start { found_util=1 }
                $0 ~ sc_start && found_util { print bind_line "\n"; found_util=0 }
                { print }
            ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        else
            # Append to the end of Utilities section
            awk -v bind_line="$BIND_LINE" -v util_start="$UTILITIES_START" '
                BEGIN { found_util=0 }
                $0 ~ util_start { found_util=1 }
                !found_util { print }
                found_util && !/^[[:space:]]*$/ && !/^\$/ && !/^bind/ { print bind_line "\n"; found_util=0; print; next }
                found_util && /^$/ { print bind_line "\n"; found_util=0 }
                { print }
            ' "$KEYBINDINGS_CONF" > "$temp_file" || { echo "Error: Failed to process $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        fi

        # Replace the original file with the modified one
        mv "$temp_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to update $KEYBINDINGS_CONF"; rm -f "$temp_file"; exit 1; }
        echo "Added '$BIND_LINE' to $KEYBINDINGS_CONF"
    fi
fi

echo "Script execution completed successfully."
