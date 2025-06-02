#!/bin/bash

# Script to compile and install Weatherspoon

# Directory where the script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Clean any previous build
rm -rf "$DIR/.build" "$DIR/build"

# Create build directory
mkdir -p "$DIR/build"

# Build using Swift Package Manager
cd "$DIR"
echo "Building Weatherspoon..."

# Use Swift Package Manager to build
echo "Building with Swift Package Manager..."
swift build -c release

# Copy the built executable to our build directory
echo "Copying executable..."
cp "$(swift build -c release --show-bin-path)/Weatherspoon" "$DIR/build/Weatherspoon"

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "Build failed. Please fix errors and try again."
    exit 1
fi

# Create app structure
APP_DIR="$DIR/build/Weatherspoon.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "Creating app bundle..."
# Copy executable
cp "$DIR/build/Weatherspoon" "$APP_DIR/Contents/MacOS/" || {
    echo "Error: Could not copy executable"
    exit 1
}

# Copy Info.plist
cp "$DIR/Resources/Info.plist" "$APP_DIR/Contents/" || {
    echo "Error: Could not copy Info.plist from Resources directory"
    exit 1
}

# Create basic PkgInfo
echo "APPLaplt" > "$APP_DIR/Contents/PkgInfo"

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
    echo "Build complete at $APP_DIR"
    echo "To install to /Applications, run this script with --install"
fi