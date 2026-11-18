#!/usr/bin/env bash
# region screenshot -> ~/Pictures + clipboard
mkdir -p "$HOME/Pictures"
f="$HOME/Pictures/shot-$(date +%Y%m%d-%H%M%S).png"
grim -g "$(slurp)" "$f" && wl-copy < "$f"
