# DICOM MCP Server Usage Examples

This document provides comprehensive examples for using the Custom DICOM MCP Server in various scenarios, particularly for iOS DICOM Viewer development.

## Basic Setup

First, ensure the server is running and accessible through Claude Code:

```bash
# Start the server
cd /path/to/iOS_DICOM/MCPs/custom-dicom-mcp
npm run build && npm start
```

## Example 1: DICOM File Validation Pipeline

This example shows how to create a complete DICOM validation pipeline for incoming files.

```typescript
/**
 * Complete DICOM validation pipeline
 */
async function validateDICOMPipeline(filePath: string) {
  console.log(`Starting validation pipeline for: ${filePath}`);
  
  // Step 1: Detect file type
  const detection = await mcp.call("detect_medical_file_type", {
    filePath: filePath
  });
  
  console.log(`File type: ${detection.detection.fileType} (${Math.round(detection.detection.confidence * 100)}% confidence)`);
  
  if (detection.detection.fileType !== "DICOM") {
    console.warn("File is not DICOM format");
    return false;
  }
  
  // Step 2: Parse metadata
  const metadata = await mcp.call("parse_dicom_metadata", {
    filePath: filePath
  });
  
  if (!metadata.validation.isValid) {
    console.error("DICOM metadata validation failed:");
    metadata.validation.errors.forEach(error => console.error(`  - ${error}`));
    return false;
  }
  
  // Step 3: Check compliance
  const compliance = await mcp.call("check_dicom_compliance", {
    filePath: filePath
  });
  
  console.log(`Compliance score: ${compliance.compliance.complianceScore}%`);
  
  if (compliance.compliance.complianceScore < 80) {
    console.warn("Low compliance score - file may have compatibility issues");
  }
  
  // Step 4: Analyze pixel data quality
  const pixelAnalysis = await mcp.call("analyze_pixel_data", {
    filePath: filePath,
    modality: metadata.metadata.modality
  });
  
  const quality = pixelAnalysis.analysis.qualityMetrics;
  console.log(`Image quality - Contrast: ${Math.round(quality.contrast * 100)}%, Noise: ${Math.round(quality.noise * 100)}%`);
  
  // Report artifacts
  if (pixelAnalysis.analysis.artifacts.length > 0) {
    console.log("Detected artifacts:");
    pixelAnalysis.analysis.artifacts.forEach(artifact => {
      console.log(`  - ${artifact.type}: ${artifact.severity} severity`);
    });
  }
  
  return {
    isValid: true,
    metadata: metadata.metadata,
    compliance: compliance.compliance,
    quality: pixelAnalysis.analysis
  };
}

// Usage
const result = await validateDICOMPipeline("/path/to/dicom/file.dcm");
if (result.isValid) {
  console.log("DICOM file is ready for import");
}
```

## Example 2: Optimal Display Settings Calculator

This example calculates optimal display settings for different imaging modalities.

```typescript
/**
 * Calculate optimal display settings for DICOM viewer
 */
async function calculateDisplaySettings(filePath: string) {
  // Get pixel analysis
  const analysis = await mcp.call("analyze_pixel_data", {
    filePath: filePath
  });
  
  const stats = analysis.analysis.statistics;
  const optimal = analysis.analysis.recommendations.optimalWindowLevel;
  
  // Get modality-specific presets
  const metadata = await mcp.call("parse_dicom_metadata", {
    filePath: filePath
  });
  
  const modality = metadata.metadata.modality;
  const presets = analysis.analysis.windowLevelSuggestions;
  
  console.log(`Image Statistics for ${modality}:`);
  console.log(`  Range: ${stats.min} to ${stats.max}`);
  console.log(`  Mean: ${Math.round(stats.mean)}`);
  console.log(`  Standard Deviation: ${Math.round(stats.standardDeviation)}`);
  
  console.log(`\nOptimal Window/Level:`);
  console.log(`  Center: ${optimal.center}`);
  console.log(`  Width: ${optimal.width}`);
  
  console.log(`\nAvailable Presets:`);
  presets.forEach(preset => {
    console.log(`  ${preset.name}: C=${preset.windowCenter}, W=${preset.windowWidth}`);
    console.log(`    ${preset.description}`);
  });
  
  return {
    optimal,
    presets,
    statistics: stats,
    recommendations: analysis.analysis.recommendations.renderingHints
  };
}

// Usage for iOS Metal renderer
const displaySettings = await calculateDisplaySettings("/path/to/ct/scan.dcm");

// Apply to iOS Metal rendering pipeline
const metalUniforms = {
  windowCenter: Float32(displaySettings.optimal.center),
  windowWidth: Float32(displaySettings.optimal.width),
  minValue: Float32(displaySettings.statistics.min),
  maxValue: Float32(displaySettings.statistics.max)
};
```

## Example 3: Batch File Processing

Process multiple DICOM files efficiently with progress tracking.

```typescript
/**
 * Batch process DICOM files with progress tracking
 */
async function batchProcessDICOMFiles(filePaths: string[]) {
  console.log(`Processing ${filePaths.length} files...`);
  
  // Step 1: Quick batch detection
  const detectionResults = await mcp.call("batch_detect_medical_files", {
    filePaths: filePaths
  });
  
  console.log(`File type summary:`);
  Object.entries(detectionResults.summary.byType).forEach(([type, count]) => {
    console.log(`  ${type}: ${count} files`);
  });
  
  // Step 2: Process DICOM files only
  const dicomFiles = detectionResults.results
    .filter(result => result.fileType === "DICOM")
    .map(result => result.filename);
  
  const results = [];
  
  for (let i = 0; i < dicomFiles.length; i++) {
    const fileName = dicomFiles[i];
    console.log(`Processing ${i + 1}/${dicomFiles.length}: ${fileName}`);
    
    try {
      // Parse metadata
      const metadata = await mcp.call("parse_dicom_metadata", {
        filePath: fileName
      });
      
      // Quick compliance check
      const compliance = await mcp.call("check_dicom_compliance", {
        filePath: fileName
      });
      
      results.push({
        file: fileName,
        patient: metadata.metadata.patientName || "Unknown",
        study: metadata.metadata.studyDescription || "Unknown",
        modality: metadata.metadata.modality || "Unknown",
        complianceScore: compliance.compliance.complianceScore,
        isValid: metadata.validation.isValid,
        hasPixelData: metadata.fileInfo.hasPixelData
      });
      
    } catch (error) {
      console.error(`Failed to process ${fileName}: ${error.message}`);
      results.push({
        file: fileName,
        error: error.message,
        isValid: false
      });
    }
  }
  
  // Generate summary report
  const validFiles = results.filter(r => r.isValid);
  const avgCompliance = validFiles.reduce((sum, r) => sum + r.complianceScore, 0) / validFiles.length;
  
  console.log(`\nBatch Processing Summary:`);
  console.log(`  Total files: ${filePaths.length}`);
  console.log(`  DICOM files: ${dicomFiles.length}`);
  console.log(`  Valid files: ${validFiles.length}`);
  console.log(`  Average compliance: ${Math.round(avgCompliance)}%`);
  
  return results;
}

// Usage
const processedFiles = await batchProcessDICOMFiles([
  "/path/to/dicom1.dcm",
  "/path/to/dicom2.dcm",
  "/path/to/image.nii"
]);
```

## Example 4: Memory Management for iOS

Calculate memory requirements and implement progressive loading strategies.

```typescript
/**
 * Memory-aware DICOM loading for iOS
 */
async function memoryAwareDICOMLoading(filePath: string, availableMemoryMB: number) {
  // Get pixel data information
  const pixelInfo = await mcp.call("extract_dicom_pixel_data", {
    filePath: filePath,
    analyzeQuality: false // Skip quality analysis for faster processing
  });
  
  const memoryRequiredMB = pixelInfo.summary.memoryRequired / (1024 * 1024);
  const dimensions = pixelInfo.pixelData.dimensions;
  
  console.log(`Image dimensions: ${dimensions.columns}x${dimensions.rows}`);
  console.log(`Memory required: ${Math.round(memoryRequiredMB)} MB`);
  console.log(`Available memory: ${availableMemoryMB} MB`);
  
  if (memoryRequiredMB <= availableMemoryMB * 0.8) {
    // Safe to load entire image
    return {
      strategy: "full_load",
      tileSize: null,
      memoryUsage: memoryRequiredMB,
      recommendation: "Load entire image in memory"
    };
  } else if (memoryRequiredMB <= availableMemoryMB * 2) {
    // Use tiled loading
    const tileSize = Math.floor(Math.sqrt(availableMemoryMB * 0.5 * 1024 * 1024 / 2)); // 2 bytes per pixel estimate
    return {
      strategy: "tiled_load",
      tileSize: tileSize,
      memoryUsage: memoryRequiredMB,
      recommendation: `Use ${tileSize}x${tileSize} tiles for progressive loading`
    };
  } else {
    // Recommend downsampling
    const downsampleFactor = Math.ceil(Math.sqrt(memoryRequiredMB / (availableMemoryMB * 0.5)));
    return {
      strategy: "downsample",
      downsampleFactor: downsampleFactor,
      memoryUsage: memoryRequiredMB / (downsampleFactor * downsampleFactor),
      recommendation: `Downsample by factor of ${downsampleFactor} to fit in memory`
    };
  }
}

// Usage for iOS app
const memoryStrategy = await memoryAwareDICOMLoading("/path/to/large/volume.dcm", 512); // 512 MB available

switch (memoryStrategy.strategy) {
  case "full_load":
    // Load entire image
    break;
  case "tiled_load":
    // Implement tiled loading with specified tile size
    break;
  case "downsample":
    // Load downsampled version first, implement zoom-to-detail
    break;
}
```

## Example 5: Medical Terminology Integration

Integrate medical terminology lookup for enhanced user experience.

```typescript
/**
 * Medical terminology assistant for DICOM viewer
 */
class MedicalTerminologyAssistant {
  async explainDICOMMetadata(metadata: any) {
    const explanations = {};
    
    // Explain modality
    if (metadata.modality) {
      const modalityInfo = await mcp.call("lookup_medical_terminology", {
        term: metadata.modality
      });
      explanations.modality = modalityInfo.lookup.definitions[0]?.definition || `${metadata.modality} imaging`;
    }
    
    // Get anatomical region info
    if (metadata.studyDescription) {
      const bodyPartInfo = await mcp.call("lookup_medical_terminology", {
        term: metadata.studyDescription.toLowerCase()
      });
      if (bodyPartInfo.lookup.definitions.length > 0) {
        explanations.anatomy = bodyPartInfo.lookup.definitions[0];
      }
    }
    
    return explanations;
  }
  
  async suggestImagingProtocol(symptoms: string, modality: string) {
    const suggestions = await mcp.call("suggest_imaging_protocol", {
      indication: symptoms,
      modality: modality
    });
    
    return suggestions.suggestions.map(suggestion => ({
      protocol: suggestion.protocol,
      description: suggestion.description,
      parameters: suggestion.parameters,
      contraindications: suggestion.contraindications
    }));
  }
  
  async getAnatomicalContext(bodyPart: string) {
    const regions = await mcp.call("get_anatomical_regions", {
      bodyPart: bodyPart
    });
    
    return regions.regions.map(region => ({
      name: region.name,
      category: region.category,
      relatedStructures: region.relatedRegions
    }));
  }
}

// Usage in iOS DICOM viewer
const assistant = new MedicalTerminologyAssistant();

// When loading a DICOM file
const metadata = await mcp.call("parse_dicom_metadata", { filePath: "/path/to/brain_mri.dcm" });
const explanations = await assistant.explainDICOMMetadata(metadata.metadata);

console.log(`This is a ${explanations.modality} scan`);
if (explanations.anatomy) {
  console.log(`Anatomical region: ${explanations.anatomy.meaning}`);
}

// When user asks about protocols
const protocols = await assistant.suggestImagingProtocol("headache", "CT");
protocols.forEach(protocol => {
  console.log(`${protocol.protocol}: ${protocol.description}`);
});
```

## Example 6: Quality Assessment Dashboard

Create a comprehensive quality assessment for DICOM images.

```typescript
/**
 * DICOM Quality Assessment Dashboard
 */
async function createQualityReport(filePath: string) {
  const analysis = await mcp.call("analyze_pixel_data", {
    filePath: filePath
  });
  
  const metadata = await mcp.call("parse_dicom_metadata", {
    filePath: filePath
  });
  
  const quality = analysis.analysis.qualityMetrics;
  const artifacts = analysis.analysis.artifacts;
  
  // Generate quality score (0-100)
  const qualityScore = Math.round(
    (quality.contrast * 30 + 
     quality.sharpness * 30 + 
     (1 - quality.noise) * 25 + 
     quality.uniformity * 15) * 100
  );
  
  // Categorize quality
  let qualityCategory;
  if (qualityScore >= 80) qualityCategory = "Excellent";
  else if (qualityScore >= 65) qualityCategory = "Good";
  else if (qualityScore >= 50) qualityCategory = "Fair";
  else qualityCategory = "Poor";
  
  const report = {
    filename: metadata.fileInfo.filename,
    patient: metadata.metadata.patientName || "Unknown",
    modality: metadata.metadata.modality,
    acquisitionDate: metadata.metadata.studyDate,
    
    qualityScore: qualityScore,
    qualityCategory: qualityCategory,
    
    metrics: {
      contrast: Math.round(quality.contrast * 100),
      sharpness: Math.round(quality.sharpness * 100),
      noiseLevel: Math.round(quality.noise * 100),
      uniformity: Math.round(quality.uniformity * 100),
      signalToNoise: Math.round(quality.signalToNoise * 10) / 10
    },
    
    artifacts: artifacts.map(artifact => ({
      type: artifact.type.replace(/_/g, ' ').toLowerCase(),
      severity: artifact.severity,
      confidence: Math.round(artifact.confidence * 100)
    })),
    
    recommendations: analysis.analysis.recommendations.processingRecommendations
  };
  
  console.log(`\n=== DICOM Quality Report ===`);
  console.log(`File: ${report.filename}`);
  console.log(`Patient: ${report.patient}`);
  console.log(`Modality: ${report.modality}`);
  console.log(`\nOverall Quality: ${report.qualityScore}/100 (${report.qualityCategory})`);
  console.log(`\nDetailed Metrics:`);
  console.log(`  Contrast: ${report.metrics.contrast}%`);
  console.log(`  Sharpness: ${report.metrics.sharpness}%`);
  console.log(`  Noise Level: ${report.metrics.noiseLevel}%`);
  console.log(`  Uniformity: ${report.metrics.uniformity}%`);
  console.log(`  Signal-to-Noise Ratio: ${report.metrics.signalToNoise}`);
  
  if (report.artifacts.length > 0) {
    console.log(`\nDetected Artifacts:`);
    report.artifacts.forEach(artifact => {
      console.log(`  - ${artifact.type} (${artifact.severity} severity, ${artifact.confidence}% confidence)`);
    });
  }
  
  if (report.recommendations.length > 0) {
    console.log(`\nRecommendations:`);
    report.recommendations.forEach(rec => console.log(`  - ${rec}`));
  }
  
  return report;
}

// Usage
const qualityReport = await createQualityReport("/path/to/dicom/file.dcm");

// Use in iOS app for quality indication
if (qualityReport.qualityScore < 50) {
  // Show quality warning to user
  console.warn("Low image quality detected - consider using different acquisition parameters");
}
```

## Example 7: Error Handling and Recovery

Implement robust error handling for production use.

```typescript
/**
 * Robust DICOM processing with error handling
 */
async function robustDICOMProcessing(filePath: string) {
  try {
    // Attempt processing
    const result = await mcp.call("parse_dicom_metadata", {
      filePath: filePath
    });
    
    return { success: true, data: result };
    
  } catch (error) {
    // Handle specific error types
    if (error.code === "FILE_NOT_FOUND") {
      console.error(`File not found: ${filePath}`);
      return { 
        success: false, 
        error: "FILE_NOT_FOUND",
        message: "The specified DICOM file could not be found.",
        suggestions: [
          "Verify the file path is correct",
          "Check if the file has been moved or deleted",
          "Ensure proper file permissions"
        ]
      };
    }
    
    if (error.code === "INVALID_DICOM_FORMAT") {
      console.error(`Invalid DICOM format: ${filePath}`);
      
      // Try to detect what format it actually is
      try {
        const detection = await mcp.call("detect_medical_file_type", {
          filePath: filePath
        });
        
        return {
          success: false,
          error: "INVALID_DICOM_FORMAT",
          message: `File is not DICOM format. Detected as: ${detection.detection.fileType}`,
          suggestions: detection.detection.recommendations
        };
      } catch {
        return {
          success: false,
          error: "INVALID_DICOM_FORMAT",
          message: "File is not a valid DICOM file.",
          suggestions: [
            "Verify the file is a DICOM file",
            "Check the file extension",
            "Try with a different file"
          ]
        };
      }
    }
    
    // Generic error handling
    return {
      success: false,
      error: error.code || "UNKNOWN_ERROR",
      message: error.message || "An unknown error occurred",
      suggestions: error.suggestions || ["Try again with a different file"]
    };
  }
}

// Usage with error recovery
const result = await robustDICOMProcessing("/path/to/suspicious/file.dcm");

if (!result.success) {
  console.error(`Processing failed: ${result.message}`);
  console.log("Suggestions:");
  result.suggestions.forEach(suggestion => console.log(`  - ${suggestion}`));
  
  // Implement fallback strategies
  switch (result.error) {
    case "FILE_NOT_FOUND":
      // Prompt user to select a different file
      break;
    case "INVALID_DICOM_FORMAT":
      // Offer to convert or suggest appropriate viewer
      break;
    default:
      // Log error for debugging and show generic error message
      break;
  }
}
```

These examples demonstrate the full capabilities of the Custom DICOM MCP Server and show how to integrate it effectively into iOS DICOM viewer development workflows. Each example includes proper error handling and follows best practices for medical imaging applications.