# Real-Time Anomaly Detection with Explainable AI

## Overview

This implementation provides state-of-the-art real-time anomaly detection for medical imaging within the iOS DICOM Viewer, leveraging the latest iOS 26 capabilities including Metal 4 tensors, MLX framework, and Foundation Models.

## Key Features

### 1. **Real-Time Detection**
- Sub-second inference on iPhone 16 Pro Max
- Continuous monitoring during image review
- Progressive loading for large studies

### 2. **Explainable AI**
- GradCAM-based heatmap visualization
- Clinical explanations for each finding
- Confidence scores and severity levels
- Differential diagnosis suggestions

### 3. **Multi-Modality Support**
- **Chest X-Ray**: 18+ pathologies including pneumonia, pneumothorax
- **Brain MRI**: Tumors, hemorrhage, infarcts, lesions
- **CT/US**: General anomaly detection
- Extensible to other modalities

### 4. **iOS 26 & Metal 4 Integration**
- Metal 4 tensor operations for GPU-accelerated ML
- MLX framework for efficient array operations
- Foundation Models for enhanced clinical context
- On-device processing for patient privacy

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  User Interface                      │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │   MTKView   │  │ Explanation  │  │  Clinical  │ │
│  │  (Overlay)  │  │    Panel     │  │  Actions   │ │
│  └─────────────┘  └──────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────┐
│              Anomaly Detection Engine                │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │   CoreML    │  │    Metal 4   │  │    MLX     │ │
│  │   Models    │  │   Tensors    │  │ Framework  │ │
│  └─────────────┘  └──────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────┐
│                  DICOM Services                      │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │   Parser    │  │   Renderer   │  │ Metadata   │ │
│  │             │  │              │  │   Store    │ │
│  └─────────────┘  └──────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────┘
```

## Implementation Guide

### 1. **Basic Setup**

```swift
// Initialize in AppDelegate or SceneDelegate
if #available(iOS 26.0, *) {
    DICOMServiceManager.shared.initializeAnomalyDetection()
}

// Enable in viewer
viewerViewController.enableAnomalyDetection()
```

### 2. **Single Image Analysis**

```swift
let engine = AnomalyDetectionEngine()
let result = try await engine.detectAnomalies(
    in: dicomInstance,
    modality: "CR",
    previousStudies: nil
)

// Process results
for anomaly in result.anomalies {
    print("Found: \(anomaly.type) with \(anomaly.confidence)% confidence")
}
```

### 3. **Batch Processing**

```swift
let batchProcessor = AnomalyBatchProcessor()
batchProcessor.processStudies(studies) { progress in
    updateProgressUI(progress)
} completion: { results in
    displayBatchResults(results)
}
```

### 4. **Real-Time Monitoring**

```swift
// In ViewerViewController
override func displayInstance(_ instance: DICOMInstance) {
    super.displayInstance(instance)
    
    if UserDefaults.standard.bool(forKey: "enableRealTimeAnomalyDetection") {
        Task {
            let result = try await anomalyEngine.detectAnomalies(in: instance)
            overlayAnomalies(result)
        }
    }
}
```

## Model Integration

### Pre-trained Models

1. **ChestXRayAnomalyDetection.mlmodel**
   - Based on DenseNet121 architecture
   - Detects 18+ chest pathologies
   - Input: 224x224 grayscale
   - Size: ~30MB

2. **BrainMRIAnomalyDetection.mlmodel**
   - Autoencoder-based anomaly detection
   - Reconstruction error approach
   - Input: 256x256 grayscale
   - Size: ~25MB

3. **GeneralMedicalAnomaly.mlmodel**
   - Transfer learning from ImageNet
   - Broad anomaly detection
   - Input: 224x224 RGB
   - Size: ~40MB

### Model Conversion

```python
# Convert PyTorch to CoreML
import coremltools as ct
import torch

# Load PyTorch model
pytorch_model = torch.load('chest_xray_model.pt')
pytorch_model.eval()

# Trace the model
example_input = torch.rand(1, 1, 224, 224)
traced_model = torch.jit.trace(pytorch_model, example_input)

# Convert to CoreML
model = ct.convert(
    traced_model,
    inputs=[ct.ImageType(shape=(1, 224, 224, 1), scale=1/255.0)],
    minimum_deployment_target=ct.target.iOS26
)

# Add metadata
model.author = "iOS DICOM Viewer"
model.short_description = "Chest X-Ray Anomaly Detection"
model.version = "2.0"

# Save
model.save("ChestXRayAnomalyDetection.mlmodel")
```

## Performance Optimization

### 1. **Metal 4 Tensor Operations**
```swift
// Use ML command encoder for parallel processing
let mlEncoder = commandQueue.makeMachineLearningCommandEncoder()
mlEncoder.encode(model: model, input: inputTensor, output: outputTensor)
```

### 2. **Progressive Loading**
```swift
// Process visible slices first
let visibleRange = getVisibleSliceRange()
for slice in visibleRange {
    await processSlice(slice)
}
```

### 3. **Caching Strategy**
```swift
// Cache results for viewed instances
let cacheKey = "\(instanceUID)_anomaly"
if let cached = anomalyCache.object(forKey: cacheKey) {
    return cached
}
```

## Clinical Integration

### 1. **DICOM SR Export**
```swift
let srData = try result.exportAsDICOMSR()
// Save or send to PACS
```

### 2. **Urgency Routing**
```swift
switch result.clinicalContext.urgencyLevel {
case .stat:
    notifyRadiologistImmediately()
case .emergent:
    addToUrgentWorklist()
default:
    addToRoutineWorklist()
}
```

### 3. **Audit Logging**
```swift
complianceManager.logAnomalyDetection(
    result,
    for: instanceUID,
    action: .aiAnalysis
)
```

## UI Components

### 1. **Overlay Visualization**
- Heatmap overlay with adjustable opacity
- Bounding boxes with severity colors
- Confidence indicators

### 2. **Explanation Panel**
- Anomaly list with details
- Clinical context
- Suggested actions

### 3. **Interactive Features**
- Tap anomaly for detailed explanation
- Pinch to zoom on regions
- Real-time toggle

## Best Practices

### 1. **Privacy & Security**
- All processing on-device
- No data leaves the device
- Audit trail for compliance

### 2. **Clinical Validation**
- Always show confidence scores
- Provide explanations
- Allow radiologist override

### 3. **Performance**
- Use appropriate input resolution
- Enable Metal 4 optimizations
- Cache processed results

### 4. **User Experience**
- Non-intrusive overlays
- Clear visual indicators
- Quick access to details

## Troubleshooting

### Common Issues

1. **Model Loading Failures**
   - Check model file exists in bundle
   - Verify iOS 26.0+ deployment
   - Ensure sufficient memory

2. **Slow Performance**
   - Reduce input resolution
   - Enable GPU-only processing
   - Check background tasks

3. **Incorrect Detections**
   - Adjust confidence threshold
   - Verify modality matching
   - Check window/level settings

## Future Enhancements

1. **Additional Modalities**
   - Mammography
   - Ultrasound
   - Nuclear Medicine

2. **Advanced Features**
   - Temporal change detection
   - Multi-view correlation
   - 3D volume analysis

3. **Integration**
   - FHIR export
   - HL7 messaging
   - Cloud backup (encrypted)

## Requirements

- iOS 26.0+
- iPhone 16 Pro Max (recommended)
- 8GB+ RAM
- Neural Engine support

## License

This implementation is part of the iOS DICOM Viewer project and follows the same licensing terms.