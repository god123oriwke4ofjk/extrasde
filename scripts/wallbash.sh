echo "Installing netflix wallbash"
git clone https://github.com/ /tmp/netflixWallbash || { echo "Error: Failed to clone netflix wallbash repository"; exit 1;}
cd /tmp/netflixWallbash || { echo "Error: Failed to change to /tmp/osu"; exit 1; }
./setup.sh
cd - || exit 1
rm -rf /tmp/netflixWallbash 
echo "Successfully installed netflix wallbash"
