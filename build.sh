#!/bin/bash
set -e

# Clone Flutter SDK if not present
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Automatically update sitemap lastmod date to current build date (YYYY-MM-DD)
BUILD_DATE=$(date -u +%Y-%m-%d)
echo "Updating sitemap lastmod date to $BUILD_DATE..."
sed -i -E "s/<lastmod>[0-9]{4}-[0-9]{2}-[0-9]{2}<\/lastmod>/<lastmod>${BUILD_DATE}<\/lastmod>/g" web/sitemap.xml

echo "Building Flutter Web release..."
flutter build web --release --no-wasm-dry-run
