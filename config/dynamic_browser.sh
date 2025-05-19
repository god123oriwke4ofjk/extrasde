#!/bin/bash

declare -A browsers=(
    ["firefox"]="firefox.desktop"
    ["brave"]="brave-browser.desktop"
    ["zen"]="zen.desktop"
)

declare -A flatpak_browsers=(
    ["firefox"]="org.mozilla.firefox.desktop"
    ["brave"]="com.brave.Browser.desktop"
)

LOG_FILE="$HOME/.dynamic_browser.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

is_known_browser() {
    local process_name="$1"
    for browser in "${!browsers[@]}" "${!flatpak_browsers[@]}"; do
        if [[ "$process_name" == "$browser" ]]; then
            return 0
        fi
    done
    return 1
}

find_desktop_file() {
    local desktop_file="$1"
    local dirs="/usr/share/applications ~/.local/share/applications /usr/local/share/applications"
    if [[ -n "$XDG_DATA_DIRS" ]]; then
        dirs="$dirs $(echo $XDG_DATA_DIRS | tr ':' ' ')"
    fi
    dirs="$dirs ~/.local/share/flatpak/exports/share/applications /var/lib/flatpak/exports/share/applications"
    for dir in $dirs; do
        dir=$(eval echo "$dir") 
        if [[ -f "$dir/$desktop_file" ]]; then
            echo "$dir/$desktop_file"
            return 0
        fi
    done
    log_message "Error: Desktop file $desktop_file not found in $dirs"
    return 1
}

set_default_browser() {
    local desktop_file="$1"
    local found_file=$(find_desktop_file "$desktop_file")
    if [[ $? -eq 0 ]]; then
        log_message "Found desktop file: $found_file"
        local current_default=$(xdg-settings get default-web-browser 2>/dev/null)
        if [[ "$current_default" == "$desktop_file" ]]; then
            log_message "Default browser already set to $desktop_file, skipping"
            return 0
        fi
        log_message "Setting default browser to $desktop_file"
        xdg-settings set default-web-browser "$desktop_file"
        if [[ $? -eq 0 ]]; then
            log_message "Successfully set $desktop_file as default browser"
        else
            log_message "Failed to set $desktop_file as default browser"
            return 1
        fi
    else
        return 1
    fi
}

monitor_browsers() {
    log_message "Starting browser monitoring"
    command -v hyprctl >/dev/null 2>&1 || { log_message "Error: hyprctl not found"; exit 1; }
    command -v jq >/dev/null 2>&1 || { log_message "Error: jq not found"; exit 1; }
    
    while true; do
        hyprctl_output=$(hyprctl activewindow -j 2>/dev/null)
        if [[ $? -ne 0 || -z "$hyprctl_output" ]]; then
            log_message "No active window or hyprctl error"
            sleep 1
            continue
        fi
        active_window=$(echo "$hyprctl_output" | jq -r '.class' 2>/dev/null)
        if [[ $? -ne 0 || -z "$active_window" ]]; then
            log_message "Failed to parse window class from hyprctl output: $hyprctl_output"
            sleep 1
            continue
        fi
        log_message "Active window class: $active_window"
        case "$active_window" in
            "firefox" | "Firefox" | "org.mozilla.firefox")
                process_name="firefox"
                ;;
            "Brave-browser" | "brave-browser" | "brave")
                process_name="brave"
                ;;
            "zen" | "Zen")
                process_name="zen"
                ;;
            *)
                process_name=""
                log_message "Unknown window class: $active_window"
                ;;
        esac

        if [[ -n "$process_name" ]] && is_known_browser "$process_name"; then
            desktop_file="${browsers[$process_name]:-${flatpak_browsers[$process_name]}}"
            log_message "Detected browser: $process_name ($desktop_file)"
            set_default_browser "$desktop_file"
        fi
        sleep 1
    done
}

touch "$LOG_FILE" 2>/dev/null || { echo "Error: Cannot write to $LOG_FILE"; exit 1; }

if [[ "$1" != "--bg" ]]; then
    log_message "Starting script in background"
    nohup "$0" --bg >> "$LOG_FILE" 2>&1 &
    if [[ $? -eq 0 ]]; then
        log_message "Background process started successfully"
        exit 0
    else
        log_message "Failed to start background process"
        exit 1
    fi
fi

monitor_browsers
