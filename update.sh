#!/bin/bash

if [ -d "$HOME/HyDE" ]; then
    HYDE_HOME="$HOME/HyDE"
else
    HYDE_HOME="$HOME/Hyde"
fi

LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
TEMP_FOLDER="/tmp/updateTemp"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
CONFIG_DIR="$HYDE_HOME/Configs"
EXTRA_VPN_SCRIPT="$HOME/Extra/config/keybinds/vpn.sh"
SCRIPT_PATH="$HOME/Extra/update.sh"
NEW_SCRIPT_PATH="$HOME/Extra/update.sh.new"

restore_files() {
    echo "Error occurred, restoring files from $TEMP_FOLDER..."
    if [ -f "$TEMP_FOLDER/install.log" ]; then
        mv "$TEMP_FOLDER/install.log" "$LOG_FILE" 2>/dev/null && echo "Restored $LOG_FILE"
    fi
    if [ -f "$TEMP_FOLDER/keybindings.conf" ] && [ ! -f "$KEYBINDINGS_CONF" ]; then
        mv "$TEMP_FOLDER/keybindings.conf" "$KEYBINDINGS_CONF" 2>/dev/null && echo "Restored $KEYBINDINGS_CONF"
    fi
    rm -rf "$TEMP_FOLDER" 2>/dev/null && echo "Cleaned up $TEMP_FOLDER"
    exit 1
}

set -e
trap restore_files ERR

mkdir -p $TEMP_FOLDER

FORCE_UPDATE=0
if [ "$1" = "-force" ]; then
    FORCE_UPDATE=1
    echo "Force update enabled for HyDE."
fi

check_repo_updates() {
    local repo_dir=$1
    local pull_command=$2
    local repo_name=$(basename "$repo_dir")

    if [ ! -d "$repo_dir" ]; then
        echo "Error: Directory $repo_dir does not exist."
        return 1
    fi

    cd "$repo_dir" || {
        echo "Error: Could not navigate to $repo_dir."
        return 1
    }

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: $repo_dir is not a valid Git repository."
        return 1
    fi

    REMOTE_URL=$(git config --get remote.origin.url)
    if [ -z "$REMOTE_URL" ]; then
        echo "Error: No remote URL found for $repo_name."
        return 1
    fi

    export GIT_ASKPASS=/bin/true

    if [ "$repo_name" = "Extra" ]; then
        if [[ "$REMOTE_URL" =~ ^https:// ]]; then
            git ls-remote --heads >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "The repository $repo_name can be pulled without authentication."
            else
                echo "Warning: The repository $repo_name requires authentication for git pull. Skipping."
                return 2
            fi
        elif [[ "$REMOTE_URL" =~ ^git@ ]]; then
            HOST=$(echo "$REMOTE_URL" | sed -n 's/^git@\([^:]*\):.*/\1/p')
            if [ -z "$HOST" ]; then
                echo "Error: Could not parse hostname from SSH URL: $REMOTE_URL"
                return 1
            fi
            SSH_TEST=$(ssh -T -o StrictHostKeyChecking=no "$HOST" 2>&1)
            if echo "$SSH_TEST" | grep -qi "success\|welcome\|authenticated"; then
                echo "The repository $repo_name can be pulled without authentication (SSH key configured)."
            else
                echo "Warning: The repository $repo_name requires authentication for git pull. Skipping."
                return 2
            fi
        else
            echo "Error: Unrecognized remote URL format: $REMOTE_URL"
            return 1
        fi
    fi

    if ! git fetch origin 2>/dev/null; then
        echo "Error: Failed to fetch updates for $repo_name."
        return 1
    fi

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u} 2>/dev/null)

    if [ -z "$REMOTE" ]; then
        echo "Warning: Remote branch not found for $repo_name. Skipping."
        return 2
    fi

    if [ "$LOCAL" = "$REMOTE" ]; then
        echo "$repo_name is up to date."
        return 0
    else
        echo "$repo_name has updates available. Pulling changes..."
        $pull_command
        if [ $? -eq 0 ]; then
            echo "$repo_name updated successfully."
            return 1
        else
            echo "Error: Failed to update $repo_name."
            return 1
        fi
    fi
}

check_self_update() {
    local script_path="$SCRIPT_PATH"
    local new_script_path="$NEW_SCRIPT_PATH"

    if [ ! -f "$script_path" ]; then
        echo "Error: Current script $script_path not found."
        return 1
    fi

    local current_hash=$(sha256sum "$script_path" | cut -d' ' -f1)

    if [ -f "$new_script_path" ]; then
        echo "Error: $new_script_path already exists, please remove or rename it."
        return 1
    fi

    cp "$script_path" "$new_script_path" 2>/dev/null || {
        echo "Error: Failed to copy $script_path to $new_script_path for comparison."
        return 1
    }

    cd "$HOME/Extra" || {
        echo "Error: Could not navigate to $HOME/Extra."
        return 1
    }

    if ! git fetch origin 2>/dev/null; then
        echo "Error: Failed to fetch updates for Extra repository."
        rm -f "$new_script_path"
        return 1
    fi

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u} 2>/dev/null)

    if [ "$LOCAL" = "$REMOTE" ]; then
        echo "Extra repository is up to date, no self-update check needed."
        rm -f "$new_script_path"
        return 0
    fi

    git pull 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "Extra repository updated successfully."
        if [ -f "$script_path" ]; then
            new_hash=$(sha256sum "$script_path" | cut -d' ' -f1)
            if [ "$current_hash" != "$new_hash" ]; then
                echo "Script $script_path has been updated. Switching to new version..."
                chmod +x "$script_path"
                rm -f "$new_script_path"
                exec "$script_path" "$@"
            else
                echo "Script $script_path unchanged after update."
                rm -f "$new_script_path"
                return 0
            fi
        else
            echo "Error: $script_path missing after update."
            rm -f "$new_script_path"
            return 1
        fi
    else
        echo "Error: Failed to update Extra repository."
        rm -f "$new_script_path"
        return 1
    fi
}

extra_updated=0
hyde_updated=0
vpn_script_existed=0

check_self_update
extra_updated=$?

if [ -f "$SCRIPT_DIR/vpn.sh" ]; then
    vpn_script_existed=1
    echo "Found existing $SCRIPT_DIR/vpn.sh, will check after update."
fi

check_repo_updates "$HOME/Extra" "git pull"
case $? in
    1) extra_updated=1 ;;
    2) echo "Skipping Extra repo update due to access issues." ;;
esac
check_repo_updates "$HYDE_HOME" "git pull origin master" || hyde_updated=1

if [ $extra_updated -eq 0 ] && [ $hyde_updated -eq 0 ] && [ $FORCE_UPDATE -eq 0 ]; then
    echo "Both repositories are up to date. There's nothing to update."
    rm -rf $TEMP_FOLDER
    exit 0
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "Install log file $LOG_FILE not found. Nothing to update."
    rm -rf $TEMP_FOLDER
    exit 0
fi

mv "$LOG_FILE" "$TEMP_FOLDER/install.log" 2>/dev/null || echo "Warning: Failed to move $LOG_FILE to $TEMP_FOLDER/install.log"

if grep -q "MODIFIED_KEYBINDINGS:" "$TEMP_FOLDER/install.log"; then
    echo "Found modified keybinds file, setting it up for update."
    cp "$HYDE_HOME/Configs/.config/hypr/keybindings.conf" "$TEMP_FOLDER/keybindings.conf" 2>/tmp/cp_error
    if grep -q "cannot stat" /tmp/cp_error; then
        if [ ! -f "$HOME/.config/hypr/keybindings.conf" ]; then
            if [ -f "$HOME/.config/hypr/keybindings.conf.save" ]; then
                cp "$HOME/.config/hypr/keybindings.conf.save" "$HOME/.config/hypr/keybindings.conf"
                echo "Restored $HOME/.config/hypr/keybindings.conf from .save"
            else
                cp "$HYDE_HOME/Configs/.config/hypr/keybindings.conf" "$HOME/.config/hypr/keybindings.conf"
                echo "Copied fallback keybindings from HYDE_HOME"
            fi
        fi
    fi
fi

if [ $extra_updated -eq 1 ] || [ $hyde_updated -eq 1 ] || [ $FORCE_UPDATE -eq 1 ]; then
    echo "Updating hyde..."
    cd "$HYDE_HOME/Scripts"
    ./install.sh -r
fi

mv "$TEMP_FOLDER/install.log" "$LOG_FILE" 2>/dev/null || echo "Warning: Failed to restore install.log"

if [ $vpn_script_existed -eq 1 ] || [ $extra_updated -eq 1 ] || [ $FORCE_UPDATE -eq 1 ]; then
    if [ ! -f "$SCRIPT_DIR/vpn.sh" ]; then
        if [ -f "$EXTRA_VPN_SCRIPT" ]; then
            cp "$EXTRA_VPN_SCRIPT" "$SCRIPT_DIR/vpn.sh"
            chmod +x "$SCRIPT_DIR/vpn.sh"
            echo "Moved vpn.sh and made it executable."
            echo "MOVED_SCRIPT: vpn.sh -> $SCRIPT_DIR/vpn.sh" >> "$LOG_FILE"
        else
            echo "Warning: $EXTRA_VPN_SCRIPT not found, cannot restore vpn.sh."
        fi
    else
        echo "$SCRIPT_DIR/vpn.sh still exists after update, no need to move."
    fi
fi

if ! cmp -s "$HOME/.config/hypr/keybindings.conf" "$TEMP_FOLDER/keybindings.conf" 2>/dev/null; then
    echo "Changed keybind.conf, updating..."
    mkdir -p "$HOME/.config/hypr"
    if [ -f "$TEMP_FOLDER/keybindings.conf" ]; then
        cp "$TEMP_FOLDER/keybindings.conf" "$HOME/.config/hypr/keybindings.conf"
        echo "Updated keybindings from temp."
    else
        cp "$HYDE_HOME/Configs/.config/hypr/keybindings.conf" "$HOME/.config/hypr/keybindings.conf"
        echo "Updated keybindings from HYDE_HOME fallback."
    fi
    if grep -q "MODIFIED_KEYBINDINGS:" "$LOG_FILE"; then
        cd "$HOME/Extra"
        mkdir -p "$BACKUP_DIR"
        if [ -f "$KEYBINDINGS_CONF" ]; then
            find "$BACKUP_DIR" -type f -name "keybindings.conf.bak" -delete
            cp "$KEYBINDINGS_CONF" "$BACKUP_DIR/keybindings.conf.bak"
            echo "BACKUP_CONFIG: $KEYBINDINGS_CONF -> $BACKUP_DIR/keybindings.conf.bak" >> "$LOG_FILE"
            echo "Backed up keybindings.conf"
        fi
        bash "$HOME/Extra/install.sh" --keybind || {
            echo "Error: Failed to run install.sh --keybind"
            restore_files
        }
        echo "Ran install.sh --keybind"
        echo "MODIFIED_KEYBINDINGS: Updated via install.sh --keybind" >> "$LOG_FILE"
    fi
fi

rm -rf $TEMP_FOLDER
trap - ERR

echo "Update successfully completed"
exit 0
