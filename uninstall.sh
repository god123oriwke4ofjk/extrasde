#!/bin/bash

USER=${USER:-$(whoami)}
[ -z "$USER" ] && { echo "Error: Could not determine username."; exit 1; }

ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
USERPREFS_CONF="/home/$USER/.config/hypr/userprefs.conf"
LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
FIREFOX_PROFILE_DIR=$(grep -E "^Path=" "$HOME/.mozilla/firefox/profiles.ini" | grep -v "default" | head -n 1 | cut -d'=' -f2)
FIREFOX_PREFS_FILE="/home/$USER/.mozilla/firefox/$FIREFOX_PROFILE_DIR/prefs.js"

[ ! -f "$LOG_FILE" ] && { echo "Error: $LOG_FILE not found. Nothing to undo."; exit 1; }

if pgrep firefox > /dev/null; then
    echo "Error: Firefox is running. Please close Firefox before undoing autoscrolling settings."
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

echo "Undo completed successfully."
