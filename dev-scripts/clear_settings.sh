#! /bin/bash

# Usage: ./clear_settings.sh [key]
# If key is provided, deletes only that setting
# If no key is provided, deletes all settings

if [ -n "$1" ]; then
    defaults delete studio.liberated.speakease "$1" 2>/dev/null
    defaults delete SpeakEase "$1" 2>/dev/null
    echo "Deleted setting: $1"
else
    defaults delete studio.liberated.speakease 2>/dev/null
    defaults delete SpeakEase 2>/dev/null
    echo "Deleted all settings"
fi
