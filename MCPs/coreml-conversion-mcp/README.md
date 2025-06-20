# Advanced CoreML Conversion MCP

A specialized Model Context Protocol (MCP) server for converting medical imaging models to CoreML with iOS 18+ optimizations. Designed specifically for TotalSegmentator and other medical imaging models in the iOS DICOM Viewer project.

## 🚀 Features

### Core Capabilities
- **TotalSegmentator Conversion**: Specialized conversion for TotalSegmentator PyTorch models to CoreML
- **iOS 18+ Optimizations**: Leverages latest CoreML Tools 8.0 features including 4-bit quantization, enhanced palettization, and stateful models
- **Medical Imaging Context**: DICOM-aware preprocessing and validation for clinical applications
- **Device Optimization**: Intelligent optimization based on target device capabilities (iPhone 16 Pro Max, etc.)
- **Comprehensive Validation**: Medical imaging compliance and performance validation

### Advanced Optimizations
- **4-bit and 8-bit Quantization**: Latest iOS 18 quantization methods
- **Enhanced Palettization**: 3-bit palettization with grouped channel support  
- **Neural Engine Optimization**: Optimized for A18/M4 Neural Engine performance
- **Model Splitting**: Large model support with automatic splitting
- **Stateful Models**: iOS 18 stateful model support for caching

### Medical Imaging Support
- **Multi-Modality**: CT, MR, US, X-Ray, PET, SPECT support
- **DICOM Integration**: Native DICOM preprocessing and validation
- **Clinical Compliance**: Medical imaging standards and best practices
- **Anatomical Validation**: Multi-organ segmentation quality assessment

## 📋 Prerequisites

### Software Requirements
```bash
# Python 3.8+ with CoreML Tools 8.0+
pip install coremltools>=8.0
pip install torch torchvision
pip install onnx  # Optional for ONNX models

# Node.js 18+ for MCP server
node --version  # Should be 18.0+
```

### Hardware Recommendations
- **iPhone 16 Pro Max** (A18 chip) - Optimal performance
- **iPhone 15 Pro** (A17 chip) - Excellent performance  
- **Mac with M4** - Development and testing
- **8GB+ RAM** - For large model conversion

## 🛠️ Installation

### 1. Install Dependencies
```bash
cd MCPs/coreml-conversion-mcp
npm install
npm run build
```

### 2. Add to Claude Code MCP Configuration
```bash
# Add to your Claude Code MCP configuration
claude mcp add coreml-conversion "/Users/leandroalmeida/iOS_DICOM/MCPs/coreml-conversion-mcp/dist/index.js"

# Verify installation
claude mcp list
```

### 3. Environment Setup
```bash
# Ensure Python environment has CoreML Tools 8.0+
python3 -c "import coremltools; print(coremltools.__version__)"

# Should output 8.0+ for iOS 18 features
```

## 🎯 Usage Examples

### 1. Convert TotalSegmentator Model

```typescript
// Download TotalSegmentator model
await mcp.call("download_totalsegmentator_model", {
  variant: "3mm",  // or "1.5mm" for higher resolution
  outputDir: "./models"
});

// Convert to CoreML with iOS 18+ optimizations
await mcp.call("convert_totalsegmentator_model", {
  modelPath: "./models/TotalSegmentator_3mm.pth",
  outputPath: "./converted/TotalSegmentator_iOS18.mlpackage",
  variant: "3mm",
  deviceTarget: "iPhone16,2",  // iPhone 16 Pro Max
  enableOptimizations: true
});
```

### 2. Validate Converted Model

```typescript
await mcp.call("validate_coreml_model", {
  modelPath: "./converted/TotalSegmentator_iOS18.mlpackage",
  deviceCapabilities: {
    deviceModel: "iPhone16,2",
    osVersion: "18.0",
    memoryGB: 8,
    hasNeuralEngine: true
  },
  medicalContext: {
    modality: "CT",
    anatomyRegions: ["liver", "kidney_left", "kidney_right", "spleen"],
    clinicalUse: "diagnostic"
  }
});
```

### 3. Generate iOS Integration Code

```typescript
await mcp.call("generate_ios_integration_code", {
  modelPath: "./converted/TotalSegmentator_iOS18.mlpackage",
  modelType: "totalsegmentator",
  integrationTarget: "segmentation_service",
  includePreprocessing: true
});
```

### 4. Batch Convert Multiple Models

```typescript
await mcp.call("batch_convert_models", {
  modelPaths: [
    "./models/TotalSegmentator_3mm.pth",
    "./models/CustomSegmentation.pth",
    "./models/Classification.pth"
  ],
  outputDirectory: "./converted_batch",
  sharedConfig: {
    deploymentTarget: "iOS18",
    enableOptimizations: true,
    maxConcurrentConversions: 2
  }
});
```

## 🏥 Medical Imaging Integration

### DICOM Preprocessing Integration

The MCP automatically generates DICOM-aware preprocessing code:

```swift
// Generated Swift integration code
extension TotalSegmentatorService {
    func processDICOMStudy(_ study: DICOMStudy) async -> SegmentationResult? {
        // DICOM pixel data extraction
        guard let pixelData = study.extractPixelData() else { return nil }
        
        // Medical imaging normalization (HU values for CT)
        let normalizedData = preprocessCTData(pixelData)
        
        // CoreML inference
        let segmentationMask = try await performSegmentation(on: normalizedData)
        
        // Post-process to anatomical labels
        return postProcessSegmentation(segmentationMask)
    }
}
```

### Clinical Validation

```typescript
// Validate medical imaging compliance
const validation = await mcp.call("validate_coreml_model", {
  modelPath: "./model.mlpackage",
  medicalContext: {
    modality: "CT",
    clinicalUse: "diagnostic",
    anatomyRegions: ["liver", "kidney", "spleen"],
    dataType: "DICOM"
  }
});

// Results include:
// - DICOM compatibility assessment
// - Clinical accuracy estimation  
// - Segmentation quality metrics
// - Regulatory compliance notes
```

## ⚡ Performance Optimizations

### iOS 18+ Advanced Features

#### 4-bit Quantization
```python
# Generated optimization code uses latest CoreML Tools 8.0
config = cto.OptimizationConfig(
    global_config=cto.OpLinearQuantizerConfig(
        mode="linear_symmetric",
        dtype="int4"  # New 4-bit support in iOS 18
    )
)
compressed_model = cto.linear_quantize_weights(model, config)
```

#### Enhanced Palettization
```python
# 3-bit palettization with grouped channels
config = cto.OptimizationConfig(
    global_config=cto.OpPalettizerConfig(
        nbits=3,  # New 3-bit support
        enable_per_channel_scale=True,
        cluster_dim=4,  # Vector palettization
        grouped_channels=True  # iOS 18+ feature
    )
)
palettized_model = cto.palettize_weights(model, config)
```

#### Stateful Models (iOS 18)
```python
# Stateful model support for caching
convert_params['states'] = [
    ct.StateType(name="kv_cache", shape=cache_shape)
]
mlmodel = ct.convert(traced_model, **convert_params)
```

### Device-Specific Optimization

The MCP automatically selects optimal settings based on target device:

| Device | Neural Engine | Recommended Optimization | Memory Limit |
|--------|---------------|-------------------------|--------------|
| iPhone 16 Pro Max | A18 (35 TOPS) | 6-bit palettization | 8GB |
| iPhone 15 Pro | A17 (35 TOPS) | 8-bit quantization | 8GB |
| iPad Pro M4 | M4 (38 TOPS) | 4-bit quantization | 16GB+ |
| MacBook Pro M4 | M4 (38 TOPS) | Full precision | 32GB+ |

## 🧪 Testing and Validation

### Model Validation Pipeline

1. **File Structure Validation**
   - CoreML format compliance
   - Input/output tensor validation
   - Metadata completeness

2. **Performance Testing**
   - Memory usage assessment
   - Inference speed benchmarking
   - Device compatibility testing

3. **Medical Compliance**
   - DICOM compatibility validation
   - Clinical accuracy estimation
   - Regulatory compliance checking

### Example Validation Results

```json
{
  "validation_result": {
    "isValid": true,
    "modelStructure": {
      "inputsValid": true,
      "outputsValid": true,
      "operationsSupported": true
    },
    "medicalCompliance": {
      "dicomCompatible": true,
      "clinicalAccuracy": 0.85,
      "segmentationQuality": {
        "boundaryAccuracy": 0.88,
        "volumeAccuracy": 0.92,
        "anatomicalConsistency": 0.90
      }
    },
    "performanceTests": {
      "cpuTest": true,
      "gpuTest": true,
      "neuralEngineTest": true,
      "memoryTest": true
    }
  }
}
```

## 🔧 Configuration

### Device Capabilities Assessment

```typescript
await mcp.call("assess_device_capabilities", {
  deviceModel: "iPhone16,2",  // iPhone 16 Pro Max
  osVersion: "18.0",
  modelRequirements: {
    estimatedSizeMB: 512,
    requires3D: true,
    preferredComputeUnit: "cpuAndNeuralEngine"
  }
});
```

### Custom Conversion Configuration

```typescript
await mcp.call("create_conversion_config", {
  modelType: "totalsegmentator",
  inputShape: [1, 1, 256, 256, 256],  // 3D CT volume
  modality: "CT",
  anatomyRegions: ["liver", "kidney_left", "kidney_right"],
  deploymentTarget: "iOS18",
  deviceConstraints: {
    maxMemoryMB: 2048,
    maxModelSizeMB: 1024,
    requireNeuralEngine: true
  }
});
```

## 📊 TotalSegmentator Specifics

### Supported Variants

- **TotalSegmentator 3mm**: Optimized for mobile deployment (256³ input)
- **TotalSegmentator 1.5mm**: High-resolution version (512³ input) 
- **TotalSegmentator MR**: Specialized for MR imaging
- **Custom Tasks**: Lung vessels, COVID, body-specific models

### 104 Anatomical Classes

The conversion automatically maps TotalSegmentator's 104 anatomical structures:
- **27 organs**: liver, kidneys, spleen, pancreas, heart, lungs, etc.
- **59 bones**: vertebrae, ribs, pelvis, long bones, etc.
- **10 muscles**: major muscle groups
- **8 vessels**: aorta, vena cava, portal vein, etc.

### Clinical Integration

```swift
// iOS DICOM app integration
let segmentationResult = await totalSegmentatorService.processDICOMStudy(study)

// Extract clinical metrics
let organVolumes = segmentationResult.calculateOrganVolumes()
let anatomicalFindings = segmentationResult.detectAbnormalities()
let quantitativeMetrics = segmentationResult.generateClinicalReport()
```

## 🔮 Future Enhancements

### Planned Features

1. **Model Management**
   - Automatic model downloading and caching
   - Version control and compatibility checking
   - Cloud-based model repository integration

2. **Advanced Validation**
   - Clinical test dataset integration
   - FDA compliance framework
   - Automated accuracy benchmarking

3. **Performance Optimization**
   - Progressive loading for large models
   - Streaming segmentation for real-time processing
   - Multi-device deployment optimization

4. **Deep Learning Integration**
   - nnU-Net model support
   - MONAI framework integration
   - Custom medical imaging model conversion

## 🐛 Troubleshooting

### Common Issues

#### 1. CoreML Tools Version
```bash
# Ensure CoreML Tools 8.0+
pip install --upgrade coremltools>=8.0
python3 -c "import coremltools; print(coremltools.__version__)"
```

#### 2. Memory Issues with Large Models
```typescript
// Enable model splitting for large 3D models
const config = {
  modelSplitting: {
    enabled: true,
    maxModelSize: 1024  // 1GB chunks
  }
};
```

#### 3. Neural Engine Compatibility
```python
# Verify Neural Engine optimization
config = cto.OptimizationConfig(
    global_config=cto.OpPalettizerConfig(nbits=6)  # Optimal for Neural Engine
)
```

### Performance Debugging

1. **Model Size Optimization**
   - Apply quantization and palettization
   - Consider model pruning for mobile deployment
   - Use model splitting for very large models

2. **Inference Speed**
   - Test on target devices
   - Optimize compute unit selection
   - Profile memory usage patterns

3. **Medical Accuracy**
   - Validate with clinical test data
   - Check preprocessing normalization
   - Verify anatomical consistency

## 📚 References

- [CoreML Tools 8.0 Documentation](https://apple.github.io/coremltools/docs-guides/index.html)
- [TotalSegmentator Paper](https://pubs.rsna.org/doi/full/10.1148/ryai.230024)
- [nnU-Net Framework](https://github.com/MIC-DKFZ/nnUNet)
- [iOS 18 CoreML Features](https://developer.apple.com/documentation/coreml)

## 🤝 Contributing

This MCP is part of the iOS DICOM Viewer project. Contributions welcome for:
- Additional medical imaging model support
- Performance optimizations
- Clinical validation improvements
- Device compatibility enhancements

## 📄 License

MIT License - See iOS DICOM Viewer project for details.

---

**Built for iOS DICOM Viewer Project** - Advanced medical imaging with iOS 18+ optimizations