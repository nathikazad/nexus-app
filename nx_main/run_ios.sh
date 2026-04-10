#!/bin/bash

# Script to run the Flutter app on iOS Simulator
echo "🚀 Starting Nexus Voice Assistant on iOS Simulator..."

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

# Check for iOS devices
echo "📱 Checking for iOS devices..."
flutter devices

# Run on iOS Simulator
echo "🎯 Running on iOS Simulator..."
flutter run -d ios

echo "✅ Done!"
