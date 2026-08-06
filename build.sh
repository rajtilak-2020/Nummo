#!/bin/bash
set -e

# Clone Flutter SDK if not present
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

echo "Building Flutter Web release..."
flutter build web --release --no-wasm-dry-run
