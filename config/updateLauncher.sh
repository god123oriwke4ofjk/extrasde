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

prompt_password() {
    PASSWORD=$(yad --center --title="Authentication Required" \
        --entry --hide-text \
        --text="Please enter your password:" \
        --button="OK:0" --button="Cancel:1")

    if [ $? -ne 0 ]; then
        return 1
    fi

    # Validate password using sudo
    echo "$PASSWORD" | sudo -S -v 2>/dev/null
    if [ $? -ne 0 ]; then
        yad --error --text="Authentication failed!"
        return 1
    fi

    return 0
}

# Main loop
while true; do
    GREETING=$(get_greeting)

    yad --center --title="Greeting Window" \
        --text="$GREETING" \
        --button="Update:0" --button="Exit:1"

    if [ $? -eq 1 ]; then
        break
    fi

    # Ask for password before continuing
    if ! prompt_password; then
        continue
    fi
done
