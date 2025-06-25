#!/bin/bash

THEME_DIR="$HOME/.config/hyde/themes"
WALLPAPER_DIR="./wallpapers"

declare -A THEMES=(
  ["Oxo Carbon"]="https://github.com/rishav12s/Oxo-Carbon"
  ["Crimson-Blue"]="https://github.com/amit-0i/Crimson-Blue"
  ["Eternal Arctic"]="https://github.com/rishav12s/Eternal-Arctic"
  ["Vanta Black"]="https://github.com/rishav12s/Vanta-Black"
  ["Obsidian-Purple"]="https://github.com/amit-0i/Obsidian-Purple"
  ["One Dark"]="https://github.com/RAprogramm/HyDe-Themes/tree/One-Dark"
  ["Virtual-Witches"]="https://github.com/RAprogramm/HyDe-Themes/tree/Virtual-Witches"
  ["BlueSky"]="https://github.com/RAprogramm/HyDe-Themes/tree/BlueSky"
)

echo "Checking and importing themes..."
for theme in "${!THEMES[@]}"; do
  theme_path="$THEME_DIR/$theme"
  if [[ ! -d "$theme_path" ]]; then
    echo "Importing $theme..."
    hydectl theme import --name "$theme" --url "${THEMES[$theme]}"
  else
    echo "Skipped $theme, already exists."
  fi
done

echo "Setting up custom wallpapers..."

move_wallpapers() {
  local src_folder="$WALLPAPER_DIR/$1"
  local theme_folder="$THEME_DIR/$2"
  local dest_folder="$theme_folder/wallpapers"
  local extra_folder="$dest_folder/Extra"

  if [[ ! -d "$src_folder" ]]; then
    echo "Source not found: $src_folder"
    return
  fi

  if [[ ! -d "$dest_folder" ]]; then
    echo "Destination wallpapers folder does not exist: $dest_folder"
    return
  fi

  mkdir -p "$extra_folder"

  echo "Copying wallpapers from $src_folder to $extra_folder (excluding already existing ones in $dest_folder)..."

  shopt -s nullglob
  for src_file in "$src_folder"/*; do
    filename=$(basename "$src_file")
    if [[ ! -e "$dest_folder/$filename" ]]; then
      cp "$src_file" "$extra_folder/"
      echo "Copied: $filename"
    else
      echo "Skipped (already exists in main): $filename"
    fi
  done
  shopt -u nullglob
}

declare -A WALLPAPER_MAP=(
  ["crimson-blue"]="Crimson-Blue"
  ["nordic-blue"]="Nordic Blue"
  ["synth-wave"]="Synth Wave"
  ["vanta-black"]="Vanta Black"
  ["oxo-carbon"]="Oxo Carbon"
  ["graphite-mono"]="Graphite Mono"
  ["obsidian-purple"]="Obsidian-Purple"
  ["catpuccin-latte"]="Catppuccin Latte"
  ["bluesky"]="BlueSky"
  ["catpucin-mocha"]="Catppuccin Mocha"
  ["rose-pine"]="Rosé Pine"
)

for src in "${!WALLPAPER_MAP[@]}"; do
  move_wallpapers "$src" "${WALLPAPER_MAP[$src]}"
done

echo "Finished setting up themes."
exit 0
