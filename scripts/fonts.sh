#!/bin/bash

error_exit() {
    local msg="$1"
    echo "Error: $msg" >&2
    echo "[$(date)] ERROR: $msg" >> "$LOG_FILE"
    exit 1
}

show_help() {
    echo "Usage: $0 [-h | -help | -discord]"
    echo "Options:"
    echo "  -h, -help     Display this help message and exit"
    echo "  -discord      Run only Discord/Vesktop-related modifications"
    exit 0
}

USER=${USER:-$(whoami)}
[ -z "$USER" ] && error_exit "Could not determine username."

XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
LOG_FILE="$HOME/.local/lib/hyde/install.log"
BACKUP_DIR="$HOME/.local/lib/hyde/backups"
BRAVE_DESKTOP_FILES=("brave-browser.desktop" "com.brave.Browser.desktop")
SYSTEM_BRAVE_SOURCE_DIR="/usr/share/applications"
FLATPAK_USER_SOURCE_DIR="$XDG_DATA_HOME/flatpak/exports/share/applications"
FLATPAK_SYSTEM_SOURCE_DIR="/var/lib/flatpak/exports/share/applications"
USER_DIR="$XDG_DATA_HOME/applications"
VESKTOP_DESKTOP_FILE="dev.vencord.Vesktop.desktop"
VESKTOP_SOURCE_DIR="$XDG_DATA_HOME/flatpak/exports/share/applications"
ARGUMENT="--enable-blink-features=MiddleClickAutoscroll"
EXTENSION_URL="https://github.com/jangxx/netflix-1080p/releases/download/v1.32.0/netflix-1080p-1.32.0.crx"
EXTENSION_DIR="$HOME/.config/brave-extensions/netflix-1080p"
VESKTOP_CONFIG_FILE="$HOME/.var/app/dev.vencord.Vesktop/config/vesktop/settings.json"
DCOL_FILE="$HOME/.config/hyde/wallbash/always/discord.dcol"

[ "$EUID" -eq 0 ] && error_exit "This script must not be run as root."

DISCORD_ONLY=false
while [ $# -gt 0 ]; do
    case "$1" in
        -h|-help)
            show_help
            ;;
        -discord)
            DISCORD_ONLY=true
            shift
            ;;
        *)
            error_exit "Unknown option: $1"
            ;;
    esac
done

if [ "$DISCORD_ONLY" = false ]; then
    ping -c 1 archlinux.org >/dev/null 2>&1 || error_exit "No internet connection."

    mkdir -p "$(dirname "$LOG_FILE")" || error_exit "Failed to create $(dirname "$LOG_FILE") directory."
    mkdir -p "$BACKUP_DIR" || error_exit "Failed to create $BACKUP_DIR directory."
    touch "$LOG_FILE" || error_exit "Failed to create $LOG_FILE."
    echo "[$(date)] New installation session (brave-vesktop)" >> "$LOG_FILE"

    if ! fc-list | grep -qi "Alef"; then
        echo "Warning: Alef font not found. Attempting to install..."
        echo "[$(date)] WARNING: Alef font not found, attempting installation" >> "$LOG_FILE"
        if command -v yay >/dev/null 2>&1; then
            yay -S --noconfirm ttf-alef >/dev/null 2>&1 || {
                echo "Warning: Failed to install ttf-alef via yay. Custom font may not apply."
                echo "[$(date)] WARNING: Failed to install ttf-alef" >> "$LOG_FILE"
            }
        else
            echo "Warning: yay not found. Please install yay to install ttf-alef."
            echo "[$(date)] WARNING: yay not found for ttf-alef installation" >> "$LOG_FILE"
        }
    else
        echo "Alef font is already installed."
        echo "[$(date)] SKIPPED: Alef font already installed" >> "$LOG_FILE"
    fi

    BRAVE_SOURCE_DIR=""
    BRAVE_FOUND=false
    BRAVE_DESKTOP_FILE_USED=""
    for desktop_file in "${BRAVE_DESKTOP_FILES[@]}"; do
        if [ -f "$SYSTEM_BRAVE_SOURCE_DIR/$desktop_file" ]; then
            BRAVE_SOURCE_DIR="$SYSTEM_BRAVE_SOURCE_DIR"
            BRAVE_DESKTOP_FILE_USED="$desktop_file"
            BRAVE_FOUND=true
            echo "[$(date)] DETECTED: Brave installed via system package ($desktop_file)" >> "$LOG_FILE"
            break
        elif [ -f "$FLATPAK_USER_SOURCE_DIR/$desktop_file" ]; then
            BRAVE_SOURCE_DIR="$FLATPAK_USER_SOURCE_DIR"
            BRAVE_DESKTOP_FILE_USED="$desktop_file"
            BRAVE_FOUND=true
            echo "[$(date)] DETECTED: Brave installed via Flatpak (user, $desktop_file)" >> "$LOG_FILE"
            break
        elif [ -f "$FLATPAK_SYSTEM_SOURCE_DIR/$desktop_file" ]; then
            BRAVE_SOURCE_DIR="$FLATPAK_SYSTEM_SOURCE_DIR"
            BRAVE_DESKTOP_FILE_USED="$desktop_file"
            BRAVE_FOUND=true
            echo "[$(date)] DETECTED: Brave installed via Flatpak (system, $desktop_file)" >> "$LOG_FILE"
            break
        elif [ -f "$USER_DIR/$desktop_file" ]; then
            BRAVE_SOURCE_DIR="$USER_DIR"
            BRAVE_DESKTOP_FILE_USED="$desktop_file"
            BRAVE_FOUND=true
            echo "[$(date)] DETECTED: Brave desktop file found in user directory ($desktop_file)" >> "$LOG_FILE"
            break
        fi
    done

    if [ "$BRAVE_FOUND" = false ] && flatpak list | grep -q com.brave.Browser; then
        echo "[$(date)] DETECTED: Brave installed via Flatpak, searching system for desktop file" >> "$LOG_FILE"
        for desktop_file in "${BRAVE_DESKTOP_FILES[@]}"; do
            FOUND_FILE=$(find / -type f -name "$desktop_file" 2>/dev/null | head -n 1)
            if [ -n "$FOUND_FILE" ]; then
                BRAVE_SOURCE_DIR="$(dirname "$FOUND_FILE")"
                BRAVE_DESKTOP_FILE_USED="$desktop_file"
                BRAVE_FOUND=true
                echo "[$(date)] DETECTED: Brave desktop file found at $FOUND_FILE" >> "$LOG_FILE"
                break
            fi
        done
    fi

    if [ "$BRAVE_FOUND" = false ]; then
        echo "Warning: Brave browser not found in system or Flatpak. Skipping Brave-related modifications."
        echo "[$(date)] WARNING: Brave not found, skipping Brave modifications" >> "$LOG_FILE"
        echo "Skipping all Brave-related modifications due to no Brave installation detected."
        echo "[$(date)] SKIPPED: All Brave-related modifications (Brave not installed)" >> "$LOG_FILE"
    fi

    if [ "$BRAVE_FOUND" = true ]; then
        mkdir -p "$USER_DIR" || error_exit "Failed to create $USER_DIR directory."
        if [ ! -f "$USER_DIR/$BRAVE_DESKTOP_FILE_USED" ]; then
            cp "$BRAVE_SOURCE_DIR/$BRAVE_DESKTOP_FILE_USED" "$USER_DIR/$BRAVE_DESKTOP_FILE_USED" || {
                echo "Warning: Failed to copy $BRAVE_DESKTOP_FILE_USED to $USER_DIR. Skipping Brave modifications."
                echo "[$(date)] WARNING: Failed to copy $BRAVE_DESKTOP_FILE_USED" >> "$LOG_FILE"
                BRAVE_FOUND=false
            }
            if [ "$BRAVE_FOUND" = true ]; then
                echo "CREATED_DESKTOP: $BRAVE_DESKTOP_FILE_USED -> $USER_DIR/$BRAVE_DESKTOP_FILE_USED" >> "$LOG_FILE"
                echo "Copied $BRAVE_DESKTOP_FILE_USED to $USER_DIR"
            fi
        else
            echo "Skipping: $BRAVE_DESKTOP_FILE_USED already exists in $USER_DIR"
            echo "[$(date)] SKIPPED: $BRAVE_DESKTOP_FILE_USED already exists" >> "$LOG_FILE"
        fi
    fi

    if [ "$BRAVE_FOUND" = true ]; then
        if [ -f "$USER_DIR/$BRAVE_DESKTOP_FILE_USED" ]; then
            cp "$USER_DIR/$BRAVE_DESKTOP_FILE_USED" "$BACKUP_DIR/$BRAVE_DESKTOP_FILE_USED.$(date +%s)" || error_exit "Failed to backup $BRAVE_DESKTOP_FILE_USED."
            echo "BACKUP_DESKTOP: $BRAVE_DESKTOP_FILE_USED -> $BACKUP_DIR/$BRAVE_DESKTOP_FILE_USED.$(date +%s)" >> "$LOG_FILE"
            echo "Created backup of $BRAVE_DESKTOP_FILE_USED"
            ls -t "$BACKUP_DIR/$BRAVE_DESKTOP_FILE_USED".* 2>/dev/null | tail -n +6 | xargs -I {} rm -f "{}"
        fi

        if grep -q -- "--load-extension=$EXTENSION_DIR" "$USER_DIR/$BRAVE_DESKTOP_FILE_USED"; then
            sed -i "s| --load-extension=$EXTENSION_DIR||" "$USER_DIR/$BRAVE_DESKTOP_FILE_USED" || error_exit "Failed to remove --load-extension flag from $BRAVE_DESKTOP_FILE_USED."
            echo "Removed invalid --load-extension flag from $BRAVE_DESKTOP_FILE_USED"
            echo "[$(date)] CLEANUP: Removed --load-extension from $BRAVE_DESKTOP_FILE_USED" >> "$LOG_FILE"
        fi
        if [[ -d "$EXTENSION_DIR" ]]; then
            rm -rf "$EXTENSION_DIR" || error_exit "Failed to remove invalid extension directory $EXTENSION_DIR."
            echo "Removed invalid extension directory $EXTENSION_DIR"
            echo "[$(date)] CLEANUP: Removed $EXTENSION_DIR" >> "$LOG_FILE"
        fi

        if grep -q -- "$ARGUMENT" "$USER_DIR/$BRAVE_DESKTOP_FILE_USED"; then
            echo "The $ARGUMENT is already present in the Exec line for Brave"
            echo "[$(date)] SKIPPED: $ARGUMENT already in $BRAVE_DESKTOP_FILE_USED" >> "$LOG_FILE"
        else
            sed -i "/^Exec=/ s|$| $ARGUMENT|" "$USER_DIR/$BRAVE_DESKTOP_FILE_USED" || error_exit "Failed to modify Exec line in $BRAVE_DESKTOP_FILE_USED."
            echo "Successfully added $ARGUMENT to the Exec line in $USER_DIR/$BRAVE_DESKTOP_FILE_USED"
            echo "New Exec line:"
            grep "^Exec=" "$USER_DIR/$BRAVE_DESKTOP_FILE_USED"
            echo "[$(date)] MODIFIED_DESKTOP: Added $ARGUMENT to $BRAVE_DESKTOP_FILE_USED" >> "$LOG_FILE"
        fi

        mkdir -p "$EXTENSION_DIR" || error_exit "Failed to create $EXTENSION_DIR."
        wget --no-config -O /tmp/netflix-1080p.crx "$EXTENSION_URL" 2>&1 | tee -a "$LOG_FILE"
        [ $? -ne 0 ] && error_exit "Failed to download extension from $EXTENSION_URL."
        unzip -o /tmp/netflix-1080p.crx -d "$EXTENSION_DIR" 2>&1 | tee -a "$LOG_FILE"
        [ $? -ne 0 ] && error_exit "Failed to unzip extension to $EXTENSION_DIR."
        [ ! -f "$EXTENSION_DIR/manifest.json" ] && error_exit "Failed to unpack extension to $EXTENSION_DIR (manifest.json missing)."
        rm -f /tmp/netflix-1080p.crx || echo "Warning: Failed to remove temporary file /tmp/netflix-1080p.crx"

        if grep -q -- "--load-extension=$EXTENSION_DIR" "$USER_DIR/$BRAVE_DESKTOP_FILE_USED"; then
            echo "The extension is already loaded in the Exec line for Brave"
            echo "[$(date)] SKIPPED: Extension already in $BRAVE_DESKTOP_FILE_USED" >> "$LOG_FILE"
        else
            sed -i "/^Exec=/ s|$| --load-extension=$EXTENSION_DIR|" "$USER_DIR/$BRAVE_DESKTOP_FILE_USED" || error_exit "Failed to add extension to $BRAVE_DESKTOP_FILE_USED."
            echo "Successfully added extension to the Exec line in $USER_DIR/$BRAVE_DESKTOP_FILE_USED"
            echo "New Exec line:"
            grep "^Exec=" "$USER_DIR/$BRAVE_DESKTOP_FILE_USED"
            echo "[$(date)] MODIFIED_DESKTOP: Added extension to $BRAVE_DESKTOP_FILE_USED" >> "$LOG_FILE"
        fi
    fi
fi

if ! command -v flatpak >/dev/null 2>&1; then
    sudo pacman -Syu --noconfirm flatpak || error_exit "Failed to install flatpak."
    echo "INSTALLED_PACKAGE: flatpak" >> "$LOG_FILE"
    echo "Installed flatpak"
else
    echo "Skipping: flatpak already installed"
    echo "[$(date)] SKIPPED: flatpak already installed" >> "$LOG_FILE"
fi

if ! flatpak --user remotes | grep -q flathub; then
    flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || error_exit "Failed to add flathub repository."
    echo "ADDED_FLATHUB: flathub" >> "$LOG_FILE"
    echo "Added flathub repository"
else
    echo "Skipping: flathub repository already added"
    echo "[$(date)] SKIPPED: flathub repository already added" >> "$LOG_FILE"
fi

if ! flatpak list | grep -q dev.vencord.Vesktop; then
    flatpak install --user -y flathub dev.vencord.Vesktop || error_exit "Failed to install Vesktop."
    echo "INSTALLED_FLATPAK: dev.vencord.Vesktop" >> "$LOG_FILE"
    echo "Installed Vesktop"
else
    echo "Skipping: Vesktop already installed"
    echo "[$(date)] SKIPPED: Vesktop already installed" >> "$LOG_FILE"
fi

if [ ! -f "$VESKTOP_SOURCE_DIR/$VESKTOP_DESKTOP_FILE" ]; then
    echo "Error: $VESKTOP_DESKTOP_FILE not found in $VESKTOP_SOURCE_DIR."
    echo "[$(date)] ERROR: $VESKTOP_DESKTOP_FILE not found in $VESKTOP_SOURCE_DIR" >> "$LOG_FILE"
    exit 1
fi

if [ ! -f "$USER_DIR/$VESKTOP_DESKTOP_FILE" ]; then
    cp "$VESKTOP_SOURCE_DIR/$VESKTOP_DESKTOP_FILE" "$USER_DIR/$VESKTOP_DESKTOP_FILE" || error_exit "Failed to copy $VESKTOP_DESKTOP_FILE to $USER_DIR."
    echo "CREATED_DESKTOP: $VESKTOP_DESKTOP_FILE -> $USER_DIR/$VESKTOP_DESKTOP_FILE" >> "$LOG_FILE"
    echo "Copied $VESKTOP_DESKTOP_FILE to $USER_DIR"
else
    echo "Skipping: $VESKTOP_DESKTOP_FILE already exists in $USER_DIR"
    echo "[$(date)] SKIPPED: $VESKTOP_DESKTOP_FILE already exists" >> "$LOG_FILE"
fi

if [ -f "$USER_DIR/$VESKTOP_DESKTOP_FILE" ]; then
    cp "$USER_DIR/$VESKTOP_DESKTOP_FILE" "$BACKUP_DIR/$VESKTOP_DESKTOP_FILE.$(date +%s)" || error_exit "Failed to backup $VESKTOP_DESKTOP_FILE."
    echo "BACKUP_DESKTOP: $VESKTOP_DESKTOP_FILE -> $BACKUP_DIR/$VESKTOP_DESKTOP_FILE.$(date +%s)" >> "$LOG_FILE"
    echo "Created backup of $VESKTOP_DESKTOP_FILE"
    ls -t "$BACKUP_DIR/$VESKTOP_DESKTOP_FILE".* 2>/dev/null | tail -n +6 | xargs -I {} rm -f "{}"
fi

if grep -q -- "$ARGUMENT" "$USER_DIR/$VESKTOP_DESKTOP_FILE"; then
    echo "Skipping: $ARGUMENT already present in $VESKTOP_DESKTOP_FILE"
    echo "[$(date)] SKIPPED: $ARGUMENT already in $VESKTOP_DESKTOP_FILE" >> "$LOG_FILE"
else
    sed -i "/^Exec=/ s/@@u %U @@/$ARGUMENT @@u %U @@/" "$USER_DIR/$VESKTOP_DESKTOP_FILE" || error_exit "Failed to modify Exec line in $VESKTOP_DESKTOP_FILE."
    echo "MODIFIED_DESKTOP: $VESKTOP_DESKTOP_FILE -> Added $ARGUMENT" >> "$LOG_FILE"
    echo "Added $ARGUMENT to $VESKTOP_DESKTOP_FILE"
    echo "New Exec line:"
    grep "^Exec=" "$USER_DIR/$VESKTOP_DESKTOP_FILE"
fi

if [ -f "$VESKTOP_CONFIG_FILE" ]; then
    if ! jq '.hardwareAcceleration == false' "$VESKTOP_CONFIG_FILE" | grep -q true; then
        cp "$VESKTOP_CONFIG_FILE" "$BACKUP_DIR/settings.json.$(date +%s)" || error_exit "Failed to backup $VESKTOP_CONFIG_FILE."
        echo "BACKUP_CONFIG: $VESKTOP_CONFIG_FILE -> $BACKUP_DIR/settings.json.$(date +%s)" >> "$LOG_FILE"
        echo "Created backup of $VESKTOP_CONFIG_FILE"
        jq '.hardwareAcceleration = false' "$VESKTOP_CONFIG_FILE" > temp.json && mv temp.json "$VESKTOP_CONFIG_FILE" || error_exit "Failed to disable hardware acceleration in $VESKTOP_CONFIG_FILE."
        echo "MODIFIED_CONFIG: $VESKTOP_CONFIG_FILE -> Disabled hardware acceleration" >> "$LOG_FILE"
        echo "Disabled hardware acceleration in Vesktop"
    else
        echo "Skipping: Hardware acceleration already disabled in $VESKTOP_CONFIG_FILE"
        echo "[$(date)] SKIPPED: Hardware acceleration already disabled" >> "$LOG_FILE"
    fi
else
    echo "Warning: $VESKTOP_CONFIG_FILE not found. Hardware acceleration not modified."
    echo "[$(date)] WARNING: $VESKTOP_CONFIG_FILE not found for hardware acceleration" >> "$LOG_FILE"
fi

CUSTOM_CSS=$(cat << 'EOF'
/* Custom font for Vesktop */
::placeholder, body, button, input, select, textarea {
    font-family: 'Alef', sans-serif;
    text-rendering: optimizeLegibility;
}
EOF
)

[ ! -f "$DCOL_FILE" ] && error_exit "$DCOL_FILE does not exist."

cp "$DCOL_FILE" "$BACKUP_DIR/discord.dcol.$(date +%s)" || error_exit "Failed to backup $DCOL_FILE."
echo "BACKUP_CONFIG: $DCOL_FILE -> $BACKUP_DIR/discord.dcol.$(date +%s)" >> "$LOG_FILE"
echo "Created backup of $DCOL_FILE"
ls -t "$BACKUP_DIR/discord.dcol".* 2>/dev/null | tail -n +6 | xargs -I {} rm -f "{}"

if grep -q "font-family: 'Alef'" "$DCOL_FILE"; then
    echo "Skipping: Custom Alef font CSS already exists in $DCOL_FILE"
    echo "[$(date)] SKIPPED: Custom Alef font CSS already in $DCOL_FILE" >> "$LOG_FILE"
else
    sed -i '/\/* Any custom CSS below here *\/$/,$d' "$DCOL_FILE" || error_exit "Failed to clean existing custom CSS in $DCOL_FILE."
    {
        echo "/* Any custom CSS below here */"
        echo "$CUSTOM_CSS"
    } >> "$DCOL_FILE" || error_exit "Failed to append custom CSS to $DCOL_FILE."
    echo "Appended custom CSS to $DCOL_FILE"
    echo "[$(date)] MODIFIED_CONFIG: $DCOL_FILE -> Appended custom CSS" >> "$LOG_FILE"
    if grep -q "font-family: 'Alef'" "$DCOL_FILE"; then
        echo "Verified: Custom Alef font CSS successfully added to $DCOL_FILE"
        echo "[$(date)] VERIFIED: Custom Alef font CSS added to $DCOL_FILE" >> "$LOG_FILE"
    else
        error_exit "Failed to verify custom CSS addition in $DCOL_FILE."
    fi
fi

echo "Installation and modification complete!"
echo "[$(date)] COMPLETED: Installation and modification" >> "$LOG_FILE"
exit 0
