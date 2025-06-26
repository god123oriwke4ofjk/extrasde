#!/usr/bin/env bash

# Early load to maintain fastfetch speed
if [ -z "${*}" ]; then
  clear
  exec fastfetch --logo-type kitty
  exit
fi

USAGE() {
  cat <<USAGE
Usage: fastfetch [commands] [options]

commands:
  logo    Display a random logo

options:
  -h, --help,     Display command's help message

USAGE
}

# Source state and os-release
# shellcheck source=/dev/null
[ -f "$HOME/.local/state/hyde/staterc" ] && source "$HOME/.local/state/hyde/staterc"
# shellcheck disable=SC1091
[ -f "/etc/os-release" ] && source "/etc/os-release"

# Set the variables
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
iconDir="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
image_dirs=()
hyde_distro_logo=${iconDir}/Wallbash-Icon/distro/$LOGO
# Normalize theme name: replace spaces with hyphens for consistency
theme_name=$(echo "${HYDE_THEME}" | tr ' ' '-')
theme_logo_dir="${confDir}/fastfetch/logo/${theme_name}"

# Parse the main command
case $1 in
logo) # eats around 13 ms
  random() {
    (
      # Check if theme-specific logo directory exists and has valid files
      if [ -n "${theme_name}" ] && [ -d "${theme_logo_dir}" ]; then
        if [ -n "$(find -L "${theme_logo_dir}" -maxdepth 1 -type f \( -name "*.icon" -o -name "*logo*" -o -name "*.png" \) ! -path "*/wall.set*" ! -path "*/wallpapers/*.png" 2>/dev/null)" ]; then
          image_dirs+=("${theme_logo_dir}")
        else
          echo "Debug: No valid logo files found in ${theme_logo_dir}" >&2
        fi
      else
        echo "Debug: Theme directory ${theme_logo_dir} does not exist" >&2
        # Fallback to general fastfetch logo directory
        image_dirs+=("${confDir}/fastfetch/logo")
      fi
      if [ ${#image_dirs[@]} -eq 0 ]; then
        echo "Debug: No valid directories to search for logos" >&2
        exit 1
      fi
      find -L "${image_dirs[@]}" -maxdepth 1 -type f \( -name "*.icon" -o -name "*logo*" -o -name "*.png" \) ! -path "*/wall.set*" ! -path "*/wallpapers/*.png" 2>/dev/null
    ) | shuf -n 1
  }
  help() {
    cat <<HELP
Usage: ${0##*/} logo [option]

options:
  --prof    Display your profile picture (~/.face.icon)
  --os      Display the distro logo
  --local   Display a logo from the general fastfetch logo directory
  --wall    Display a logo from the wallbash fastfetch directory
  --theme   Display a logo from the current theme's logo directory
  --rand    Display a random logo from the current theme
  *         Display a random logo from the current theme
  *help*    Display this help message

Note: Options can be combined to search across multiple sources
Example: ${0##*/} logo --local --os --prof
HELP
  }

  # Parse the logo options
  shift
  [ -z "${*}" ] && random && exit
  [[ "$1" = "--rand" ]] && random && exit
  [[ "$1" = *"help"* ]] && help && exit
  (
    image_dirs=()
    for arg in "$@"; do
      case $arg in
      --prof)
        [ -f "$HOME/.face.icon" ] && image_dirs+=("$HOME/.face.icon")
        ;;
      --os)
        [ -f "$hyde_distro_logo" ] && image_dirs+=("$hyde_distro_logo")
        ;;
      --local)
        image_dirs+=("${confDir}/fastfetch/logo")
        ;;
      --wall)
        image_dirs+=("${iconDir}/Wallbash-Icon/fastfetch/")
        ;;
      --theme)
        if [ -n "${theme_name}" ] && [ -d "${theme_logo_dir}" ]; then
          image_dirs+=("${theme_logo_dir}")
        fi
        ;;
      esac
    done
    if [ ${#image_dirs[@]} -eq 0 ]; then
      echo "Debug: No valid directories specified for logo search" >&2
      exit 1
    fi
    find -L "${image_dirs[@]}" -maxdepth 1 -type f \( -name "*.icon" -o -name "*logo*" -o -name "*.png" \) ! -path "*/wall.set*" ! -path "*/wallpapers/*.png" 2>/dev/null
  ) | shuf -n 1

  ;;
--select | -S)
  :

  ;;
help | --help | -h)
  USAGE
  ;;
*)
  clear
  exec fastfetch --logo-type kitty
  ;;
esac
