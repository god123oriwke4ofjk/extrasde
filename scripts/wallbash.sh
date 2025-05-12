#!/bin/bash

set -euo pipefail

ALWAYS="$HOME/.config/hyde/wallbash/always"
SCRIPTS="$HOME/.config/hyde/wallbash/scripts"

echo "Installing Netflix wallbash"
git clone https://github.com/god123oriwke4ofjk/netflix-wallbash /tmp/netflixWallbash || { echo "Error: Failed to clone Netflix wallbash repository"; exit 1; }
cd /tmp/netflixWallbash || { echo "Error: Failed to change to /tmp/netflixWallbash"; exit 1; }
./setup.sh || { echo "Error: Failed to run setup.sh for Netflix wallbash"; exit 1; }
cd - || exit 1
rm -rf /tmp/netflixWallbash
echo "Successfully installed Netflix wallbash theme"

echo "Installing Steam wallbash"
git clone https://github.com/dim-ghub/Steam-Wallbash /tmp/steamWallbash || { echo "Error: Failed to clone Steam wallbash repository"; exit 1; }
cd /tmp/steamWallbash || { echo "Error: Failed to change to /tmp/steamWallbash"; exit 1; }
mv .config/hyde/wallbash/always/*.dcol "$ALWAYS" || { echo "Error: Failed to move .dcol files to $ALWAYS"; exit 1; }
mv .config/hyde/wallbash/scripts/steam.sh "$SCRIPTS" || { echo "Error: Failed to move steam.sh file to $SCRIPTS"; exit 1; }
chmod +x "$SCRIPTS/steam.sh" || { echo "Error: Failed to grant permissions to $SCRIPTS/steam.sh"; exit 1; }
"$SCRIPTS/steam.sh"
cd - || exit 1
rm -rf /tmp/steamWallbash
echo "Successfully installed Steam wallbash theme. Please follow the instructions to set it up:"
echo "Open Steam, enter Big Picture Mode, press Control + 2 to open the panel. Navigate to the plugin store and install CSS Loader. Then in the new CSS Loader menu, click refresh and enable the two themes. You can now exit Big Picture Mode by pressing Mod + Q."

echo "Installing OBS wallbash"
git clone https://github.com/dim-ghub/OBS-wallbash /tmp/obsWallbash || { echo "Error: Failed to clone OBS wallbash repository"; exit 1; }
cd /tmp/obsWallbash || { echo "Error: Failed to change to /tmp/obsWallbash"; exit 1; }
mv .config/hyde/wallbash/always/*.dcol "$ALWAYS" || { echo "Error: Failed to move .dcol files to $ALWAYS"; exit 1; }
mv .config/hyde/wallbash/scripts/obs.sh "$SCRIPTS" || { echo "Error: Failed to move obs.sh file to $SCRIPTS"; exit 1; }
chmod +x "$SCRIPTS/obs.sh" || { echo "Error: Failed to grant permissions to $SCRIPTS/obs.sh"; exit 1; }
"$SCRIPTS/obs.sh"
cd - || exit 1
rm -rf /tmp/obsWallbash
echo "Successfully installed OBS wallbash theme. Please follow the instructions to set it up:"
echo "Open OBS, go to File > Settings > Appearance, then in the Theme menu choose Catppuccin and in the Style option choose Wallbash. Note: this theme does not automatically refresh when switching wallpapers, so you will need to manually refresh it."

echo "Installing Zen-Browser wallbash"
git clone https://github.com/dim-ghub/ZenBash /tmp/zenWallbash || { echo "Error: Failed to clone Zen-Browser wallbash repository"; exit 1; }
cd /tmp/zenWallbash || { echo "Error: Failed to change to /tmp/zenWallbash"; exit 1; }
mv .config/hyde/wallbash/always/*.dcol "$ALWAYS" || { echo "Error: Failed to move .dcol files to $ALWAYS"; exit 1; }
mv .config/hyde/wallbash/scripts/ZenBash.sh "$SCRIPTS" || { echo "Error: Failed to move ZenBash.sh file to $SCRIPTS"; exit 1; }
chmod +x "$SCRIPTS/ZenBash.sh" || { echo "Error: Failed to grant permissions to $SCRIPTS/ZenBash.sh"; exit 1; }
"$SCRIPTS/ZenBash.sh"
cd - || exit 1
rm -rf /tmp/zenWallbash
echo "Successfully installed Zen-Browser wallbash theme"

echo "Setting up spicetify"
sudo chmod a+wr /opt/spotify
sudo chmod a+wr /opt/spotify/Apps -R
yay -S spicetify-cli
mkdir -p "$(dirname $HOME/.config/spicetify/Themes/text/user.css)"
curl -sSL "https://raw.githubusercontent.com/spicetify/spicetify-themes/refs/heads/master/text/user.css" -o $HOME/.config/spicetify/Themes/text/user.css || {
    echo "Error downloading user.css"
    exit 1
}
git clone --depth 1 https://github.com/dim-ghub/Wallbash-TUIs.git /tmp/spotifyWallbash || {
    echo "Error cloning repository"
    exit 1
}
cd /tmp/spotifyWallbash/.config/hyde/wallbash || { echo "Error: chanding directory to /tmp/spotifyWallbash"; exit 1; }
if [ -f /scripts/spotify.sh ]; then
    cp /scripts/spotify.sh "$HOME/.config/spicetify/Themes/text/user.css" || {
        echo "Error copying spotify.sh"
        exit 1
    }
    chmod +x $SCRIPTS/spotify.sh || {
        echo "Error setting permissions on spotify.sh"
        exit 1
    }
else
    echo "spotify.sh not found in repository"
    exit 1
fi 
if ! $SCRIPTS/spotify.sh; then
    echo "Error running spotify.sh"
    exit 1
fi
spicetify config current_theme text || {
    echo "Error setting spicetify theme"
    exit 1
}
spicetify config color_scheme Wallbash || {
    echo "Error setting spicetify color scheme"
    exit 1
}
spicetify restore backup apply || {
    echo "Error applying spicetify backup"
    exit 1
}
cd - || exit 1
rm -rf /tmp/spotifyWallbash
