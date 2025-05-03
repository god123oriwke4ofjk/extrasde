#!/bin/bash
scrDir=$(dirname "$(realpath "$0")")
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
