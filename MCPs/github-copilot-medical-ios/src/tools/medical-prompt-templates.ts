import { z } from 'zod';
import { PromptEnhancer } from '../utils/prompt-enhancer.js';

const PromptTemplateSchema = z.object({
  category: z.enum(['dicom-parsing', 'volume-rendering', 'mpr-visualization', 'roi-tools', 'segmentation', 'compliance']),
  subcategory: z.string().optional(),
  complexity: z.enum(['basic', 'intermediate', 'advanced']).default('intermediate'),
  includeSwiftOptimizations: z.boolean().default(true),
  includeMetalIntegration: z.boolean().default(false)
});

export class MedicalPromptTemplates {
  private promptEnhancer: PromptEnhancer;

  constructor() {
    this.promptEnhancer = new PromptEnhancer();
  }

  async getPromptTemplate(args: z.infer<typeof PromptTemplateSchema>): Promise<{
    template: string;
    context: string;
    examples: string[];
    bestPractices: string[];
  }> {
    const template = this.generateTemplate(args);
    const context = this.generateContext(args);
    const examples = this.generateExamples(args);
    const bestPractices = this.generateBestPractices(args);

    return {
      template,
      context,
      examples,
      bestPractices
    };
  }

  private generateTemplate(args: z.infer<typeof PromptTemplateSchema>): string {
    const templates = {
      'dicom-parsing': {
        basic: `Create a Swift function to parse DICOM metadata from a file:
- Extract patient information (name, ID, birth date)
- Parse study information (date, time, description)
- Handle series-level metadata
- Implement basic error handling`,
        
        intermediate: `Implement comprehensive DICOM parsing with DCMTK integration:
- Support multiple transfer syntaxes (uncompressed, JPEG, RLE)
- Extract pixel data with proper bit depth handling
- Parse all standard DICOM tags with type safety
- Implement memory-efficient streaming for large files
- Handle multi-frame datasets correctly`,
        
        advanced: `Create enterprise-grade DICOM parser with full compliance:
- Support all DICOM transfer syntaxes including JPEG 2000
- Implement DICOM conformance statement validation
- Handle compressed pixel data with proper decompression
- Support DICOM Structured Reporting (SR)
- Implement DICOM Web (WADO-RS/WADO-URI) integration
- Include comprehensive audit logging for clinical environments`
      },

      'volume-rendering': {
        basic: `Implement basic 3D volume visualization:
- Load DICOM series into 3D texture
- Create simple ray casting renderer
- Implement basic camera controls
- Apply window/level adjustments`,
        
        intermediate: `Create advanced Metal-based volume renderer:
- Implement multiple rendering algorithms (ray casting, MIP, MinIP)
- Support transfer functions for tissue differentiation
- Add interactive camera controls with touch gestures
- Optimize for iOS memory constraints
- Include quality level adjustments`,
        
        advanced: `Build production-grade volume rendering system:
- Implement advanced rendering techniques (gradient shading, ambient occlusion)
- Support real-time transfer function editing
- Add clipping planes and arbitrary orientations
- Implement multi-volume rendering for fusion studies
- Include performance profiling and adaptive quality
- Support VR/AR rendering for immersive visualization`
      },

      'mpr-visualization': {
        basic: `Create Multi-Planar Reconstruction viewer:
- Display axial, sagittal, and coronal views
- Implement slice navigation
- Add crosshair cursor display
- Support basic window/level adjustments`,
        
        intermediate: `Implement comprehensive MPR system:
- Synchronize navigation across three views
- Add oblique and curved MPR capabilities
- Implement thick slice MIP rendering
- Support annotation overlays
- Include measurement tools`,
        
        advanced: `Build advanced MPR platform:
- Support arbitrary oblique planes
- Implement curved and straightened MPR
- Add 4D time-series navigation
- Include advanced measurement tools (angles, areas, volumes)
- Support multi-modality fusion display
- Implement DICOM coordinate system transformations`
      },

      'roi-tools': {
        basic: `Create basic ROI measurement tools:
- Linear distance measurements
- Circular and rectangular ROIs
- Display measurements in real-world units
- Basic statistical calculations`,
        
        intermediate: `Implement comprehensive ROI toolkit:
- Support multiple ROI shapes (polygon, ellipse, freehand)
- Calculate statistical measures (mean, std dev, histogram)
- Implement interactive editing with touch gestures
- Add ROI persistence and export capabilities
- Include Hounsfield unit calculations for CT`,
        
        advanced: `Build professional ROI analysis system:
- Support 3D volumetric ROIs
- Implement automated segmentation tools
- Add texture analysis capabilities
- Support DICOM RT Structure Set integration
- Include radiomics feature extraction
- Implement ROI-based dosimetry calculations`
      },

      'segmentation': {
        basic: `Create basic image segmentation tools:
- Threshold-based segmentation
- Region growing algorithms
- Binary mask creation
- Simple overlay visualization`,
        
        intermediate: `Implement advanced segmentation system:
- Support DICOM Segmentation (SEG) objects
- Implement multiple segmentation algorithms
- Add interactive editing tools
- Support multi-label segmentations
- Include 3D visualization of segments`,
        
        advanced: `Build AI-powered segmentation platform:
- Integrate machine learning models for organ segmentation
- Support DICOM Parametric Map objects
- Implement active contour and level set methods
- Add automatic quality assessment
- Support real-time collaborative editing
- Include clinical workflow integration`
      },

      'compliance': {
        basic: `Implement basic medical compliance features:
- Patient data anonymization
- Basic audit logging
- DICOM conformance validation
- Simple access controls`,
        
        intermediate: `Create comprehensive compliance system:
- HIPAA-compliant data handling
- FDA 510(k) submission support
- IEC 62304 software lifecycle compliance
- DICOM conformance statement generation
- Clinical audit trail management`,
        
        advanced: `Build enterprise compliance platform:
- Full regulatory compliance (FDA, CE marking, Health Canada)
- Clinical trial data management (CDISC standards)
- Advanced security framework with encryption
- Comprehensive audit and risk management
- Integration with clinical information systems
- Support for international medical device regulations`
      }
    };

    return templates[args.category][args.complexity];
  }

  private generateContext(args: z.infer<typeof PromptTemplateSchema>): string {
    let context = `MEDICAL IMAGING CONTEXT:
This code will be used in a clinical iOS DICOM Viewer application that must meet medical device software standards.

TARGET ENVIRONMENT:
- iOS 15.0+ deployment target
- Swift 5.7+ with modern concurrency
- Metal for GPU acceleration
- DCMTK integration for DICOM parsing
- Memory-constrained mobile environment

COMPLIANCE REQUIREMENTS:
- DICOM Part 5 (Data Structures and Encoding)
- DICOM Part 14 (Grayscale Standard Display Function)
- FDA medical device software guidelines
- HIPAA patient data protection
- IEC 62304 software lifecycle processes`;

    if (args.includeSwiftOptimizations) {
      context += `

SWIFT OPTIMIZATION REQUIREMENTS:
- Use ARC for automatic memory management
- Implement async/await for non-blocking operations
- Use weak references to prevent retain cycles
- Optimize for iOS memory warnings
- Follow Swift naming conventions and best practices`;
    }

    if (args.includeMetalIntegration) {
      context += `

METAL INTEGRATION REQUIREMENTS:
- Use Metal Performance Shaders where applicable
- Implement efficient buffer management
- Optimize for iOS GPU architectures
- Handle GPU/CPU synchronization properly
- Support both integrated and discrete GPUs`;
    }

    return context;
  }

  private generateExamples(args: z.infer<typeof PromptTemplateSchema>): string[] {
    const exampleMap = {
      'dicom-parsing': [
        'Parse CT scan with window/level metadata',
        'Extract MR sequence parameters',
        'Handle multi-frame ultrasound data',
        'Process DICOM RT dose distribution'
      ],
      'volume-rendering': [
        'Render CT angiography with vessel enhancement',
        'Display MR brain volume with tissue differentiation',
        'Show PET/CT fusion with metabolic overlay'
      ],
      'mpr-visualization': [
        'Navigate through spine CT in three planes',
        'Display cardiac MR in short and long axis views',
        'Show temporal progression in 4D MR'
      ],
      'roi-tools': [
        'Measure liver lesion diameter',
        'Calculate left ventricular ejection fraction',
        'Analyze bone density in trabecular regions'
      ],
      'segmentation': [
        'Segment lung nodules from chest CT',
        'Delineate brain tumors in MR images',
        'Extract cardiac chambers from echocardiogram'
      ],
      'compliance': [
        'Anonymize patient data for research',
        'Generate DICOM conformance statement',
        'Implement clinical audit logging'
      ]
    };

    return exampleMap[args.category] || [];
  }

  private generateBestPractices(args: z.infer<typeof PromptTemplateSchema>): string[] {
    const practices = [
      'Follow DICOM standards strictly for interoperability',
      'Implement comprehensive error handling and validation',
      'Use appropriate data types for medical measurements',
      'Maintain patient privacy and data security',
      'Document all clinical assumptions and limitations',
      'Test with diverse DICOM datasets from multiple vendors',
      'Implement proper memory management for large datasets',
      'Follow iOS accessibility guidelines for clinical users',
      'Include appropriate medical disclaimers',
      'Design for clinical workflow efficiency'
    ];

    if (args.includeSwiftOptimizations) {
      practices.push(
        'Use value types (structs) for medical data models',
        'Implement proper async/await patterns for file I/O',
        'Use NSCache for medical image caching',
        'Handle iOS memory warnings gracefully'
      );
    }

    if (args.includeMetalIntegration) {
      practices.push(
        'Use Metal Performance Shaders for image processing',
        'Implement efficient GPU buffer management',
        'Handle GPU memory limitations on iOS devices',
        'Optimize Metal shaders for mobile GPUs'
      );
    }

    return practices;
  }

  getSchema() {
    return PromptTemplateSchema;
  }
}