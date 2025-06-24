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
  src="$WALLPAPER_DIR/$1"
  dest="$THEME_DIR/$2"

  if [[ ! -d "$src" ]]; then
    echo "Source not found: $src"
    return
  fi

  echo "Getting wallpapers for $2"

  shopt -s nullglob
  files=("$src"/*)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No wallpapers to copy in: $src"
    return
  fi

  mkdir -p "$dest"  

  for wp in "${files[@]}"; do
    name=$(basename "$wp")
    if [[ ! -e "$dest/$name" ]]; then
      cp "$wp" "$dest/"
      echo "Copied: $name"
    else
      echo "Skipped (already exists): $name"
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
)

for src in "${!WALLPAPER_MAP[@]}"; do
  move_wallpapers "$src" "${WALLPAPER_MAP[$src]}"
done

echo "Finished setting up themes."
exit 0
