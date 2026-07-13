#!/bin/bash
#
# uninstall.sh — remove TCPV4MAC and every trace it leaves on this Mac.
# TCPV4MAC — Copyright (C) 2026 Jensy Leonardo Martínez Cruz — GNU GPL v3.0
#
# Use this if you don't have the app anymore (the app also has a built-in
# "Uninstall TCPV4MAC…" option under the ⋯ menu that does the same).

set -u
APP="TCPV4MAC.app"
BUNDLE_IDS=("com.jensyleo.tcpv4mac")

echo "Uninstalling TCPV4MAC…"

# 1. Quit if running.
osascript -e 'quit app "TCPV4MAC"' 2>/dev/null || true
pkill -x TCPV4MAC 2>/dev/null || true
sleep 1

# 2. Remove the app bundle from the usual locations.
rm -rf "$HOME/Applications/$APP" "/Applications/$APP"

# 3. Preferences, saved state, caches, and TCC grants — for every bundle id.
for BUNDLE_ID in "${BUNDLE_IDS[@]}"; do
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
    rm -f  "$HOME/Library/Preferences/$BUNDLE_ID.plist"
    rm -rf "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
    rm -rf "$HOME/Library/Caches/$BUNDLE_ID"
    rm -rf "$HOME/Library/HTTPStorages/$BUNDLE_ID"
    tccutil reset All "$BUNDLE_ID" 2>/dev/null || true
done

echo "Done. TCPV4MAC and its traces have been removed."
