# 🏥 iOS DICOM Viewer

> **Professional iOS DICOM viewer app with 3D rendering, segmentation support, and RT structure visualization. OHIF-inspired architecture for clinical-grade medical imaging.**

[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![DICOM](https://img.shields.io/badge/DICOM-Compliant-brightgreen.svg)](https://www.dicomstandard.org/)

## ⚠️ Medical Disclaimer

**This application is for informational and educational purposes only. It is not intended for clinical diagnosis or medical decision-making. Always consult qualified medical professionals for medical advice.**

## 🌟 Features

### 🏗️ **OHIF-Inspired Architecture**
- **Modular Design**: Clean separation of concerns with extensible components
- **Service-Oriented**: Centralized data management and business logic
- **Performance-First**: Optimized for large medical imaging datasets
- **Extension Ready**: Plugin architecture for specialized medical tools

### 📱 **Native iOS Integration**
- **Touch Interactions**: Professional pinch-to-zoom, pan, and gesture controls
- **File Import**: Seamless integration with Files app, iCloud Drive, and AirDrop
- **Modern UI**: Native iOS design patterns with medical imaging focus
- **Document Types**: Automatic DICOM file type registration and handling

### 🏥 **Medical Imaging Standards**
- **DICOM Compliance**: Standard-compliant metadata handling and parsing
- **Window/Level**: Medical-grade image display with clinical presets
- **Multi-Modality**: Support for CT, MRI, X-Ray, and other DICOM types
- **Multi-Frame**: Efficient handling of multi-slice studies and series

### 🎮 **Advanced Rendering**
- **2D Viewer**: High-performance image rendering with window/level adjustments
- **3D Ready**: Metal-based 3D volume rendering framework
- **Caching**: Memory-efficient image caching for smooth navigation
- **Real-time**: Responsive touch-based window/level adjustments

## 🚀 **Quick Start**

### **Prerequisites**
- macOS 12.0+ with Xcode 15.0+
- iOS 15.0+ target device or simulator
- Swift 5.9+ knowledge

### **1. Clone and Build**
```bash
git clone https://github.com/YOUR_USERNAME/iOS-DICOM-Viewer.git
cd iOS-DICOM-Viewer
open iOS_DICOMViewer.xcodeproj
```

### **2. Run with Sample Data**
- Build and run the project (⌘+R)
- The app includes sample DICOM studies for immediate testing
- Navigate through studies, series, and instances
- Test touch interactions and window/level adjustments

### **3. Import Real DICOM Files**
- Tap the "+" button in the study list
- Use the document picker to import DICOM files
- Support for Files app, iCloud Drive, and AirDrop

## 🔧 **DCMTK Integration (Optional)**

For production use with real DICOM files, integrate the DCMTK library:

```bash
# Build DCMTK for iOS
./build_dcmtk.sh

# Configure Xcode project:
# 1. Add library search paths
# 2. Link DCMTK libraries
# 3. Update bridging header
```

See [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) for detailed integration steps.

## 📋 **Project Structure**

```
iOS_DICOMViewer/
├── Core/
│   ├── Models/              # DICOM domain objects
│   │   ├── DICOMMetadata.swift
│   │   ├── DICOMStudy.swift
│   │   ├── DICOMSeries.swift
│   │   └── DICOMInstance.swift
│   └── Services/            # Business logic layer
│       ├── DICOMServiceManager.swift
│       ├── DICOMMetadataStore.swift
│       ├── DICOMFileImporter.swift
│       └── DICOMImageRenderer.swift
├── ViewControllers/         # UI presentation layer
│   ├── MainViewController.swift
│   ├── StudyListViewController.swift
│   └── ViewerViewController.swift
├── DICOM/
│   ├── Parser/             # DICOM file parsing
│   └── Bridge/             # DCMTK C++ integration
├── Rendering/
│   └── 3D/                 # Future 3D rendering
└── Extensions/
    ├── Segmentation/       # DICOM segmentation
    └── StructureSet/       # RT structure sets
```

## 🎯 **Core Capabilities**

### **Study Management**
- **Study List**: Browse imported DICOM studies with metadata
- **Series Navigation**: Multi-series support with thumbnail previews
- **Instance Browsing**: Frame-by-frame navigation with slider controls
- **File Import**: Multiple import methods with validation

### **Image Viewing**
- **Professional Viewer**: Medical-grade image display interface
- **Window/Level**: Touch-based adjustments with clinical presets
- **Zoom & Pan**: Smooth touch interactions with gesture recognition
- **Multi-Frame**: Efficient navigation through CT/MRI slices

### **Touch Interactions**
- **Pinch to Zoom**: Smooth scaling with automatic centering
- **Pan Gestures**: Window/level adjustment via finger movement
- **Double Tap**: Quick zoom reset functionality
- **Slider Navigation**: Precise instance-by-instance browsing

## 🛠️ **Architecture Highlights**

### **Service Layer Pattern**
```swift
// Centralized service coordination
DICOMServiceManager.shared.metadataStore
DICOMServiceManager.shared.fileImporter
DICOMServiceManager.shared.parser
```

### **Async/Await Integration**
```swift
// Modern Swift concurrency
Task {
    let study = try await DICOMParser.shared.parseFile(url)
    await metadataStore.addStudy(study)
}
```

### **Memory Management**
```swift
// Efficient caching with automatic cleanup
class DICOMImageCache {
    private let cache = NSCache<NSString, UIImage>()
    // Automatic memory pressure handling
}
```

## 🚀 **Future Extensions**

### **🎮 3D Rendering** *(Planned)*
- Metal-based volume rendering
- Multi-planar reconstruction (MPR)
- Isosurface visualization
- Real-time 3D interactions

### **🎨 Segmentation Support** *(Planned)*
- DICOM SEG overlay rendering
- Interactive segmentation tools
- Multi-segment visualization
- Color-coded anatomical regions

### **⚗️ RT Structure Sets** *(Planned)*
- RT Structure Set visualization
- Radiation therapy planning
- Dose distribution display
- Beam geometry visualization

### **📏 Advanced Measurements** *(Planned)*
- Distance and angle measurements
- Area and volume calculations
- Clinical measurement presets
- Automated analysis tools

## 🧪 **Sample Data**

The app includes built-in sample data for testing:
- **Sample CT Study**: Multi-slice abdominal CT with realistic metadata
- **Sample MR Series**: T1-weighted brain MR images
- **Realistic Parameters**: Authentic DICOM metadata and image characteristics

## 📚 **Documentation**

- [Implementation Summary](IMPLEMENTATION_SUMMARY.md) - Detailed technical overview
- [Build Instructions](README.md) - Setup and compilation guide
- [Architecture Guide](docs/architecture.md) *(Coming Soon)*
- [API Documentation](docs/api.md) *(Coming Soon)*

## 🤝 **Contributing**

We welcome contributions! Please see our contributing guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### **Development Setup**
```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/iOS-DICOM-Viewer.git

# Create feature branch
git checkout -b feature/new-feature

# Make changes and test
# Commit and push
```

## 📋 **Requirements**

### **Development**
- macOS 12.0+
- Xcode 15.0+
- Swift 5.9+
- iOS 15.0+ SDK

### **Runtime**
- iOS 15.0+
- 2GB+ RAM recommended
- 500MB+ available storage

### **Optional Dependencies**
- DCMTK 3.6.8+ (for production DICOM parsing)
- CMake 3.20+ (for DCMTK compilation)

## 🏷️ **Tags**

`ios` `dicom` `medical-imaging` `healthcare` `ohif` `swift` `xcode` `3d-rendering` `segmentation` `rt-structures` `medical-software` `imaging-viewer`

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **OHIF Viewers**: Architectural inspiration and design patterns
- **DCMTK Project**: DICOM parsing and processing capabilities
- **Medical Imaging Community**: Standards and best practices
- **Apple Developer Community**: iOS development excellence

## 📞 **Support**

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/iOS-DICOM-Viewer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/iOS-DICOM-Viewer/discussions)
- **Documentation**: [Project Wiki](https://github.com/YOUR_USERNAME/iOS-DICOM-Viewer/wiki)

---

**⚠️ Important**: This software is provided for educational and informational purposes only. It is not FDA approved and should not be used for clinical diagnosis or treatment decisions.
