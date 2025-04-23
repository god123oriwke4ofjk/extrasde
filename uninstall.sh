#!/bin/bash

USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo "Error: Could not determine username."; exit 1; }

ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
USERPREFS_CONF="/home/$USER/.config/hypr/userprefs.conf"
LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
FIREFOX_PROFILE_DIR=$(grep -E "^Path=" "$HOME/.mozilla/firefox/profiles.ini" | grep -v "default" | head -n 1 | cut -d'=' -f2 2>/dev/null)
FIREFOX_PREFS_FILE="/home/$USER/.mozilla/firefox/$FIREFOX_PROFILE_DIR/prefs.js"
USER_DIR="$HOME/.local/share/applications"
EXTENSION_DIR="$HOME/.config/brave-extensions/netflix-1080p"
FULL_PROFILE_DIR="$HOME/.mozilla/firefox/$FIREFOX_PROFILE_DIR"
EXTENSIONS_DIR="$FULL_PROFILE_DIR/extensions"
STAGING_DIR="$FULL_PROFILE_DIR/extensions.staging"
EXTENSIONS_JSON="$FULL_PROFILE_DIR/extensions.json"
FONT_DIR="$HOME/.local/share/fonts"
SYSTEM_FONTCONFIG_DIR="$HOME/.config/fontconfig"
SYSTEM_FONTCONFIG_FILE="$SYSTEM_FONTCONFIG_DIR/fonts.conf"

[ ! -f "$LOG_FILE" ] && { echo "Error: $LOG_FILE not found. Nothing to undo."; exit 1; }

if pgrep firefox >/dev/null; then
    echo "Error: Firefox is running. Please close Firefox before undoing settings."
    exit 1
fi

reversed_actions=0

while IFS=': ' read -r action details; do
    case "$action" in
        CREATED_SCRIPT)
            script_path="${details##* -> }"
            if [ -f "$script_path" ]; then
                rm "$script_path" || { echo "Error: Failed to remove $script_path"; exit 1; }
                echo "Removed $script_path"
                ((reversed_actions++))
            else
                echo "Skipping $script_path: already removed"
            fi
            ;;
        REPLACED_SCRIPT)
            script_path="${details##* -> }"
            script_name=$(basename "$script_path")
            backup_file=$(ls -t "$BACKUP_DIR/$script_name."* 2>/dev/null | head -n 1)
            if [ -f "$script_path" ] && [ -n "$backup_file" ]; then
                mv "$backup_file" "$script_path" || { echo "Error: Failed to restore $script_path"; exit 1; }
                echo "Restored $script_path from backup"
                ((reversed_actions++))
            else
                echo "Skipping $script_path: no backup or already restored"
            fi
            ;;
        MOVED_SVG)
            svg_path="${details##* -> }"
            if [ -f "$svg_path" ]; then
                rm "$svg_path" || { echo "Error: Failed to remove $svg_path"; exit 1; }
                echo "Removed $svg_path"
                ((reversed_actions++))
            else
                echo "Skipping $svg_path: already removed"
            fi
            ;;
        REPLACED_SVG)
            svg_path="${details##* -> }"
            svg_name=$(basename "$svg_path")
            backup_file=$(ls -t "$BACKUP_DIR/$svg_name."* 2>/dev/null | head -n 1)
            if [ -f "$svg_path" ] && [ -n "$backup_file" ]; then
                mv "$backup_file" "$svg_path" || { echo "Error: Failed to restore $svg_path"; exit 1; }
                echo "Restored $svg_path from backup"
                ((reversed_actions++))
            else
                echo "Skipping $svg_path: no backup or already restored"
            fi
            ;;
        MODIFIED_KEYBINDINGS)
            backup_file=$(ls -t "$BACKUP_DIR/keybindings.conf."* 2>/dev/null | head -n 1)
            if [ -n "$backup_file" ]; then
                mv "$backup_file" "$KEYBINDINGS_CONF" || { echo "Error: Failed to restore $KEYBINDINGS_CONF"; exit 1; }
                echo "Restored $KEYBINDINGS_CONF from backup"
                ((reversed_actions++))
            else
                echo "Skipping $KEYBINDINGS_CONF: no backup found"
            fi
            ;;
        MODIFIED_USERPREFS)
            backup_file=$(ls -t "$BACKUP_DIR/userprefs.conf."* 2>/dev/null | head -n 1)
            if [ -n "$backup_file" ]; then
                mv "$backup_file" "$USERPREFS_CONF" || { echo "Error: Failed to restore $USERPREFS_CONF"; exit 1; }
                echo "Restored $USERPREFS_CONF from backup"
                ((reversed_actions++))
            else
                echo "Skipping $USERPREFS_CONF: no backup found"
            fi
            ;;
        MODIFIED_FIREFOX_AUTOSCROLL)
            backup_file=$(ls -t "$BACKUP_DIR/prefs.js."* 2>/dev/null | head -n 1)
            if [ -n "$backup_file" ]; then
                mv "$backup_file" "$FIREFOX_PREFS_FILE" || { echo "Error: Failed to restore $FIREFOX_PREFS_FILE"; exit 1; }
                echo "Restored $FIREFOX_PREFS_FILE from backup"
                ((reversed_actions++))
            else
                echo "Skipping $FIREFOX_PREFS_FILE: no backup found"
            fi
            ;;
        INSTALLED_PACKAGE)
            package="$details"
            if pacman -Qs "$package" >/dev/null 2>&1; then
                sudo pacman -Rns --noconfirm "$package" || { echo "Error: Failed to remove $package"; exit 1; }
                echo "Removed package $package"
                ((reversed_actions++))
            else
                echo "Skipping $package: not installed"
            fi
            ;;
        ADDED_FLATHUB)
            if flatpak --user remotes | grep -q flathub; then
                flatpak --user remote-delete flathub || { echo "Error: Failed to remove flathub repository"; exit 1; }
                echo "Removed flathub repository"
                ((reversed_actions++))
            else
                echo "Skipping flathub: not present"
            fi
            ;;
        INSTALLED_FLATPAK)
            flatpak="$details"
            if flatpak list | grep -q "$flatpak"; then
                flatpak uninstall --user -y "$flatpak" || { echo "Error: Failed to uninstall $flatpak"; exit 1; }
                echo "Uninstalled flatpak $flatpak"
                ((reversed_actions++))
            else
                echo "Skipping $flatpak: not installed"
            fi
            ;;
        CREATED_DESKTOP)
            desktop_path="${details##* -> }"
            if [ -f "$desktop_path" ]; then
                rm "$desktop_path" || { echo "Error: Failed to remove $desktop_path"; exit 1; }
                echo "Removed $desktop_path"
                ((reversed_actions++))
            else
                echo "Skipping $desktop_path: already removed"
            fi
            ;;
        MODIFIED_DESKTOP)
            desktop_file=$(echo "$details" | cut -d' ' -f1)
            backup_file=$(ls -t "$BACKUP_DIR/$desktop_file."* 2>/dev/null | head -n 1)
            if [ -f "$USER_DIR/$desktop_file" ] && [ -n "$backup_file" ]; then
                mv "$backup_file" "$USER_DIR/$desktop_file" || { echo "Error: Failed to restore $USER_DIR/$desktop_file"; exit 1; }
                echo "Restored $USER_DIR/$desktop_file from backup"
                ((reversed_actions++))
            else
                echo "Skipping $USER_DIR/$desktop_file: no backup or already restored"
            fi
            ;;
        CREATED_EXTENSION)
            extension_path="$details"
            if [ -d "$extension_path" ]; then
                rm -rf "$extension_path" || { echo "Error: Failed to remove $extension_path"; exit 1; }
                echo "Removed $extension_path"
                ((reversed_actions++))
            else
                echo "Skipping $extension_path: already removed"
            fi
            ;;
        INSTALLED_EXTENSION)
            extension_path="${details##* -> }"
            if [[ "$extension_path" == *.xpi ]]; then
                if [ -f "$extension_path" ]; then
                    rm "$extension_path" || { echo "Error: Failed to remove $extension_path"; exit 1; }
                    echo "Removed $extension_path"
                    ((reversed_actions++))
                else
                    echo "Skipping $extension_path: already removed"
                fi
            elif [[ "$extension_path" == *extensions.json* ]]; then
                backup_file=$(ls -t "$BACKUP_DIR/extensions.json."* 2>/dev/null | head -n 1)
                if [ -n "$backup_file" ] && [ -f "$EXTENSIONS_JSON" ]; then
                    mv "$backup_file" "$EXTENSIONS_JSON" || { echo "Error: Failed to restore $EXTENSIONS_JSON"; exit 1; }
                    echo "Restored $EXTENSIONS_JSON from backup"
                    ((reversed_actions++))
                else
                    echo "Skipping $EXTENSIONS_JSON: no backup or already restored"
                fi
            fi
            ;;
        BACKUP_JSON)
            continue
            ;;
        CREATED_PROFILE)
            echo "Skipping $details: Profile directory not removed to preserve user data"
            ;;
        COPIED_FONTS)
            font_dir="${details##* -> }"
            if [ -d "$font_dir" ]; then
                rm -rf "$font_dir" || { echo "Error: Failed to remove $font_dir"; exit 1; }
                echo "Removed $font_dir"
                fc-cache -fv "$font_dir" 2>/dev/null || echo "Failed to refresh font cache after removal"
                ((reversed_actions++))
            else
                echo "Skipping $font_dir: already removed"
            fi
            ;;
        CREATED_FONTCONFIG)
            fontconfig_file="$details"
            if [ -f "$fontconfig_file" ]; then
                rm "$fontconfig_file" || { echo "Error: Failed to remove $fontconfig_file"; exit 1; }
                echo "Removed $fontconfig_file"
                ((reversed_actions++))
            else
                echo "Skipping $fontconfig_file: already removed"
            fi
            ;;
        BACKUP_FONTCONFIG)
            fontconfig_file="${details%% -> *}"
            backup_file="${details##* -> }"
            if [ -f "$backup_file" ]; then
                mv "$backup_file" "$fontconfig_file" || { echo "Error: Failed to restore $fontconfig_file"; exit 1; }
                echo "Restored $fontconfig_file from backup"
                ((reversed_actions++))
            else
                echo "Skipping $fontconfig_file: no backup found"
            fi
            ;;
    esac
done < "$LOG_FILE"

[ "$reversed_actions" -eq 0 ] && echo "No actions to undo."

rm -f "$LOG_FILE" && echo "Removed $LOG_FILE"
if [ -d "$BACKUP_DIR" ] && [ -z "$(ls -A "$BACKUP_DIR")" ]; then
    rmdir "$BACKUP_DIR" && echo "Removed empty $BACKUP_DIR"
fi

if [ -d "$SCRIPT_DIR" ] && [ -z "$(ls -A "$SCRIPT_DIR")" ]; then
    rmdir "$SCRIPT_DIR" && echo "Removed empty $SCRIPT_DIR"
fi

if [ -d "$ICON_DIR" ] && [ -z "$(ls -A "$ICON_DIR")" ]; then
    rmdir "$ICON_DIR" && echo "Removed empty $ICON_DIR"
fi

if [ -d "$USER_DIR" ] && [ -z "$(ls -A "$USER_DIR")" ]; then
    rmdir "$USER_DIR" && echo "Removed empty $USER_DIR"
fi

if [ -d "$HOME/.config/brave-extensions" ] && [ -z "$(ls -A "$HOME/.config/brave-extensions")" ]; then
    rmdir "$HOME/.config/brave-extensions" && echo "Removed empty $HOME/.config/brave-extensions"
fi

if [ -d "$EXTENSIONS_DIR" ] && [ -z "$(ls -A "$EXTENSIONS_DIR")" ]; then
    rmdir "$EXTENSIONS_DIR" && echo "Removed empty $EXTENSIONS_DIR"
fi

if [ -d "$STAGING_DIR" ] && [ -z "$(ls -A "$STAGING_DIR")" ]; then
    rmdir "$STAGING_DIR" && echo "Removed empty $STAGING_DIR"
fi

if [ -d "$FONT_DIR" ] && [ -z "$(ls -A "$FONT_DIR")" ]; then
    rmdir "$FONT_DIR" && echo "Removed empty $FONT_DIR"
fi

if [ -d "$SYSTEM_FONTCONFIG_DIR" ] && [ -z "$(ls -A "$SYSTEM_FONTCONFIG_DIR")" ]; then
    rmdir "$SYSTEM_FONTCONFIG_DIR" && echo "Removed empty $SYSTEM_FONTCONFIG_DIR"
fi

echo "Undo completed successfully."
