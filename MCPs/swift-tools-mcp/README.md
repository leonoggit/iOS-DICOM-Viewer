# Swift Tools MCP Server

A comprehensive Model Context Protocol (MCP) server providing specialized Swift and iOS development tools for enhanced Claude Code capabilities when working with iOS projects, particularly medical imaging applications.

## Features

### 🏗️ Xcode Project Management
- **Project Analysis**: Comprehensive analysis of Xcode projects (.xcodeproj/.xcworkspace)
- **Target Management**: Analyze build targets, schemes, and configurations
- **Build Settings Validation**: Validate build settings for iOS deployment best practices
- **Dependency Analysis**: Detect and analyze CocoaPods, Swift Package Manager dependencies
- **Project Health Checks**: Identify configuration issues and inconsistencies

### 📱 iOS Development Utilities
- **Simulator Management**: List, boot, shutdown, and manage iOS simulators
- **App Installation**: Install and launch apps on simulators
- **Deployment Validation**: Validate iOS deployment configuration and requirements
- **Info.plist Analysis**: Parse and validate Info.plist settings
- **Certificate Management**: Analyze code signing certificates and provisioning profiles

### 🚀 Swift Code Analysis
- **Syntax Checking**: Validate Swift code syntax and compilation
- **Style Guidelines**: Check Swift style guidelines and naming conventions
- **Performance Analysis**: Identify performance issues and anti-patterns
- **Memory Management**: Detect potential memory leaks and retain cycles
- **iOS Best Practices**: Check for iOS-specific best practices and patterns

### ⚡ Metal Shader Support
- **Shader Compilation**: Compile and validate Metal shaders for iOS
- **Performance Analysis**: Analyze Metal shader performance and optimization opportunities
- **Compatibility Checking**: Validate Metal version requirements and device compatibility
- **Medical Imaging Optimization**: Specialized checks for DICOM and medical imaging shaders

### 🧠 Memory Profiling
- **Memory Leak Detection**: Identify potential memory leaks in iOS applications
- **Retain Cycle Analysis**: Detect circular references and memory management issues
- **Performance Optimization**: Suggest memory usage optimizations
- **DICOM-Specific Analysis**: Medical imaging memory management patterns

### 🎨 SwiftUI & UIKit Best Practices
- **SwiftUI Analysis**: Check SwiftUI code for performance and accessibility
- **UIKit Modernization**: Suggest UIKit to SwiftUI migration opportunities
- **Accessibility Compliance**: Ensure accessibility best practices
- **Architecture Patterns**: Validate proper use of architectural patterns

### 🏥 Medical Imaging Specialization
- **DICOM Patterns**: Specialized analysis for DICOM image processing
- **Medical Compliance**: HIPAA and medical software compliance checks
- **Performance Optimization**: Medical imaging performance optimizations
- **Metal Integration**: Specialized Metal shader analysis for medical visualization

## Installation

```bash
cd swift-tools-mcp
npm install
npm run build
```

## Available Tools

### Xcode Project Management
- `analyze_xcode_project` - Analyze Xcode project structure and configuration
- `validate_build_settings` - Validate build settings for iOS deployment
- `build_ios_project` - Build iOS project with specified configuration
- `run_ios_tests` - Run iOS unit and UI tests

### Swift Code Analysis
- `analyze_swift_code` - Analyze Swift code for syntax, style, and performance
- `compile_swift_file` - Compile Swift file and check for compilation errors

### iOS Deployment
- `validate_ios_deployment` - Validate iOS deployment configuration
- `list_ios_simulators` - List available iOS simulators
- `boot_simulator` - Boot an iOS simulator
- `install_app_simulator` - Install and launch app on simulator

### Metal Shaders
- `compile_metal_shaders` - Compile and validate Metal shaders
- `analyze_metal_performance` - Analyze Metal shader performance

### Memory Analysis
- `analyze_memory_usage` - Analyze iOS app memory usage patterns

### Best Practices
- `check_swiftui_best_practices` - Check SwiftUI code for best practices
- `check_uikit_best_practices` - Check UIKit code and suggest improvements

## Usage Examples

### Analyze Xcode Project
```typescript
// Analyze the iOS DICOM Viewer project
await server.callTool('analyze_xcode_project', {
  projectPath: '/path/to/iOS_DICOMViewer.xcodeproj',
  analyzeTargets: true,
  analyzeSchemes: true
});
```

### Validate Swift Code
```typescript
// Analyze Swift code for issues
await server.callTool('analyze_swift_code', {
  filePath: '/path/to/swift/files',
  checkSyntax: true,
  checkStyle: true,
  checkPerformance: true
});
```

### Compile Metal Shaders
```typescript
// Compile and validate Metal shaders
await server.callTool('compile_metal_shaders', {
  shaderPath: '/path/to/shaders',
  target: 'ios',
  optimizationLevel: 'speed'
});
```

### Memory Analysis
```typescript
// Analyze memory usage patterns
await server.callTool('analyze_memory_usage', {
  projectPath: '/path/to/project',
  analyzeLeaks: true
});
```

### Simulator Management
```typescript
// List available simulators
await server.callTool('list_ios_simulators', {
  runtime: 'iOS-17',
  deviceType: 'iPhone'
});

// Boot a simulator
await server.callTool('boot_simulator', {
  deviceId: 'iPhone 15 Pro',
  waitForBoot: true
});
```

## Resources

The server provides several resources for project information:

- `swift://project-info` - Current iOS project configuration and status
- `swift://build-settings` - Current build configuration and settings  
- `swift://simulators` - Available iOS simulators and their status

## Medical Imaging Focus

This MCP server is specifically optimized for medical imaging applications like DICOM viewers:

### DICOM-Specific Features
- **Memory Management**: Specialized analysis for large medical image data
- **Performance**: Optimizations for real-time medical image processing
- **Compliance**: Medical software compliance and security checks
- **Metal Shaders**: Advanced GPU processing for medical visualization

### Medical Imaging Patterns
- **Volume Rendering**: Analysis of 3D volume rendering implementations
- **DICOM Processing**: Validation of DICOM parsing and processing code
- **RT Structure Sets**: Analysis of radiotherapy structure visualization
- **Window/Level Operations**: Optimization of medical imaging display functions

## Development

### Building
```bash
npm run build
```

### Development Mode
```bash
npm run dev
```

### Watch Mode
```bash
npm run watch
```

## Requirements

- Node.js 16+
- TypeScript 5+
- Xcode (for iOS development tools)
- macOS (for Xcode integration)

## Integration with Claude Code

This MCP server is designed to be automatically configured when working with iOS projects in Claude Code. It provides specialized tools that understand:

- iOS project structure and conventions
- Swift language patterns and best practices
- Medical imaging requirements and optimizations
- Metal shader development for iOS
- iOS deployment and App Store requirements

## License

ISC License - See LICENSE file for details.

## Contributing

This MCP server is part of the iOS DICOM Viewer project ecosystem. Contributions should focus on:

1. iOS development workflow improvements
2. Medical imaging optimization tools
3. Swift code analysis enhancements
4. Metal shader development utilities
5. Accessibility and compliance features

For medical imaging applications, ensure all contributions maintain compliance with healthcare software standards and follow medical imaging best practices.