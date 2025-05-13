#!/bin/bash

# Exit on any error
set -e

# Step 1: Check and install dependencies if not already installed
echo "Checking for required packages..."
packages="git nodejs npm tesseract jq"
for pkg in $packages; do
    if ! pacman -Qs "$pkg" > /dev/null; then
        echo "Installing $pkg..."
        sudo pacman -S --noconfirm "$pkg"
    else
        echo "$pkg is already installed, skipping..."
    fi
done

# Step 2: Clone the repository to /tmp
echo "Cloning vpnbook-scraper repository to /tmp..."
clone_dir="/tmp/vpnbook-scraper"
if [ -d "$clone_dir" ]; then
    echo "Removing existing $clone_dir..."
    rm -rf "$clone_dir"
fi
git clone https://github.com/NithinV404/vpnbook-scraper "$clone_dir"

# Step 3: Navigate to the project directory
cd "$clone_dir"

# Step 4: Initialize Node.js project
echo "Initializing Node.js project..."
npm init -y

# Step 5: Modify package.json to set type: module
echo "Updating package.json to use ES Modules..."
jq '. + { "type": "module" }' package.json > temp.json && mv temp.json package.json

# Step 6: Install Node.js dependencies
echo "Installing puppeteer, axios, and tesseract.js..."
npm install puppeteer axios tesseract.js

# Step 7: Run the scraper and capture output
echo "Running scrape_with_puppeteer.js..."
output=$(node src/scrape_with_puppeteer.js)

# Step 8: Print the full output
echo "Full output of scrape_with_puppeteer.js:"
echo "$output"

# Step 9: Extract the Username and Recognized Text (password)
echo "Extracting Username and Recognized Text..."
username=$(echo "$output" | grep "Username :" | sed 's/Username : //')
recognized_text=$(echo "$output" | grep "Recognized Text:" | sed 's/Recognized Text: //')

# Step 10: Create ~/.config/vpnbook directory and write to auth.txt
config_dir="$HOME/.config/vpn"
auth_file="$config_dir/auth.txt"
echo "Writing username and password to $auth_file..."
mkdir -p "$config_dir"
echo $username > "$auth_file"
echo $recognized_text >> "$auth_file"

# Step 11: Clean up the cloned repository
echo "Cleaning up $clone_dir..."
cd /tmp
rm -rf "$clone_dir"

# Step 12: Print only the extracted password
if [ -n "$recognized_text" ]; then
    echo "Extracted Password: $recognized_text"
else
    echo "Error: Recognized Text not found in output"
    exit 1
fi

# Step 13: Copy the script to a persistent location and ensure systemd timer is enabled
echo "Ensuring systemd timer is set up..."
script_path="$HOME/setup_and_scrape.sh"
service_dir="$HOME/.config/systemd/user"
systemd_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/systemd"
service_file="$systemd_dir/vpnbook-scraper.service"
timer_file="$systemd_dir/vpnbook-scraper.timer"

# Copy the script to a persistent location
current_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
if [ "$current_script" != "$script_path" ]; then
    cp "$current_script" "$script_path"
    chmod +x "$script_path"
fi

# Copy systemd files to user systemd directory
mkdir -p "$service_dir"
cp "$service_file" "$service_dir/"
cp "$timer_file" "$service_dir/"

# Enable and start the timer
systemctl --user daemon-reload
systemctl --user enable vpnbook-scraper.timer
systemctl --user start vpnbook-scraper.timer

echo "Systemd timer enabled and started. Check status with: systemctl --user status vpnbook-scraper.timer"
