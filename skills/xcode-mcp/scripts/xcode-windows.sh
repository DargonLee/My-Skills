#!/bin/bash
# xcode-windows.sh - List Xcode windows using AppleScript

echo "Xcode Windows:"
echo ""

# Get window names from Xcode
osascript -e 'tell application "Xcode" to get name of every window' 2>&1 | tr ',' '\n' | while read window; do
    window=$(echo "$window" | sed 's/^ *//;s/ *$//')
    if [ -n "$window" ]; then
        echo "* $window"
    fi
done

# Try to get workspace paths from window titles
echo ""
echo "---"
echo "Tip: Window titles usually contain the workspace/project name"