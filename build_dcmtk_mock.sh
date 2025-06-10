#!/bin/bash

# Simplified DCMTK Mock Framework for iOS DICOM Viewer
# This creates a mock DCMTK framework structure for compilation compatibility
# Real DICOM parsing will be handled by Swift DICOM libraries

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$PROJECT_ROOT/iOS_DICOMViewer/Frameworks/DCMTK"

echo "🏗️  Creating Mock DCMTK Framework for iOS DICOM Viewer"
echo "Project root: $PROJECT_ROOT"

# Create directories
mkdir -p "$INSTALL_DIR/include/dcmtk/dcmdata"
mkdir -p "$INSTALL_DIR/include/dcmtk/dcmimgle"
mkdir -p "$INSTALL_DIR/include/dcmtk/dcmimage"
mkdir -p "$INSTALL_DIR/include/dcmtk/ofstd"
mkdir -p "$INSTALL_DIR/lib"

# Create mock headers that provide the interface expected by DCMTKBridge
cat > "$INSTALL_DIR/include/dcmtk/dcmdata/dctk.h" << 'EOF'
#ifndef DCTK_H
#define DCTK_H

// Mock DCMTK headers for iOS compilation compatibility
// Real DICOM functionality implemented in Swift

#ifdef __cplusplus
extern "C" {
#endif

// Basic DICOM types
typedef struct {
    unsigned short group;
    unsigned short element;
} DcmTagKey;

typedef struct {
    char* value;
    size_t length;
} DcmElement;

// Mock functions for compatibility
int dcmDataDict_isDefined() { return 1; }
void dcmDataDict_clear() {}

#ifdef __cplusplus
}
#endif

#endif // DCTK_H
EOF

cat > "$INSTALL_DIR/include/dcmtk/dcmimgle/dcmimage.h" << 'EOF'
#ifndef DCMIMAGE_H
#define DCMIMAGE_H

// Mock DCMTK image headers for iOS compilation compatibility
#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int width;
    int height;
    int depth;
} DicomImageInfo;

#ifdef __cplusplus
}
#endif

#endif // DCMIMAGE_H
EOF

cat > "$INSTALL_DIR/include/dcmtk/dcmimage/diregist.h" << 'EOF'
#ifndef DIREGIST_H
#define DIREGIST_H

// Mock DCMTK registration headers for iOS compilation compatibility
#ifdef __cplusplus
extern "C" {
#endif

void DiRegisterGlobalDecompressionCodecs() {}
void DiRegisterGlobalCompressionCodecs() {}

#ifdef __cplusplus
}
#endif

#endif // DIREGIST_H
EOF

cat > "$INSTALL_DIR/include/dcmtk/ofstd/oftypes.h" << 'EOF'
#ifndef OFTYPES_H
#define OFTYPES_H

// Mock DCMTK basic types for iOS compilation compatibility
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef uint8_t  Uint8;
typedef uint16_t Uint16;
typedef uint32_t Uint32;
typedef int8_t   Sint8;
typedef int16_t  Sint16;
typedef int32_t  Sint32;

#ifdef __cplusplus
}
#endif

#endif // OFTYPES_H
EOF

# Create empty static libraries for linking
echo "📦 Creating mock static libraries..."
cat > "$INSTALL_DIR/lib/empty.c" << 'EOF'
// Empty source file for creating mock libraries
void dcmtk_mock_function() {}
EOF

# Compile mock libraries
clang -c "$INSTALL_DIR/lib/empty.c" -o "$INSTALL_DIR/lib/empty.o"

# Create mock static libraries
ar rcs "$INSTALL_DIR/lib/libdcmdata.a" "$INSTALL_DIR/lib/empty.o"
ar rcs "$INSTALL_DIR/lib/libofstd.a" "$INSTALL_DIR/lib/empty.o"
ar rcs "$INSTALL_DIR/lib/libdcmimgle.a" "$INSTALL_DIR/lib/empty.o"
ar rcs "$INSTALL_DIR/lib/libdcmimage.a" "$INSTALL_DIR/lib/empty.o"

# Clean up
rm "$INSTALL_DIR/lib/empty.c" "$INSTALL_DIR/lib/empty.o"

# Create module map for Swift interop
echo "🗺️  Creating module map..."
cat > "$INSTALL_DIR/module.modulemap" << 'EOF'
module DCMTK {
    header "dcmtk/dcmdata/dctk.h"
    header "dcmtk/dcmimgle/dcmimage.h"
    header "dcmtk/dcmimage/diregist.h"
    export *
}
EOF

# Create Info.plist for framework
cat > "$INSTALL_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>org.dcmtk.DCMTK.Mock</string>
    <key>CFBundleName</key>
    <string>DCMTK Mock</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
</dict>
</plist>
EOF

echo "✅ Mock DCMTK framework created successfully!"
echo "📁 Framework installed in: $INSTALL_DIR"
echo ""
echo "This mock framework provides:"
echo "- Header compatibility for DCMTKBridge compilation"
echo "- Empty static libraries for linking"
echo "- Module map for Swift interoperability" 
echo ""
echo "Real DICOM functionality will be implemented using:"
echo "- Swift DICOM parsing libraries"
echo "- Native iOS image processing"
echo "- Direct pixel data manipulation"
echo ""
echo "Next steps:"
echo "1. Open iOS_DICOMViewer.xcodeproj in Xcode"
echo "2. Build the project (should compile successfully now)"
echo "3. Implement native Swift DICOM parsing in DCMTKBridge.mm"
echo ""
echo "🎉 Ready to build the iOS DICOM Viewer with native Swift implementation!"
