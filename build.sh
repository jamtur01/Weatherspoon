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

# Sign the application
if [ -z "$CI" ]; then
  if [ -n "$APPLE_DEVELOPER_CERTIFICATE_P12_BASE64" ] && [ -n "$APPLE_DEVELOPER_CERTIFICATE_PASSWORD" ]; then
    echo "Code signing the application with Developer ID..."

    KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
    KEYCHAIN_PASSWORD="temporary-password"

    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

    echo $APPLE_DEVELOPER_CERTIFICATE_P12_BASE64 | base64 --decode > certificate.p12
    security import certificate.p12 -k "$KEYCHAIN_PATH" -P "$APPLE_DEVELOPER_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

    echo "Available signing identities:"
    security find-identity -v -p codesigning "$KEYCHAIN_PATH"

    IDENTITY_HASH=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -o '[A-F0-9]\{40\}' | head -1)

    if [ -z "$IDENTITY_HASH" ]; then
      echo "No signing identity found in keychain. Using ad-hoc signing instead."
      /usr/bin/codesign --force --options runtime --sign - "$APP_DIR" --deep
    else
      echo "Signing with identity hash: $IDENTITY_HASH"
      /usr/bin/codesign --force --options runtime --entitlements "$DIR/Resources/Weatherspoon.entitlements" \
        --sign "$IDENTITY_HASH" \
        --keychain "$KEYCHAIN_PATH" \
        "$APP_DIR" --deep --timestamp
    fi

    echo "Verifying signature..."
    codesign -vvv --deep --strict "$APP_DIR" || echo "Warning: Signature verification failed, but continuing..."
    rm certificate.p12
  else
    echo "No Developer ID certificate provided, using ad-hoc signing instead..."

    if [ -r "$DIR/Resources/Weatherspoon.entitlements" ]; then
      echo "Using entitlements file..."
      /usr/bin/codesign --force --options runtime --entitlements "$DIR/Resources/Weatherspoon.entitlements" --sign - "$APP_DIR" --deep
    else
      echo "Entitlements file not found or not readable, using basic ad-hoc signing..."
      /usr/bin/codesign --force --options runtime --sign - "$APP_DIR" --deep
    fi

    echo "Note: App is signed with ad-hoc signature. Users will need to right-click and select Open"
    echo "or use 'xattr -cr Weatherspoon.app' after downloading to bypass Gatekeeper."
  fi
else
  echo "CI environment detected; skipping codesign in build.sh (handled by workflow)"
fi

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