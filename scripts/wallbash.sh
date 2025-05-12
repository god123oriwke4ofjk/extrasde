#!/bin/bash

set -euo pipefail

ALWAYS="$HOME/.config/hyde/wallbash/always"
SCRIPTS="$HOME/.config/hyde/wallbash/scripts"
SPICETIFY_CSS_DEST="$HOME/.config/spicetify/Themes/text/user.css"
SPICETIFY_CSS_URL="https://raw.githubusercontent.com/spicetify/spicetify-themes/refs/heads/master/text/user.css"

mkdir -p "$ALWAYS" "$SCRIPTS" "$(dirname "$SPICETIFY_CSS_DEST")"

cleanup() {
    rm -rf /tmp/netflixWallbash /tmp/steamWallbash /tmp/obsWallbash /tmp/zenWallbash /tmp/spotifyWallbash
}
trap cleanup EXIT

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "Installing Netflix wallbash"
NETFLIX_REPO="https://github.com/<correct-user>/netflix-wallbash"
git clone "$NETFLIX_REPO" /tmp/netflixWallbash || { echo "Error: Failed to clone Netflix wallbash repository"; exit 1; }
cd /tmp/netflixWallbash || { echo "Error: Failed to change to /tmp/netflixWallbash"; exit 1; }
if [ -f setup.sh ]; then
    ./setup.sh || { echo "Error: Failed to run setup.sh for Netflix wallbash"; exit 1; }
else
    echo "Error: setup.sh not found in Netflix wallbash repository"
    exit 1
fi
cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
echo "Successfully installed Netflix wallbash theme"

echo "Installing Steam wallbash"
git clone https://github.com/dim-ghub/Steam-Wallbash /tmp/steamWallbash || { echo "Error: Failed to clone Steam wallbash repository"; exit 1; }
cd /tmp/steamWallbash || { echo "Error: Failed to change to /tmp/steamWallbash"; exit 1; }
if ls .config/hyde/wallbash/always/*.dcol >/dev/null 2>&1; then
    cp -f .config/hyde/wallbash/always/*.dcol "$ALWAYS" || { echo "Error: Failed to copy .dcol files to $ALWAYS"; exit 1; }
else
    echo "Error: No .dcol files found in Steam wallbash repository"
    exit 1
fi
if [ -f .config/hyde/wallbash/scripts/steam.sh ]; then
    cp -f .config/hyde/wallbash/scripts/steam.sh "$SCRIPTS/steam.sh" || { echo "Error: Failed to copy steam.sh to $SCRIPTS"; exit 1; }
    chmod +x "$SCRIPTS/steam.sh" || { echo "Error: Failed to grant permissions to $SCRIPTS/steam.sh"; exit 1; }
    "$SCRIPTS/steam.sh" || { echo "Error: Failed to run steam.sh"; exit 1; }
else
    echo "Error: steam.sh not found in Steam wallbash repository"
    exit 1
fi
cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
echo "Successfully installed Steam wallbash theme. Please follow the instructions to set it up:"
echo "Open Steam, enter Big Picture Mode, press Control + 2 to open the panel. Navigate to the plugin store and install CSS Loader. Then in the new CSS Loader menu, click refresh and enable the two themes. You can now exit Big Picture Mode by pressing Mod + Q."

echo "Installing OBS wallbash"
git clone https://github.com/dim-ghub/OBS-wallbash /tmp/obsWallbash || { echo "Error: Failed to clone OBS wallbash repository"; exit 1; }
cd /tmp/obsWallbash || { echo "Error: Failed to change to /tmp/obsWallbash"; exit 1; }
if ls .config/hyde/wallbash/always/*.dcol >/dev/null 2>&1; then
    cp -f .config/hyde/wallbash/always/*.dcol "$ALWAYS" || { echo "Error: Failed to copy .dcol files to $ALWAYS"; exit 1; }
else
    echo "Error: No .dcol files found in OBS wallbash repository"
    exit 1
fi
if [ -f .config/hyde/wallbash/scripts/obs.sh ]; then
    cp -f .config/hyde/wallbash/scripts/obs.sh "$SCRIPTS/obs.sh" || { echo "Error: Failed to copy obs.sh to $SCRIPTS"; exit 1; }
    chmod +x "$SCRIPTS/obs.sh" || { echo "Error: Failed to grant permissions to $SCRIPTS/obs.sh"; exit 1; }
    "$SCRIPTS/obs.sh" || { echo "Error: Failed to run obs.sh"; exit 1; }
else
    echo "Error: obs.sh not found in OBS wallbash repository"
    exit 1
fi
cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
echo "Successfully installed OBS wallbash theme. Please follow the instructions to set it up:"
echo "Open OBS, go to File > Settings > Appearance, then in the Theme menu choose Catppuccin and in the Style option choose Wallbash. Note: this theme does not automatically refresh when switching wallpapers, so you will need to manually refresh it."

echo "Installing Zen-Browser wallbash"
git clone https://github.com/dim-ghub/ZenBash /tmp/zenWallbash || { echo "Error: Failed to clone Zen-Browser wallbash repository"; exit 1; }
cd /tmp/zenWallbash || { echo "Error: Failed to change to /tmp/zenWallbash"; exit 1; }
if ls .config/hyde/wallbash/always/*.dcol >/dev/null 2>&1; then
    cp -f .config/hyde/wallbash/always/*.dcol "$ALWAYS" || { echo "Error: Failed to copy .dcol files to $ALWAYS"; exit 1; }
else
    echo "Error: No .dcol files found in Zen-Browser wallbash repository"
    exit 1
fi
if [ -f .config/hyde/wallbash/scripts/ZenBash.sh ]; then
    cp -f .config/hyde/wallbash/scripts/ZenBash.sh "$SCRIPTS/ZenBash.sh" || { echo "Error: Failed to copy ZenBash.sh to $SCRIPTS"; exit 1; }
    chmod +x "$SCRIPTS/ZenBash.sh" || { echo "Error: Failed to grant permissions to $SCRIPTS/ZenBash.sh"; exit 1; }
    "$SCRIPTS/ZenBash.sh" || { echo "Error: Failed to run ZenBash.sh"; exit 1; }
else
    echo "Error: ZenBash.sh not found in Zen-Browser wallbash repository"
    exit 1
fi
cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }
echo "Successfully installed Zen-Browser wallbash theme"

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
    cp -f .config/hyde/wallbash/always/spotify.dcol "$ALWAYS/spotify.dcol" || { echo "Error: Failed to copy spotify.dcol"; exit 1; }
else
    echo "Error: spotify.dcol not found in Wallbash-TUIs repository"
    exit 1
fi
if [ -f .config/hyde/wallbash/scripts/spotify.sh ]; then
    cp -f .config/hyde/wallbash/scripts/spotify.sh "$SCRIPTS/spotify.sh" || { echo "Error: Failed to copy spotify.sh"; exit 1; }
    chmod +x "$SCRIPTS/spotify.sh" || { echo "Error: Failed to set permissions on spotify.sh"; exit 1; }
    "$SCRIPTS/spotify.sh" || { echo "Error: Failed to run spotify.sh"; exit 1; }
else
    echo "Error: spotify.sh not found in Wallbash-TUIs repository"
    exit 1
fi
spicetify config current_theme text || { echo "Error: Failed to set spicetify theme"; exit 1; }
spicetify config color_scheme Wallbash || { echo "Error: Failed to set spicetify color scheme"; exit 1; }
spicetify restore backup apply || { echo "Error: Failed to apply spicetify backup"; exit 1; }
cd - >/dev/null || { echo "Error: Failed to return to previous directory"; exit 1; }

echo "Script completed successfully!"
