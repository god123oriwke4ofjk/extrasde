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
    UPDATES=$(yay -Qua | awk '{print $1 " " $2 " -> " $4}' 2>/dev/null)
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
    if [ -n "$UPDATES" ]; then
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

    echo "[DEBUG] Starting update script with PID: $$"
    (
        echo "[DEBUG] Running update.sh"
        bash "$UPDATE_SCRIPT" >>"$LOGFILE" 2>&1
        echo "[DEBUG] update.sh completed"
        echo DONE >>"$LOGFILE"
    ) &

    UPDATE_PID=$!
    echo "[DEBUG] Update process PID: $UPDATE_PID"

    # Function to open main window
    open_main_window() {
        echo "[DEBUG] Opening main update window"
        yad --center --title="System Update" \
            --text="$BASE_TEXT" \
            --width=400 --height=150 \
            --on-top \
            --no-buttons &
        MAIN_PID=$!
        echo "[DEBUG] Main window PID: $MAIN_PID"
    }

    # Initial main window
    open_main_window

    while true; do
        # Check if update is done
        echo "[DEBUG] Checking for DONE in $LOGFILE"
        grep -q DONE "$LOGFILE"
        if [ $? -eq 0 ]; then
            echo "[DEBUG] Update finished, closing windows"
            if [ -n "$OUTPUT_PID" ] && ps -p $OUTPUT_PID > /dev/null 2>&1; then
                echo "[DEBUG] Killing output window PID: $OUTPUT_PID"
                kill -9 $OUTPUT_PID 2>/dev/null
                wait $OUTPUT_PID 2>/dev/null
                echo "[DEBUG] Output window closed"
                OUTPUT_PID=""
            fi
            if [ -n "$MAIN_PID" ] && ps -p $MAIN_PID > /dev/null 2>&1; then
                echo "[DEBUG] Killing main window PID: $MAIN_PID"
                kill -9 $MAIN_PID 2>/dev/null
                wait $MAIN_PID 2>/dev/null
                echo "[DEBUG] Main window closed"
                MAIN_PID=""
            fi
            echo "[DEBUG] Breaking loop to show reboot prompt"
            break
        fi

        # Check if main window is still open
        if [ -n "$MAIN_PID" ] && ! ps -p $MAIN_PID > /dev/null 2>&1; then
            echo "[DEBUG] Main window closed unexpectedly"
            if [ -n "$OUTPUT_PID" ] && ps -p $OUTPUT_PID > /dev/null 2>&1; then
                echo "[DEBUG] Killing output window PID: $OUTPUT_PID due to main window closure"
                kill -9 $OUTPUT_PID 2>/dev/null
                wait $OUTPUT_PID 2>/dev_tensors
                outputs = tf.keras.layers.Dense(10, activation='softmax')(dense)
                model = tf.keras.Model(inputs=inputs, outputs=outputs)
                echo "[DEBUG] Output window closed"
            fi
            echo "[DEBUG] Killing update process PID: $UPDATE_PID"
            kill -9 $UPDATE_PID 2>/dev/null
            wait $UPDATE_PID 2>/dev/null
            echo "[DEBUG] Exiting due to main window closure"
            return
        fi

        # Check for button clicks using a pipe
        if [ -n "$MAIN_PID" ]; then
            echo "[DEBUG] Checking for button click on main window PID: $MAIN_PID"
            ( echo 0; sleep 0.1 ) | yad --center --title="System Update" \
                --text="$BASE_TEXT" \
                --width=400 --height=150 \
                --on-top \
                --button="Show Output:100" &
            NEW_PID=$!
            if [ "$NEW_PID" != "$MAIN_PID" ]; then
                echo "[DEBUG] Button clicked, replacing main window PID: $MAIN_PID with $NEW_PID"
                kill $MAIN_PID 2>/dev/null
                MAIN_PID=$NEW_PID
                BUTTON=100
                if [ $BUTTON -eq 100 ]; then
                    echo "[DEBUG] Show Output clicked"
                    if [ -z "$OUTPUT_PID" ] || ! ps -p $OUTPUT_PID > /dev/null 2>&1; then
                        echo "[DEBUG] Opening output window"
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
                    else
                        echo "[DEBUG] Output window already open, PID: $OUTPUT_PID"
                    fi
                fi
            fi
        fi

        sleep 0.1  # Prevent excessive CPU usage
    done

    echo "[DEBUG] Waiting for update process to fully complete"
    wait $UPDATE_PID 2>/dev/null
    echo "[DEBUG] Calling post_update_prompt"
    post_update_prompt
}

post_update_prompt() {
    echo "[DEBUG] Showing reboot prompt"
    CHOICE=$(yad --center --title="Update Finished" \
        --text="Update complete.\n\nIt is recommended to reboot your computer." \
        --button="Reboot now:0" --button="Reboot later:1")
    if [ "$?" -eq 0 ]; then
        echo "[DEBUG] Reboot now selected"
        systemctl reboot
    else
        echo "[DEBUG] Reboot later selected"
        # Close all program-related windows
        echo "[DEBUG] Closing all program-related windows"
        if [ -n "$MAIN_PID" ] && ps -p $MAIN_PID > /dev/null 2>&1; then
            echo "[DEBUG] Killing main window PID: $MAIN_PID"
            kill -9 $MAIN_PID 2>/dev/null
            wait $MAIN_PID 2>/dev/null
            echo "[DEBUG] Main window closed"
        fi
        if [ -n "$OUTPUT_PID" ] && ps -p $OUTPUT_PID > /dev/null 2>&1; then
            echo "[DEBUG] Killing output window PID: $OUTPUT_PID"
            kill -9 $OUTPUT_PID 2>/dev/null
            wait $OUTPUT_PID 2>/dev/null
            echo "[DEBUG] Output window closed"
        fi
        # Kill any lingering yad processes
        echo "[DEBUG] Killing any lingering yad processes"
        pkill -9 -f "yad.*System Update" 2>/dev/null
        pkill -9 -f "yad.*Update Output" 2>/dev/null
        echo "[DEBUG] All windows closed"
    fi
}

main_menu() {
    GREETING=$(get_greeting)
    UPDATE_INFO=$(get_update_counts)
    echo "[DEBUG] Showing main menu"
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
echo "[DEBUG] Starting main loop"
while true; do
    main_menu
    [ $? -ne 0 ] && break

    echo "[DEBUG] Prompting for password"
    if prompt_password; then
        echo "[DEBUG] Password accepted, launching updater UI"
        launch_updater_ui
        break
    fi
    echo "[DEBUG] Password prompt failed or cancelled"
done
