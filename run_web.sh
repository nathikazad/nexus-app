#!/bin/bash

# Script to run the Flutter app on Chrome
echo "🚀 Starting Nexus Voice Assistant on Chrome..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Navigate to mobile directory
cd "$(dirname "$0")"

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Check for Chrome
echo "🌐 Checking for Chrome..."
flutter devices

# Run on Chrome
echo "🎯 Running on Chrome..."
flutter run -d chrome

echo "✅ Done!"
