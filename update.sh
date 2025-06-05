#!/bin/bash

LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
TEMP_FOLDER="/tmp/updateTemp"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
CONFIG_DIR="$HOME/HyDE/Configs"
EXTRA_VPN_SCRIPT="$HOME/Extra/config/keybinds/vpn.sh"

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

extra_updated=0
hyde_updated=0
vpn_script_existed=0

if [ -f "$SCRIPT_DIR/vpn.sh" ]; then
    vpn_script_existed=1
    echo "Found existing $SCRIPT_DIR/vpn.sh, will check after update."
fi

check_repo_updates "$HOME/Extra" "git pull"
case $? in
    1) extra_updated=1 ;;
    2) echo "Skipping Extra repo update due to access issues." ;;
esac
check_repo_updates "$HOME/HyDE" "git pull origin master" || hyde_updated=1

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
    cp "$HOME/HyDE/Configs/.config/hypr/keybindings.conf" "$TEMP_FOLDER/keybindings.conf" 2>/tmp/cp_error
    if grep -q "cannot stat" /tmp/cp_error; then
        if [ ! -f "$HOME/.config/hypr/keybindings.conf" ]; then
            if [ -f "$HOME/.config/hypr/keybindings.conf.save" ]; then
                cp "$HOME/.config/hypr/keybindings.conf.save" "$HOME/.config/hypr/keybindings.conf"
                echo "Restored $HOME/.config/hypr/keybindings.conf from $HOME/.config/hypr/keybindings.conf.save"
            else
                cp "$HOME/HyDE/Configs/.config/hypr/keybindings.conf" "$HOME/.config/hypr/keybindings.conf"
                echo "Copied $HOME/HyDE/Configs/.config/hypr/keybindings.conf to $HOME/.config/hypr/keybindings.conf"
            fi
            hyprctl reload
        fi
    fi
fi

if [ $extra_updated -eq 1 ] || [ $hyde_updated -eq 1 ] || [ $FORCE_UPDATE -eq 1 ]; then
    echo "Updating hyde..."
    cd $HOME/HyDE/Scripts
    ./install.sh -r
fi

mv "$TEMP_FOLDER/install.log" "$LOG_FILE" 2>/dev/null || echo "Warning: Failed to move $TEMP_FOLDER/install.log back to $LOG_FILE"

if [ $vpn_script_existed -eq 1 ] && [ $extra_updated -eq 1 ]; then
    if [ ! -f "$SCRIPT_DIR/vpn.sh" ]; then
        if [ -f "$EXTRA_VPN_SCRIPT" ]; then
            cp "$EXTRA_VPN_SCRIPT" "$SCRIPT_DIR/vpn.sh"
            chmod +x "$SCRIPT_DIR/vpn.sh"
            echo "Moved $EXTRA_VPN_SCRIPT to $SCRIPT_DIR/vpn.sh and made it executable."
            echo "MOVED_SCRIPT: vpn.sh -> $SCRIPT_DIR/vpn.sh" >> "$LOG_FILE"
        else
            echo "Warning: $EXTRA_VPN_SCRIPT not found, cannot move to $SCRIPT_DIR/vpn.sh."
        fi
    else
        echo "$SCRIPT_DIR/vpn.sh still exists after update, no need to move."
    fi
fi

if ! cmp -s $HOME/.config/hypr/keybindings.conf $TEMP_FOLDER/keybindings.conf; then
    echo "Changed keybind.conf, remaking it"
    rm $HOME/.config/hypr/keybindings.conf 
    mv $TEMP_FOLDER/keybindings.conf $HOME/.config/hypr
    if grep -q "MODIFIED_KEYBINDINGS:" "$LOG_FILE"; then
        cd $HOME/Extra
        if [ -f "$KEYBINDINGS_CONF" ]; then
            find "$BACKUP_DIR" -type f -name "keybindings.conf.bak" -delete
            cp "$KEYBINDINGS_CONF" "$BACKUP_DIR/keybindings.conf.bak"
            echo "BACKUP_CONFIG: $KEYBINDINGS_CONF -> $BACKUP_DIR/keybindings.conf.bak" >> "$LOG_FILE"
            echo "Backed up $KEYBINDINGS_CONF to $BACKUP_DIR/keybindings.conf.bak"
        fi
        VPN_LINE="bindd = \$mainMod Alt, V, \$d toggle vpn, exec, \$scrPath/vpn.sh toggle # toggle vpn"
        if grep -Fx "$VPN_LINE" "$KEYBINDINGS_CONF" > /dev/null; then
            echo "Skipping: VPN binding already exists in $KEYBINDINGS_CONF"
        else
            UTILITIES_START='$d=[$ut]'
            temp_file=$(mktemp)
            if ! grep -q "$UTILITIES_START" "$KEYBINDINGS_CONF"; then
                echo "Appending Utilities section to $KEYBINDINGS_CONF"
                echo -e "\n$UTILITIES_START\n$VPN_LINE" >> "$KEYBINDINGS_CONF"
                echo "DEBUG: Appended Utilities section with VPN binding" >> "$LOG_FILE"
                echo "MODIFIED_KEYBINDINGS: Added Utilities section with VPN binding" >> "$LOG_FILE"
            else
                awk -v vpn_line="$VPN_LINE" -v util_start="$UTILITIES_START" '
                    BEGIN { found_util=0; added=0 }
                    $0 ~ util_start { found_util=1; print; next }
                    found_util && !added && /^[[:space:]]*$/ { print vpn_line "\n"; added=1; print; next }
                    found_util && !added && /^\$d=/ { print vpn_line "\n"; added=1; print; next }
                    found_util && !added && !/^[[:space:]]*$/ && !/^bind/ { print vpn_line "\n"; added=1; print; next }
                    { print }
                    END { if (found_util && !added) print vpn_line }
                ' "$KEYBINDINGS_CONF" > "$temp_file"
                mv "$temp_file" "$KEYBINDINGS_CONF"
                echo "Added VPN binding to Utilities section in $KEYBINDINGS_CONF"
                echo "DEBUG: Added VPN binding to Utilities section" >> "$LOG_FILE"
                echo "MODIFIED_KEYBINDINGS: Added VPN binding to Utilities section" >> "$LOG_FILE"
            fi
        fi
        declare -A keybind_scripts
        keybind_scripts["vpn.sh"]="$CONFIG_DIR/vpn.sh"
        for script_name in "${!keybind_scripts[@]}"; do
            src_script="${keybind_scripts[$script_name]}"
            script_path="$SCRIPT_DIR/$script_name"
            if [ ! -f "$src_script" ]; then
                echo "Warning: Source script $src_script not found. Skipping."
                continue
            fi
            if [ -f "$script_path" ]; then
                echo "Warning: $script_path already exists."
                src_hash=$(sha256sum "$src_script" | cut -d' ' -f1)
                tgt_hash=$(sha256sum "$script_path" | cut -d' ' -f1)
                if [ "$src_hash" = "$tgt_hash" ]; then
                    echo "$script_path has identical content, checking permissions."
                    [ -x "$script_path" ] || { chmod +x "$script_path"; echo "Made $script_path executable."; }
                else
                    echo "$script_path has different content."
                    read -p "Replace $script_path with content from $src_script? [y/N]: " replace_script
                    if [[ "$replace_script" =~ ^[Yy]$ ]]; then
                        current_timestamp=$(date +%s)
                        cp "$script_path" "$BACKUP_DIR/$script_name.$current_timestamp"
                        cp "$src_script" "$script_path"
                        chmod +x "$script_path"
                        echo "Replaced and made $script_path executable."
                        echo "REPLACED_SCRIPT: $script_name -> $script_path" >> "$LOG_FILE"
                    else
                        echo "Skipping replacement of $script_path."
                        [ -x "$script_path" ] || { chmod +x "$script_path"; echo "Made $script_path executable."; }
                    fi
                fi
            else
                cp "$src_script" "$script_path"
                chmod +x "$script_path"
                echo "Created and made $script_path executable."
                echo "CREATED_SCRIPT: $script_name -> $script_path" >> "$LOG_FILE"
            fi
            ls -l "$script_path"
        done
    fi
fi

rm -rf $TEMP_FOLDER

echo "Updated successfully completed"
exit 0
