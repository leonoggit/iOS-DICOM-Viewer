import * as fs from 'fs-extra';
import * as path from 'path';
import { execSync } from 'child_process';
import glob from 'fast-glob';

export interface SwiftCodeIssue {
  type: 'error' | 'warning' | 'info' | 'style';
  category: string;
  message: string;
  file: string;
  line?: number;
  column?: number;
  suggestion?: string;
  severity: 'high' | 'medium' | 'low';
}

export interface SwiftCodeAnalysisResult {
  filePath: string;
  issues: SwiftCodeIssue[];
  syntaxValid: boolean;
  compilationSuccess: boolean;
  metrics: CodeMetrics;
}

export interface CodeMetrics {
  linesOfCode: number;
  numberOfClasses: number;
  numberOfStructs: number;
  numberOfEnums: number;
  numberOfFunctions: number;
  numberOfProperties: number;
  cyclomaticComplexity: number;
  maintainabilityIndex: number;
}

export class SwiftCodeAnalyzer {
  async analyzeCode(filePath: string, options: {
    checkSyntax?: boolean;
    checkStyle?: boolean;
    checkPerformance?: boolean;
  } = {}): Promise<any> {
    try {
      if (!await fs.pathExists(filePath)) {
        throw new Error(`File or directory does not exist: ${filePath}`);
      }

      const stats = await fs.stat(filePath);
      const files = stats.isDirectory() 
        ? await glob('**/*.swift', { cwd: filePath, absolute: true })
        : [filePath];

      if (files.length === 0) {
        throw new Error('No Swift files found');
      }

      const results: SwiftCodeAnalysisResult[] = [];
      
      for (const file of files) {
        const result = await this.analyzeSwiftFile(file, options);
        results.push(result);
      }

      return {
        content: [{
          type: 'text',
          text: this.formatAnalysisResults(results, filePath),
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to analyze Swift code: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async compileSwiftFile(filePath: string, target?: string, sdk: string = 'iphonesimulator'): Promise<any> {
    try {
      if (!await fs.pathExists(filePath)) {
        throw new Error(`Swift file does not exist: ${filePath}`);
      }

      const args = ['swiftc'];
      
      // Add SDK
      args.push('-sdk', await this.getSDKPath(sdk));
      
      // Add target if specified
      if (target) {
        args.push('-target', this.getSwiftTarget(target, sdk));
      }
      
      // Add the file
      args.push(filePath);
      
      // Compile to temporary location
      const tempDir = '/tmp';
      const outputName = path.basename(filePath, '.swift');
      args.push('-o', path.join(tempDir, outputName));

      try {
        const output = execSync(args.join(' '), { 
          encoding: 'utf8',
          timeout: 30000
        });
        
        return {
          content: [{
            type: 'text',
            text: `✅ Swift compilation successful!\n\nOutput:\n${output || 'No output (compilation successful)'}`,
          }],
        };
      } catch (error: any) {
        const errorOutput = error.stderr || error.stdout || error.message;
        return {
          content: [{
            type: 'text',
            text: `❌ Swift compilation failed!\n\nError:\n${errorOutput}`,
          }],
          isError: true,
        };
      }
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to compile Swift file: ${error}`,
        }],
        isError: true,
      };
    }
  }

  private async analyzeSwiftFile(filePath: string, options: {
    checkSyntax?: boolean;
    checkStyle?: boolean;
    checkPerformance?: boolean;
  }): Promise<SwiftCodeAnalysisResult> {
    const content = await fs.readFile(filePath, 'utf8');
    const issues: SwiftCodeIssue[] = [];
    
    const result: SwiftCodeAnalysisResult = {
      filePath,
      issues,
      syntaxValid: true,
      compilationSuccess: true,
      metrics: this.calculateMetrics(content)
    };

    // Check syntax if requested
    if (options.checkSyntax !== false) {
      await this.checkSyntax(filePath, content, issues);
    }

    // Check style if requested
    if (options.checkStyle !== false) {
      this.checkStyleGuidelines(filePath, content, issues);
    }

    // Check performance if requested
    if (options.checkPerformance !== false) {
      this.checkPerformanceIssues(filePath, content, issues);
    }

    // Additional checks for iOS/medical imaging
    this.checkiOSBestPractices(filePath, content, issues);
    this.checkMedicalImagingPatterns(filePath, content, issues);

    result.syntaxValid = !issues.some(i => i.type === 'error');
    
    return result;
  }

  private async checkSyntax(filePath: string, content: string, issues: SwiftCodeIssue[]): Promise<void> {
    try {
      // Try to compile the file to check syntax
      const args = [
        'swiftc',
        '-parse',
        filePath
      ];

      execSync(args.join(' '), { encoding: 'utf8', timeout: 10000 });
    } catch (error: any) {
      // Parse compiler errors
      const errorOutput = error.stderr || error.stdout || '';
      this.parseCompilerErrors(errorOutput, issues);
    }
  }

  private checkStyleGuidelines(filePath: string, content: string, issues: SwiftCodeIssue[]): void {
    const lines = content.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lineNumber = i + 1;
      
      // Check line length
      if (line.length > 120) {
        issues.push({
          type: 'style',
          category: 'Line Length',
          message: `Line exceeds 120 characters (${line.length} characters)`,
          file: filePath,
          line: lineNumber,
          suggestion: 'Break long lines into multiple lines',
          severity: 'low'
        });
      }
      
      // Check for trailing whitespace
      if (line.endsWith(' ') || line.endsWith('\t')) {
        issues.push({
          type: 'style',
          category: 'Whitespace',
          message: 'Line has trailing whitespace',
          file: filePath,
          line: lineNumber,
          suggestion: 'Remove trailing whitespace',
          severity: 'low'
        });
      }
      
      // Check for proper spacing around operators
      if (line.match(/\w[+\-*/=<>!&|]+\w/)) {
        issues.push({
          type: 'style',
          category: 'Spacing',
          message: 'Missing spaces around operators',
          file: filePath,
          line: lineNumber,
          suggestion: 'Add spaces around operators (e.g., a + b instead of a+b)',
          severity: 'low'
        });
      }
      
      // Check for proper naming conventions
      this.checkNamingConventions(line, lineNumber, filePath, issues);
    }
    
    // Check for missing documentation
    this.checkDocumentation(content, filePath, issues);
  }

  private checkPerformanceIssues(filePath: string, content: string, issues: SwiftCodeIssue[]): void {
    const lines = content.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lineNumber = i + 1;
      
      // Check for force unwrapping
      if (line.includes('!') && !line.includes('//') && !line.includes('!=')) {
        const forceUnwrapMatches = line.match(/\w+!/g);
        if (forceUnwrapMatches) {
          issues.push({
            type: 'warning',
            category: 'Force Unwrapping',
            message: 'Force unwrapping detected - potential crash risk',
            file: filePath,
            line: lineNumber,
            suggestion: 'Use optional binding (if let) or nil coalescing operator (??)',
            severity: 'high'
          });
        }
      }
      
      // Check for string concatenation in loops
      if (line.includes('for ') && content.substring(content.indexOf(line)).includes('+=')) {
        issues.push({
          type: 'warning',
          category: 'String Concatenation',
          message: 'String concatenation in loop detected',
          file: filePath,
          line: lineNumber,
          suggestion: 'Use StringBuilder or array.joined() for better performance',
          severity: 'medium'
        });
      }
      
      // Check for unnecessary retain cycles
      if (line.includes('self.') && (content.includes('{ [weak self]') || content.includes('{ [unowned self]'))) {
        // This is a simplified check - more sophisticated analysis would be needed
      }
      
      // Check for inefficient array operations
      if (line.includes('.count > 0')) {
        issues.push({
          type: 'info',
          category: 'Array Operations',
          message: 'Use !isEmpty instead of count > 0',
          file: filePath,
          line: lineNumber,
          suggestion: 'Replace .count > 0 with !.isEmpty for better performance',
          severity: 'low'
        });
      }
    }
  }

  private checkiOSBestPractices(filePath: string, content: string, issues: SwiftCodeIssue[]): void {
    // Check for proper iOS lifecycle methods
    if (content.includes('viewDidLoad') && !content.includes('super.viewDidLoad()')) {
      issues.push({
        type: 'warning',
        category: 'iOS Lifecycle',
        message: 'viewDidLoad override should call super.viewDidLoad()',
        file: filePath,
        suggestion: 'Add super.viewDidLoad() at the beginning of viewDidLoad',
        severity: 'high'
      });
    }
    
    // Check for proper memory management in UIKit
    if (content.includes('UIViewController') && content.includes('deinit')) {
      if (!content.includes('removeObserver') && content.includes('addObserver')) {
        issues.push({
          type: 'warning',
          category: 'Memory Management',
          message: 'Potential memory leak - NotificationCenter observers should be removed in deinit',
          file: filePath,
          suggestion: 'Remove NotificationCenter observers in deinit',
          severity: 'high'
        });
      }
    }
    
    // Check for main thread operations
    if (content.includes('DispatchQueue.main') && content.includes('sync')) {
      issues.push({
        type: 'warning',
        category: 'Threading',
        message: 'Synchronous dispatch to main queue can cause deadlocks',
        file: filePath,
        suggestion: 'Use DispatchQueue.main.async instead of sync',
        severity: 'high'
      });
    }
  }

  private checkMedicalImagingPatterns(filePath: string, content: string, issues: SwiftCodeIssue[]): void {
    // Check for DICOM-specific patterns
    if (content.includes('DICOM') || content.includes('DCMTK')) {
      // Check for proper DICOM error handling
      if (content.includes('dcmtk') && !content.includes('try')) {
        issues.push({
          type: 'info',
          category: 'DICOM',
          message: 'DCMTK operations should use proper error handling',
          file: filePath,
          suggestion: 'Use try-catch blocks for DCMTK operations',
          severity: 'medium'
        });
      }
      
      // Check for memory management in medical imaging
      if (content.includes('CVPixelBuffer') && !content.includes('CVPixelBufferRelease')) {
        issues.push({
          type: 'warning',
          category: 'Medical Imaging',
          message: 'CVPixelBuffer may not be properly released',
          file: filePath,
          suggestion: 'Ensure CVPixelBuffer is released with CVPixelBufferRelease',
          severity: 'medium'
        });
      }
    }
    
    // Check for Metal shader compilation
    if (content.includes('MTLDevice') || content.includes('Metal')) {
      if (content.includes('makeLibrary') && !content.includes('error')) {
        issues.push({
          type: 'info',
          category: 'Metal',
          message: 'Metal library creation should check for errors',
          file: filePath,
          suggestion: 'Handle potential errors when creating Metal libraries',
          severity: 'medium'
        });
      }
    }
  }

  private checkNamingConventions(line: string, lineNumber: number, filePath: string, issues: SwiftCodeIssue[]): void {
    // Check class names (should be PascalCase)
    const classMatch = line.match(/class\s+([a-z][a-zA-Z0-9]*)/);
    if (classMatch) {
      issues.push({
        type: 'style',
        category: 'Naming Convention',
        message: `Class name '${classMatch[1]}' should start with uppercase letter`,
        file: filePath,
        line: lineNumber,
        suggestion: 'Use PascalCase for class names',
        severity: 'medium'
      });
    }
    
    // Check variable names (should be camelCase)
    const varMatch = line.match(/var\s+([A-Z][a-zA-Z0-9]*)/);
    if (varMatch) {
      issues.push({
        type: 'style',
        category: 'Naming Convention',
        message: `Variable name '${varMatch[1]}' should start with lowercase letter`,
        file: filePath,
        line: lineNumber,
        suggestion: 'Use camelCase for variable names',
        severity: 'medium'
      });
    }
  }

  private checkDocumentation(content: string, filePath: string, issues: SwiftCodeIssue[]): void {
    const publicClassMatches = content.match(/public class \w+/g);
    const publicFuncMatches = content.match(/public func \w+/g);
    
    const totalPublicItems = (publicClassMatches?.length || 0) + (publicFuncMatches?.length || 0);
    const docCommentMatches = content.match(/\/\*\*[\s\S]*?\*\//g);
    const docCommentCount = docCommentMatches?.length || 0;
    
    if (totalPublicItems > 0 && docCommentCount < totalPublicItems * 0.5) {
      issues.push({
        type: 'info',
        category: 'Documentation',
        message: 'Low documentation coverage for public APIs',
        file: filePath,
        suggestion: 'Add documentation comments for public classes and methods',
        severity: 'medium'
      });
    }
  }

  private calculateMetrics(content: string): CodeMetrics {
    const lines = content.split('\n');
    
    return {
      linesOfCode: lines.filter(line => line.trim().length > 0 && !line.trim().startsWith('//')).length,
      numberOfClasses: (content.match(/class\s+\w+/g) || []).length,
      numberOfStructs: (content.match(/struct\s+\w+/g) || []).length,
      numberOfEnums: (content.match(/enum\s+\w+/g) || []).length,
      numberOfFunctions: (content.match(/func\s+\w+/g) || []).length,
      numberOfProperties: (content.match(/(var|let)\s+\w+/g) || []).length,
      cyclomaticComplexity: this.calculateCyclomaticComplexity(content),
      maintainabilityIndex: this.calculateMaintainabilityIndex(content)
    };
  }

  private calculateCyclomaticComplexity(content: string): number {
    // Simple cyclomatic complexity calculation
    const patterns = [
      /if\s+/g,
      /else\s+if\s+/g,
      /while\s+/g,
      /for\s+/g,
      /switch\s+/g,
      /case\s+/g,
      /catch\s+/g,
      /&&/g,
      /\|\|/g
    ];
    
    let complexity = 1; // Base complexity
    
    for (const pattern of patterns) {
      const matches = content.match(pattern);
      if (matches) {
        complexity += matches.length;
      }
    }
    
    return complexity;
  }

  private calculateMaintainabilityIndex(content: string): number {
    // Simplified maintainability index calculation
    const loc = content.split('\n').length;
    const complexity = this.calculateCyclomaticComplexity(content);
    
    // Simplified formula (real calculation is more complex)
    const maintainabilityIndex = Math.max(0, (171 - 5.2 * Math.log(loc) - 0.23 * complexity) * 100 / 171);
    
    return Math.round(maintainabilityIndex);
  }

  private parseCompilerErrors(errorOutput: string, issues: SwiftCodeIssue[]): void {
    const lines = errorOutput.split('\n');
    
    for (const line of lines) {
      if (line.includes('error:') || line.includes('warning:')) {
        const match = line.match(/^(.+):(\d+):(\d+):\s*(error|warning):\s*(.+)$/);
        if (match) {
          const [, file, lineNum, column, type, message] = match;
          
          issues.push({
            type: type as 'error' | 'warning',
            category: 'Syntax',
            message,
            file: path.basename(file),
            line: parseInt(lineNum),
            column: parseInt(column),
            severity: type === 'error' ? 'high' : 'medium'
          });
        }
      }
    }
  }

  private async getSDKPath(sdk: string): Promise<string> {
    try {
      const output = execSync(`xcrun --show-sdk-path --sdk ${sdk}`, { encoding: 'utf8' });
      return output.trim();
    } catch (error) {
      throw new Error(`Failed to get SDK path for ${sdk}: ${error}`);
    }
  }

  private getSwiftTarget(target: string, sdk: string): string {
    const arch = sdk === 'iphonesimulator' ? 'x86_64' : 'arm64';
    const platform = sdk === 'iphonesimulator' ? 'ios-simulator' : 'ios';
    return `${arch}-apple-${platform}${target}`;
  }

  private formatAnalysisResults(results: SwiftCodeAnalysisResult[], basePath: string): string {
    let output = `# Swift Code Analysis Results\n\n`;
    
    if (results.length === 1) {
      output += `**File:** ${path.relative(process.cwd(), results[0].filePath)}\n\n`;
    } else {
      output += `**Analyzed ${results.length} Swift files** in ${path.relative(process.cwd(), basePath)}\n\n`;
    }
    
    // Summary statistics
    const totalIssues = results.reduce((sum, r) => sum + r.issues.length, 0);
    const totalErrors = results.reduce((sum, r) => sum + r.issues.filter(i => i.type === 'error').length, 0);
    const totalWarnings = results.reduce((sum, r) => sum + r.issues.filter(i => i.type === 'warning').length, 0);
    const totalStyleIssues = results.reduce((sum, r) => sum + r.issues.filter(i => i.type === 'style').length, 0);
    
    output += `## Summary\n\n`;
    output += `- **Total Issues:** ${totalIssues}\n`;
    output += `- **Errors:** ${totalErrors}\n`;
    output += `- **Warnings:** ${totalWarnings}\n`;
    output += `- **Style Issues:** ${totalStyleIssues}\n`;
    output += `- **Files with Issues:** ${results.filter(r => r.issues.length > 0).length}/${results.length}\n\n`;
    
    // Code metrics summary
    if (results.length === 1) {
      const metrics = results[0].metrics;
      output += `## Code Metrics\n\n`;
      output += `- **Lines of Code:** ${metrics.linesOfCode}\n`;
      output += `- **Classes:** ${metrics.numberOfClasses}\n`;
      output += `- **Structs:** ${metrics.numberOfStructs}\n`;
      output += `- **Enums:** ${metrics.numberOfEnums}\n`;
      output += `- **Functions:** ${metrics.numberOfFunctions}\n`;
      output += `- **Properties:** ${metrics.numberOfProperties}\n`;
      output += `- **Cyclomatic Complexity:** ${metrics.cyclomaticComplexity}\n`;
      output += `- **Maintainability Index:** ${metrics.maintainabilityIndex}%\n\n`;
    }
    
    // Detailed issues
    if (totalIssues > 0) {
      output += `## Detailed Issues\n\n`;
      
      for (const result of results) {
        if (result.issues.length === 0) continue;
        
        if (results.length > 1) {
          output += `### ${path.relative(process.cwd(), result.filePath)}\n\n`;
        }
        
        const errors = result.issues.filter(i => i.type === 'error');
        const warnings = result.issues.filter(i => i.type === 'warning');
        const styleIssues = result.issues.filter(i => i.type === 'style');
        const infoIssues = result.issues.filter(i => i.type === 'info');
        
        if (errors.length > 0) {
          output += `#### Errors (${errors.length})\n\n`;
          for (const issue of errors) {
            output += `❌ **${issue.category}** `;
            if (issue.line) output += `(Line ${issue.line})`;
            output += `\n   ${issue.message}\n`;
            if (issue.suggestion) {
              output += `   💡 *${issue.suggestion}*\n`;
            }
            output += '\n';
          }
        }
        
        if (warnings.length > 0) {
          output += `#### Warnings (${warnings.length})\n\n`;
          for (const issue of warnings) {
            output += `⚠️ **${issue.category}** `;
            if (issue.line) output += `(Line ${issue.line})`;
            output += `\n   ${issue.message}\n`;
            if (issue.suggestion) {
              output += `   💡 *${issue.suggestion}*\n`;
            }
            output += '\n';
          }
        }
        
        if (styleIssues.length > 0) {
          output += `#### Style Issues (${styleIssues.length})\n\n`;
          for (const issue of styleIssues) {
            output += `🎨 **${issue.category}** `;
            if (issue.line) output += `(Line ${issue.line})`;
            output += `\n   ${issue.message}\n`;
            if (issue.suggestion) {
              output += `   💡 *${issue.suggestion}*\n`;
            }
            output += '\n';
          }
        }
        
        if (infoIssues.length > 0) {
          output += `#### Recommendations (${infoIssues.length})\n\n`;
          for (const issue of infoIssues) {
            output += `ℹ️ **${issue.category}** `;
            if (issue.line) output += `(Line ${issue.line})`;
            output += `\n   ${issue.message}\n`;
            if (issue.suggestion) {
              output += `   💡 *${issue.suggestion}*\n`;
            }
            output += '\n';
          }
        }
      }
    } else {
      output += '✅ No issues found in the analyzed Swift code!\n\n';
    }
    
    return output;
  }
}