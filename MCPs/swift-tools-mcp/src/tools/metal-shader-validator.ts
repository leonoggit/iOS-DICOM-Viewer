import * as fs from 'fs-extra';
import * as path from 'path';
import { execSync } from 'child_process';
import glob from 'fast-glob';

export interface MetalShaderResult {
  file: string;
  compiled: boolean;
  errors: MetalError[];
  warnings: MetalWarning[];
  performance: PerformanceAnalysis;
  compatibility: CompatibilityInfo;
}

export interface MetalError {
  line: number;
  column?: number;
  message: string;
  type: 'syntax' | 'semantic' | 'linking';
}

export interface MetalWarning {
  line: number;
  column?: number;
  message: string;
  category: 'performance' | 'deprecation' | 'best-practice';
  suggestion?: string;
}

export interface PerformanceAnalysis {
  estimatedRegisters: number;
  memoryBandwidth: 'low' | 'medium' | 'high' | 'very-high';
  complexity: 'simple' | 'moderate' | 'complex' | 'very-complex';
  optimizations: OptimizationSuggestion[];
  bottlenecks: string[];
}

export interface OptimizationSuggestion {
  type: 'memory' | 'compute' | 'bandwidth' | 'branching';
  description: string;
  impact: 'low' | 'medium' | 'high';
  implementation: string;
}

export interface CompatibilityInfo {
  minMetalVersion: string;
  supportedDevices: string[];
  featureRequirements: string[];
  limitations: string[];
}

export class MetalShaderValidator {
  async compileShaders(
    shaderPath: string,
    target: string = 'ios',
    optimizationLevel: string = 'speed'
  ): Promise<any> {
    try {
      if (!await fs.pathExists(shaderPath)) {
        throw new Error(`Shader path does not exist: ${shaderPath}`);
      }

      const stats = await fs.stat(shaderPath);
      const files = stats.isDirectory() 
        ? await glob('**/*.metal', { cwd: shaderPath, absolute: true })
        : [shaderPath];

      if (files.length === 0) {
        throw new Error('No Metal shader files found');
      }

      const results: MetalShaderResult[] = [];
      
      for (const file of files) {
        const result = await this.compileMetalFile(file, target, optimizationLevel);
        results.push(result);
      }

      return {
        content: [{
          type: 'text',
          text: this.formatCompilationResults(results, shaderPath),
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to compile Metal shaders: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async analyzePerformance(shaderPath: string, deviceFamily: string = 'iPhone'): Promise<any> {
    try {
      if (!await fs.pathExists(shaderPath)) {
        throw new Error(`Shader file does not exist: ${shaderPath}`);
      }

      const result = await this.performShaderAnalysis(shaderPath, deviceFamily);

      return {
        content: [{
          type: 'text',
          text: this.formatPerformanceAnalysis(result, shaderPath),
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to analyze Metal shader performance: ${error}`,
        }],
        isError: true,
      };
    }
  }

  private async compileMetalFile(
    filePath: string,
    target: string,
    optimizationLevel: string
  ): Promise<MetalShaderResult> {
    const result: MetalShaderResult = {
      file: filePath,
      compiled: false,
      errors: [],
      warnings: [],
      performance: this.initializePerformanceAnalysis(),
      compatibility: this.initializeCompatibilityInfo()
    };

    try {
      // Read and analyze the shader source
      const source = await fs.readFile(filePath, 'utf8');
      
      // Static analysis
      this.performStaticAnalysis(source, result);
      
      // Compile the shader
      await this.compileWithXcrun(filePath, target, optimizationLevel, result);
      
      // Performance analysis
      this.analyzeShaderPerformance(source, result);
      
      // Compatibility analysis
      this.analyzeCompatibility(source, result);

    } catch (error) {
      result.errors.push({
        line: 0,
        message: `Compilation failed: ${error}`,
        type: 'linking'
      });
    }

    return result;
  }

  private async compileWithXcrun(
    filePath: string,
    target: string,
    optimizationLevel: string,
    result: MetalShaderResult
  ): Promise<void> {
    try {
      const outputPath = path.join('/tmp', `${path.basename(filePath, '.metal')}.air`);
      
      const args = [
        'xcrun',
        '-sdk', target === 'ios-simulator' ? 'iphonesimulator' : 'iphoneos',
        'metal',
        '-c',
        filePath,
        '-o', outputPath
      ];

      // Add optimization flags
      switch (optimizationLevel) {
        case 'speed':
          args.push('-O');
          break;
        case 'size':
          args.push('-Os');
          break;
        case 'none':
          args.push('-O0');
          break;
      }

      const output = execSync(args.join(' '), { 
        encoding: 'utf8',
        timeout: 30000
      });

      result.compiled = true;
      
      // Parse any warnings from output
      this.parseCompilerOutput(output, result);
      
    } catch (error: any) {
      result.compiled = false;
      this.parseCompilerErrors(error.stderr || error.stdout || error.message, result);
    }
  }

  private performStaticAnalysis(source: string, result: MetalShaderResult): void {
    const lines = source.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lineNumber = i + 1;
      
      // Check for common issues
      this.checkSyntaxIssues(line, lineNumber, result);
      this.checkPerformanceIssues(line, lineNumber, result);
      this.checkBestPractices(line, lineNumber, result);
      this.checkMedicalImagingPatterns(line, lineNumber, result);
    }
  }

  private checkSyntaxIssues(line: string, lineNumber: number, result: MetalShaderResult): void {
    // Check for missing semicolons
    if (line.trim().match(/^(float|int|uint|half|bool|float[2-4]|int[2-4]|uint[2-4]|half[2-4])\s+\w+\s*=.*[^;]$/)) {
      result.warnings.push({
        line: lineNumber,
        message: 'Statement may be missing semicolon',
        category: 'best-practice',
        suggestion: 'Add semicolon at end of statement'
      });
    }
    
    // Check for potential precision issues
    if (line.includes('float') && line.includes('/')) {
      result.warnings.push({
        line: lineNumber,
        message: 'Potential precision loss in floating-point division',
        category: 'performance',
        suggestion: 'Consider using half precision if full precision is not needed'
      });
    }
  }

  private checkPerformanceIssues(line: string, lineNumber: number, result: MetalShaderResult): void {
    // Check for expensive operations
    if (line.includes('sin(') || line.includes('cos(') || line.includes('tan(')) {
      result.warnings.push({
        line: lineNumber,
        message: 'Trigonometric functions are expensive on GPU',
        category: 'performance',
        suggestion: 'Consider using lookup tables or approximations for better performance'
      });
    }
    
    if (line.includes('pow(')) {
      result.warnings.push({
        line: lineNumber,
        message: 'Power function is expensive on GPU',
        category: 'performance',
        suggestion: 'Use multiplication for small integer powers (e.g., x*x instead of pow(x,2))'
      });
    }
    
    if (line.includes('sqrt(')) {
      result.warnings.push({
        line: lineNumber,
        message: 'Square root function has performance impact',
        category: 'performance',
        suggestion: 'Consider using rsqrt() if you need 1/sqrt(x), or fast_sqrt() for approximation'
      });
    }
    
    // Check for branching in loops
    if (line.includes('for') && (line.includes('if') || line.includes('?'))) {
      result.warnings.push({
        line: lineNumber,
        message: 'Branching inside loops can hurt performance',
        category: 'performance',
        suggestion: 'Try to minimize conditional statements in loops'
      });
    }
  }

  private checkBestPractices(line: string, lineNumber: number, result: MetalShaderResult): void {
    // Check for vector operations
    if (line.match(/float\s+\w+\s*=.*[xyz]\s*[\+\-\*\/]/)) {
      result.warnings.push({
        line: lineNumber,
        message: 'Consider using vector operations instead of scalar operations on vector components',
        category: 'best-practice',
        suggestion: 'Use built-in vector functions like dot(), cross(), length(), etc.'
      });
    }
    
    // Check for magic numbers
    if (line.match(/[\+\-\*\/]\s*\d+\.\d+/) && !line.includes('//')) {
      result.warnings.push({
        line: lineNumber,
        message: 'Magic numbers should be defined as constants',
        category: 'best-practice',
        suggestion: 'Define numeric literals as named constants at the top of the shader'
      });
    }
    
    // Check for texture sampling optimization
    if (line.includes('sample(') && !line.includes('coord')) {
      result.warnings.push({
        line: lineNumber,
        message: 'Texture sampling should use optimized coordinate calculation',
        category: 'performance',
        suggestion: 'Pre-calculate texture coordinates when possible'
      });
    }
  }

  private checkMedicalImagingPatterns(line: string, lineNumber: number, result: MetalShaderResult): void {
    // Check for DICOM-specific patterns
    if (line.includes('windowLevel') || line.includes('windowWidth')) {
      result.warnings.push({
        line: lineNumber,
        message: 'DICOM window/level operations detected',
        category: 'best-practice',
        suggestion: 'Ensure proper handling of DICOM pixel value scaling and window/level transformations'
      });
    }
    
    // Check for volume rendering patterns
    if (line.includes('raycast') || line.includes('volumeTexture')) {
      result.warnings.push({
        line: lineNumber,
        message: 'Volume rendering detected - ensure optimal sampling',
        category: 'performance',
        suggestion: 'Use adaptive sampling and early ray termination for better performance'
      });
    }
    
    // Check for medical color mappings
    if (line.includes('colormap') || line.includes('lut')) {
      result.warnings.push({
        line: lineNumber,
        message: 'Color mapping detected',
        category: 'best-practice',
        suggestion: 'Ensure color mappings are appropriate for medical visualization standards'
      });
    }
  }

  private analyzeShaderPerformance(source: string, result: MetalShaderResult): void {
    // Estimate register usage
    const floatVars = (source.match(/float[2-4]?\s+\w+/g) || []).length;
    const intVars = (source.match(/int[2-4]?\s+\w+/g) || []).length;
    result.performance.estimatedRegisters = floatVars * 4 + intVars * 2;
    
    // Analyze memory bandwidth
    const textureAccesses = (source.match(/sample\(/g) || []).length;
    const bufferAccesses = (source.match(/device\s+\w+/g) || []).length;
    
    if (textureAccesses > 10 || bufferAccesses > 5) {
      result.performance.memoryBandwidth = 'very-high';
    } else if (textureAccesses > 5 || bufferAccesses > 2) {
      result.performance.memoryBandwidth = 'high';
    } else if (textureAccesses > 2 || bufferAccesses > 0) {
      result.performance.memoryBandwidth = 'medium';
    } else {
      result.performance.memoryBandwidth = 'low';
    }
    
    // Analyze complexity
    const mathOps = (source.match(/(sin|cos|tan|sqrt|pow|exp|log)\(/g) || []).length;
    const branches = (source.match(/(if|for|while)\s*\(/g) || []).length;
    
    if (mathOps > 10 || branches > 5) {
      result.performance.complexity = 'very-complex';
    } else if (mathOps > 5 || branches > 2) {
      result.performance.complexity = 'complex';
    } else if (mathOps > 2 || branches > 0) {
      result.performance.complexity = 'moderate';
    } else {
      result.performance.complexity = 'simple';
    }
    
    // Generate optimization suggestions
    this.generateOptimizationSuggestions(source, result.performance);
  }

  private generateOptimizationSuggestions(source: string, performance: PerformanceAnalysis): void {
    // Memory optimizations
    if (performance.memoryBandwidth === 'very-high') {
      performance.optimizations.push({
        type: 'memory',
        description: 'High memory bandwidth usage detected',
        impact: 'high',
        implementation: 'Reduce texture sampling frequency, use lower precision formats, or implement texture caching'
      });
    }
    
    // Compute optimizations
    if (performance.complexity === 'very-complex') {
      performance.optimizations.push({
        type: 'compute',
        description: 'High computational complexity detected',
        impact: 'high',
        implementation: 'Use lookup tables for expensive functions, reduce mathematical operations, or split into multiple passes'
      });
    }
    
    // Branching optimizations
    const branches = (source.match(/(if|for|while)\s*\(/g) || []).length;
    if (branches > 3) {
      performance.optimizations.push({
        type: 'branching',
        description: 'Multiple branches detected which can cause divergence',
        impact: 'medium',
        implementation: 'Minimize conditional statements, use select() function, or restructure algorithm to reduce branching'
      });
    }
    
    // Register pressure
    if (performance.estimatedRegisters > 32) {
      performance.optimizations.push({
        type: 'memory',
        description: 'High register usage may limit occupancy',
        impact: 'medium',
        implementation: 'Reduce the number of variables, reuse variables, or split shader into smaller functions'
      });
    }
  }

  private analyzeCompatibility(source: string, result: MetalShaderResult): void {
    // Check for Metal version requirements
    if (source.includes('raytracing') || source.includes('intersection')) {
      result.compatibility.minMetalVersion = '2.4';
      result.compatibility.featureRequirements.push('Ray Tracing (iOS 14+)');
      result.compatibility.supportedDevices = ['iPhone 12 and later', 'iPad Pro 2020 and later'];
    } else if (source.includes('imageblock') || source.includes('threadgroup_imageblock')) {
      result.compatibility.minMetalVersion = '2.0';
      result.compatibility.featureRequirements.push('Tile Shaders (iOS 11+)');
      result.compatibility.supportedDevices = ['A11 and later'];
    } else if (source.includes('argument_buffer')) {
      result.compatibility.minMetalVersion = '2.0';
      result.compatibility.featureRequirements.push('Argument Buffers (iOS 11+)');
      result.compatibility.supportedDevices = ['A11 and later'];
    } else {
      result.compatibility.minMetalVersion = '1.0';
      result.compatibility.supportedDevices = ['All Metal-capable devices'];
    }
    
    // Check for precision requirements
    if (source.includes('half')) {
      result.compatibility.featureRequirements.push('Half precision support');
    }
    
    // Check for compute shader features
    if (source.includes('kernel') && source.includes('threadgroup')) {
      result.compatibility.featureRequirements.push('Compute shaders with threadgroup memory');
    }
  }

  private async performShaderAnalysis(shaderPath: string, deviceFamily: string): Promise<MetalShaderResult> {
    const source = await fs.readFile(shaderPath, 'utf8');
    
    const result: MetalShaderResult = {
      file: shaderPath,
      compiled: true,
      errors: [],
      warnings: [],
      performance: this.initializePerformanceAnalysis(),
      compatibility: this.initializeCompatibilityInfo()
    };
    
    this.performStaticAnalysis(source, result);
    this.analyzeShaderPerformance(source, result);
    this.analyzeCompatibility(source, result);
    
    // Device-specific analysis
    this.analyzeDeviceSpecificPerformance(source, deviceFamily, result);
    
    return result;
  }

  private analyzeDeviceSpecificPerformance(source: string, deviceFamily: string, result: MetalShaderResult): void {
    // Adjust recommendations based on device family
    if (deviceFamily.toLowerCase().includes('iphone')) {
      // iPhone-specific optimizations
      if (result.performance.complexity === 'very-complex') {
        result.performance.bottlenecks.push('Complex shaders may cause thermal throttling on iPhone');
      }
      
      if (result.performance.memoryBandwidth === 'very-high') {
        result.performance.bottlenecks.push('High memory bandwidth usage may impact battery life on iPhone');
      }
    } else if (deviceFamily.toLowerCase().includes('ipad')) {
      // iPad-specific considerations
      if (result.performance.estimatedRegisters > 64) {
        result.performance.bottlenecks.push('High register usage may limit performance on older iPad models');
      }
    }
  }

  private parseCompilerOutput(output: string, result: MetalShaderResult): void {
    const lines = output.split('\n');
    
    for (const line of lines) {
      if (line.includes('warning:')) {
        const match = line.match(/(\d+):(\d+):\s*warning:\s*(.+)/);
        if (match) {
          const [, lineNum, column, message] = match;
          result.warnings.push({
            line: parseInt(lineNum),
            column: parseInt(column),
            message,
            category: 'best-practice'
          });
        }
      }
    }
  }

  private parseCompilerErrors(errorOutput: string, result: MetalShaderResult): void {
    const lines = errorOutput.split('\n');
    
    for (const line of lines) {
      if (line.includes('error:')) {
        const match = line.match(/(\d+):(\d+):\s*error:\s*(.+)/);
        if (match) {
          const [, lineNum, column, message] = match;
          result.errors.push({
            line: parseInt(lineNum),
            column: parseInt(column),
            message,
            type: 'syntax'
          });
        }
      }
    }
  }

  private initializePerformanceAnalysis(): PerformanceAnalysis {
    return {
      estimatedRegisters: 0,
      memoryBandwidth: 'low',
      complexity: 'simple',
      optimizations: [],
      bottlenecks: []
    };
  }

  private initializeCompatibilityInfo(): CompatibilityInfo {
    return {
      minMetalVersion: '1.0',
      supportedDevices: [],
      featureRequirements: [],
      limitations: []
    };
  }

  private formatCompilationResults(results: MetalShaderResult[], basePath: string): string {
    let output = `# Metal Shader Compilation Results\n\n`;
    
    if (results.length === 1) {
      output += `**Shader:** ${path.relative(process.cwd(), results[0].file)}\n\n`;
    } else {
      output += `**Compiled ${results.length} Metal shaders** in ${path.relative(process.cwd(), basePath)}\n\n`;
    }
    
    // Summary
    const compiled = results.filter(r => r.compiled).length;
    const totalErrors = results.reduce((sum, r) => sum + r.errors.length, 0);
    const totalWarnings = results.reduce((sum, r) => sum + r.warnings.length, 0);
    
    output += `## Compilation Summary\n\n`;
    output += `- **Successfully Compiled:** ${compiled}/${results.length}\n`;
    output += `- **Total Errors:** ${totalErrors}\n`;
    output += `- **Total Warnings:** ${totalWarnings}\n\n`;
    
    if (compiled === results.length && totalErrors === 0) {
      output += `✅ All shaders compiled successfully!\n\n`;
    }
    
    // Individual results
    for (const result of results) {
      if (results.length > 1) {
        output += `### ${path.basename(result.file)}\n\n`;
      }
      
      if (result.compiled) {
        output += `✅ **Compilation:** Successful\n`;
      } else {
        output += `❌ **Compilation:** Failed\n`;
      }
      
      // Performance metrics
      if (result.compiled) {
        output += `\n**Performance Metrics:**\n`;
        output += `- **Estimated Registers:** ${result.performance.estimatedRegisters}\n`;
        output += `- **Memory Bandwidth:** ${result.performance.memoryBandwidth}\n`;
        output += `- **Complexity:** ${result.performance.complexity}\n`;
        
        if (result.compatibility.minMetalVersion !== '1.0') {
          output += `- **Min Metal Version:** ${result.compatibility.minMetalVersion}\n`;
        }
        output += '\n';
      }
      
      // Errors
      if (result.errors.length > 0) {
        output += `**Errors (${result.errors.length}):**\n\n`;
        for (const error of result.errors) {
          output += `❌ Line ${error.line}: ${error.message}\n`;
        }
        output += '\n';
      }
      
      // Warnings
      if (result.warnings.length > 0) {
        output += `**Warnings (${result.warnings.length}):**\n\n`;
        for (const warning of result.warnings) {
          output += `⚠️ Line ${warning.line}: ${warning.message}\n`;
          if (warning.suggestion) {
            output += `   💡 ${warning.suggestion}\n`;
          }
        }
        output += '\n';
      }
      
      // Optimization suggestions
      if (result.performance.optimizations.length > 0) {
        output += `**Optimization Suggestions:**\n\n`;
        for (const opt of result.performance.optimizations) {
          const impactIcon = opt.impact === 'high' ? '🔴' : opt.impact === 'medium' ? '🟡' : '🟢';
          output += `${impactIcon} **${opt.type.toUpperCase()}:** ${opt.description}\n`;
          output += `   💡 ${opt.implementation}\n\n`;
        }
      }
      
      // Bottlenecks
      if (result.performance.bottlenecks.length > 0) {
        output += `**Potential Bottlenecks:**\n\n`;
        for (const bottleneck of result.performance.bottlenecks) {
          output += `⚡ ${bottleneck}\n`;
        }
        output += '\n';
      }
      
      if (results.length > 1) {
        output += '---\n\n';
      }
    }
    
    return output;
  }

  private formatPerformanceAnalysis(result: MetalShaderResult, shaderPath: string): string {
    let output = `# Metal Shader Performance Analysis\n\n`;
    
    output += `**Shader:** ${path.relative(process.cwd(), shaderPath)}\n\n`;
    
    // Performance overview
    output += `## Performance Overview\n\n`;
    output += `- **Estimated Registers:** ${result.performance.estimatedRegisters}\n`;
    output += `- **Memory Bandwidth:** ${result.performance.memoryBandwidth}\n`;
    output += `- **Complexity Level:** ${result.performance.complexity}\n`;
    output += `- **Min Metal Version:** ${result.compatibility.minMetalVersion}\n\n`;
    
    // Compatibility
    if (result.compatibility.featureRequirements.length > 0) {
      output += `## Feature Requirements\n\n`;
      for (const req of result.compatibility.featureRequirements) {
        output += `- ${req}\n`;
      }
      output += '\n';
    }
    
    if (result.compatibility.supportedDevices.length > 0) {
      output += `## Supported Devices\n\n`;
      for (const device of result.compatibility.supportedDevices) {
        output += `- ${device}\n`;
      }
      output += '\n';
    }
    
    // Performance recommendations
    if (result.performance.optimizations.length > 0) {
      output += `## Optimization Recommendations\n\n`;
      
      const highImpact = result.performance.optimizations.filter(o => o.impact === 'high');
      const mediumImpact = result.performance.optimizations.filter(o => o.impact === 'medium');
      const lowImpact = result.performance.optimizations.filter(o => o.impact === 'low');
      
      if (highImpact.length > 0) {
        output += `### High Impact (${highImpact.length})\n\n`;
        for (const opt of highImpact) {
          output += `🔴 **${opt.type.toUpperCase()}:** ${opt.description}\n`;
          output += `   💡 ${opt.implementation}\n\n`;
        }
      }
      
      if (mediumImpact.length > 0) {
        output += `### Medium Impact (${mediumImpact.length})\n\n`;
        for (const opt of mediumImpact) {
          output += `🟡 **${opt.type.toUpperCase()}:** ${opt.description}\n`;
          output += `   💡 ${opt.implementation}\n\n`;
        }
      }
      
      if (lowImpact.length > 0) {
        output += `### Low Impact (${lowImpact.length})\n\n`;
        for (const opt of lowImpact) {
          output += `🟢 **${opt.type.toUpperCase()}:** ${opt.description}\n`;
          output += `   💡 ${opt.implementation}\n\n`;
        }
      }
    } else {
      output += `✅ No significant performance optimizations needed.\n\n`;
    }
    
    // Bottlenecks
    if (result.performance.bottlenecks.length > 0) {
      output += `## Potential Bottlenecks\n\n`;
      for (const bottleneck of result.performance.bottlenecks) {
        output += `⚡ ${bottleneck}\n`;
      }
      output += '\n';
    }
    
    // Warnings
    if (result.warnings.length > 0) {
      output += `## Performance Warnings\n\n`;
      for (const warning of result.warnings) {
        if (warning.category === 'performance') {
          output += `⚠️ Line ${warning.line}: ${warning.message}\n`;
          if (warning.suggestion) {
            output += `   💡 ${warning.suggestion}\n`;
          }
          output += '\n';
        }
      }
    }
    
    return output;
  }
}