import * as fs from 'fs-extra';
import * as path from 'path';
import { execSync } from 'child_process';
import glob from 'fast-glob';

export interface MemoryAnalysisResult {
  projectPath: string;
  target: string;
  issues: MemoryIssue[];
  optimizations: MemoryOptimization[];
  patterns: MemoryPattern[];
  metrics: MemoryMetrics;
}

export interface MemoryIssue {
  type: 'leak' | 'retain-cycle' | 'excessive-allocation' | 'inefficient-pattern';
  severity: 'critical' | 'high' | 'medium' | 'low';
  file: string;
  line?: number;
  description: string;
  impact: string;
  solution: string;
  codeExample?: string;
}

export interface MemoryOptimization {
  category: 'allocation' | 'deallocation' | 'caching' | 'pooling' | 'lazy-loading';
  description: string;
  implementation: string;
  expectedGain: string;
  difficulty: 'easy' | 'medium' | 'hard';
}

export interface MemoryPattern {
  pattern: string;
  occurrences: number;
  files: string[];
  recommendation: string;
  impact: 'positive' | 'negative' | 'neutral';
}

export interface MemoryMetrics {
  totalSwiftFiles: number;
  potentialLeaks: number;
  retainCycles: number;
  heavyAllocators: number;
  memoryEfficientPatterns: number;
  dicomSpecificIssues: number;
}

export class iOSMemoryProfiler {
  async analyzeMemoryUsage(
    projectPath: string,
    target?: string,
    options: { analyzeLeaks?: boolean } = {}
  ): Promise<any> {
    try {
      if (!await fs.pathExists(projectPath)) {
        throw new Error(`Project path does not exist: ${projectPath}`);
      }

      const projectDir = path.dirname(projectPath);
      const swiftFiles = await glob(['**/*.swift'], { cwd: projectDir, absolute: true });

      if (swiftFiles.length === 0) {
        throw new Error('No Swift files found in project');
      }

      const result: MemoryAnalysisResult = {
        projectPath,
        target: target || 'main',
        issues: [],
        optimizations: [],
        patterns: [],
        metrics: this.initializeMetrics()
      };

      // Analyze each Swift file
      for (const file of swiftFiles) {
        await this.analyzeSwiftFile(file, result);
      }

      // Calculate metrics
      this.calculateMetrics(result);

      // Generate optimizations
      this.generateOptimizations(result);

      // Memory patterns are analyzed within analyzeFilePatterns method

      return {
        content: [{
          type: 'text',
          text: this.formatMemoryAnalysis(result),
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to analyze memory usage: ${error}`,
        }],
        isError: true,
      };
    }
  }

  private async analyzeSwiftFile(filePath: string, result: MemoryAnalysisResult): Promise<void> {
    try {
      const content = await fs.readFile(filePath, 'utf8');
      const lines = content.split('\n');
      const relativePath = path.relative(path.dirname(result.projectPath), filePath);

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const lineNumber = i + 1;

        // Check for memory leaks
        this.checkForMemoryLeaks(line, lineNumber, relativePath, result);

        // Check for retain cycles
        this.checkForRetainCycles(line, lineNumber, relativePath, result);

        // Check for excessive allocations
        this.checkForExcessiveAllocations(line, lineNumber, relativePath, result);

        // Check for inefficient patterns
        this.checkForInefficientPatterns(line, lineNumber, relativePath, result);

        // Check DICOM-specific memory issues
        this.checkDICOMMemoryIssues(line, lineNumber, relativePath, result);
      }

      // Analyze entire file for patterns
      this.analyzeFilePatterns(content, relativePath, result);

    } catch (error) {
      result.issues.push({
        type: 'inefficient-pattern',
        severity: 'low',
        file: path.relative(path.dirname(result.projectPath), filePath),
        description: `Failed to analyze file: ${error}`,
        impact: 'Unknown impact due to analysis failure',
        solution: 'Ensure file is readable and contains valid Swift code'
      });
    }
  }

  private checkForMemoryLeaks(line: string, lineNumber: number, file: string, result: MemoryAnalysisResult): void {
    // Check for NotificationCenter observers without removal
    if (line.includes('NotificationCenter.default.addObserver') || line.includes('addObserver')) {
      result.issues.push({
        type: 'leak',
        severity: 'high',
        file,
        line: lineNumber,
        description: 'NotificationCenter observer added without corresponding removal',
        impact: 'Memory leak - observers will persist after object deallocation',
        solution: 'Remove observers in deinit or use NotificationCenter.default.removeObserver()',
        codeExample: `deinit {\n    NotificationCenter.default.removeObserver(self)\n}`
      });
    }

    // Check for timer without invalidation
    if (line.includes('Timer.scheduledTimer') || line.includes('Timer(')) {
      result.issues.push({
        type: 'leak',
        severity: 'high',
        file,
        line: lineNumber,
        description: 'Timer created without invalidation',
        impact: 'Memory leak - timer will retain target object',
        solution: 'Invalidate timer in deinit or when no longer needed',
        codeExample: `deinit {\n    timer?.invalidate()\n    timer = nil\n}`
      });
    }

    // Check for KVO without removal
    if (line.includes('addObserver') && line.includes('keyPath')) {
      result.issues.push({
        type: 'leak',
        severity: 'high',
        file,
        line: lineNumber,
        description: 'KVO observer added without removal',
        impact: 'Memory leak and potential crashes',
        solution: 'Remove KVO observers in deinit',
        codeExample: `deinit {\n    removeObserver(self, forKeyPath: "keyPath")\n}`
      });
    }
  }

  private checkForRetainCycles(line: string, lineNumber: number, file: string, result: MemoryAnalysisResult): void {
    // Check for strong reference to self in closures
    if (line.includes('self.') && (line.includes('{') || line.includes('completion:'))) {
      if (!line.includes('[weak self]') && !line.includes('[unowned self]')) {
        result.issues.push({
          type: 'retain-cycle',
          severity: 'medium',
          file,
          line: lineNumber,
          description: 'Potential retain cycle - strong reference to self in closure',
          impact: 'Memory leak due to circular reference',
          solution: 'Use [weak self] or [unowned self] in closure capture list',
          codeExample: `{ [weak self] in\n    guard let self = self else { return }\n    self.doSomething()\n}`
        });
      }
    }

    // Check for delegate cycles
    if (line.includes('delegate') && line.includes('=') && !line.includes('weak')) {
      result.issues.push({
        type: 'retain-cycle',
        severity: 'medium',
        file,
        line: lineNumber,
        description: 'Delegate property should be weak to avoid retain cycles',
        impact: 'Memory leak between delegate and delegating object',
        solution: 'Mark delegate property as weak',
        codeExample: `weak var delegate: SomeProtocol?`
      });
    }

    // Check for parent-child relationships
    if (line.includes('parent') && line.includes('=') && !line.includes('weak')) {
      result.issues.push({
        type: 'retain-cycle',
        severity: 'medium',
        file,
        line: lineNumber,
        description: 'Parent reference should typically be weak',
        impact: 'Potential retain cycle in hierarchical relationships',
        solution: 'Consider using weak reference for parent',
        codeExample: `weak var parent: ParentClass?`
      });
    }
  }

  private checkForExcessiveAllocations(line: string, lineNumber: number, file: string, result: MemoryAnalysisResult): void {
    // Check for array allocation in loops
    if ((line.includes('for ') || line.includes('while ')) && line.includes('[') && line.includes(']')) {
      result.issues.push({
        type: 'excessive-allocation',
        severity: 'medium',
        file,
        line: lineNumber,
        description: 'Array allocation inside loop',
        impact: 'Performance degradation and memory pressure',
        solution: 'Pre-allocate arrays outside loops or use array capacity reservation',
        codeExample: `var results = [Type]()\nresults.reserveCapacity(expectedCount)\n// then append in loop`
      });
    }

    // Check for string concatenation in loops
    if ((line.includes('for ') || line.includes('while ')) && line.includes('+=') && line.includes('String')) {
      result.issues.push({
        type: 'excessive-allocation',
        severity: 'high',
        file,
        line: lineNumber,
        description: 'String concatenation in loop',
        impact: 'Exponential memory allocation and performance issues',
        solution: 'Use Array<String> and joined() or StringBuilder pattern',
        codeExample: `var parts = [String]()\n// append to parts in loop\nlet result = parts.joined()`
      });
    }

    // Check for repeated UIImage creation
    if (line.includes('UIImage(named:') && (line.includes('for ') || line.includes('while '))) {
      result.issues.push({
        type: 'excessive-allocation',
        severity: 'medium',
        file,
        line: lineNumber,
        description: 'UIImage creation in loop',
        impact: 'Memory pressure and performance issues',
        solution: 'Cache images outside loop or use lazy loading',
        codeExample: `let cachedImage = UIImage(named: "imageName")\n// use cachedImage in loop`
      });
    }
  }

  private checkForInefficientPatterns(line: string, lineNumber: number, file: string, result: MemoryAnalysisResult): void {
    // Check for inefficient array operations
    if (line.includes('.count > 0')) {
      result.issues.push({
        type: 'inefficient-pattern',
        severity: 'low',
        file,
        line: lineNumber,
        description: 'Using .count > 0 instead of !.isEmpty',
        impact: 'Minor performance impact for large collections',
        solution: 'Use !.isEmpty for better performance',
        codeExample: `if !array.isEmpty { // instead of array.count > 0`
      });
    }

    // Check for force unwrapping
    if (line.includes('!') && !line.includes('//') && !line.includes('!=')) {
      const forceUnwrapMatches = line.match(/\w+!/g);
      if (forceUnwrapMatches) {
        result.issues.push({
          type: 'inefficient-pattern',
          severity: 'medium',
          file,
          line: lineNumber,
          description: 'Force unwrapping can cause crashes',
          impact: 'App crashes when optional is nil',
          solution: 'Use optional binding or nil coalescing operator',
          codeExample: `if let value = optionalValue {\n    // use value\n}`
        });
      }
    }

    // Check for viewDidLoad without super call
    if (line.includes('override func viewDidLoad()')) {
      result.issues.push({
        type: 'inefficient-pattern',
        severity: 'high',
        file,
        line: lineNumber,
        description: 'viewDidLoad should call super.viewDidLoad()',
        impact: 'Potential memory and initialization issues',
        solution: 'Always call super.viewDidLoad() first',
        codeExample: `override func viewDidLoad() {\n    super.viewDidLoad()\n    // your code here\n}`
      });
    }
  }

  private checkDICOMMemoryIssues(line: string, lineNumber: number, file: string, result: MemoryAnalysisResult): void {
    // Check for DICOM image buffer management
    if (line.includes('CVPixelBuffer') && !line.includes('CVPixelBufferRelease')) {
      result.issues.push({
        type: 'leak',
        severity: 'high',
        file,
        line: lineNumber,
        description: 'CVPixelBuffer may not be properly released',
        impact: 'Memory leak in medical imaging pipeline',
        solution: 'Ensure CVPixelBuffer is released or use automatic memory management',
        codeExample: `defer { CVPixelBufferRelease(pixelBuffer) }`
      });
    }

    // Check for large DICOM data allocations
    if (line.includes('Data(count:') || line.includes('UnsafeMutablePointer')) {
      result.issues.push({
        type: 'excessive-allocation',
        severity: 'medium',
        file,
        line: lineNumber,
        description: 'Large data allocation detected - consider streaming for DICOM files',
        impact: 'High memory usage for large medical images',
        solution: 'Use streaming or chunked processing for large DICOM files',
        codeExample: `// Process DICOM data in chunks\nlet chunkSize = 1024 * 1024 // 1MB chunks`
      });
    }

    // Check for Metal buffer management
    if (line.includes('makeBuffer') && !line.includes('autoreleasepool')) {
      result.issues.push({
        type: 'inefficient-pattern',
        severity: 'medium',
        file,
        line: lineNumber,
        description: 'Metal buffer allocation should use autorelease pool for frequent allocations',
        impact: 'Memory pressure during 3D rendering operations',
        solution: 'Use autoreleasepool for Metal buffer allocations in loops',
        codeExample: `autoreleasepool {\n    let buffer = device.makeBuffer(...)\n    // use buffer\n}`
      });
    }

    // Check for DCMTK memory management
    if (line.includes('dcmtk') || line.includes('DCMTK')) {
      result.issues.push({
        type: 'inefficient-pattern',
        severity: 'medium',
        file,
        line: lineNumber,
        description: 'DCMTK operations require careful memory management',
        impact: 'Potential memory leaks in C++ bridge code',
        solution: 'Ensure proper cleanup of DCMTK objects and use RAII patterns',
        codeExample: `// Use defer for cleanup\ndefer { dcmtkObject?.cleanup() }`
      });
    }
  }

  private analyzeFilePatterns(content: string, file: string, result: MemoryAnalysisResult): void {
    // Analyze class/struct patterns
    const classCount = (content.match(/class\s+\w+/g) || []).length;
    const structCount = (content.match(/struct\s+\w+/g) || []).length;
    
    if (classCount > structCount * 2) {
      result.patterns.push({
        pattern: 'Excessive class usage',
        occurrences: classCount,
        files: [file],
        recommendation: 'Consider using structs for value types to reduce heap allocations',
        impact: 'negative'
      });
    }

    // Analyze weak reference usage
    const weakCount = (content.match(/weak\s+var/g) || []).length;
    const strongRefCount = (content.match(/var\s+\w+:/g) || []).length;
    
    if (weakCount === 0 && strongRefCount > 5) {
      result.patterns.push({
        pattern: 'No weak references found',
        occurrences: 1,
        files: [file],
        recommendation: 'Consider using weak references for delegates and parent references',
        impact: 'negative'
      });
    }

    // Analyze deinit presence
    if (classCount > 0 && !content.includes('deinit')) {
      result.patterns.push({
        pattern: 'Classes without deinit',
        occurrences: classCount,
        files: [file],
        recommendation: 'Add deinit to clean up resources (observers, timers, etc.)',
        impact: 'negative'
      });
    }
  }

  private calculateMetrics(result: MemoryAnalysisResult): void {
    result.metrics.totalSwiftFiles = result.patterns.reduce((sum, p) => {
      return p.pattern === 'Total Swift files' ? p.occurrences : sum;
    }, 0);

    result.metrics.potentialLeaks = result.issues.filter(i => i.type === 'leak').length;
    result.metrics.retainCycles = result.issues.filter(i => i.type === 'retain-cycle').length;
    result.metrics.heavyAllocators = result.issues.filter(i => i.type === 'excessive-allocation').length;
    result.metrics.memoryEfficientPatterns = result.patterns.filter(p => p.impact === 'positive').length;
    result.metrics.dicomSpecificIssues = result.issues.filter(i => 
      i.description.toLowerCase().includes('dicom') || 
      i.description.toLowerCase().includes('metal') ||
      i.description.toLowerCase().includes('cvpixel')
    ).length;
  }

  private generateOptimizations(result: MemoryAnalysisResult): void {
    // Object pooling for frequent allocations
    if (result.metrics.heavyAllocators > 3) {
      result.optimizations.push({
        category: 'pooling',
        description: 'Implement object pooling for frequently allocated objects',
        implementation: 'Create object pools for commonly used types like DICOM instances or image buffers',
        expectedGain: 'Reduced allocation overhead and garbage collection pressure',
        difficulty: 'medium'
      });
    }

    // Lazy loading for large resources
    if (result.issues.some(i => i.description.includes('large') || i.description.includes('DICOM'))) {
      result.optimizations.push({
        category: 'lazy-loading',
        description: 'Implement lazy loading for large medical images',
        implementation: 'Load DICOM images on-demand and implement progressive loading',
        expectedGain: 'Reduced initial memory footprint and faster app startup',
        difficulty: 'medium'
      });
    }

    // Caching strategy
    if (result.issues.some(i => i.description.includes('UIImage') || i.description.includes('repeated'))) {
      result.optimizations.push({
        category: 'caching',
        description: 'Implement intelligent caching for images and computed data',
        implementation: 'Use NSCache or custom LRU cache for images and metadata',
        expectedGain: 'Reduced redundant allocations and improved performance',
        difficulty: 'easy'
      });
    }

    // Memory-mapped files for large DICOM data
    if (result.metrics.dicomSpecificIssues > 0) {
      result.optimizations.push({
        category: 'allocation',
        description: 'Use memory-mapped files for large DICOM datasets',
        implementation: 'Map DICOM files to memory instead of loading entire files',
        expectedGain: 'Reduced memory usage and faster access to large medical images',
        difficulty: 'hard'
      });
    }

    // Autorelease pool optimization
    if (result.issues.some(i => i.description.includes('Metal') || i.description.includes('buffer'))) {
      result.optimizations.push({
        category: 'allocation',
        description: 'Optimize autorelease pool usage for graphics operations',
        implementation: 'Wrap Metal operations and frequent allocations in autorelease pools',
        expectedGain: 'Reduced memory peaks during rendering operations',
        difficulty: 'easy'
      });
    }
  }

  private initializeMetrics(): MemoryMetrics {
    return {
      totalSwiftFiles: 0,
      potentialLeaks: 0,
      retainCycles: 0,
      heavyAllocators: 0,
      memoryEfficientPatterns: 0,
      dicomSpecificIssues: 0
    };
  }

  private formatMemoryAnalysis(result: MemoryAnalysisResult): string {
    let output = `# iOS Memory Usage Analysis\n\n`;
    
    output += `**Project:** ${path.basename(result.projectPath)}\n`;
    output += `**Target:** ${result.target}\n\n`;
    
    // Metrics overview
    output += `## Memory Health Overview\n\n`;
    output += `- **Potential Memory Leaks:** ${result.metrics.potentialLeaks}\n`;
    output += `- **Retain Cycles:** ${result.metrics.retainCycles}\n`;
    output += `- **Heavy Allocators:** ${result.metrics.heavyAllocators}\n`;
    output += `- **DICOM-Specific Issues:** ${result.metrics.dicomSpecificIssues}\n`;
    output += `- **Memory Efficient Patterns:** ${result.metrics.memoryEfficientPatterns}\n\n`;
    
    // Overall health score
    const totalIssues = result.metrics.potentialLeaks + result.metrics.retainCycles + result.metrics.heavyAllocators;
    const healthScore = Math.max(0, 100 - (totalIssues * 10));
    const healthIcon = healthScore >= 80 ? '🟢' : healthScore >= 60 ? '🟡' : '🔴';
    
    output += `${healthIcon} **Memory Health Score:** ${healthScore}%\n\n`;
    
    // Critical issues first
    const criticalIssues = result.issues.filter(i => i.severity === 'critical' || i.severity === 'high');
    const mediumIssues = result.issues.filter(i => i.severity === 'medium');
    const lowIssues = result.issues.filter(i => i.severity === 'low');
    
    if (criticalIssues.length > 0) {
      output += `## Critical Memory Issues (${criticalIssues.length})\n\n`;
      for (const issue of criticalIssues) {
        output += `❌ **${issue.type.toUpperCase()}** in ${issue.file}`;
        if (issue.line) output += ` (Line ${issue.line})`;
        output += `\n`;
        output += `   📝 ${issue.description}\n`;
        output += `   ⚡ **Impact:** ${issue.impact}\n`;
        output += `   🔧 **Solution:** ${issue.solution}\n`;
        if (issue.codeExample) {
          output += `   💡 **Example:**\n\`\`\`swift\n${issue.codeExample}\n\`\`\`\n`;
        }
        output += '\n';
      }
    }
    
    if (mediumIssues.length > 0) {
      output += `## Medium Priority Issues (${mediumIssues.length})\n\n`;
      for (const issue of mediumIssues) {
        output += `⚠️ **${issue.type.toUpperCase()}** in ${issue.file}`;
        if (issue.line) output += ` (Line ${issue.line})`;
        output += `\n`;
        output += `   📝 ${issue.description}\n`;
        output += `   🔧 **Solution:** ${issue.solution}\n`;
        output += '\n';
      }
    }
    
    if (lowIssues.length > 0 && lowIssues.length <= 10) {
      output += `## Low Priority Issues (${lowIssues.length})\n\n`;
      for (const issue of lowIssues.slice(0, 5)) {
        output += `ℹ️ **${issue.type.toUpperCase()}** in ${issue.file}`;
        if (issue.line) output += ` (Line ${issue.line})`;
        output += ` - ${issue.description}\n`;
      }
      if (lowIssues.length > 5) {
        output += `   ... and ${lowIssues.length - 5} more low priority issues\n`;
      }
      output += '\n';
    }
    
    // Optimization recommendations
    if (result.optimizations.length > 0) {
      output += `## Memory Optimization Recommendations\n\n`;
      
      const easyOpts = result.optimizations.filter(o => o.difficulty === 'easy');
      const mediumOpts = result.optimizations.filter(o => o.difficulty === 'medium');
      const hardOpts = result.optimizations.filter(o => o.difficulty === 'hard');
      
      if (easyOpts.length > 0) {
        output += `### Quick Wins (${easyOpts.length})\n\n`;
        for (const opt of easyOpts) {
          output += `🟢 **${opt.category.toUpperCase()}:** ${opt.description}\n`;
          output += `   🛠️ ${opt.implementation}\n`;
          output += `   📈 **Expected Gain:** ${opt.expectedGain}\n\n`;
        }
      }
      
      if (mediumOpts.length > 0) {
        output += `### Medium Effort (${mediumOpts.length})\n\n`;
        for (const opt of mediumOpts) {
          output += `🟡 **${opt.category.toUpperCase()}:** ${opt.description}\n`;
          output += `   🛠️ ${opt.implementation}\n`;
          output += `   📈 **Expected Gain:** ${opt.expectedGain}\n\n`;
        }
      }
      
      if (hardOpts.length > 0) {
        output += `### Advanced Optimizations (${hardOpts.length})\n\n`;
        for (const opt of hardOpts) {
          output += `🔴 **${opt.category.toUpperCase()}:** ${opt.description}\n`;
          output += `   🛠️ ${opt.implementation}\n`;
          output += `   📈 **Expected Gain:** ${opt.expectedGain}\n\n`;
        }
      }
    }
    
    // Memory patterns
    const negativePatterns = result.patterns.filter(p => p.impact === 'negative');
    if (negativePatterns.length > 0) {
      output += `## Memory Anti-Patterns Found\n\n`;
      for (const pattern of negativePatterns) {
        output += `📊 **${pattern.pattern}** (${pattern.occurrences} occurrences)\n`;
        output += `   💡 ${pattern.recommendation}\n`;
        if (pattern.files.length <= 3) {
          output += `   📁 Files: ${pattern.files.join(', ')}\n`;
        } else {
          output += `   📁 Files: ${pattern.files.slice(0, 3).join(', ')} and ${pattern.files.length - 3} more\n`;
        }
        output += '\n';
      }
    }
    
    if (totalIssues === 0) {
      output += `## 🎉 Excellent Memory Management!\n\n`;
      output += `No critical memory issues found. Your code follows good memory management practices.\n\n`;
      output += `### Recommendations for maintaining good memory health:\n`;
      output += `- Continue using weak references for delegates\n`;
      output += `- Keep implementing proper cleanup in deinit methods\n`;
      output += `- Monitor memory usage during DICOM image processing\n`;
      output += `- Use Instruments to profile memory usage regularly\n\n`;
    }
    
    return output;
  }
}