#!/usr/bin/env bash

get_greeting() {
    HOUR=$(date +%H)
    USER=$(whoami)

    if [ "$HOUR" -ge 5 ] && [ "$HOUR" -lt 12 ]; then
        GREETING="Good morning, $USER!"
    elif [ "$HOUR" -ge 12 ] && [ "$HOUR" -lt 18 ]; then
        GREETING="Good afternoon, $USER!"
    else
        GREETING="Good evening, $USER!"
    fi
    echo "$GREETING"
}

# Main loop
while true; do
    GREETING=$(get_greeting)

    yad --center --title="Greeting Window" \
        --text="$GREETING" \
        --button="Update:0" --button="Exit:1"

    # If Exit was pressed (exit code 1), break the loop
    if [ $? -eq 1 ]; then
        break
    fi
done

