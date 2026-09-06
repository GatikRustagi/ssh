#!/bin/bash
# Install Flutter and build the web app

echo "Downloading Flutter..."
git clone https://github.com/flutter/flutter.git -b stable

echo "Adding Flutter to PATH..."
export PATH="$PATH:`pwd`/flutter/bin"

echo "Running Flutter build..."
flutter build web --release
