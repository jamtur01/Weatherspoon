#!/bin/bash

# Exit on error
set -e

# Get version from VERSION file
VERSION=$(cat VERSION)

echo "Building Weatherspoon version $VERSION..."

# Directory where the script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Clean any previous build
rm -rf "$DIR/.build" "$DIR/build"

# Create build directory
mkdir -p "$DIR/build"

# Build using Swift
cd "$DIR"
echo "Building with Swift..."
swift build -c release

# Create app structure
APP_DIR="$DIR/build/Weatherspoon.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Creating app bundle..."
# Copy executable
cp "$(swift build -c release --show-bin-path)/Weatherspoon" "$MACOS_DIR/" || {
    echo "Error: Could not copy executable"
    exit 1
}

# Copy Info.plist
cp "$DIR/Resources/Info.plist" "$CONTENTS_DIR/" || {
    echo "Error: Could not copy Info.plist from Resources directory"
    exit 1
}

# Create basic PkgInfo
echo "APPLaplt" > "$CONTENTS_DIR/PkgInfo"

# Copy app to Applications folder if requested
if [ "$1" == "--install" ]; then
    echo "Installing to /Applications..."
    cp -R "$APP_DIR" "/Applications/" || {
        echo "Error: Could not copy to /Applications. Try running with sudo."
        exit 1
    }
    echo "Weatherspoon installed to /Applications"
    echo "You can now launch it from /Applications/Weatherspoon.app"
else
    echo "Application bundle created: $APP_DIR"
    echo "To install to /Applications, run this script with --install"
fi