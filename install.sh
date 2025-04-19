#!/bin/bash

USER=${USER:-$(whoami)}
if [ -z "$USER" ]; then
    echo "Error: Could not determine username."
    exit 1
fi

ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
TOGGLE_SLEEP="/home/$USER/.local/lib/hyde/toggle-sleep.sh"

mkdir -p "$ICON_DIR" || { echo "Error: Failed to create $ICON_DIR"; exit 1; }
mkdir -p "$(dirname "$TOGGLE_SLEEP")" || { echo "Error: Failed to create $(dirname "$TOGGLE_SLEEP")"; exit 1; }

for file in *.svg; do
    if [ -f "$file" ]; then
        mv "$file" "$ICON_DIR/" || { echo "Error: Failed to move $file"; exit 1; }
    else
        echo "Warning: No .svg files found in current directory, skipping."
        break
    fi
done

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
ls -l "$TOGGLE_SLEEP"
