#!/bin/bash

if [ ! -d "$HOME/.config/hyde/themes/Oxo Carbon" ]; then
  echo "Importing Oxo Carbon..."
  hydectl theme import --name "Oxo Carbon" --url https://github.com/rishav12s/Oxo-Carbon
else
  echo "Skipped Oxo Carbon, already exists."
fi

if [ ! -d "$HOME/.config/hyde/themes/Crimson-Blue" ]; then
  echo "Importing Crimson Blue..."
  hydectl theme import --name "Crimson-Blue" --url https://github.com/amit-0i/Crimson-Blue
else
  echo "Skipped Crimson Blue, already exists."
fi

if [ ! -d "$HOME/.config/hyde/themes/Eternal Arctic" ]; then
  echo "Importing Eternal Arctic..."
  hydectl theme import --name "Eternal Arctic" --url https://github.com/rishav12s/Eternal-Arctic
else
  echo "Skipped Eternal Arctic, already exists."
fi

if [ ! -d "$HOME/.config/hyde/themes/Vanta Black" ]; then
  echo "Importing Vanta Black..."
  hydectl theme import --name "Vanta Black" --url https://github.com/rishav12s/Vanta-Black
else
  echo "Skipped Vanta Black, already exists."
fi

if [ ! -d "$HOME/.config/hyde/themes/Obsidian-Purple" ]; then
  echo "Importing Obsidian Purple..."
  hydectl theme import --name "Obsidian-Purple" --url https://github.com/amit-0i/Obsidian-Purple
else
  echo "Skipped Obsidian Purple, already exists."
fi

if [ ! -d "$HOME/.config/hyde/themes/One Dark" ]; then
  echo "Importing One Dark..."
  hydectl theme import --name "One Dark" --url https://github.com/RAprogramm/HyDe-Themes/tree/One-Dark
else 

if [ ! -d "$HOME/.config/hyde/themes/Virtual-Witches" ]; then
  echo "Importing Virtual Witches..."
  hydectl theme import --name "One Dark" --url https://github.com/RAprogramm/HyDe-Themes/tree/One-Dark
else 
  echo "Skipped One Dark, already exists."

echo "Finished setting up themes"
exit 0
