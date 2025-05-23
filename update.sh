#!/bin/bash

LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
TEMP_FOLDER='/tmp/updateTemp'
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"

mkdir $TEMP_FOLDER

check_repo_updates() {
    local repo_dir=$1
    local pull_command=$2
    local repo_name=$(basename "$repo_dir")

    if  ! -d "$repo_dir" ; then
        echo "Error: Directory $repo_dir does not exist."
        return 1
    }

    cd "$repo_dir" || {
        echo "Error: Could not navigate to $repo_dir."
        return 1
    }

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: $repo_dir is not a valid Git repository."
        return 1
    }

    git fetch origin

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u})

    if [ "$LOCAL" = "$REMOTE" ]; then
        echo "$repo_name is up to date."
        return 0
    else
        echo "$repo_name has updates available. Pulling changes..."
        $pull_command
        if [ $? -eq 0 ]; then
            echo "$repo_name updated successfully."
        else
            echo "Error: Failed to update $repo_name."
        fi
        return 1
    fi
}

extra_updated=0
hyde_updated=0

check_repo_updates "$HOME/Extra" "git pull" || extra_updated=1
check_repo_updates "$HOME/HyDE" "git pull origin master" || hyde_updated=1

if [ $extra_updated -eq 0 ] && [ $hyde_updated -eq 0 ]; then
    echo "Both repositories are up to date. Theres nothing to update."
    exit 0
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "Install log file $LOG_FILE not found. Nothing to update."
    exit 0
fi

if grep -q "MODIFIED_KEYBINDINGS:" "$LOG_FILE"; then
    echo "Found modifed keybinds file, setting it up for update."
    mv $HOME/HyDE/Configs/.config/hypr/keybindings.conf $TEMP_FOLDER
fi

if [ $extra_updated -eq 1 ]; then
    echo "Updating hyde..."
    cd $HOME/HyDE/Scripts
    ./install.sh -r
fi

if cmp -s $HOME/.config/hypr/keybindings.conf $TEMP_FOLDER/keybindings.conf; then
    echo "Changed keybind.conf, remaking it"
    rm $HOME/.config/hypr/keybindings.conf 
    mv $TEMP_FOLDER/keybindings.conf $HOME/.config/hypr
    if grep -q "MODIFIED_KEYBINDINGS:" "$LOG_FILE"; then
        cd $HOME/Extra
        ./install.sh --keybind
    fi
fi

rm -rf $TEMP_FOLDER

echo "Updated successfully completed"
exit 0
