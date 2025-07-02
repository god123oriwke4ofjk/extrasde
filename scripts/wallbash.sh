#!/bin/bash

set -euo pipefail

ALWAYS="$HOME/.config/hyde/wallbash/always"
SCRIPTS="$HOME/.config/hyde/wallbash/scripts"
SPICETIFY_CSS_DEST="$HOME/.config/spicetify/Themes/text/user.css"
SPICETIFY_CSS_URL="https://raw.githubusercontent.com/spicetify/spicetify-themes/refs/heads/master/text/user.css"
SWAYNC_CONFIG_DIR="$HOME/.config/swaync"
CONFIG_TOML="$HOME/.config/hyde/config.toml"

APPS=("netflix" "steam" "obs" "zen" "spotify" "swaync" "anki")
CONFIG_APPS=("anki") 

usage() {
    echo "Usage: $0 [-all | -netflix | -steam | -obs | -zen | -spotify | -swaync | -anki] [...]"
    echo "       $0 -config [-all | -anki] [...]"
    echo "       $0 -remove [-all | -netflix | -steam | -obs | -zen | -spotify | -swaync | -anki]"
    echo "       $0 -remove -config [-all | -anki]"
    echo "At least one parameter is required."
    echo "-all: Install/remove for all applications."
    echo "-config: Install using alternative configuration method (currently supports: anki)."
    echo "Stack parameters to install for multiple apps (e.g., -netflix -steam)."
    echo "For removal, use -remove with -all or an app (e.g., -remove -netflix)."
    echo "For config removal, use -remove -config with -all or an app (e.g., -remove -config -anki)."
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

cleanup() {
    rm -rf /tmp/netflixWallbash /tmp/steamWallbash /tmp/obsWallbash /tmp/zenWallbash /tmp/spotifyWallbash /tmp/SwayNC-Wallbash /tmp/ankiWallbash /tmp/ankiDotfiles
}
trap cleanup EXIT

install_netflix() {
    echo "Checking for Netflix..."
    if command_exists yay && yay -Qs netflix >/dev/null 2>&1; then
        echo "Installing Netflix wallbash"
        NETFLIX_REPO="https://github.com/god123oriwke4ofjk/netflix-wallbash"
        git clone "$NETFLIX_REPO" /tmp/netflixWallbash || { echo "Error: Failed to clone Netflix wallbash repository"; exit 1; }
        cd /tmp/netflixWallbash || { echo "Error: Failed to change to /tmp/netflixWallbash"; exit 1; }
        if [ -f setup.sh ]; then
            chmod +x setup.sh || { echo "Error: Failed to make setup.sh executable"; exit 1; }
            ./setup.sh || { echo "Error: Failed to run setup.sh for Netflix wallbash"; exit 1; }
        else
            echo "Error: setup.sh not found in Netflix wallbash repository"
            exit 1
        fi
        cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
        echo "Successfully installed Netflix wallbash theme"
    else
        echo "Netflix not found (not installed via AUR). Skipping Netflix wallbash setup."
    fi
}

remove_netflix() {
    echo "Removing Netflix wallbash..."
    if [ -d /tmp/netflixWallbash ]; then
        cd /tmp/netflixWallbash || { echo "Error: Failed to change to /tmp/netflixWallbash"; exit 1; }
        if [ -f setup.sh ]; then
            chmod +x setup.sh || { echo "Error: Failed to make setup.sh executable"; exit 1; }
            ./setup.sh -remove || { echo "Error: Failed to run setup.sh -remove"; exit 1; }
            echo "Ran setup.sh -remove"
        fi
        cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
    fi
    if [ -f "$ALWAYS/netflix.dcol" ]; then
        rm -f "$ALWAYS/netflix.dcol" || { echo "Error: Failed to remove netflix.dcol"; exit 1; }
        echo "Removed $ALWAYS/netflix.dcol"
    fi
    if [ -f "$SCRIPTS/netflix.sh" ]; then
        rm -f "$SCRIPTS/netflix.sh" || { echo "Error: Failed to remove netflix.sh"; exit 1; }
        echo "Removed $SCRIPTS/netflix.sh"
    fi
    echo "Netflix wallbash removed"
}

install_anki() {
    echo "Checking for Anki..."
    if pacman -Qs anki >/dev/null 2>&1 || (command_exists yay && yay -Qs anki >/dev/null 2>&1) || flatpak list | grep -q net.ankiweb.Anki; then
        echo "Installing Anki wallbash"
        ANKI_REPO="https://github.com/god123oriwke4ofjk/anki-wallbash"
        git clone "$ANKI_REPO" /tmp/ankiWallbash || { echo "Error: Failed to clone Anki wallbash repository"; exit 1; }
        cd /tmp/ankiWallbash || { echo "Error: Failed to change to /tmp/ankiWallbash"; exit 1; }
        if [ -f setup_anki_wallbash.sh ]; then
            chmod +x setup_anki_wallbash.sh || { echo "Error: Failed to make setup_anki_wallbash.sh executable"; exit 1; }
            ./setup_anki_wallbash.sh || { echo "Error: Failed to run setup_anki_wallbash.sh for Anki wallbash"; exit 1; }
        else
            echo "Error: setup_anki_wallbash.sh not found in Anki wallbash repository"
            exit 1
        fi
        cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
        echo "Successfully installed Anki wallbash theme"
    else
        echo "Anki not found (not installed via pacman, AUR, or Flatpak). Skipping Anki wallbash setup."
    fi
}

remove_anki() {
    echo "Removing Anki wallbash..."
    if [ -d /tmp/ankiWallbash ]; then
        cd /tmp/ankiWallbash || { echo "Error: Failed to change to /tmp/ankiWallbash"; exit 1; }
        if [ -f setup_anki_wallbash.sh ]; then
            chmod +x setup_anki_wallbash.sh || { echo "Error: Failed to make setup_anki_wallbash.sh executable"; exit 1; }
            ./setup_anki_wallbash.sh -remove || { echo "Error: Failed to run setup_anki_wallbash.sh -remove"; exit 1; }
            echo "Ran setup_anki_wallbash.sh -remove"
        fi
        cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
    fi
    if [ -f "$ALWAYS/anki.dcol" ]; then
        rm -f "$ALWAYS/anki.dcol" || { echo "Error: Failed to remove anki.dcol"; exit 1; }
        echo "Removed $ALWAYS/anki.dcol"
    fi
    if [ -f "$SCRIPTS/anki.sh" ]; then
        rm -f "$SCRIPTS/anki.sh" || { echo "Error: Failed to remove anki.sh"; exit 1; }
        echo "Removed $SCRIPTS/anki.sh"
    fi
    echo "Anki wallbash removed"
}

install_config_anki() {
    echo "Checking for Anki..."
    if pacman -Qs anki >/dev/null 2>&1 || (command_exists yay && yay -Qs anki >/dev/null 2>&1) || flatpak list | grep -q net.ankiweb.Anki; then
        echo "Installing Anki configuration via dotfiles"
        ANKI_DOTFILES_REPO="https://github.com/god123oriwke4ofjk/anki-dotfiles"
        git clone "$ANKI_DOTFILES_REPO" /tmp/ankiDotfiles || { echo "Error: Failed to clone Anki dotfiles repository"; exit 1; }
        cd /tmp/ankiDotfiles || { echo "Error: Failed to change to /tmp/ankiDotfiles"; exit 1; }

        ANKI2_DIR="$HOME/.local/share/Anki2"
        BACKUP_DIR="$HOME/.local/share/Anki2_backup_$(date +%Y%m%d_%H%M%S)"
        if [ -d "$ANKI2_DIR" ]; then
            echo "Backing up $ANKI2_DIR to $BACKUP_DIR"
            mv "$ANKI2_DIR" "$BACKUP_DIR" || { echo "Error: Failed to backup $ANKI2_DIR"; exit 1; }
        fi

        if [ -d .local/share/Anki2 ]; then
            mkdir -p "$(dirname "$ANKI2_DIR")"
            cp -r .local/share/Anki2 "$ANKI2_DIR" || { echo "Error: Failed to copy Anki2 directory"; exit 1; }
            echo "Copied Anki2 directory to $ANKI2_DIR"
        else
            echo "Error: .local/share/Anki2 not found in anki-dotfiles repository"
            exit 1
        fi

        if [ -f .config/hyde/wallbash/always/anki.dcol ]; then
            mkdir -p "$ALWAYS"
            cp -f .config/hyde/wallbash/always/anki.dcol "$ALWAYS/anki.dcol" || { echo "Error: Failed to copy anki.dcol"; exit 1; }
            echo "Copied anki.dcol to $ALWAYS"
        else
            echo "Error: .config/hyde/wallbash/always/anki.dcol not found in anki-dotfiles repository"
            exit 1
        fi

        if [ -f .config/hyde/wallbash/scripts/anki.sh ]; then
            mkdir -p "$SCRIPTS"
            cp -f .config/hyde/wallbash/scripts/anki.sh "$SCRIPTS/anki.sh" || { echo "Error: Failed to copy anki.sh"; exit 1; }
            chmod +x "$SCRIPTS/anki.sh" || { echo "Error: Failed to set permissions on anki.sh"; exit 1; }
            echo "Copied anki.sh to $SCRIPTS"
        else
            echo "Error: .config/hyde/wallbash/scripts/anki.sh not found in anki-dotfiles repository"
            exit 1
        fi

        cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
        echo "Successfully installed Anki configuration via dotfiles"
    else
        echo "Anki not found (not installed via pacman, AUR, or Flatpak). Skipping Anki configuration setup."
    fi
}

remove_config_anki() {
    echo "Removing Anki configuration..."
    ANKI2_DIR="$HOME/.local/share/Anki2"
    BACKUP_DIR=$(find "$HOME/.local/share" -maxdepth 1 -type d -name 'Anki2_backup_*' | sort -r | head -n 1)
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        echo "Restoring $BACKUP_DIR to $ANKI2_DIR"
        rm -rf "$ANKI2_DIR" || { echo "Error: Failed to remove current $ANKI2_DIR"; exit 1; }
        mv "$BACKUP_DIR" "$ANKI2_DIR" || { echo "Error: Failed to restore $BACKUP_DIR"; exit 1; }
        echo "Restored $ANKI2_DIR from backup"
    else
        echo "No backup found for $ANKI2_DIR. Removing current directory if it exists."
        rm -rf "$ANKI2_DIR" || { echo "Error: Failed to remove $ANKI2_DIR"; exit 1; }
    fi

    if [ -f "$ALWAYS/anki.dcol" ]; then
        rm -f "$ALWAYS/anki.dcol" || { echo "Error: Failed to remove anki.dcol"; exit 1; }
        echo "Removed $ALWAYS/anki.dcol"
    fi

    if [ -f "$SCRIPTS/anki.sh" ]; then
        rm -f "$SCRIPTS/anki.sh" || { echo "Error: Failed to remove anki.sh"; exit 1; }
        echo "Removed $SCRIPTS/anki.sh"
    fi

    echo "Anki configuration removed"
}

install_steam() {
    echo "Checking for Steam..."
    if pacman -Qs steam >/dev/null 2>&1 || (command_exists yay && yay -Qs steam >/dev/null 2>&1) || flatpak list | grep -q com.valvesoftware.Steam; then
        echo "Installing Steam wallbash"
        git clone https://github.com/dim-ghub/Steam-Wallbash /tmp/steamWallbash || { echo "Error: Failed to clone Steam wallbash repository"; exit 1; }
        cd /tmp/steamWallbash || { echo "Error: Failed to change to /tmp/steamWallbash"; exit 1; }
        if ls .config/hyde/wallbash/always/*.dcol >/dev/null 2>&1; then
            for file in .config/hyde/wallbash/always/*.dcol; do
                dest="$ALWAYS/$(basename "$file")"
                if [ ! -f "$dest" ] || ! cmp -s "$file" "$dest"; then
                    cp -f "$file" "$ALWAYS" || { echo "Error: Failed to copy $(basename "$file") to $ALWAYS"; exit 1; }
                fi
            done
        else
            echo "Error: No .dcol files found in Steam wallbash repository"
            exit 1
        fi
        if [ -f .config/hyde/wallbash/scripts/steam.sh ]; then
            if [ ! -f "$SCRIPTS/steam.sh" ] || ! cmp -s .config/hyde/wallbash/scripts/steam.sh "$SCRIPTS/steam.sh"; then
                cp -f .config/hyde/wallbash/scripts/steam.sh "$SCRIPTS/steam.sh" || { echo "Error: Failed to copy steam.sh to $SCRIPTS"; exit 1; }
                chmod +x "$SCRIPTS/steam.sh" || { echo "Error: Failed to grant permissions to $SCRIPTS/steam.sh"; exit 1; }
            fi
            "$SCRIPTS/steam.sh" || { echo "Error: Failed to run steam.sh"; exit 1; }
        else
            echo "Error: steam.sh not found in Steam wallbash repository"
            exit 1
        fi
        cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
        echo "Successfully installed Steam wallbash theme. Please follow the instructions to set it up:"
        echo "Open Steam, enter Big Picture Mode, press Control + 2 to open the panel. Navigate to the plugin store and install CSS Loader. Then in the new CSS Loader menu, click refresh and enable the two themes. You can now exit Big Picture Mode by pressing Mod + Q."
    else
        echo "Steam not found (not installed via pacman, AUR, or Flatpak). Skipping Steam wallbash setup."
    fi
}

remove_steam() {
    echo "Removing Steam wallbash..."
    if [ -f "$ALWAYS/steam.dcol" ]; then
        rm -f "$ALWAYS/steam.dcol" || { echo "Error: Failed to remove steam.dcol"; exit 1; }
        echo "Removed $ALWAYS/steam.dcol"
    fi
    if [ -f "$SCRIPTS/steam.sh" ]; then
        rm -f "$SCRIPTS/steam.sh" || { echo "Error: Failed to remove steam.sh"; exit 1; }
        echo "Removed $SCRIPTS/steam.sh"
    fi
    echo "Steam wallbash removed"
}

install_obs() {
    echo "Checking for OBS..."
    if pacman -Qs obs-studio >/dev/null 2>&1 || (command_exists yay && yay -Qs obs-studio >/dev/null 2>&1) || flatpak list | grep -q com.obsproject.Studio; then
        echo "Installing OBS wallbash"
        git clone https://github.com/dim-ghub/OBS-wallbash /tmp/obsWallbash || { echo "Error: Failed to clone OBS wallbash repository"; exit 1; }
        cd /tmp/obsWallbash || { echo "Error: Failed to change to /tmp/obsWallbash"; exit 1; }
        if ls .config/hyde/wallbash/always/*.dcol >/dev/null 2>&1; then
            for file in .config/hyde/wallbash/always/*.dcol; do
                dest="$ALWAYS/$(basename "$file")"
                if [ ! -f "$dest" ] || ! cmp -s "$file" "$dest"; then
                    cp -f "$file" "$ALWAYS" || { echo "Error: Failed to copy $(basename "$file") to $ALWAYS"; exit 1; }
                fi
            done
        else
            echo "Error: No .dcol files found in OBS wallbash repository"
            exit 1
        fi
        if [ -f .config/hyde/wallbash/scripts/obs.sh ]; then
            if [ ! -f "$SCRIPTS/obs.sh" ] || ! cmp -s .config/hyde/wallbash/scripts/obs.sh "$SCRIPTS/obs.sh"; then
                cp -f .config/hyde/wallbash/scripts/obs.sh "$SCRIPTS/obs.sh" || { echo "Error: Failed to copy obs.sh to $SCRIPTS"; exit 1; }
                chmod +x "$SCRIPTS/obs.sh" || { echo "Error: Failed to grant permissions to $SCRIPTS/obs.sh"; exit 1; }
            fi
            "$SCRIPTS/obs.sh" || { echo "Error: Failed to run obs.sh"; exit 1; }
        else
            echo "Error: obs.sh not found in OBS wallbash repository"
            exit 1
        fi
        cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
        echo "Successfully installed OBS wallbash theme. Please follow the instructions to set it up:"
        echo "Open OBS, go to File > Settings > Appearance, then in the Theme menu choose Catppuccin and in the Style option choose Wallbash. Note: this theme does not automatically refresh when switching wallpapers, so you will need to manually refresh it."
    else
        echo "OBS not found (not installed via pacman, AUR, or Flatpak). Skipping OBS wallbash setup."
    fi
}

remove_obs() {
    echo "Removing OBS wallbash..."
    if [ -f "$ALWAYS/obs.dcol" ]; then
        rm -f "$ALWAYS/obs.dcol" || { echo "Error: Failed to remove obs.dcol"; exit 1; }
        echo "Removed $ALWAYS/obs.dcol"
    fi
    if [ -f "$SCRIPTS/obs.sh" ]; then
        rm -f "$SCRIPTS/obs.sh" || { echo "Error: Failed to remove obs.sh"; exit 1; }
        echo "Removed $SCRIPTS/obs.sh"
    fi
    echo "OBS wallbash removed"
}

install_zen() {
    echo "Checking for Zen Browser..."
    if pacman -Qs zen-browser >/dev/null 2>&1; then
        echo "Installing Zen-Browser wallbash"
        git clone https://github.com/dim-ghub/ZenBash /tmp/zenWallbash || { echo "Error: Failed to clone Zen-Browser wallbash repository"; exit 1; }
        cd /tmp/zenWallbash || { echo "Error: Failed to change to /tmp/zenWallbash"; exit 1; }
        if ls .config/hyde/wallbash/always/*.dcol >/dev/null 2>&1; then
            for file in .config/hyde/wallbash/always/*.dcol; do
                dest="$ALWAYS/$(basename "$file")"
                if [ ! -f "$dest" ] || ! cmp -s "$file" "$dest"; then
                    cp -f "$file" "$ALWAYS" || { echo "Error: Failed to copy $(basename "$file") to $ALWAYS"; exit 1; }
                fi
            done
        else
            echo "Error: No .dcol files found in Zen-Browser wallbash repository"
            exit 1
        fi
        if [ -f .config/hyde/wallbash/scripts/ZenBash.sh ]; then
            if [ ! -f "$SCRIPTS/ZenBash.sh" ] || ! cmp -s .config/hyde/wallbash/scripts/ZenBash.sh "$SCRIPTS/ZenBash.sh"; then
                cp -f .config/hyde/wallbash/scripts/ZenBash.sh "$SCRIPTS/ZenBash.sh" || { echo "Error: Failed to copy ZenBash.sh to $SCRIPTS"; exit 1; }
                chmod +x "$SCRIPTS/ZenBash.sh" || { echo "Error: Failed to grant permissions to $SCRIPTS/ZenBash.sh"; exit 1; }
            fi
            "$SCRIPTS/ZenBash.sh" || { echo "Error: Failed to run ZenBash.sh"; exit 1; }
        else
            echo "Error: ZenBash.sh not found in Zen-Browser wallbash repository"
            exit 1
        fi
        cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
        echo "Successfully installed Zen-Browser wallbash theme"
    else
        echo "Zen Browser not found (not installed via pacman). Skipping Zen-Browser wallbash setup."
    fi
}

remove_zen() {
    echo "Removing Zen-Browser wallbash..."
    if [ -f "$ALWAYS/zen.dcol" ]; then
        rm -f "$ALWAYS/zen.dcol" || { echo "Error: Failed to remove zen.dcol"; exit 1; }
        echo "Removed $ALWAYS/zen.dcol"
    fi
    if [ -f "$SCRIPTS/ZenBash.sh" ]; then
        rm -f "$SCRIPTS/ZenBash.sh" || { echo "Error: Failed to remove ZenBash.sh"; exit 1; }
        echo "Removed $SCRIPTS/ZenBash.sh"
    fi
    echo "Zen-Browser wallbash removed"
}

install_spotify() {
    echo "Checking for Spotify..."
    if pacman -Qs spotify >/dev/null 2>&1 || (command_exists yay && yay -Qs spotify >/dev/null 2>&1) || flatpak list | grep -q com.spotify.Client; then
        echo "Setting up spicetify"
        if [ -d /opt/spotify ]; then
            sudo chmod a+wr /opt/spotify
            sudo chmod a+wr /opt/spotify/Apps -R
        else
            echo "Warning: /opt/spotify not found. Skipping permission changes."
        fi
        if command_exists yay; then
            yay -S spicetify-cli || { echo "Error: Failed to install spicetify-cli"; exit 1; }
        else
            echo "Error: 'yay' not found. Please install spicetify-cli manually or ensure an AUR helper is available."
            exit 1
        fi
        curl -sSL "$SPICETIFY_CSS_URL" -o "$SPICETIFY_CSS_DEST" || { echo "Error: Failed to download user.css"; exit 1; }
        git clone --depth 1 https://github.com/dim-ghub/Wallbash-TUIs.git /tmp/spotifyWallbash || { echo "Error: Failed to clone Wallbash-TUIs repository"; exit 1; }
        cd /tmp/spotifyWallbash || { echo "Error: Failed to change to /tmp/spotifyWallbash"; exit 1; }
        if [ -f .config/hyde/wallbash/always/spotify.dcol ]; then
            if [ ! -f "$ALWAYS/spotify.dcol" ] || ! cmp -s .config/hyde/wallbash/always/spotify.dcol "$ALWAYS/spotify.dcol"; then
                cp -f .config/hyde/wallbash/always/spotify.dcol "$ALWAYS/spotify.dcol" || { echo "Error: Failed to copy spotify.dcol"; exit 1; }
            fi
        else
            echo "Error: spotify.dcol not found in Wallbash-TUIs repository"
            exit 1
        fi
        if [ -f .config/hyde/wallbash/scripts/spotify.sh ]; then
            if [ ! -f "$SCRIPTS/spotify.sh" ] || ! cmp -s .config/hyde/wallbash/scripts/spotify.sh "$SCRIPTS/spotify.sh"; then
                cp -f .config/hyde/wallbash/scripts/spotify.sh "$SCRIPTS/spotify.sh" || { echo "Error: Failed to copy spotify.sh to $SCRIPTS"; exit 1; }
                chmod +x "$SCRIPTS/spotify.sh" || { echo "Error: Failed to set permissions on spotify.sh"; exit 1; }
            fi
            "$SCRIPTS/spotify.sh" || { echo "Error: Failed to run spotify.sh"; exit 1; }
        else
            echo "Error: spotify.sh not found in Wallbash-TUIs repository"
            exit 1
        fi
        spicetify config current_theme text || { echo "Error: Failed to set spicetify theme"; exit 1; }
        spicetify config color_scheme Wallbash || { echo "Error: Failed to set spicetify color scheme"; exit 1; }
        spicetify restore backup apply || { echo "Error: Failed to apply spicetify backup"; exit 1; }
        cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
    else
        echo "Spotify not found (not installed via pacman, AUR, or Flatpak). Skipping Spotify wallbash setup."
    fi
}

remove_spotify() {
    echo "Removing Spotify wallbash..."
    if [ -f "$ALWAYS/spotify.dcol" ]; then
        rm -f "$ALWAYS/spotify.dcol" || { echo "Error: Failed to remove spotify.dcol"; exit 1; }
        echo "Removed $ALWAYS/spotify.dcol"
    fi
    if [ -f "$SCRIPTS/spotify.sh" ]; then
        rm -f "$SCRIPTS/spotify.sh" || { echo "Error: Failed to remove spotify.sh"; exit 1; }
        echo "Removed $SCRIPTS/spotify.sh"
    fi
    if [ -f "$SPICETIFY_CSS_DEST" ]; then
        rm -f "$SPICETIFY_CSS_DEST" || { echo "Error: Failed to remove spicetify user.css"; exit 1; }
        echo "Removed $SPICETIFY_CSS_DEST"
    fi
    echo "Spotify wallbash removed"
}

install_swaync() {
    echo "Checking for SwayNC..."
    if ! pacman -Qs swaync >/dev/null 2>&1; then
        echo "Installing swaync..."
        sudo pacman -S swaync --noconfirm || { echo "Error: Failed to install swaync"; exit 1; }
    else
        echo "swaync is already installed."
    fi
    echo "Installing SwayNC wallbash"
    if [ -f "$CONFIG_TOML" ]; then
        if ! grep -q "\[hyprland-start\]" "$CONFIG_TOML"; then
            echo "Adding hyprland-start section to config.toml..."
            echo -e "\n[hyprland-start]\nnotifications = \"swaync\"" >> "$CONFIG_TOML"
        else
            echo "hyprland-start section already exists in config.toml."
        fi
    else
        echo "Error: $CONFIG_TOML not found."
        exit 1
    fi
    git clone https://github.com/dim-ghub/SwayNC-Wallbash /tmp/SwayNC-Wallbash || { echo "Error: Failed to clone SwayNC-Wallbash repository"; exit 1; }
    cd /tmp/SwayNC-Wallbash || { echo "Error: Failed to change to /tmp/SwayNC-Wallbash"; exit 1; }
    if [ -f .config/hyde/wallbash/always/swaync.dcol ]; then
        if [ ! -f "$ALWAYS/swaync.dcol" ] || ! cmp -s .config/hyde/wallbash/always/swaync.dcol "$ALWAYS/swaync.dcol"; then
            cp -f .config/hyde/wallbash/always/swaync.dcol "$ALWAYS/swaync.dcol" || { echo "Error: Failed to copy swaync.dcol"; exit 1; }
        fi
    else
        echo "Error: swaync.dcol not found in SwayNC-Wallbash repository"
        exit 1
    fi
    if [ -f .config/hyde/wallbash/scripts/swaync.sh ]; then
        if [ ! -f "$SCRIPTS/swaync.sh" ] || ! cmp -s .config/hyde/wallbash/scripts/swaync.sh "$SCRIPTS/swaync.sh"; then
            cp -f .config/hyde/wallbash/scripts/swaync.sh "$SCRIPTS/swaync.sh" || { echo "Error: Failed to copy swaync.sh to $SCRIPTS"; exit 1; }
            chmod +x "$SCRIPTS/swaync.sh" || { echo "Error: Failed to set permissions on swaync.sh"; exit 1; }
        fi
    else
        echo "Error: swaync.sh not found in SwayNC-Wallbash repository"
        exit 1
    fi
    if [ -f .config/swaync/config.json ]; then
        if [ ! -f "$SWAYNC_CONFIG_DIR/config.json" ] || ! cmp -s .config/swaync/config.json "$SWAYNC_CONFIG_DIR/config.json"; then
            cp -f .config/swaync/config.json "$SWAYNC_CONFIG_DIR/config.json" || { echo "Error: Failed to copy swaync config.json"; exit 1; }
        fi
    else
        echo "Error: config.json not found in SwayNC-Wallbash repository"
        exit 1
    fi
    if [ -f "$ALWAYS/swaync.dcol" ]; then
        color.set.sh --single "$ALWAYS/swaync.dcol" || { echo "Error: Failed to run color.set.sh"; exit 1; }
    else
        echo "Error: swaync.dcol not found in $ALWAYS"
        exit 1
    fi
    cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
    echo "Successfully installed SwayNC wallbash theme"
}

remove_swaync() {
    echo "Removing SwayNC wallbash..."
    if [ -f "$ALWAYS/swaync.dcol" ]; then
        rm -f "$ALWAYS/swaync.dcol" || { echo "Error: Failed to remove swaync.dcol"; exit 1; }
        echo "Removed $ALWAYS/swaync.dcol"
    fi
    if [ -f "$SCRIPTS/swaync.sh" ]; then
        rm -f "$SCRIPTS/swaync.sh" || { echo "Error: Failed to remove swaync.sh"; exit 1; }
        echo "Removed $SCRIPTS/swaync.sh"
    fi
    if [ -f "$SWAYNC_CONFIG_DIR/config.json" ]; then
        rm -f "$SWAYNC_CONFIG_DIR/config.json" || { echo "Error: Failed to remove swaync config.json"; exit 1; }
        echo "Removed $SWAYNC_CONFIG_DIR/config.json"
    fi
    if [ -f "$CONFIG_TOML" ] && grep -q "\[hyprland-start\]" "$CONFIG_TOML"; then
        sed -i '/\[hyprland-start\]/,/^$/d' "$CONFIG_TOML" || { echo "Error: Failed to remove hyprland-start section from config.toml"; exit 1; }
        echo "Removed hyprland-start section from $CONFIG_TOML"
    fi
    echo "SwayNC wallbash removed"
}

if [ $# -eq 0 ]; then
    usage
fi

mkdir -p "$ALWAYS" "$SCRIPTS" "$(dirname "$SPICETIFY_CSS_DEST")" "$SWAYNC_CONFIG_DIR"

REMOVE_MODE=false
CONFIG_MODE=false
INSTALL_ALL=false
INSTALL_APPS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -remove)
            REMOVE_MODE=true
            shift
            ;;
        -config)
            CONFIG_MODE=true
            shift
            ;;
        -all)
            if [ "$REMOVE_MODE" = true ]; then
                if [ "$CONFIG_MODE" = true ]; then
                    for app in "${CONFIG_APPS[@]}"; do
                        remove_config_"$app"
                    done
                    echo "All config-based configurations removed"
                else
                    for app in "${APPS[@]}"; do
                        remove_"$app"
                    done
                    echo "All wallbash configurations removed"
                fi
                exit 0
            else
                INSTALL_ALL=true
                shift
            fi
            ;;
        -netflix|-steam|-obs|-zen|-spotify|-swaync|-anki)
            app=$(echo "$1" | sed 's/^-//')
            if [ "$REMOVE_MODE" = true ]; then
                if [ "$CONFIG_MODE" = true ]; then
                    if [[ " ${CONFIG_APPS[*]} " =~ " $app " ]]; then
                        remove_config_"$app"
                    else
                        echo "Error: -config not supported for $app"
                        exit 1
                    fi
                else
                    remove_"$app"
                fi
            else
                INSTALL_APPS+=("$app")
            fi
            shift
            ;;
        *)
            echo "Error: Unknown parameter: $1"
            usage
            ;;
    esac
done

if [ "$REMOVE_MODE" = true ] && [ ${#INSTALL_APPS[@]} -eq 0 ] && [ "$INSTALL_ALL" = false ]; then
    echo "Error: -remove requires -all or an application parameter (e.g., -netflix or -config -anki)"
    usage
fi

if [ "$CONFIG_MODE" = true ] && [ "$REMOVE_MODE" = false ]; then
    if [ "$INSTALL_ALL" = true ]; then
        for app in "${CONFIG_APPS[@]}"; do
            install_config_"$app"
        done
    else
        for app in "${INSTALL_APPS[@]}"; do
            if [[ " ${CONFIG_APPS[*]} " =~ " $app " ]]; then
                install_config_"$app"
            else
                echo "Error: -config not supported for $app"
                exit 1
            fi
        done
    fi
elif [ "$INSTALL_ALL" = true ]; then
    for app in "${APPS[@]}"; do
        install_"$app"
    done
else
    for app in "${INSTALL_APPS[@]}"; do
        install_"$app"
    done
fi

echo "Script completed successfully!"
