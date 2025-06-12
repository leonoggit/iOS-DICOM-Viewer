# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS DICOM Viewer app built with Swift, inspired by OHIF Viewers architecture. It provides medical imaging capabilities with support for 2D/3D rendering, segmentation, and RT structure visualization.

## Build Commands

### Standard Build
```bash
# Open project in Xcode
open iOS_DICOMViewer.xcodeproj

# Build and run from Xcode (⌘+R)
# The app includes sample DICOM data for immediate testing
```

### DCMTK Integration (Real DICOM Parsing)
```bash
# Install dependencies
brew install cmake

# Build DCMTK libraries for iOS
./build_dcmtk.sh

# After building, configure Xcode project:
# 1. Add Library Search Paths: $(PROJECT_DIR)/iOS_DICOMViewer/Frameworks/DCMTK/lib
# 2. Add Header Search Paths: $(PROJECT_DIR)/iOS_DICOMViewer/Frameworks/DCMTK/include  
# 3. Link libraries: libdcmdata.a, libofstd.a, libdcmimgle.a, libdcmimage.a, libdcmjpeg.a
# 4. Uncomment DCMTK headers in iOS_DICOMViewer-Bridging-Header.h
# 5. Build with real DICOM parsing enabled
```

### Mock Build (Testing Without DCMTK)
```bash
# Use this for testing without full DCMTK integration
./build_dcmtk_mock.sh
```

## Architecture Overview

### Service Layer Pattern (OHIF-Inspired)
- **DICOMServiceManager**: Central coordinator for all DICOM services
- **DICOMMetadataStore**: In-memory storage for DICOM studies/series/instances
- **DICOMImageRenderer**: Image processing and window/level adjustments
- **DICOMFileImporter**: Async file import with validation

### View Controllers
- **MainViewController**: App coordinator and primary navigation
- **StudyListViewController**: DICOM study management interface
- **ViewerViewController**: Medical image viewer with touch interactions

### DICOM Data Flow
1. Files imported via DICOMFileImporter
2. Parsed by DICOMParser (with optional DCMTK integration)
3. Stored in DICOMMetadataStore as Study > Series > Instance hierarchy
4. Rendered by DICOMImageRenderer with medical imaging standards

### Extension Architecture
- **Segmentation**: `/Extensions/Segmentation/` - DICOM SEG support
- **Structure Sets**: `/Extensions/StructureSet/` - RT Structure visualization
- **3D Rendering**: `/Rendering/3D/` - Metal-based volume rendering

## Key Technical Details

### DICOM Models Hierarchy
```swift
DICOMStudy
├── DICOMSeries[]
    ├── DICOMInstance[]
        └── DICOMMetadata
```

### Service Initialization
Services are initialized through `DICOMServiceManager.shared.initialize()` which sets up all core and extension services with proper dependencies.

### Real DICOM Parsing (DCMTKBridge.mm)
- **Robust DICOM parsing** using DCMTK C++ library
- **Pixel data extraction** supporting 8-bit and 16-bit data
- **Comprehensive metadata parsing** - all standard DICOM tags
- **Transfer syntax support** including JPEG, RLE, uncompressed
- **Multi-frame support** for dynamic and temporal studies
- **DICOM Segmentation (SEG)** parsing for overlays
- **RT Structure Sets** parsing for radiotherapy contours
- **Error handling** with comprehensive exception catching
- **Memory efficient** pixel data processing with DicomImage
- **Window/Level extraction** with multi-value support

### Advanced 3D Volume Rendering (VolumeRenderer.swift)
- **Multiple rendering modes**: Ray casting, Maximum Intensity Projection (MIP), Isosurface rendering
- **High-performance Metal compute shaders** with GPU acceleration
- **Gradient-based shading** for enhanced 3D visualization
- **Quality levels**: Low, Medium, High, Ultra (adaptive based on device capabilities)
- **Advanced camera controls** with spherical coordinate rotation
- **Transfer function presets** for CT, MR, and specialized tissue types
- **Real-time performance monitoring** with FPS tracking
- **Memory-efficient volume loading** with async batch processing
- **Window/level integration** from DICOM metadata
- **Jittering and anti-aliasing** for high-quality rendering

### Multi-Planar Reconstruction (MPR) - MPRRenderer.swift
- **Three orthogonal views**: Axial, Sagittal, Coronal slice visualization
- **Real-time slice navigation** with synchronized crosshair positioning
- **Interactive transformations**: Zoom, pan, rotation, flip operations
- **Window/Level controls** with DICOM-compliant adjustments
- **Crosshair synchronization** across tri-planar views
- **Touch gesture support** for intuitive medical image interaction
- **Thick slice MIP rendering** for enhanced visualization
- **Oblique and curved MPR** for advanced viewing angles
- **Annotation overlays** with slice information and measurements
- **Metal compute pipeline** for high-performance 2D slice extraction

### ROI Tools and Measurement Capabilities
- **Linear measurements**: Distance calculations with sub-pixel accuracy
- **Area measurements**: Circular, rectangular, elliptical, and polygon ROIs
- **Angle measurements**: Three-point angular measurement tool
- **Statistical analysis**: Mean, std dev, min/max, histogram analysis for ROIs
- **Real-world units**: Automatic conversion using DICOM pixel spacing
- **Interactive editing**: Touch-based tool creation and modification
- **Persistent storage**: Save/load ROI annotations per DICOM instance
- **Export capabilities**: JSON, text reports, and sharing functionality
- **Metal-based rendering**: High-performance GPU annotation overlay
- **Medical compliance**: Audit logging and measurement validation

### Bridging to C++/DCMTK
- Real DCMTK integration in `/DICOM/Bridge/DCMTKBridge.mm`
- Swift bridging header: `iOS_DICOMViewer-Bridging-Header.h`
- Module map for DCMTK at `Frameworks/DCMTK/module.modulemap`
- Automatic JPEG decoder registration for compressed transfer syntaxes

### Medical Imaging Standards
- Window/Level adjustments for clinical viewing
- DICOM-compliant metadata handling
- Multi-modality support (CT, MR, X-Ray)
- Standard medical imaging presets

## Development Notes

### Sample Data
The app includes built-in sample DICOM data for testing without requiring real medical files.

### File Import
Supports iOS Files app integration, iCloud Drive, and AirDrop for DICOM file import.

### Performance Considerations
- Image caching with NSCache for memory efficiency
- Async/await patterns for non-blocking operations
- Lazy loading of DICOM instances

### Comprehensive Testing Framework
- **Unit Tests**: Core functionality validation for DICOM parsing, rendering, and data models
- **Integration Tests**: End-to-end workflow testing with real DICOM data processing
- **UI Tests**: Automated testing of touch interactions, navigation, and accessibility
- **Performance Tests**: Rendering benchmarks, memory usage validation, and scalability testing
- **Compliance Tests**: Medical imaging standards (DICOM), FDA guidelines, and clinical requirements
- **Rendering Tests**: 3D volume rendering accuracy, MPR precision, and Metal pipeline validation
- **Memory Tests**: Leak detection, large dataset handling, and resource management
- **Concurrent Tests**: Multi-threaded rendering and data processing validation

## Medical Compliance

This is educational software with medical disclaimer. Not intended for clinical diagnosis or treatment decisions.

## Implementation Guidelines

- Remember to always optimize implementation for iOS environment and iOS native deployment
- Prioritize iOS-native technologies and frameworks (Swift, SwiftUI, Metal, Core Graphics)
- Ensure memory efficiency and performance tuning specific to iOS devices
- Leverage iOS-specific optimizations and architectural best practices