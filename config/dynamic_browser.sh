#!/bin/bash

declare -A browsers=(
    ["firefox"]="firefox.desktop"
    ["brave"]="brave-browser.desktop"
    ["chromium"]="chromium.desktop"
    ["google-chrome"]="google-chrome.desktop"
    ["opera"]="opera.desktop"
    ["edge"]="microsoft-edge.desktop"
)

LOG_FILE="$HOME/.dynamic_browser.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

is_known_browser() {
    local process_name="$1"
    for browser in "${!browsers[@]}"; do
        if [[ "$process_name" == "$browser" ]]; then
            return 0
        fi
    done
    return 1
}

set_default_browser() {
    local desktop_file="$1"
    log_message "Setting default browser to $desktop_file"
    xdg-settings set default-web-browser "$desktop_file"
    if [[ $? -eq 0 ]]; then
        log_message "Successfully set $desktop_file as default browser"
    else
        log_message "Failed to set $desktop_file as default browser"
    fi
}

monitor_browsers() {
    log_message "Starting browser monitoring"
    
    while true; do
        active_window=$(hyprctl activewindow -j | jq -r '.class')
        if [[ -n "$active_window" ]]; then
            case "$active_window" in
                "firefox") process_name="firefox" ;;
                "Brave-browser") process_name="brave" ;;
                "chromium" | "Chromium") process_name="chromium" ;;
                "Google-chrome") process_name="google-chrome" ;;
                "opera" | "Opera") process_name="opera" ;;
                "microsoft-edge" | "Microsoft-edge") process_name="edge" ;;
                *) process_name="" ;;
            esac

            if [[ -n "$process_name" ]] && is_known_browser "$process_name"; then
                desktop_file="${browsers[$process_name]}"
                log_message "Detected browser: $process_name ($desktop_file)"
                set_default_browser "$desktop_file"
            fi
        fi
        sleep 1
    done
}

if [[ "$1" != "--bg" ]]; then
    log_message "Starting script in background"
    nohup "$0" --bg >> "$LOG_FILE" 2>&1 &
    exit 0
fi

monitor_browsers
