# Custom DICOM MCP Server

A comprehensive Model Context Protocol (MCP) server that provides specialized DICOM and medical imaging functionality for Claude Code, designed specifically to enhance development of the iOS DICOM Viewer project.

## 🚀 Features

### Core DICOM Operations
- **Comprehensive Metadata Parsing**: Extract complete DICOM metadata including patient, study, series, and image information
- **Compliance Validation**: Validate DICOM files against standard profiles (CT, MR, Secondary Capture)
- **Pixel Data Analysis**: Advanced pixel data statistics, quality metrics, and artifact detection
- **File Format Detection**: Identify and analyze various medical imaging formats (DICOM, NIfTI, ANALYZE, etc.)

### Medical Imaging Tools
- **Window/Level Optimization**: Calculate optimal display parameters with modality-specific presets
- **Quality Assessment**: Image quality metrics including contrast, sharpness, noise analysis
- **Artifact Detection**: Automated detection of common imaging artifacts (motion blur, noise, truncation)
- **ROI Analysis**: Region of interest detection and statistical analysis

### Medical Terminology
- **Terminology Lookup**: Comprehensive medical term definitions and relationships
- **Code Validation**: Validate medical terminology codes (SNOMED, DCM, ICD-10, UCUM)
- **Anatomical Regions**: Searchable database of anatomical structures
- **Imaging Procedures**: Protocol suggestions based on clinical indications

### iOS Development Integration
- **Memory Optimization**: Memory usage estimates and optimization recommendations
- **Performance Metrics**: Rendering performance analysis and recommendations
- **Metal Shader Support**: Specialized analysis for GPU-accelerated rendering
- **iOS-Specific Guidelines**: Tailored recommendations for iOS medical imaging apps

## 📦 Installation

```bash
# Navigate to the MCP directory
cd /path/to/iOS_DICOM/MCPs/custom-dicom-mcp

# Install dependencies
npm install

# Build the TypeScript project
npm run build

# Start the server
npm start
```

## 🛠️ Development

```bash
# Development mode with auto-reload
npm run dev

# Build only
npm run build

# Clean build directory
npm run clean

# Full rebuild
npm run rebuild
```

## 🔧 Configuration

The server can be configured through the main MCP configuration file at `/path/to/iOS_DICOM/MCPs/config/mcp-config.json`:

```json
{
  "servers": {
    "custom-dicom-mcp": {
      "command": "node",
      "args": ["/path/to/iOS_DICOM/MCPs/custom-dicom-mcp/dist/index.js"],
      "env": {
        "DICOM_MCP_LOG_LEVEL": "info",
        "DICOM_MCP_MAX_FILE_SIZE": "2147483648"
      }
    }
  }
}
```

## 📚 API Reference

### DICOM Metadata Operations

#### `parse_dicom_metadata`
Extract comprehensive metadata from DICOM files.

```typescript
// Input
{
  "filePath": "/absolute/path/to/dicom/file.dcm"
}

// Output
{
  "success": true,
  "metadata": {
    "patientName": "Doe^John",
    "studyDescription": "Brain MRI",
    "modality": "MR",
    "rows": 512,
    "columns": 512,
    // ... extensive metadata
  },
  "validation": {
    "isValid": true,
    "errors": [],
    "warnings": []
  },
  "fileInfo": {
    "filename": "file.dcm",
    "size": 1048576,
    "isDICOM": true,
    "hasPixelData": true
  }
}
```

#### `check_dicom_compliance`
Validate DICOM compliance against standard profiles.

```typescript
// Input
{
  "filePath": "/path/to/dicom/file.dcm",
  "profile": "CT_IMAGE" // Optional: CT_IMAGE, MR_IMAGE, SC_IMAGE
}

// Output
{
  "success": true,
  "compliance": {
    "profile": "CT Image Storage",
    "sopClass": "1.2.840.10008.5.1.4.1.1.2",
    "complianceScore": 95,
    "isCompliant": true,
    "tagCompliance": {
      "required": { "total": 23, "present": 23, "missing": [] },
      "conditional": { "total": 2, "applicable": 2, "present": 2 }
    }
  }
}
```

### File Detection and Analysis

#### `detect_medical_file_type`
Detect and analyze medical imaging file formats.

```typescript
// Input
{
  "filePath": "/path/to/medical/image.nii"
}

// Output
{
  "success": true,
  "detection": {
    "filename": "image.nii",
    "fileType": "NIfTI",
    "confidence": 0.95,
    "characteristics": {
      "hasHeader": true,
      "isCompressed": false,
      "estimatedDimensions": 3
    },
    "recommendations": [
      "Use NIfTI libraries for proper orientation handling"
    ]
  }
}
```

#### `batch_detect_medical_files`
Analyze multiple files efficiently.

```typescript
// Input
{
  "filePaths": [
    "/path/to/file1.dcm",
    "/path/to/file2.nii",
    "/path/to/file3.img"
  ]
}

// Output includes results array and summary statistics
```

### Pixel Data Analysis

#### `analyze_pixel_data`
Comprehensive pixel data analysis with quality metrics.

```typescript
// Input
{
  "filePath": "/path/to/dicom/file.dcm",
  "modality": "CT" // Optional
}

// Output
{
  "success": true,
  "analysis": {
    "statistics": {
      "min": -1024,
      "max": 3071,
      "mean": -200.5,
      "standardDeviation": 450.2,
      "histogram": [/* 256 bins */]
    },
    "qualityMetrics": {
      "contrast": 0.75,
      "sharpness": 0.82,
      "noise": 0.15,
      "signalToNoise": 15.3
    },
    "artifacts": [
      {
        "type": "motion_blur",
        "severity": "low",
        "confidence": 0.6
      }
    ],
    "recommendations": {
      "optimalWindowLevel": { "center": -200, "width": 900 },
      "processingRecommendations": [
        "High dynamic range - use 16-bit rendering pipeline"
      ]
    }
  }
}
```

### Medical Terminology

#### `lookup_medical_terminology`
Look up medical terms and definitions.

```typescript
// Input
{
  "term": "brain"
}

// Output
{
  "success": true,
  "lookup": {
    "term": "brain",
    "category": "anatomy",
    "confidence": 0.9,
    "definitions": [
      {
        "code": "T-A0100",
        "meaning": "Brain",
        "codingScheme": "SNM3",
        "definition": "Anatomical region: Brain"
      }
    ],
    "relatedTerms": ["skull", "head", "neck"]
  }
}
```

#### `suggest_imaging_protocol`
Get protocol suggestions based on clinical indication.

```typescript
// Input
{
  "indication": "headache",
  "modality": "CT"
}

// Output
{
  "success": true,
  "suggestions": [
    {
      "protocol": "Brain CT without contrast",
      "description": "Non-contrast CT examination of the brain",
      "parameters": ["120 kVp", "200-400 mAs", "5mm slice thickness"],
      "contraindications": ["pregnancy (relative)"]
    }
  ]
}
```

## 🎯 Use Cases for iOS DICOM Viewer Development

### 1. Automated DICOM Validation
```typescript
// Validate DICOM files during import
const validation = await mcp.call("check_dicom_compliance", {
  filePath: "/path/to/imported/file.dcm"
});

if (validation.compliance.complianceScore < 80) {
  console.warn("DICOM file may have compatibility issues");
}
```

### 2. Optimal Display Settings
```typescript
// Get optimal window/level for display
const analysis = await mcp.call("analyze_pixel_data", {
  filePath: "/path/to/ct/scan.dcm",
  modality: "CT"
});

const { windowCenter, windowWidth } = analysis.recommendations.optimalWindowLevel;
// Apply to iOS Metal rendering pipeline
```

### 3. Memory Management
```typescript
// Check memory requirements before loading
const pixelData = await mcp.call("extract_dicom_pixel_data", {
  filePath: "/path/to/large/volume.dcm"
});

const memoryRequired = pixelData.summary.memoryRequired;
if (memoryRequired > availableMemory) {
  // Implement progressive loading
}
```

### 4. Quality Assessment
```typescript
// Detect image quality issues
const analysis = await mcp.call("analyze_pixel_data", {
  filePath: "/path/to/scan.dcm"
});

for (const artifact of analysis.artifacts) {
  if (artifact.severity === "high") {
    console.warn(`Quality issue detected: ${artifact.description}`);
  }
}
```

## 🔍 Error Handling

The server provides comprehensive error handling with standardized error codes:

```typescript
// Example error response
{
  "success": false,
  "error": {
    "code": "FILE_NOT_FOUND",
    "message": "File not found: /path/to/file.dcm",
    "severity": "high",
    "recoverable": true,
    "suggestions": [
      "Verify the file path is correct",
      "Check if the file exists",
      "Ensure proper file permissions"
    ],
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

### Error Codes
- `FILE_NOT_FOUND`: File does not exist
- `FILE_ACCESS_DENIED`: Permission issues
- `INVALID_DICOM_FORMAT`: Not a valid DICOM file
- `DICOM_PARSE_ERROR`: DICOM parsing failed
- `PIXEL_ANALYSIS_FAILED`: Pixel data analysis error
- `MEMORY_ALLOCATION_ERROR`: Insufficient memory
- `PROCESSING_TIMEOUT`: Operation timed out

## 🧪 Testing

```bash
# Test basic functionality
node -e "
const { DICOMMetadataParser } = require('./dist/tools/dicom-metadata-parser.js');
const parser = new DICOMMetadataParser();
console.log('DICOM MCP Server loaded successfully');
"

# Test with sample DICOM file (if available)
echo '{"method": "parse_dicom_metadata", "params": {"filePath": "/path/to/sample.dcm"}}' | node dist/index.js
```

## 📱 iOS Integration Examples

### Swift Integration Helper
```swift
// Example iOS integration helper
class DICOMAnalysisService {
    func analyzeDICOMFile(_ url: URL) async throws -> DICOMAnalysisResult {
        // Call MCP server through Claude Code
        let analysis = try await callMCPTool("analyze_pixel_data", [
            "filePath": url.path
        ])
        return DICOMAnalysisResult(from: analysis)
    }
}
```

### Metal Shader Integration
```swift
// Use MCP recommendations for Metal rendering
let analysis = try await analyzeDICOMFile(dicomURL)
let windowLevel = analysis.recommendations.optimalWindowLevel

// Apply to Metal compute shader
metalRenderer.setWindowLevel(
    center: Float(windowLevel.center),
    width: Float(windowLevel.width)
)
```

## 📄 License

This MCP server is part of the iOS DICOM Viewer project and follows the same licensing terms.

## 🤝 Contributing

Contributions are welcome! Please ensure:
1. TypeScript types are properly defined
2. Error handling follows the established patterns
3. Medical terminology accuracy is maintained
4. Performance implications for iOS are considered

## 📞 Support

For issues related to the DICOM MCP server:
1. Check error messages and suggestions
2. Verify DICOM file format and integrity
3. Ensure sufficient system resources
4. Review the API documentation for proper usage

---

**Note**: This is specialized medical imaging software intended for educational and development purposes. It is not intended for clinical diagnosis or treatment decisions.