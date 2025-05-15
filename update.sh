#!/bin/bash

LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
TEMP_FOLDER='/tmp/updateTemp'
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"

mkdir $TEMP_FOLDER

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Install log file $LOG_FILE not found. Nothing to update."
    exit 1
fi

if grep -q "MODIFIED_KEYBINDINGS:" "$LOG_FILE"; then
    echo "Found modifed keybinds file, setting it up for update."
    mv "$BACKUP_DIR/keybindings.conf.bak" ~/.config/hypr/keybindings.conf
fi

cd ~/HyDE/Scripts
git pull origin master
./install.sh -r

cd ~/Extra
git pull
./install.sh

rm -rf $TEMP_FOLDER
