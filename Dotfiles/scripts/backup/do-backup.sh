#!/bin/bash

SOURCE="/home/mpendlebury/Documents/"
DEST="$HOME/Backup/archlinux/mpendlebury/Documents/"
EXCLUDES="$HOME/.scripts/backup/excludes"

rsync -avh --info=progress2 --delete --no-links --exclude-from="$EXCLUDES" "$SOURCE" "$DEST"
