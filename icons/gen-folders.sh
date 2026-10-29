#!/usr/bin/env bash
# Build the "Exsbe" icon theme: WhiteSur-dark with its blue folder/places icons recoloured
# to the Exsbe graphite accent. Everything else is inherited from WhiteSur-dark.
# Usage: gen-folders.sh [SRC_THEME_DIR] [OUT_THEME_DIR]
set -euo pipefail
src=${1:-$HOME/.local/share/icons/WhiteSur-dark}
out=${2:-$HOME/.local/share/icons/Exsbe}
# WhiteSur blue (light -> dark)  ->  Exsbe graphite blue
map=(-e 's/#83d4fb/#b4c4d8/gI' -e 's/#60c0f0/#8fa4c0/gI' -e 's/#3daee9/#8fa4c0/gI'
     -e 's/#46a2d7/#7088a8/gI' -e 's/#008ea2/#4a5a70/gI')
dirs=(places/16 places/22 places/24 places/scalable)

rm -rf "$out"
for d in "${dirs[@]}"; do
  mkdir -p "$out/$d"
  for f in "$src/$d"/*.svg; do
    grep -qiE '#(83d4fb|60c0f0|3daee9|46a2d7|008ea2)' "$f" || continue
    sed "${map[@]}" "$f" > "$out/$d/$(basename "$f")"   # follows symlinks, writes real files
  done
done

{
  echo "[Icon Theme]"
  echo "Name=Exsbe"
  echo "Comment=WhiteSur-dark with graphite Exsbe folders"
  echo "Inherits=WhiteSur-dark,breeze-dark,hicolor"
  echo "Example=folder"
  echo "Directories=$(IFS=,; echo "${dirs[*]}")"
  for d in "${dirs[@]}"; do
    echo; echo "[$d]"
    if [[ $d == */scalable ]]; then
      echo "Size=64"; echo "MinSize=16"; echo "MaxSize=512"; echo "Type=Scalable"
    else
      echo "Size=${d#*/}"; echo "Type=Fixed"
    fi
    echo "Context=Places"
  done
} > "$out/index.theme"
