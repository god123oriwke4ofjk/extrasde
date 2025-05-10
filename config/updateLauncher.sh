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

get_update_counts() {
    # Count official pacman updates
    OFFICIAL_COUNT=$(pacman -Qu 2>/dev/null | wc -l)
    
    # Count AUR updates (assuming yay as AUR helper, replace with paru if needed)
    AUR_COUNT=$(yay -Qua 2>/dev/null | wc -l)
    
    # Count Flatpak updates
    FLATPAK_COUNT=$(flatpak remote-ls --updates 2>/dev/null | wc -l)

    # Return clickable links with counts
    echo "Available updates: <a href='official'>Official[$OFFICIAL_COUNT]</a>, <a href='aur'>AUR[$AUR_COUNT]</a>, <a href='flatpak'>Flatpak[$FLATPAK_COUNT]</a>"
}

show_official_updates() {
    # Get detailed pacman updates (name, old version -> new version)
    UPDATES=$(pacman -Qu | awk '{print $1 " " $2 " -> " $4}' 2>/dev/null)
    if [ -z "$UPDATES" ]; then
        UPDATES="No official updates available."
    fi
    echo "$UPDATES" | yad --center --title="Official Updates" \
        --text-info \
        --width=600 --height=400 \
        --fontname="Monospace" \
        --button="Exit:0"
}

show_aur_updates() {
    # Get detailed AUR updates (name, old version -> new version)
    UPDATES=$(yay -Qua | awk '{

print $1 " " $2 " -> " $4}' 2>/dev/null)
    if [ -z "$UPDATES" ]; then
        UPDATES="No AUR updates available."
    fi
    echo "$UPDATES" | yad --center --title="AUR Updates" \
        --text-info \
        --width=600 --height=400 \
        --fontname="Monospace" \
        --button="Exit:0"
}

show_flatpak_updates() {
    # Get Flatpak updates (name and branch)
    UPDATES=$(flatpak remote-ls --updates 2>/dev/null | awk '{print $1 " (Branch: " $2 ")"}')
    if [ -z "$UPDATES" ]; then
        UPDATES="No Flatpak updates available."
    fi
    echo "$UPDATES" | yad --center --title="Flatpak Updates" \
        --text-info \
        --width=600 --height=400 \
        --fontname="Monospace" \
        --button="Exit:0"
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
    MAIN_PID=""

    echo "[DEBUG] Starting update script..."
    (
        bash "$UPDATE_SCRIPT" >>"$LOGFILE" 2>&1
        echo DONE >>"$LOGFILE"
    ) &

    UPDATE_PID=$!

    # Show main update window
    yad --center --title="System Update" \
        --text="$BASE_TEXT" \
        --width=400 --height=150 \
        --on-top \
        --button="Show Output:100" &
    MAIN_PID=$!

    while true; do
        # Check if update is done
        grep -q DONE "$LOGFILE"
        if [ $? -eq 0 ]; then
            echo "[DEBUG] Update finished, closing windows"
            if [ -n "$OUTPUT_PID" ] && ps -p $OUTPUT_PID > /dev/null 2>&1; then
                kill $OUTPUT_PID 2>/dev/null
                wait $OUTPUT_PID 2>/dev/null
                echo "[DEBUG] Output window closed"
            fi
            if [ -n "$MAIN_PID" ] && ps -p $MAIN_PID > /dev/null 2>&1; then
                kill $MAIN_PID 2>/dev/null
                wait $MAIN_PID 2>/dev/null
                echo "[DEBUG] Main window closed"
            fi
            break
        fi

        # Check if main window is still open
        if ! ps -p $MAIN_PID > /dev/null 2>&1; then
            # Main window was closed manually, clean up and exit
            if [ -n "$OUTPUT_PID" ] && ps -p $OUTPUT_PID > /dev/null 2>&1; then
                kill $OUTPUT_PID 2>/dev/null
                wait $OUTPUT_PID 2>/dev/null
            fi
            kill $UPDATE_PID 2>/dev/null
            wait $UPDATE_PID 2>/dev/null
            return
        fi

        # Check for button clicks by reading the exit status of the last yad instance
        wait $MAIN_PID
        BUTTON=$?
        echo "[DEBUG] Button clicked: $BUTTON"

        case $BUTTON in
            100)
                echo "[DEBUG] Show Output clicked"
                if [ -z "$OUTPUT_PID" ] || ! ps -p $OUTPUT_PID > /dev/null 2>&1; then
                    ( tail -n 100 -f "$LOGFILE" | yad --title="Update Output" \
                        --text-info \
                        --width=600 --height=400 \
                        --center \
                        --button="Exit:0" \
                        --fontname="Monospace" \
                        --on-top \
                        --skip-taskbar \
                        --borders=10 \
                        --window-icon=system-run ) &
                    OUTPUT_PID=$!
                    echo "[DEBUG] Output window PID: $OUTPUT_PID"
                fi
                ;;
        esac

        # Restart main window if it was closed by a button
        if [ -n "$BUTTON" ] && [ $BUTTON -eq 100 ]; then
            yad --center --title="System Update" \
                --text="$BASE_TEXT" \
                --width=400 --height=150 \
                --on-top \
                --button="Show Output:100" &
            MAIN_PID=$!
        fi
    done

    wait $UPDATE_PID 2>/dev/null
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
    UPDATE_INFO=$(get_update_counts)
    yad --center --title="System Update" \
        --text="$GREETING\n\n$UPDATE_INFO" \
        --width=400 --height=200 \
        --html \
        --uri-handler="$0" \
        --button="Update:0" --button="Exit:1"
}

# Handle URI clicks
case "$1" in
    official)
        show_official_updates
        exit 0
        ;;
    aur)
        show_aur_updates
        exit 0
        ;;
    flatpak)
        show_flatpak_updates
        exit 0
        ;;
esac

# Run flow
while true; do
    main_menu
    [ $? -ne 0 ] && break

    if prompt_password; then
        launch_updater_ui
        break
    fi
done
