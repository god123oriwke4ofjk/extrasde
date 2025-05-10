#!/usr/bin/env bash

UPDATE_SCRIPT="./update.sh"
LOGFILE="/tmp/update-log-$$.txt"
> "$LOGFILE"

get_greeting() {
    HOUR=$(date +%H)
    USER=$(whoami)

    if [ "$HOUR" -ge 5 ] && [ "$HOUR" -lt 12 ]; then
        echo "Good morning, $USER!"
    elif [ "$HOUR" -ge 12 ] && [ "$HOUR" -lt 18 ]; then
        echo "Good afternoon, $USER!"
    else
        echo "Good evening, $USER!"
    fi
}

prompt_password() {
    PASSWORD=$(yad --center --title="Authentication Required" \
        --entry --hide-text \
        --text="Please enter your password:" \
        --button="OK:0" --button="Cancel:1")

    if [ $? -ne 0 ]; then
        return 1
    fi

    sudo -K
    echo "$PASSWORD" | sudo -S true 2>/dev/null
    if [ $? -ne 0 ]; then
        yad --error --title="Error" --text="Incorrect password!"
        return 1
    fi
    return 0
}

launch_updater_ui() {
    BASE_TEXT="<b>Updating... please do not shut down your computer.</b>"

    OUTPUT_PID=""
    OUTPUT_VISIBLE=false

    (
        bash "$UPDATE_SCRIPT" >>"$LOGFILE" 2>&1
        echo DONE >> "$LOGFILE"
    ) &

    while true; do
        BUTTON=$(yad --center --title="System Update" \
            --text="$BASE_TEXT" \
            --width=400 --height=150 \
            --on-top \
            --button="Show Output:100" --button="Hide Output:101" --button="Exit:102")

        case $BUTTON in
            100)
                if [ -z "$OUTPUT_PID" ] || ! ps -p $OUTPUT_PID > /dev/null 2>&1; then
                    ( tail -n 100 -f "$LOGFILE" | yad --title="Update Output" \
                        --text-info \
                        --width=600 --height=400 \
                        --center \
                        --no-buttons \
                        --fontname=monospace \
                        --on-top \
                        --skip-taskbar \
                        --borders=10 \
                        --window-icon=system-run ) &
                    OUTPUT_PID=$!
                fi
                ;;
            101)
                if [ -n "$OUTPUT_PID" ]; then
                    kill $OUTPUT_PID 2>/dev/null
                    OUTPUT_PID=""
                fi
                ;;
            102)
                return
                ;;
        esac

        grep -q DONE "$LOGFILE"
        if [ $? -eq 0 ]; then
            [ -n "$OUTPUT_PID" ] && kill $OUTPUT_PID 2>/dev/null
            break
        fi
        sleep 1
    done

    post_update_prompt
}

post_update_prompt() {
    CHOICE=$(yad --center --title="Update Finished" \
        --text="Update complete.\n\nIt is recommended to reboot your computer." \
        --button="Reboot now:0" --button="Reboot later:1")
    if [ "$?" -eq 0 ]; then
        systemctl reboot
    fi
}

main_menu() {
    GREETING=$(get_greeting)
    yad --center --title="Greeting" \
        --text="$GREETING" \
        --button="Update:0" --button="Exit:1"
}

# Run flow
while true; do
    main_menu
    [ $? -ne 0 ] && break

    if prompt_password; then
        launch_updater_ui
        break
    fi
done
