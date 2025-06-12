#!/bin/bash

# Configure Xcode Project for DCMTK Integration
# This script configures the iOS DICOM Viewer project with proper DCMTK settings

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FILE="$PROJECT_ROOT/iOS_DICOMViewer.xcodeproj/project.pbxproj"

echo "🔧 Configuring Xcode project for DCMTK integration..."

# Check if project file exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Project file not found at: $PROJECT_FILE"
    exit 1
fi

# Check if DCMTK frameworks exist
DCMTK_LIB_DIR="$PROJECT_ROOT/iOS_DICOMViewer/Frameworks/DCMTK/lib"
DCMTK_INCLUDE_DIR="$PROJECT_ROOT/iOS_DICOMViewer/Frameworks/DCMTK/include"

if [ ! -d "$DCMTK_LIB_DIR" ]; then
    echo "❌ DCMTK lib directory not found. Run ./build_dcmtk_mock.sh first"
    exit 1
fi

if [ ! -d "$DCMTK_INCLUDE_DIR" ]; then
    echo "❌ DCMTK include directory not found. Run ./build_dcmtk_mock.sh first"
    exit 1
fi

echo "✅ DCMTK frameworks found"

# Verify key project settings are in place
if grep -q "HEADER_SEARCH_PATHS.*DCMTK" "$PROJECT_FILE"; then
    echo "✅ Header search paths configured"
else
    echo "⚠️  Header search paths not found in project"
fi

if grep -q "LIBRARY_SEARCH_PATHS.*DCMTK" "$PROJECT_FILE"; then
    echo "✅ Library search paths configured"
else
    echo "⚠️  Library search paths not found in project"
fi

if grep -q "SWIFT_OBJC_BRIDGING_HEADER" "$PROJECT_FILE"; then
    echo "✅ Bridging header configured"
else
    echo "⚠️  Bridging header not configured"
fi

# Check for DCMTK libraries
echo "📦 Checking DCMTK libraries:"
for lib in libdcmdata.a libofstd.a libdcmimgle.a libdcmimage.a; do
    if [ -f "$DCMTK_LIB_DIR/$lib" ]; then
        echo "  ✅ $lib"
    else
        echo "  ❌ $lib (missing)"
    fi
done

# Check for DCMTK headers
echo "📋 Checking DCMTK headers:"
for header in "dcmtk/dcmdata/dctk.h" "dcmtk/dcmimgle/dcmimage.h" "dcmtk/dcmimage/diregist.h"; do
    if [ -f "$DCMTK_INCLUDE_DIR/$header" ]; then
        echo "  ✅ $header"
    else
        echo "  ❌ $header (missing)"
    fi
done

# Instructions for manual configuration
echo ""
echo "🏗️  Manual Configuration Steps for Xcode:"
echo "1. Open iOS_DICOMViewer.xcodeproj in Xcode"
echo "2. Select the project in the navigator"
echo "3. Go to Build Settings"
echo "4. Verify the following settings:"
echo ""
echo "   Header Search Paths:"
echo "   \$(PROJECT_DIR)/iOS_DICOMViewer/Frameworks/DCMTK/include"
echo ""
echo "   Library Search Paths:"
echo "   \$(PROJECT_DIR)/iOS_DICOMViewer/Frameworks/DCMTK/lib"
echo ""
echo "   Swift Objective-C Bridging Header:"
echo "   iOS_DICOMViewer-Bridging-Header.h"
echo ""
echo "5. In Build Phases > Link Binary With Libraries, add:"
echo "   - libdcmdata.a"
echo "   - libofstd.a"
echo "   - libdcmimgle.a"
echo "   - libdcmimage.a"
echo ""
echo "6. Add DCMTKBridge.mm to Sources build phase"
echo ""
echo "🎉 Ready to build with DCMTK integration!"