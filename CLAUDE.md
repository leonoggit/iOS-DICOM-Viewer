# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS DICOM Viewer app built with Swift, inspired by OHIF Viewers architecture. It provides medical imaging capabilities with support for 2D/3D rendering, segmentation, and RT structure visualization.

## MCP Server Configuration

### Automatic Initialization
```bash
# Initialize all MCP servers for this project
./MCPs/init-all-mcps.sh
```

### Manual MCP Setup
```bash
# Add all MCP servers individually
claude mcp add filesystem "npx -y @modelcontextprotocol/server-filesystem /Users/leandroalmeida/iOS_DICOM"
claude mcp add memory "npx -y @modelcontextprotocol/server-memory"
claude mcp add github "npx -y @modelcontextprotocol/server-github"
claude mcp add brave-search "npx -y @modelcontextprotocol/server-brave-search"
claude mcp add postgres "npx -y @modelcontextprotocol/server-postgres"
claude mcp add XcodeBuildMCP "npx -y xcodebuildmcp@latest"
claude mcp add custom-dicom-mcp "/Users/leandroalmeida/iOS_DICOM/MCPs/custom-dicom-mcp/dist/index.js"
claude mcp add swift-tools-mcp "/Users/leandroalmeida/iOS_DICOM/MCPs/swift-tools-mcp/dist/index.js"
claude mcp add github-copilot-medical-ios "/Users/leandroalmeida/iOS_DICOM/MCPs/github-copilot-medical-ios/dist/index.js"

# Verify configuration
claude mcp list
```

### Available MCP Tools
- **filesystem**: File system operations for project files
- **memory**: Persistent context and conversation memory
- **github**: GitHub integration for repository management
- **brave-search**: Web search capabilities for research
- **postgres**: Database operations for DICOM metadata storage
- **XcodeBuildMCP**: Xcode build and project management tools
- **custom-dicom-mcp**: Specialized DICOM medical imaging tools
- **swift-tools-mcp**: Swift and iOS development optimization tools
- **github-copilot-medical-ios**: Enhanced code generation with medical context

### Environment Variables
```bash
# Required for GitHub integration
export GITHUB_TOKEN="your_github_token"

# Optional for enhanced functionality
export BRAVE_API_KEY="your_brave_api_key"
export POSTGRES_CONNECTION_STRING="your_postgres_connection"
```

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

### Advanced Automatic Segmentation System
- **Clinical-Grade Urinary Tract Segmentation**: Specialized service for bilateral kidneys, ureters, bladder, and stone detection
- **Multi-Algorithm Pipeline**: Traditional computer vision + deep learning preparation for nnU-Net/MONAI integration
- **GPU-Accelerated Processing**: Metal compute shaders for real-time segmentation with specialized kernels
- **Quality Validation**: Clinical compliance metrics including Dice coefficient, Jaccard index, and anatomical consistency
- **Progressive Enhancement**: Hybrid approach combining traditional algorithms with future CoreML model integration

#### AutomaticSegmentationService.swift
- **Enhanced tissue thresholds** for urinary tract structures with contrast-enhanced and non-enhanced CT support
- **Multi-organ segmentation** supporting liver, kidneys, spleen, pancreas with organ-specific parameters
- **Morphological operations** with erosion, dilation, opening, closing for boundary refinement
- **Connected components analysis** for noise reduction and structure isolation
- **Specialized urinary tract methods** including bilateral kidney separation and tubular structure detection

#### UrinaryTractSegmentationService.swift
- **Clinical-grade precision** with multi-phase segmentation pipeline (kidneys → ureters → bladder → stones)
- **Bilateral kidney segmentation** with anatomical constraints and automatic left/right separation
- **Tubular structure enhancement** for ureter tracking using renal pelvis seed points
- **Bladder fluid detection** with variance analysis for uniform fluid identification
- **Stone detection pipeline** with high-density analysis and contrast validation
- **Real-time progress tracking** with detailed phase reporting and quality metrics
- **Clinical findings extraction** including volume measurements, asymmetry analysis, and stone characterization

#### CoreMLSegmentationService.swift
- **Future-ready infrastructure** for nnU-Net, MONAI, and TotalSegmentator model integration
- **Hybrid processing modes**: Traditional-only, deep learning-only, hybrid fusion, ensemble, and cascaded approaches
- **Model management system** with automatic downloading, caching, and version control
- **Quality validation pipeline** with output consistency and anatomical plausibility checks
- **Clinical deployment preparation** with validation datasets and FDA compliance framework

#### AutoSegmentationShaders.metal
- **Specialized GPU kernels** for urinary tract processing with bilateral kidney segmentation
- **Tubular structure enhancement** using gradient analysis for ureter detection
- **High-density stone detection** with contrast-based validation
- **Boundary refinement algorithms** for precise organ edge detection
- **Anatomical constraint validation** ensuring clinically plausible results

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

## Advanced Segmentation Implementation Status

### ✅ Completed Features (December 2024)
1. **Enhanced Traditional Algorithms** with urinary tract-specific optimizations
   - Clinical-grade tissue thresholds for contrast-enhanced and non-enhanced CT
   - Bilateral kidney detection with automatic left/right separation
   - Specialized Hounsfield unit ranges for kidneys, ureters, bladder, stones
   - Multi-organ segmentation pipeline with quality validation

2. **UrinaryTractSegmentationService** with clinical parameters
   - Multi-phase segmentation: kidneys → ureters → bladder → stones
   - Real-time progress tracking with detailed phase reporting
   - Clinical findings extraction (volumes, asymmetry, stone analysis)
   - Quality metrics including Dice coefficient and anatomical consistency

3. **GPU-Accelerated Metal Shaders** for real-time processing
   - Bilateral kidney segmentation kernels
   - Tubular structure enhancement for ureter detection
   - High-density stone detection with contrast validation
   - Boundary refinement and anatomical constraint validation

4. **CoreML Integration Infrastructure** for future deep learning models
   - nnU-Net, MONAI, and TotalSegmentator model preparation
   - Hybrid processing modes (traditional + deep learning fusion)
   - Model management with downloading and caching
   - Clinical validation pipeline for FDA compliance

5. **Complete UI Integration** in MainViewController
   - Segmentation action buttons with progress tracking
   - Comprehensive result display with clinical metrics
   - Export functionality for clinical reports
   - Error handling and fallback mechanisms

### 🚧 Next Implementation Steps

#### High Priority
1. **TotalSegmentator Model Integration**
   - Download and convert TotalSegmentator PyTorch models to CoreML
   - Implement proper preprocessing pipeline for model input requirements
   - Add model versioning and automatic updates

2. **3D Mesh Generation and Visualization**
   - Implement marching cubes algorithm for mesh generation from segmentation masks
   - Extend VolumeRenderer to display segmentation overlays
   - Add organ-specific colors and interactive selection
   - Real-time 3D segmentation overlay with performance optimization

3. **Enhanced 3D Renderer Integration**
   - Multi-organ 3D rendering with transparency controls
   - Interactive organ isolation and highlighting
   - Progressive mesh loading for large datasets

#### Medium Priority
4. **Model Management System**
   - Automatic model downloading from cloud storage
   - Version control and compatibility checking
   - Fallback strategies when models are unavailable

5. **Performance Optimization**
   - Progressive loading and Level-of-Detail (LOD) rendering
   - Streaming segmentation for multi-slice processing
   - Memory optimization for real-time 3D visualization

6. **Clinical Validation Pipeline**
   - Accuracy metrics and validation datasets
   - FDA compliance preparation and audit logging
   - Clinical study integration framework

### Technical Architecture Decisions

#### Segmentation Processing Pipeline
```
DICOM Input → Traditional Algorithms → CoreML Enhancement → 3D Mesh → Visualization
     ↓              ↓                      ↓               ↓           ↓
Validation → GPU Acceleration → Quality Metrics → Interactive → Clinical Report
```

#### Service Integration Pattern
- **AutomaticSegmentationService**: Base algorithms and multi-organ support
- **UrinaryTractSegmentationService**: Specialized clinical-grade urinary tract processing
- **CoreMLSegmentationService**: Deep learning model integration and hybrid processing
- **VolumeRenderer**: 3D visualization with segmentation overlay support

## Troubleshooting Guide

### Black Screen UI Issue (Resolved)
**Problem**: MainViewController showing black screen during initialization
**Root Causes Identified**:
1. **Async service initialization blocking main thread**
2. **Missing UI state updates during service loading**
3. **Premature view controller transitions**

**Solution Implemented**:
1. **Elegant loading interface** with welcome card and progress indicators
2. **Proper async/await patterns** for service initialization
3. **Graceful UI transitions** with animation and state management
4. **Error handling** with user-friendly fallback states

**Code Reference**: `MainViewController.swift:187-207` - initializeDICOMServices()

### Service Initialization Pattern
```swift
private func initializeDICOMServices() {
    Task {
        do {
            try await DICOMServiceManager.shared.initialize()
            await initializeSegmentationServices()
            await MainActor.run {
                self.updateUIForServicesReady()
            }
        } catch {
            await MainActor.run {
                self.updateUIForServicesError()
            }
        }
    }
}
```

### Metal Pipeline Debugging
- **Compute pipeline validation**: Check shader compilation and buffer allocation
- **Texture format compatibility**: Ensure proper pixel format for segmentation masks
- **Thread group sizing**: Optimize threadgroup dimensions for target hardware
- **Memory management**: Monitor GPU memory usage during segmentation processing

### Performance Optimization Tips
- **Lazy loading**: Initialize segmentation services only when needed
- **Progressive enhancement**: Start with traditional algorithms, enhance with deep learning
- **Caching strategies**: Cache segmentation results for repeated access
- **Background processing**: Use global queues for compute-intensive operations