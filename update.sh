#!/bin/bash

LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
TEMP_FOLDER='/tmp/updateTemp'

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Install log file $LOG_FILE not found. Nothing to update."
    exit 1
fi

cd ~/HyDE/Scripts
git pull origin master
./install.sh -r

cd ~/Extra
git pull
./install.sh
