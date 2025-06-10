#!/bin/bash

# DCMTK Build Script for iOS DICOM Viewer
# This script downloads and builds DCMTK for iOS

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCMTK_DIR="$PROJECT_ROOT/External/dcmtk"
BUILD_DIR="$PROJECT_ROOT/External/dcmtk-build"
INSTALL_DIR="$PROJECT_ROOT/iOS_DICOMViewer/Frameworks/DCMTK"

echo "🏗️  Building DCMTK for iOS DICOM Viewer"
echo "Project root: $PROJECT_ROOT"

# Create directories
mkdir -p "$PROJECT_ROOT/External"
mkdir -p "$INSTALL_DIR/include"
mkdir -p "$INSTALL_DIR/lib"

# Download DCMTK if not exists
if [ ! -d "$DCMTK_DIR" ]; then
    echo "📥 Downloading DCMTK..."
    cd "$PROJECT_ROOT/External"
    git clone https://github.com/DCMTK/dcmtk.git
    cd dcmtk
    git checkout DCMTK-3.6.8  # Use stable version
else
    echo "✅ DCMTK already downloaded"
fi

# iOS toolchain setup
IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="15.0"

# Build for iOS Device (arm64)
echo "🔨 Building DCMTK for iOS (arm64)..."
mkdir -p "$BUILD_DIR/ios-arm64"
cd "$BUILD_DIR/ios-arm64"

cmake "$DCMTK_DIR" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_MIN_VERSION \
    -DCMAKE_OSX_SYSROOT=$IOS_SDK_PATH \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DDCMTK_WITH_THREADS=OFF \
    -DDCMTK_WITH_ZLIB=OFF \
    -DDCMTK_WITH_OPENSSL=OFF \
    -DDCMTK_WITH_PNG=OFF \
    -DDCMTK_WITH_TIFF=OFF \
    -DDCMTK_WITH_XML=OFF \
    -DDCMTK_WITH_ICONV=OFF \
    -DDCMTK_WITH_ICU=OFF \
    -DDCMTK_WITH_WRAP=OFF \
    -DDCMTK_ENABLE_BUILTIN_DICTIONARY=ON \
    -DDCMTK_ENABLE_PRIVATE_TAGS=ON \
    -DBUILD_SHARED_LIBS=OFF

make -j$(sysctl -n hw.ncpu)

# Build for iOS Simulator (x86_64 and arm64)
echo "🔨 Building DCMTK for iOS Simulator..."
IOS_SIM_SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)

# x86_64 simulator
mkdir -p "$BUILD_DIR/ios-sim-x86_64"
cd "$BUILD_DIR/ios-sim-x86_64"

cmake "$DCMTK_DIR" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_MIN_VERSION \
    -DCMAKE_OSX_SYSROOT=$IOS_SIM_SDK_PATH \
    -DCMAKE_BUILD_TYPE=Release \
    -DDCMTK_WITH_THREADS=OFF \
    -DDCMTK_WITH_ZLIB=OFF \
    -DDCMTK_WITH_OPENSSL=OFF \
    -DDCMTK_WITH_PNG=OFF \
    -DDCMTK_WITH_TIFF=OFF \
    -DDCMTK_WITH_XML=OFF \
    -DDCMTK_WITH_ICONV=OFF \
    -DDCMTK_WITH_ICU=OFF \
    -DDCMTK_WITH_WRAP=OFF \
    -DDCMTK_ENABLE_BUILTIN_DICTIONARY=ON \
    -DDCMTK_ENABLE_PRIVATE_TAGS=ON \
    -DBUILD_SHARED_LIBS=OFF

make -j$(sysctl -n hw.ncpu)

# arm64 simulator
mkdir -p "$BUILD_DIR/ios-sim-arm64"
cd "$BUILD_DIR/ios-sim-arm64"

cmake "$DCMTK_DIR" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_MIN_VERSION \
    -DCMAKE_OSX_SYSROOT=$IOS_SIM_SDK_PATH \
    -DCMAKE_BUILD_TYPE=Release \
    -DDCMTK_WITH_THREADS=OFF \
    -DDCMTK_WITH_ZLIB=OFF \
    -DDCMTK_WITH_OPENSSL=OFF \
    -DDCMTK_WITH_PNG=OFF \
    -DDCMTK_WITH_TIFF=OFF \
    -DDCMTK_WITH_XML=OFF \
    -DDCMTK_WITH_ICONV=OFF \
    -DDCMTK_WITH_ICU=OFF \
    -DDCMTK_WITH_WRAP=OFF \
    -DDCMTK_ENABLE_BUILTIN_DICTIONARY=ON \
    -DDCMTK_ENABLE_PRIVATE_TAGS=ON \
    -DBUILD_SHARED_LIBS=OFF

make -j$(sysctl -n hw.ncpu)

# Create universal libraries
echo "🔗 Creating universal libraries..."
cd "$INSTALL_DIR"

# List of DCMTK libraries to combine
LIBRARIES=(
    "dcmdata"
    "ofstd"
    "dcmimgle"
    "dcmimage"
    "dcmjpeg"
    "ijg8"
    "ijg12"
    "ijg16"
)

for lib in "${LIBRARIES[@]}"; do
    if [ -f "$BUILD_DIR/ios-arm64/lib/lib${lib}.a" ]; then
        echo "📦 Creating universal library for lib${lib}.a"
        lipo -create \
            "$BUILD_DIR/ios-arm64/lib/lib${lib}.a" \
            "$BUILD_DIR/ios-sim-x86_64/lib/lib${lib}.a" \
            "$BUILD_DIR/ios-sim-arm64/lib/lib${lib}.a" \
            -output "$INSTALL_DIR/lib/lib${lib}.a"
    fi
done

# Copy headers
echo "📋 Copying headers..."
if [ -d "$BUILD_DIR/ios-arm64/include" ]; then
    cp -R "$BUILD_DIR/ios-arm64/include/"* "$INSTALL_DIR/include/"
fi

# Copy config headers from source
if [ -d "$DCMTK_DIR/config/include" ]; then
    cp -R "$DCMTK_DIR/config/include/"* "$INSTALL_DIR/include/"
fi

# Create module map for Swift interop
echo "🗺️  Creating module map..."
cat > "$INSTALL_DIR/module.modulemap" << EOF
module DCMTK {
    header "dcmtk/dcmdata/dctk.h"
    header "dcmtk/dcmimgle/dcmimage.h"
    header "dcmtk/dcmimage/diregist.h"
    export *
}
EOF

# Create Info.plist for framework
cat > "$INSTALL_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>org.dcmtk.DCMTK</string>
    <key>CFBundleName</key>
    <string>DCMTK</string>
    <key>CFBundleVersion</key>
    <string>3.6.8</string>
</dict>
</plist>
EOF

echo "✅ DCMTK build complete!"
echo "📁 Libraries installed in: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "1. Open iOS_DICOMViewer.xcodeproj in Xcode"
echo "2. Add the following to Build Settings:"
echo "   - Library Search Paths: \$(PROJECT_DIR)/iOS_DICOMViewer/Frameworks/DCMTK/lib"
echo "   - Header Search Paths: \$(PROJECT_DIR)/iOS_DICOMViewer/Frameworks/DCMTK/include"
echo "3. Link the following libraries in Build Phases:"
for lib in "${LIBRARIES[@]}"; do
    echo "   - lib${lib}.a"
done
echo "4. Set Objective-C Bridging Header to: iOS_DICOMViewer-Bridging-Header.h"
echo ""
echo "🎉 Ready to build the iOS DICOM Viewer!"
