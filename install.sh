mv sleep_toggle.svg /home/kot/.local/share/icons/Wallbash-Icon/sleep_toggle.svg
mv awake-toggle.svg /home/kot/.local/share/icons/Wallbash-Icon/awake-toggle.svg

TOGGLE_SLEEP="/home/$USER/.local/lib/hyde/toggle-sleep.sh"
cat > "TOGGLE_SLEEP" << 'EOF'
#!/bin/bash
# File: ~/.config/hypr/scripts/toggle-sleep.sh

scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
source "$scrDir/globalcontrol.sh"

STATE_FILE="$HOME/.config/hypr/sleep-inhibit.state"
IDLE_DAEMON="hypridle" # Change to "swayidle" if you use swayidle

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

chmod +x "TOGGLE_SLEEP"
echo "Created toggle sleep script at $TOGGLE_SLEEP"
