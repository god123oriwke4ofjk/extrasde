#!/bin/bash

USER=${USER:-$(whoami)}
VESKTOP_CSS_FILE="/home/$USER/.var/app/dev.vencord.Vesktop/config/vesktop/settings/quickCss.css"
FONT_NAME="Alef"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
LOG_FILE="/home/$USER/.local/lib/hyde/install.log"

FONT_CSS="
/* Custom font for Vesktop */
::placeholder, body, button, input, select, textarea {
    font-family: '$FONT_NAME', sans-serif;
    text-rendering: optimizeLegibility;
}
"

mkdir -p "$BACKUP_DIR" || { echo "Error: Failed to create $BACKUP_DIR"; exit 1; }

if [ -f "$VESKTOP_CSS_FILE" ]; then
    if ! grep -q "font-family: '$FONT_NAME'" "$VESKTOP_CSS_FILE"; then
        cp "$VESKTOP_CSS_FILE" "$BACKUP_DIR/quickCss.css.$(date +%s)" || { echo "Error: Failed to backup $VESKTOP_CSS_FILE"; exit 1; }
        echo "[$(date)] BACKUP_CSS: $VESKTOP_CSS_FILE -> $BACKUP_DIR/quickCss.css.$(date +%s)" >> "$LOG_FILE"
        echo "Created backup of $VESKTOP_CSS_FILE"
        echo "$FONT_CSS" >> "$VESKTOP_CSS_FILE" || { echo "Error: Failed to append font CSS to $VESKTOP_CSS_FILE"; exit 1; }
        echo "[$(date)] MODIFIED_CSS: $VESKTOP_CSS_FILE -> Added custom font CSS for $FONT_NAME" >> "$LOG_FILE"
        echo "Added custom font CSS to $VESKTOP_CSS_FILE"
    else
        echo "[$(date)] SKIPPED: Custom font CSS for $FONT_NAME already present in $VESKTOP_CSS_FILE" >> "$LOG_FILE"
        echo "Custom font CSS already present in $VESKTOP_CSS_FILE"
    fi
else
    mkdir -p "$(dirname "$VESKTOP_CSS_FILE")" || { echo "Error: Failed to create directory for $VESKTOP_CSS_FILE"; exit 1; }
    echo "$FONT_CSS" > "$VESKTOP_CSS_FILE" || { echo "Error: Failed to create $VESKTOP_CSS_FILE with font CSS"; exit 1; }
    echo "[$(date)] CREATED_CSS: $VESKTOP_CSS_FILE -> Added custom font CSS for $FONT_NAME" >> "$LOG_FILE"
    echo "Created $VESKTOP_CSS_FILE with custom font CSS"
fi

exit 0
