# iOS Integration Guide for TotalSegmentator CoreML Model

## Overview

You have successfully converted the TotalSegmentator model to CoreML format. The model files are located in `/MODEL_FILES/` directory.

## Files Generated

1. **model.mlmodel** (6.1 KB) - The CoreML model in Neural Network format
2. **weight.bin** (60.5 KB) - Model weights
3. **Manifest.json** - CoreML package manifest
4. **TotalSegmentatorWrapper.swift** - Swift integration code

## Integration Steps

### 1. Add Model to Xcode Project

#### Option A: Direct Integration
1. Open your iOS DICOM Viewer project in Xcode
2. Drag `model.mlmodel` into your project navigator
3. Ensure "Copy items if needed" is checked
4. Add to target: iOS_DICOMViewer

#### Option B: Create MLPackage (Recommended for iOS 16+)
1. Create a new folder called `TotalSegmentator.mlpackage`
2. Copy these files into it:
   - `Manifest.json`
   - `model.mlmodel` → rename to `com.apple.CoreML/model.mlmodel`
   - `weight.bin` → place in `com.apple.CoreML/weights/`
3. Add the entire `.mlpackage` folder to Xcode

### 2. Update Swift Integration Code

Since the model was created as a simplified version, update the `TotalSegmentatorWrapper.swift`:

```swift
import CoreML
import Vision
import Accelerate

@available(iOS 15.0, *)
class TotalSegmentatorModel {
    private let model: MLModel
    
    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        // Load the model - update class name to match your generated model
        if let modelURL = Bundle.main.url(forResource: "model", withExtension: "mlmodel") {
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
        } else {
            throw SegmentationError.modelNotFound
        }
    }
    
    func segment(ctVolume: MLMultiArray) throws -> MLMultiArray {
        // Create input
        let input = try MLDictionaryFeatureProvider(
            dictionary: ["ct_scan": MLFeatureValue(multiArray: ctVolume)]
        )
        
        // Run prediction
        let output = try model.prediction(from: input)
        
        // Get output - the name might be "output" or "var_XXXX"
        guard let outputName = output.featureNames.first,
              let segmentationMask = output.featureValue(for: outputName)?.multiArrayValue else {
            throw SegmentationError.invalidOutput
        }
        
        return segmentationMask
    }
}

enum SegmentationError: Error {
    case modelNotFound
    case invalidInput
    case invalidOutput
}
```

### 3. Integrate with DICOM Viewer

Add to your `AutoSegmentationViewController`:

```swift
class AutoSegmentationViewController: UIViewController {
    private var segmentationModel: TotalSegmentatorModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadSegmentationModel()
    }
    
    private func loadSegmentationModel() {
        do {
            segmentationModel = try TotalSegmentatorModel()
            print("✅ TotalSegmentator model loaded successfully")
        } catch {
            print("❌ Failed to load model: \(error)")
        }
    }
    
    func performSegmentation(on dicomVolume: DICOMVolume) async {
        guard let model = segmentationModel else { return }
        
        do {
            // Prepare input data (64x64x64 for the simplified model)
            let inputArray = try prepareInputArray(from: dicomVolume, size: 64)
            
            // Run segmentation
            let startTime = Date()
            let segmentationMask = try model.segment(ctVolume: inputArray)
            let inferenceTime = Date().timeIntervalSince(startTime)
            
            print("✅ Segmentation completed in \(inferenceTime) seconds")
            
            // Process results
            await processSegmentationResults(segmentationMask)
            
        } catch {
            print("❌ Segmentation failed: \(error)")
        }
    }
    
    private func prepareInputArray(from volume: DICOMVolume, size: Int) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [1, 1, size, size, size], dataType: .float32)
        
        // Resample DICOM volume to 64x64x64 and normalize
        // This is a simplified version - implement proper resampling
        for z in 0..<size {
            for y in 0..<size {
                for x in 0..<size {
                    let index = z * size * size + y * size + x
                    // Normalize HU values to [0, 1]
                    let huValue = volume.getVoxel(at: x, y, z)
                    let normalized = (huValue + 1000.0) / 2000.0
                    array[index] = NSNumber(value: Float(normalized))
                }
            }
        }
        
        return array
    }
}
```

### 4. Add to AI Integration Manager

Update your `AIIntegrationManager.swift`:

```swift
extension AIIntegrationManager {
    func runTotalSegmentator(on instances: [DICOMInstance]) async throws -> SegmentationResult {
        // Create 3D volume from DICOM instances
        let volume = try await createVolumeFromInstances(instances)
        
        // Run segmentation
        let model = try TotalSegmentatorModel()
        let segmentationMask = try model.segment(ctVolume: volume)
        
        // Convert to visualization format
        let organs = extractOrgans(from: segmentationMask)
        
        return SegmentationResult(
            mask: segmentationMask,
            detectedOrgans: organs,
            modelVersion: "simplified-64x64x64"
        )
    }
}
```

### 5. Visualization Integration

Add visualization to your `SegmentationRenderer`:

```swift
extension SegmentationRenderer {
    func renderTotalSegmentatorResults(_ mask: MLMultiArray) {
        // Convert MLMultiArray to Metal texture
        let texture = createTexture(from: mask)
        
        // Apply color mapping for different organs
        let colorMap = createOrganColorMap()
        
        // Render with transparency
        renderSegmentationOverlay(texture: texture, colorMap: colorMap, opacity: 0.5)
    }
}
```

## Model Specifications

Based on the generated files:

- **Input Shape**: [1, 1, 64, 64, 64] (simplified model)
- **Output Shape**: [1, 104, 64, 64, 64] (104 organ classes)
- **Model Size**: ~66 KB (very lightweight)
- **Format**: Neural Network (mlmodel)

## Performance Considerations

1. **Model Size**: The generated model is very small (66KB), suggesting it's a simplified version
2. **Input Resolution**: 64x64x64 is lower than typical CT resolution
3. **Inference Speed**: Should be very fast (<0.5 seconds on modern iPhones)

## Next Steps

1. **Test the Model**: Run inference on sample CT data
2. **Validate Output**: Ensure the 104 classes map correctly to organs
3. **Optimize Performance**: Consider using larger input sizes if needed
4. **Add Post-processing**: Implement smoothing and connected component analysis

## Troubleshooting

### If model doesn't load:
```swift
// Check model file exists
if let modelPath = Bundle.main.path(forResource: "model", ofType: "mlmodel") {
    print("Model found at: \(modelPath)")
} else {
    print("Model file not found in bundle")
}
```

### If inference fails:
```swift
// Verify input shape
print("Expected shape: [1, 1, 64, 64, 64]")
print("Actual shape: \(inputArray.shape)")
```

### To inspect model:
```bash
# In Xcode console
po model.modelDescription
```

## Production Considerations

For production use, you should:

1. **Download Full Model**: The current model is simplified. Consider downloading the full TotalSegmentator weights
2. **Increase Resolution**: Use 128x128x128 or 256x256x256 for better accuracy
3. **Add Preprocessing**: Implement proper HU windowing and normalization
4. **Optimize Memory**: Use batch processing for large volumes
5. **Add Error Handling**: Comprehensive error handling for edge cases

## Example Usage

```swift
// In your viewer
func segmentCurrentStudy() {
    Task {
        do {
            let segmentation = try await AIIntegrationManager.shared.runTotalSegmentator(
                on: currentStudy.instances
            )
            
            // Update UI
            await MainActor.run {
                displaySegmentation(segmentation)
                showOrganList(segmentation.detectedOrgans)
            }
        } catch {
            print("Segmentation failed: \(error)")
        }
    }
}
```

This completes the integration of your TotalSegmentator CoreML model into the iOS DICOM Viewer app!