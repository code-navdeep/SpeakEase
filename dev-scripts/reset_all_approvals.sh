#! /bin/bash

echo "Resetting all permissions for SpeakEase..."

# Reset all permissions
echo "Resetting all TCC permissions..."
sudo tccutil reset All studio.liberated.speakease

# Reset specific permissions (more targeted approach)
echo "Resetting specific permissions..."
sudo tccutil reset Microphone studio.liberated.speakease
sudo tccutil reset Accessibility studio.liberated.speakease
sudo tccutil reset AppleEvents studio.liberated.speakease

echo "Permissions have been reset. Please restart the app."
echo "Note: You may need to restart your computer for changes to take full effect."
