#!/usr/bin/env bash
# uses ~/Pictures/wallpaper.png if present, else a flat colour
if [ -f "$HOME/Pictures/wallpaper.png" ]; then
  exec swaybg -m fill -i "$HOME/Pictures/wallpaper.png"
else
  exec swaybg -c '#11111b'
fi
