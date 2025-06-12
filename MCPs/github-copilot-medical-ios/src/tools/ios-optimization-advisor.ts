import { z } from 'zod';

const OptimizationAnalysisSchema = z.object({
  codeSnippet: z.string().describe('Swift code to analyze for iOS optimizations'),
  context: z.enum(['memory', 'performance', 'battery', 'gpu', 'network']),
  targetDevice: z.enum(['iPhone', 'iPad', 'universal']).default('universal'),
  iosVersion: z.string().default('15.0'),
  medicalImaging: z.boolean().default(true)
});

export class IOSOptimizationAdvisor {
  async analyzeCode(args: z.infer<typeof OptimizationAnalysisSchema>): Promise<{
    issues: Array<{
      severity: 'low' | 'medium' | 'high' | 'critical';
      category: string;
      issue: string;
      recommendation: string;
      codeExample?: string;
    }>;
    optimizations: Array<{
      type: string;
      benefit: string;
      implementation: string;
      codeExample: string;
    }>;
    medicalSpecificAdvice: string[];
  }> {
    const issues = this.identifyIssues(args.codeSnippet, args.context, args.medicalImaging);
    const optimizations = this.suggestOptimizations(args.codeSnippet, args.context, args.targetDevice);
    const medicalSpecificAdvice = this.generateMedicalAdvice(args.codeSnippet);

    return {
      issues,
      optimizations,
      medicalSpecificAdvice
    };
  }

  private identifyIssues(code: string, context: string, medicalImaging: boolean) {
    const issues: Array<{
      severity: 'low' | 'medium' | 'high' | 'critical';
      category: string;
      issue: string;
      recommendation: string;
      codeExample?: string;
    }> = [];

    // Memory-related issues
    if (context === 'memory' || medicalImaging) {
      if (code.includes('UIImage(data:') && !code.includes('autoreleasepool')) {
        issues.push({
          severity: 'high',
          category: 'Memory Management',
          issue: 'Loading large images without autoreleasepool can cause memory spikes',
          recommendation: 'Wrap image loading in autoreleasepool blocks, especially for DICOM images',
          codeExample: `autoreleasepool {
    let image = UIImage(data: largeImageData)
    // Process image
}`
        });
      }

      if (code.includes('[weak self]') && code.includes('self?') && !code.includes('guard')) {
        issues.push({
          severity: 'medium',
          category: 'Memory Management',
          issue: 'Multiple optional chaining with weak self can be simplified',
          recommendation: 'Use guard let self = self else { return } pattern for cleaner code',
          codeExample: `{ [weak self] in
    guard let self = self else { return }
    // Use self directly without optional chaining
}`
        });
      }
    }

    // Performance issues
    if (context === 'performance' || context === 'gpu') {
      if (code.includes('for') && code.includes('UIImage') && !code.includes('async')) {
        issues.push({
          severity: 'critical',
          category: 'Performance',
          issue: 'Synchronous image processing in loops can block the main thread',
          recommendation: 'Use async/await or dispatch queues for image processing',
          codeExample: `await withTaskGroup(of: ProcessedImage.self) { group in
    for image in images {
        group.addTask {
            await processImage(image)
        }
    }
}`
        });
      }

      if (code.includes('Metal') && !code.includes('MTLBuffer') && code.includes('data')) {
        issues.push({
          severity: 'high',
          category: 'GPU Performance',
          issue: 'Inefficient data transfer to GPU without proper buffer management',
          recommendation: 'Use MTLBuffer for efficient GPU memory management',
          codeExample: `let buffer = device.makeBuffer(bytes: data, length: data.count, options: .storageModeShared)`
        });
      }
    }

    // Medical imaging specific issues
    if (medicalImaging) {
      if (code.includes('Float') && code.includes('pixel') && !code.includes('Int16')) {
        issues.push({
          severity: 'medium',
          category: 'Medical Imaging',
          issue: 'Using Float for pixel values may lose precision for medical images',
          recommendation: 'Consider using Int16 for DICOM pixel data to maintain bit depth accuracy'
        });
      }

      if (code.includes('window') && code.includes('level') && !code.includes('clamp')) {
        issues.push({
          severity: 'medium',
          category: 'Medical Imaging',
          issue: 'Window/Level operations should include proper clamping for display',
          recommendation: 'Implement proper DICOM windowing with clamping to display range'
        });
      }
    }

    return issues;
  }

  private suggestOptimizations(code: string, context: string, targetDevice: string) {
    const optimizations: Array<{
      type: string;
      benefit: string;
      implementation: string;
      codeExample: string;
    }> = [];

    // Memory optimizations
    if (context === 'memory') {
      optimizations.push({
        type: 'NSCache Implementation',
        benefit: 'Automatic memory management for cached images with system memory pressure handling',
        implementation: 'Replace manual caching with NSCache for automatic eviction',
        codeExample: `private let imageCache = NSCache<NSString, UIImage>()
imageCache.countLimit = 50  // Limit cached images
imageCache.totalCostLimit = 100 * 1024 * 1024  // 100MB limit`
      });

      optimizations.push({
        type: 'Lazy Loading',
        benefit: 'Reduces initial memory footprint and improves app launch time',
        implementation: 'Use lazy var for expensive objects that may not be needed immediately',
        codeExample: `lazy var volumeRenderer: VolumeRenderer = {
    return VolumeRenderer(device: metalDevice)
}()`
      });
    }

    // GPU optimizations
    if (context === 'gpu') {
      optimizations.push({
        type: 'Metal Performance Shaders',
        benefit: 'Leverage optimized GPU kernels for common image processing operations',
        implementation: 'Use MPSImageGaussianBlur, MPSImageHistogram for better performance',
        codeExample: `let gaussianBlur = MPSImageGaussianBlur(device: device, sigma: 2.0)
gaussianBlur.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)`
      });

      optimizations.push({
        type: 'Compute Shader Optimization',
        benefit: 'Custom GPU kernels for specialized medical imaging algorithms',
        implementation: 'Implement window/level adjustments and volume rendering in Metal compute shaders',
        codeExample: `kernel void windowLevel(texture2d<float, access::read> input [[texture(0)]],
                      texture2d<float, access::write> output [[texture(1)]],
                      constant WindowLevelParams& params [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    float pixel = input.read(gid).r;
    float windowed = (pixel - params.level + params.width/2.0) / params.width;
    output.write(float4(clamp(windowed, 0.0, 1.0)), gid);
}`
      });
    }

    // Device-specific optimizations
    if (targetDevice === 'iPad') {
      optimizations.push({
        type: 'Multi-Window Support',
        benefit: 'Take advantage of iPad\'s larger screen for multi-pane medical imaging interfaces',
        implementation: 'Implement adaptive UI with UISplitViewController for side-by-side viewing',
        codeExample: `let splitViewController = UISplitViewController(style: .doubleColumn)
splitViewController.preferredDisplayMode = .oneBesideSecondary
splitViewController.preferredSplitBehavior = .tile`
      });
    }

    return optimizations;
  }

  private generateMedicalAdvice(code: string): string[] {
    const advice: string[] = [];

    if (code.includes('DICOM') || code.includes('medical')) {
      advice.push(
        'Implement comprehensive error handling for malformed DICOM files',
        'Use appropriate bit depth (Int16) for medical image pixel data',
        'Ensure DICOM conformance with Part 5 data structures',
        'Implement proper window/level calculations according to DICOM Part 14',
        'Add audit logging for clinical compliance requirements',
        'Validate patient data privacy (PHI) handling according to HIPAA',
        'Consider FDA guidelines for medical device software classification'
      );
    }

    if (code.includes('Metal') || code.includes('GPU')) {
      advice.push(
        'Optimize Metal shaders for medical imaging precision requirements',
        'Implement fallback CPU paths for devices without Metal support',
        'Use appropriate texture formats for medical image bit depths',
        'Consider GPU memory limitations on mobile devices for large datasets'
      );
    }

    if (code.includes('async') || code.includes('await')) {
      advice.push(
        'Ensure medical image processing doesn\'t block clinical workflows',
        'Implement proper error handling in async medical image processing',
        'Use task groups for parallel processing of DICOM series',
        'Consider user experience during long-running medical computations'
      );
    }

    advice.push(
      'Always test with real clinical datasets from multiple DICOM vendors',
      'Implement appropriate medical disclaimers for diagnostic limitations',
      'Consider accessibility requirements for clinical users',
      'Design UI/UX with clinical workflow efficiency in mind'
    );

    return advice;
  }

  getSchema() {
    return OptimizationAnalysisSchema;
  }
}