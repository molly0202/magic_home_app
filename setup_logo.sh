#!/bin/bash

# Create directory if it doesn't exist
mkdir -p assets/images

# Instructions for user
echo "=========================================================="
echo "To use your own Figma PNG logo:"
echo "1. Export your logo from Figma as a PNG"
echo "2. Save it as 'logo.png' in the assets/images directory"
echo "3. Run 'flutter pub get' to update assets"
echo "4. Run your app"
echo "=========================================================="

echo "Logo directory prepared at: $(pwd)/assets/images"
echo "Place your logo.png file there" 