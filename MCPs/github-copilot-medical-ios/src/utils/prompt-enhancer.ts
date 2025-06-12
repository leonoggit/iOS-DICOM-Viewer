import { MedicalImagingPrompt, IOSDevPrompt, CodeGenerationRequest } from '../types/github-copilot.js';

export class PromptEnhancer {
  private medicalImagingContext = {
    CT: {
      windowLevels: 'Hounsfield units, bone/soft tissue/lung windows',
      pixelSpacing: 'Real-world measurements, DICOM calibration',
      reconstruction: '2D/3D MPR, volume rendering, slice thickness'
    },
    MR: {
      sequences: 'T1, T2, FLAIR, DWI, perfusion, DTI',
      contrast: 'Gadolinium enhancement patterns',
      artifacts: 'Motion, susceptibility, flow artifacts'
    },
    'X-Ray': {
      projections: 'PA, AP, lateral, oblique views',
      technique: 'kVp, mAs, grid, collimation',
      processing: 'Digital radiography, histogram equalization'
    },
    Ultrasound: {
      transducers: 'Linear, curved, phased array transducers',
      frequency: 'Frequency selection, penetration depth',
      modes: 'B-mode, M-mode, Doppler, 3D ultrasound'
    },
    PET: {
      tracers: 'FDG, specific radiopharmaceuticals',
      reconstruction: 'Iterative reconstruction, attenuation correction',
      quantification: 'SUV calculations, kinetic modeling'
    },
    SPECT: {
      isotopes: 'Tc-99m, I-123, other radioisotopes',
      acquisition: 'Multi-head cameras, rotation angles',
      processing: 'Reconstruction filters, scatter correction'
    },
    Mammography: {
      positioning: 'CC, MLO, spot compression views',
      technique: 'kVp selection, compression, magnification',
      processing: 'CAD integration, tomosynthesis'
    }
  };

  private iosDevContext = {
    memory: 'ARC, weak references, memory warnings, autoreleasepool',
    performance: 'Instruments profiling, Time Profiler, Allocations, Leaks',
    metal: 'GPU compute shaders, Metal Performance Shaders, vertex/fragment shaders',
    architecture: 'Coordinators, MVVM, dependency injection, protocol-oriented programming'
  };

  private complianceStandards = {
    DICOM: 'Part 3 (Information Object Definitions), Part 5 (Data Structures), Part 14 (Grayscale Standard Display Function)',
    FDA: '510(k) submission requirements, predicate device analysis, clinical validation',
    HIPAA: 'PHI protection, audit logging, access controls, encryption',
    IEC: '62304 Medical device software lifecycle, risk management'
  };

  enhancePromptWithMedicalContext(
    originalPrompt: string,
    medicalContext?: MedicalImagingPrompt
  ): string {
    if (!medicalContext) return originalPrompt;

    const modalityInfo = medicalContext.modality ? this.medicalImagingContext[medicalContext.modality as keyof typeof this.medicalImagingContext] : undefined;
    const complianceInfo = medicalContext.complianceStandards 
      ? medicalContext.complianceStandards
          .map(std => this.complianceStandards[std as keyof typeof this.complianceStandards])
          .filter(Boolean)
          .join(', ')
      : '';

    return `${originalPrompt}

MEDICAL IMAGING CONTEXT:
- Modality: ${medicalContext.modality || 'General'}
- Clinical Context: ${medicalContext.clinicalContext || 'Standard medical imaging'}
- Technical Requirements: ${medicalContext.technicalRequirements ? medicalContext.technicalRequirements.join(', ') : 'Standard DICOM compliance'}
- Compliance Standards: ${complianceInfo || 'Standard medical device requirements'}
- Modality-Specific Considerations: ${modalityInfo ? Object.values(modalityInfo).join(', ') : 'Standard medical imaging protocols'}

IMPORTANT: Ensure all code follows medical device software standards, includes proper error handling for patient data, and maintains audit trails for clinical compliance.`;
  }

  enhancePromptWithIOSContext(
    originalPrompt: string,
    iosContext?: IOSDevPrompt
  ): string {
    if (!iosContext) return originalPrompt;

    const performanceInfo = iosContext.performance ? this.iosDevContext[iosContext.performance as keyof typeof this.iosDevContext] : '';
    const architectureInfo = iosContext.architecturalPattern ? 
                           (this.iosDevContext[iosContext.architecturalPattern.toLowerCase() as keyof typeof this.iosDevContext] || this.iosDevContext.architecture) :
                           this.iosDevContext.architecture;

    return `${originalPrompt}

iOS DEVELOPMENT CONTEXT:
- Swift Version: ${iosContext.swiftVersion || 'Latest'}
- Deployment Target: ${iosContext.deploymentTarget || 'iOS 15.0+'}
- Frameworks: ${iosContext.frameworks ? iosContext.frameworks.join(', ') : 'UIKit, Metal, Foundation'}
- Architectural Pattern: ${iosContext.architecturalPattern || 'MVVM'}
- Performance Focus: ${iosContext.performance || 'balanced'}
- Performance Considerations: ${performanceInfo || 'Standard iOS optimizations'}
- Architecture Guidelines: ${architectureInfo}

IMPORTANT: Optimize for iOS memory management, use Metal for GPU acceleration where appropriate, follow Apple Human Interface Guidelines, and ensure compatibility with iOS accessibility features.`;
  }

  generateComprehensivePrompt(request: CodeGenerationRequest): string {
    let enhancedPrompt = request.prompt;

    // Add medical imaging context
    if (request.context.medical) {
      enhancedPrompt = this.enhancePromptWithMedicalContext(enhancedPrompt, request.context.medical);
    }

    // Add iOS development context
    if (request.context.ios) {
      enhancedPrompt = this.enhancePromptWithIOSContext(enhancedPrompt, request.context.ios);
    }

    // Add existing code context
    if (request.context.existingCode) {
      enhancedPrompt += `\n\nEXISTING CODE CONTEXT:\n${request.context.existingCode}`;
    }

    // Add project structure context
    if (request.context.projectStructure) {
      enhancedPrompt += `\n\nPROJECT STRUCTURE:\n${request.context.projectStructure.join('\n')}`;
    }

    // Add preferences
    enhancedPrompt += `\n\nCODE GENERATION PREFERENCES:
- Verbosity: ${request.preferences.verbosity}
- Include Tests: ${request.preferences.includeTests}
- Include Documentation: ${request.preferences.includeDocumentation}
- Optimize For: ${request.preferences.optimizeFor}

Please provide Swift code that is production-ready, follows iOS best practices, includes comprehensive error handling, and meets medical device software standards where applicable.`;

    return enhancedPrompt;
  }

  generateMedicalImagingSpecificPrompts(): { [key: string]: string } {
    return {
      'dicom-parsing': `Generate Swift code for robust DICOM file parsing with the following requirements:
- Support for all standard DICOM transfer syntaxes
- Proper error handling for malformed files
- Memory-efficient pixel data extraction
- Comprehensive metadata parsing
- Support for multi-frame datasets
- Integration with DCMTK C++ library through Objective-C bridge`,

      'volume-rendering': `Create Metal-based 3D volume rendering code with:
- Ray casting algorithm implementation
- Multiple rendering modes (MIP, MinIP, Average)
- Transfer function support for different tissue types
- Interactive camera controls with touch gestures
- Memory optimization for large datasets
- Quality level adjustments based on device capabilities`,

      'mpr-visualization': `Implement Multi-Planar Reconstruction (MPR) with:
- Three orthogonal views (Axial, Sagittal, Coronal)
- Real-time slice navigation
- Crosshair synchronization
- Window/Level adjustments
- Zoom, pan, and rotation capabilities
- Thick slice MIP rendering`,

      'roi-tools': `Develop ROI (Region of Interest) measurement tools including:
- Linear distance measurements with sub-pixel accuracy
- Area calculations for various geometric shapes
- Statistical analysis (mean, std dev, min/max)
- Real-world unit conversion using pixel spacing
- Interactive editing with touch gestures
- Export capabilities for clinical reports`
    };
  }

  generateIOSSpecificPrompts(): { [key: string]: string } {
    return {
      'memory-optimization': `Create memory-efficient iOS code with:
- Proper ARC usage and weak reference patterns
- NSCache implementation for image caching
- Memory warning handling
- Autorelease pool optimization
- Large dataset streaming techniques`,

      'metal-integration': `Implement Metal GPU acceleration with:
- Compute shader setup and execution
- Buffer management for large datasets
- Metal Performance Shaders integration
- Efficient texture handling
- GPU/CPU synchronization patterns`,

      'coordinator-pattern': `Implement Coordinator pattern for navigation with:
- Protocol-based coordinator interfaces
- Dependency injection setup
- Navigation flow management
- Deep linking support
- State preservation and restoration`,

      'accessibility-compliance': `Ensure iOS accessibility with:
- VoiceOver support for medical imaging
- Dynamic Type support
- High contrast mode compatibility
- Voice Control integration
- Assistive touch accommodations`
    };
  }
}