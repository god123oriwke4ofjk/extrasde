#!/bin/bash

LOG_FILE="/home/$USER/.local/lib/hyde/install.log"
SCRIPT_DIR="/home/$USER/.local/lib/hyde"
ICON_DIR="/home/$USER/.local/share/icons/Wallbash-Icon"
KEYBINDINGS_CONF="/home/$USER/.config/hypr/keybindings.conf"
TEMP_FOLDER="/tmp/updateTemp"
BACKUP_DIR="/home/$USER/.local/lib/hyde/backups"
CONFIG_DIR="$HOME/HyDE/Configs"

mkdir -p $TEMP_FOLDER

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

    if ! git fetch origin 2>/dev/null; then
        if [ "$repo_name" = "Extra" ]; then
            echo "Warning: Unable to access Extra repository (may be private). Skipping."
            return 0
        else
            echo "Error: Failed to fetch updates for $repo_name."
            return 1
        fi
    fi

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u} 2>/dev/null)

    if [ -z "$REMOTE" ]; then
        echo "Warning: Remote branch not found for $repo_name. Skipping."
        return 0
    fi

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
    echo "Both repositories are up to date. There's nothing to update."
    rm -rf $TEMP_FOLDER
    exit 0
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "Install log file $LOG_FILE not found. Nothing to update."
    rm -rf $TEMP_FOLDER
    exit 0
fi

if grep -q "MODIFIED_KEYBINDINGS:" "$LOG_FILE"; then
    echo "Found modified keybinds file, setting it up for update."
    mv $HOME/HyDE/Configs/.config/hypr/keybindings.conf $TEMP_FOLDER
fi

if [ $extra_updated -eq 1 ]; then
    echo "Updating hyde..."
    cd $HOME/HyDE/Scripts
    ./install.sh -r
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
        VPN_LINE="bindd = \$mainMod, V, \$d toggle vpn, exec, \$scrPath/vpn.sh toggle # toggle vpn"
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
