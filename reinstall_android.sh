#!/bin/bash

# 🛡️ trekwithmussaffir: ANDROID TACTICAL REINSTALLATION SCRIPT
# This script performs a deep reset of the Android environment to resolve AAR & Desugaring conflicts.

echo "📡 Phase 1: Cleaning Flutter Battalion..."
flutter clean

echo "📡 Phase 2: Synchronizing Dependencies..."
flutter pub get

echo "📡 Phase 3: Surgical Wipe of Android Artifacts..."
cd android
# Remove build folders and gradle cache for this project
rm -rf .gradle
rm -rf build
rm -rf app/build

echo "📡 Phase 4: Native Gradle Purification..."
# Run gradlew clean if it exists
if [ -f "gradlew" ]; then
    chmod +x gradlew
    ./gradlew clean
fi

echo "🚀 Phase 5: Re-initializing Build System..."
cd ..
echo "✅ Android Reinstallation Complete."
echo "👉 You can now run: flutter run"
