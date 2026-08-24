#!/bin/bash

# 🛡️ Trek India Tactical Build Script for Vercel

# 1. Acquire Flutter Intelligence
if [ ! -d "$HOME/flutter" ]; then
  echo "📡 Downloading Flutter Sector Assets..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
fi

# 2. Establish Command Environment
export PATH="$PATH:$HOME/flutter/bin"

# 3. Synchronize Dependencies
echo "📡 Synchronizing Battalion Dependencies..."
flutter pub get

# 4. Generate Web Distribution
echo "🚀 Building Web Terminal..."
flutter build web --release
