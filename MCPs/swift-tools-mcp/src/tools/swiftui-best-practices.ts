import * as fs from 'fs-extra';
import * as path from 'path';
import glob from 'fast-glob';

export interface BestPracticeIssue {
  type: 'performance' | 'accessibility' | 'modernization' | 'architecture' | 'memory';
  severity: 'critical' | 'high' | 'medium' | 'low';
  file: string;
  line?: number;
  title: string;
  description: string;
  solution: string;
  codeExample?: string;
  learnMore?: string;
}

export interface BestPracticeAnalysis {
  framework: 'SwiftUI' | 'UIKit' | 'Mixed';
  totalFiles: number;
  issues: BestPracticeIssue[];
  modernizationOpportunities: ModernizationSuggestion[];
  performanceOptimizations: PerformanceOptimization[];
  accessibilityScore: number;
}

export interface ModernizationSuggestion {
  category: 'SwiftUI Migration' | 'iOS Version Update' | 'Framework Adoption';
  description: string;
  benefit: string;
  effort: 'low' | 'medium' | 'high';
  implementation: string;
}

export interface PerformanceOptimization {
  area: 'rendering' | 'data-binding' | 'navigation' | 'memory' | 'networking';
  issue: string;
  solution: string;
  impact: 'high' | 'medium' | 'low';
}

export class SwiftUIBestPractices {
  async checkSwiftUI(filePath: string, options: {
    checkPerformance?: boolean;
    checkAccessibility?: boolean;
  } = {}): Promise<any> {
    try {
      if (!await fs.pathExists(filePath)) {
        throw new Error(`File or directory does not exist: ${filePath}`);
      }

      const stats = await fs.stat(filePath);
      const files = stats.isDirectory() 
        ? await glob(['**/*.swift'], { cwd: filePath, absolute: true })
        : [filePath];

      const swiftUIFiles = await this.filterSwiftUIFiles(files);
      
      if (swiftUIFiles.length === 0) {
        throw new Error('No SwiftUI files found');
      }

      const analysis = await this.analyzeSwiftUIFiles(swiftUIFiles, options);

      return {
        content: [{
          type: 'text',
          text: this.formatSwiftUIAnalysis(analysis, filePath),
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to analyze SwiftUI code: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async checkUIKit(filePath: string, options: {
    suggestSwiftUI?: boolean;
    checkMemoryManagement?: boolean;
  } = {}): Promise<any> {
    try {
      if (!await fs.pathExists(filePath)) {
        throw new Error(`File or directory does not exist: ${filePath}`);
      }

      const stats = await fs.stat(filePath);
      const files = stats.isDirectory() 
        ? await glob('**/*.swift', { cwd: filePath, absolute: true })
        : [filePath];

      const uikitFiles = await this.filterUIKitFiles(files);
      
      if (uikitFiles.length === 0) {
        throw new Error('No UIKit files found');
      }

      const analysis = await this.analyzeUIKitFiles(uikitFiles, options);

      return {
        content: [{
          type: 'text',
          text: this.formatUIKitAnalysis(analysis, filePath),
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to analyze UIKit code: ${error}`,
        }],
        isError: true,
      };
    }
  }

  private async filterSwiftUIFiles(files: string[]): Promise<string[]> {
    const swiftUIFiles: string[] = [];
    
    for (const file of files) {
      try {
        const content = await fs.readFile(file, 'utf8');
        if (content.includes('import SwiftUI') || 
            content.includes('View') ||
            content.includes('@State') ||
            content.includes('@Binding') ||
            content.includes('@ObservableObject')) {
          swiftUIFiles.push(file);
        }
      } catch (error) {
        // Skip files that can't be read
      }
    }
    
    return swiftUIFiles;
  }

  private async filterUIKitFiles(files: string[]): Promise<string[]> {
    const uikitFiles: string[] = [];
    
    for (const file of files) {
      try {
        const content = await fs.readFile(file, 'utf8');
        if (content.includes('import UIKit') || 
            content.includes('UIViewController') ||
            content.includes('UIView') ||
            content.includes('UITableView') ||
            content.includes('UICollectionView')) {
          uikitFiles.push(file);
        }
      } catch (error) {
        // Skip files that can't be read
      }
    }
    
    return uikitFiles;
  }

  private async analyzeSwiftUIFiles(files: string[], options: any): Promise<BestPracticeAnalysis> {
    const analysis: BestPracticeAnalysis = {
      framework: 'SwiftUI',
      totalFiles: files.length,
      issues: [],
      modernizationOpportunities: [],
      performanceOptimizations: [],
      accessibilityScore: 100
    };

    for (const file of files) {
      const content = await fs.readFile(file, 'utf8');
      const relativePath = path.relative(process.cwd(), file);
      
      // Check SwiftUI-specific best practices
      this.checkSwiftUIPerformance(content, relativePath, analysis);
      this.checkSwiftUIAccessibility(content, relativePath, analysis);
      this.checkSwiftUIArchitecture(content, relativePath, analysis);
      this.checkSwiftUIModernization(content, relativePath, analysis);
      this.checkMedicalImagingSwiftUI(content, relativePath, analysis);
    }

    // Calculate accessibility score
    this.calculateAccessibilityScore(analysis);

    return analysis;
  }

  private async analyzeUIKitFiles(files: string[], options: any): Promise<BestPracticeAnalysis> {
    const analysis: BestPracticeAnalysis = {
      framework: 'UIKit',
      totalFiles: files.length,
      issues: [],
      modernizationOpportunities: [],
      performanceOptimizations: [],
      accessibilityScore: 85 // UIKit typically starts with lower accessibility score
    };

    for (const file of files) {
      const content = await fs.readFile(file, 'utf8');
      const relativePath = path.relative(process.cwd(), file);
      
      // Check UIKit-specific best practices
      this.checkUIKitPerformance(content, relativePath, analysis);
      this.checkUIKitMemoryManagement(content, relativePath, analysis);
      this.checkUIKitModernization(content, relativePath, analysis);
      this.checkUIKitAccessibility(content, relativePath, analysis);
      
      if (options.suggestSwiftUI !== false) {
        this.suggestSwiftUIMigration(content, relativePath, analysis);
      }
    }

    return analysis;
  }

  private checkSwiftUIPerformance(content: string, file: string, analysis: BestPracticeAnalysis): void {
    const lines = content.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lineNumber = i + 1;
      
      // Check for @State in loops or computed properties
      if (line.includes('@State') && (content.includes('ForEach') || content.includes('List'))) {
        analysis.issues.push({
          type: 'performance',
          severity: 'medium',
          file,
          line: lineNumber,
          title: 'State in collection views',
          description: '@State variables in ForEach or List can cause performance issues',
          solution: 'Use @StateObject or pass state from parent view',
          codeExample: `@StateObject private var viewModel = ItemViewModel()\n// instead of @State in ForEach`
        });
      }
      
      // Check for unnecessary body computations
      if (line.includes('var body: some View') && content.includes('print(')) {
        analysis.issues.push({
          type: 'performance',
          severity: 'medium',
          file,
          line: lineNumber,
          title: 'Debug code in body',
          description: 'Print statements in view body affect performance',
          solution: 'Remove debug print statements or use proper logging',
          codeExample: `// Remove: print("View updated")\n// Use: os_log or conditional compilation`
        });
      }
      
      // Check for complex computations in body
      if (line.includes('var body') && content.match(/\.(map|filter|reduce|sorted)\(/g)) {
        analysis.issues.push({
          type: 'performance',
          severity: 'high',
          file,
          line: lineNumber,
          title: 'Complex operations in view body',
          description: 'Heavy computations in view body cause UI lag',
          solution: 'Move computations to computed properties or view model',
          codeExample: `private var sortedItems: [Item] {\n    items.sorted { $0.name < $1.name }\n}`
        });
      }
    }
  }

  private checkSwiftUIAccessibility(content: string, file: string, analysis: BestPracticeAnalysis): void {
    const lines = content.split('\n');
    let accessibilityModifiers = 0;
    let interactiveElements = 0;
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lineNumber = i + 1;
      
      // Count interactive elements
      if (line.includes('Button') || line.includes('Toggle') || line.includes('Slider')) {
        interactiveElements++;
      }
      
      // Count accessibility modifiers
      if (line.includes('.accessibilityLabel') || 
          line.includes('.accessibilityHint') ||
          line.includes('.accessibilityValue')) {
        accessibilityModifiers++;
      }
      
      // Check for missing accessibility labels
      if (line.includes('Button') && !content.includes('.accessibilityLabel')) {
        analysis.issues.push({
          type: 'accessibility',
          severity: 'high',
          file,
          line: lineNumber,
          title: 'Missing accessibility label',
          description: 'Button without accessibility label is not accessible to VoiceOver users',
          solution: 'Add .accessibilityLabel modifier',
          codeExample: `Button("Sign In") { }\n    .accessibilityLabel("Sign in to your account")`
        });
      }
      
      // Check for images without accessibility
      if (line.includes('Image(') && !line.includes('decorative') && !content.includes('.accessibilityLabel')) {
        analysis.issues.push({
          type: 'accessibility',
          severity: 'medium',
          file,
          line: lineNumber,
          title: 'Image without accessibility',
          description: 'Images should have accessibility labels or be marked as decorative',
          solution: 'Add accessibility label or mark as decorative',
          codeExample: `Image("icon")\n    .accessibilityLabel("Settings icon")\n// OR\nImage(decorative: "background")`
        });
      }
    }
    
    // Calculate accessibility coverage for this file
    if (interactiveElements > 0) {
      const coverage = (accessibilityModifiers / interactiveElements) * 100;
      if (coverage < 50) {
        analysis.issues.push({
          type: 'accessibility',
          severity: 'high',
          file,
          title: 'Low accessibility coverage',
          description: `Only ${Math.round(coverage)}% of interactive elements have accessibility modifiers`,
          solution: 'Add accessibility labels, hints, and values to interactive elements',
          learnMore: 'https://developer.apple.com/accessibility/ios/'
        });
      }
    }
  }

  private checkSwiftUIArchitecture(content: string, file: string, analysis: BestPracticeAnalysis): void {
    const lines = content.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lineNumber = i + 1;
      
      // Check for massive view bodies
      if (line.includes('var body: some View')) {
        const bodyLines = this.countBodyLines(content, i);
        if (bodyLines > 50) {
          analysis.issues.push({
            type: 'architecture',
            severity: 'medium',
            file,
            line: lineNumber,
            title: 'View body too large',
            description: `View body has ${bodyLines} lines - consider breaking into smaller views`,
            solution: 'Extract subviews or use ViewBuilder functions',
            codeExample: `private var headerView: some View {\n    VStack { /* header content */ }\n}`
          });
        }
      }
      
      // Check for business logic in views
      if (line.includes('URLSession') || line.includes('CoreData') || line.includes('UserDefaults')) {
        analysis.issues.push({
          type: 'architecture',
          severity: 'high',
          file,
          line: lineNumber,
          title: 'Business logic in view',
          description: 'Views should not contain business logic or data access code',
          solution: 'Move business logic to view models or services',
          codeExample: `@StateObject private var viewModel = DataViewModel()\n// Handle data operations in view model`
        });
      }
      
      // Check for proper @Published usage
      if (line.includes('@Published') && !content.includes('ObservableObject')) {
        analysis.issues.push({
          type: 'architecture',
          severity: 'medium',
          file,
          line: lineNumber,
          title: '@Published without ObservableObject',
          description: '@Published should be used in ObservableObject classes',
          solution: 'Use @Published only in classes conforming to ObservableObject',
          codeExample: `class ViewModel: ObservableObject {\n    @Published var data: [Item] = []\n}`
        });
      }
    }
  }

  private checkSwiftUIModernization(content: string, file: string, analysis: BestPracticeAnalysis): void {
    // Check for iOS 14+ features usage
    if (!content.includes('@main') && content.includes('App')) {
      analysis.modernizationOpportunities.push({
        category: 'iOS Version Update',
        description: 'Use @main attribute for App struct (iOS 14+)',
        benefit: 'Cleaner app lifecycle and better SwiftUI integration',
        effort: 'low',
        implementation: 'Add @main attribute to your App struct'
      });
    }
    
    // Check for async/await usage
    if (content.includes('URLSession') && !content.includes('async')) {
      analysis.modernizationOpportunities.push({
        category: 'Framework Adoption',
        description: 'Adopt async/await for network operations (iOS 15+)',
        benefit: 'Better error handling and more readable asynchronous code',
        effort: 'medium',
        implementation: 'Replace completion handlers with async/await syntax'
      });
    }
    
    // Check for SwiftUI navigation
    if (content.includes('NavigationView') && !content.includes('NavigationStack')) {
      analysis.modernizationOpportunities.push({
        category: 'iOS Version Update',
        description: 'Use NavigationStack instead of NavigationView (iOS 16+)',
        benefit: 'Better navigation performance and programmatic control',
        effort: 'low',
        implementation: 'Replace NavigationView with NavigationStack'
      });
    }
  }

  private checkMedicalImagingSwiftUI(content: string, file: string, analysis: BestPracticeAnalysis): void {
    // Check for DICOM viewer specific patterns
    if (content.includes('DICOM') || content.includes('Medical')) {
      if (!content.includes('accessibilityLabel')) {
        analysis.issues.push({
          type: 'accessibility',
          severity: 'critical',
          file,
          title: 'Medical imaging accessibility',
          description: 'Medical imaging views must be accessible for healthcare professionals',
          solution: 'Add comprehensive accessibility labels and values for medical data',
          codeExample: `.accessibilityLabel("Patient scan showing chest X-ray")\n.accessibilityValue("Window level: \\(windowLevel), Window width: \\(windowWidth)")`
        });
      }
    }
    
    // Check for Metal integration
    if (content.includes('Metal') || content.includes('MTK')) {
      analysis.performanceOptimizations.push({
        area: 'rendering',
        issue: 'Metal view integration with SwiftUI',
        solution: 'Use UIViewRepresentable for Metal views and proper state management',
        impact: 'high'
      });
    }
    
    // Check for large data handling
    if (content.includes('Image') && content.includes('Data')) {
      analysis.performanceOptimizations.push({
        area: 'memory',
        issue: 'Large medical image data in SwiftUI',
        solution: 'Implement lazy loading and image caching for DICOM images',
        impact: 'high'
      });
    }
  }

  private checkUIKitPerformance(content: string, file: string, analysis: BestPracticeAnalysis): void {
    const lines = content.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lineNumber = i + 1;
      
      // Check for main thread blocking
      if (line.includes('DispatchQueue.main.sync')) {
        analysis.issues.push({
          type: 'performance',
          severity: 'critical',
          file,
          line: lineNumber,
          title: 'Main queue synchronous dispatch',
          description: 'Synchronous dispatch to main queue can cause deadlocks',
          solution: 'Use DispatchQueue.main.async instead',
          codeExample: `DispatchQueue.main.async {\n    // Update UI here\n}`
        });
      }
      
      // Check for expensive operations in main thread
      if (line.includes('viewDidLoad') && content.includes('URLSession')) {
        analysis.issues.push({
          type: 'performance',
          severity: 'high',
          file,
          line: lineNumber,
          title: 'Network operation in view lifecycle',
          description: 'Network operations should not be performed in view lifecycle methods',
          solution: 'Move network operations to background queue or view model',
          codeExample: `override func viewDidLoad() {\n    super.viewDidLoad()\n    viewModel.loadData() // Move network ops to view model\n}`
        });
      }
    }
  }

  private checkUIKitMemoryManagement(content: string, file: string, analysis: BestPracticeAnalysis): void {
    if (content.includes('UIViewController') && !content.includes('deinit')) {
      analysis.issues.push({
        type: 'memory',
        severity: 'medium',
        file,
        title: 'Missing deinit in view controller',
        description: 'View controllers should implement deinit for proper cleanup',
        solution: 'Add deinit method to clean up observers, timers, and other resources',
        codeExample: `deinit {\n    NotificationCenter.default.removeObserver(self)\n    timer?.invalidate()\n}`
      });
    }
  }

  private checkUIKitModernization(content: string, file: string, analysis: BestPracticeAnalysis): void {
    // Check for storyboard usage
    if (content.includes('storyboard') || content.includes('segue')) {
      analysis.modernizationOpportunities.push({
        category: 'SwiftUI Migration',
        description: 'Consider migrating from Storyboards to programmatic UI or SwiftUI',
        benefit: 'Better code review, version control, and testability',
        effort: 'high',
        implementation: 'Gradually replace storyboard scenes with programmatic views'
      });
    }
    
    // Check for delegation patterns that could use Combine
    if (content.includes('delegate') && content.includes('protocol')) {
      analysis.modernizationOpportunities.push({
        category: 'Framework Adoption',
        description: 'Consider using Combine publishers instead of delegation',
        benefit: 'More functional approach and better composition',
        effort: 'medium',
        implementation: 'Replace delegate protocols with Combine publishers'
      });
    }
  }

  private checkUIKitAccessibility(content: string, file: string, analysis: BestPracticeAnalysis): void {
    if (content.includes('UIButton') && !content.includes('accessibilityLabel')) {
      analysis.issues.push({
        type: 'accessibility',
        severity: 'high',
        file,
        title: 'UIButton without accessibility label',
        description: 'UIButtons should have proper accessibility labels',
        solution: 'Set accessibilityLabel property',
        codeExample: `button.accessibilityLabel = "Save document"`
      });
    }
  }

  private suggestSwiftUIMigration(content: string, file: string, analysis: BestPracticeAnalysis): void {
    // Simple view controllers that could be SwiftUI views
    if (content.includes('UIViewController') && 
        !content.includes('UITableView') &&
        !content.includes('UICollectionView') &&
        !content.includes('complex')) {
      analysis.modernizationOpportunities.push({
        category: 'SwiftUI Migration',
        description: `${path.basename(file)} could be migrated to SwiftUI`,
        benefit: 'Simpler code, better preview support, and modern declarative syntax',
        effort: 'medium',
        implementation: 'Rewrite as SwiftUI View with @State and @Binding properties'
      });
    }
  }

  private countBodyLines(content: string, startIndex: number): number {
    const lines = content.split('\n');
    let braceCount = 0;
    let lineCount = 0;
    let started = false;
    
    for (let i = startIndex; i < lines.length; i++) {
      const line = lines[i];
      
      if (line.includes('{')) {
        braceCount += (line.match(/\{/g) || []).length;
        started = true;
      }
      
      if (line.includes('}')) {
        braceCount -= (line.match(/\}/g) || []).length;
      }
      
      if (started) {
        lineCount++;
      }
      
      if (started && braceCount === 0) {
        break;
      }
    }
    
    return lineCount;
  }

  private calculateAccessibilityScore(analysis: BestPracticeAnalysis): void {
    const accessibilityIssues = analysis.issues.filter(i => i.type === 'accessibility');
    const totalIssues = analysis.issues.length;
    
    if (totalIssues === 0) {
      analysis.accessibilityScore = 100;
    } else {
      const score = Math.max(0, 100 - (accessibilityIssues.length / totalIssues) * 100);
      analysis.accessibilityScore = Math.round(score);
    }
  }

  private formatSwiftUIAnalysis(analysis: BestPracticeAnalysis, basePath: string): string {
    let output = `# SwiftUI Best Practices Analysis\n\n`;
    
    output += `**Analyzed:** ${analysis.totalFiles} SwiftUI files in ${path.relative(process.cwd(), basePath)}\n\n`;
    
    // Score overview
    const totalIssues = analysis.issues.length;
    const criticalIssues = analysis.issues.filter(i => i.severity === 'critical').length;
    const highIssues = analysis.issues.filter(i => i.severity === 'high').length;
    
    output += `## Overview\n\n`;
    output += `- **Total Issues:** ${totalIssues}\n`;
    output += `- **Critical:** ${criticalIssues}\n`;
    output += `- **High Priority:** ${highIssues}\n`;
    output += `- **Accessibility Score:** ${analysis.accessibilityScore}%\n`;
    output += `- **Modernization Opportunities:** ${analysis.modernizationOpportunities.length}\n\n`;
    
    // Health indicator
    const healthScore = Math.max(0, 100 - (criticalIssues * 20 + highIssues * 10));
    const healthIcon = healthScore >= 80 ? '🟢' : healthScore >= 60 ? '🟡' : '🔴';
    output += `${healthIcon} **SwiftUI Health Score:** ${healthScore}%\n\n`;
    
    // Issues by category
    if (analysis.issues.length > 0) {
      output += this.formatIssuesByCategory(analysis.issues);
    }
    
    // Performance optimizations
    if (analysis.performanceOptimizations.length > 0) {
      output += `## Performance Optimizations\n\n`;
      for (const opt of analysis.performanceOptimizations) {
        const impactIcon = opt.impact === 'high' ? '🔴' : opt.impact === 'medium' ? '🟡' : '🟢';
        output += `${impactIcon} **${opt.area.toUpperCase()}:** ${opt.issue}\n`;
        output += `   💡 ${opt.solution}\n\n`;
      }
    }
    
    // Modernization opportunities
    if (analysis.modernizationOpportunities.length > 0) {
      output += `## Modernization Opportunities\n\n`;
      
      const lowEffort = analysis.modernizationOpportunities.filter(o => o.effort === 'low');
      const mediumEffort = analysis.modernizationOpportunities.filter(o => o.effort === 'medium');
      const highEffort = analysis.modernizationOpportunities.filter(o => o.effort === 'high');
      
      if (lowEffort.length > 0) {
        output += `### Quick Wins (${lowEffort.length})\n\n`;
        for (const opp of lowEffort) {
          output += `🟢 **${opp.category}:** ${opp.description}\n`;
          output += `   📈 **Benefit:** ${opp.benefit}\n`;
          output += `   🛠️ **Implementation:** ${opp.implementation}\n\n`;
        }
      }
      
      if (mediumEffort.length > 0) {
        output += `### Medium Effort (${mediumEffort.length})\n\n`;
        for (const opp of mediumEffort) {
          output += `🟡 **${opp.category}:** ${opp.description}\n`;
          output += `   📈 **Benefit:** ${opp.benefit}\n`;
          output += `   🛠️ **Implementation:** ${opp.implementation}\n\n`;
        }
      }
      
      if (highEffort.length > 0) {
        output += `### Long-term Projects (${highEffort.length})\n\n`;
        for (const opp of highEffort) {
          output += `🔴 **${opp.category}:** ${opp.description}\n`;
          output += `   📈 **Benefit:** ${opp.benefit}\n`;
          output += `   🛠️ **Implementation:** ${opp.implementation}\n\n`;
        }
      }
    }
    
    if (totalIssues === 0) {
      output += `## 🎉 Excellent SwiftUI Code!\n\n`;
      output += `Your SwiftUI code follows best practices. Keep up the good work!\n\n`;
    }
    
    return output;
  }

  private formatUIKitAnalysis(analysis: BestPracticeAnalysis, basePath: string): string {
    let output = `# UIKit Best Practices Analysis\n\n`;
    
    output += `**Analyzed:** ${analysis.totalFiles} UIKit files in ${path.relative(process.cwd(), basePath)}\n\n`;
    
    // Similar formatting to SwiftUI but with UIKit-specific content
    const totalIssues = analysis.issues.length;
    const criticalIssues = analysis.issues.filter(i => i.severity === 'critical').length;
    
    output += `## Overview\n\n`;
    output += `- **Total Issues:** ${totalIssues}\n`;
    output += `- **Critical:** ${criticalIssues}\n`;
    output += `- **SwiftUI Migration Opportunities:** ${analysis.modernizationOpportunities.filter(o => o.category === 'SwiftUI Migration').length}\n\n`;
    
    if (analysis.issues.length > 0) {
      output += this.formatIssuesByCategory(analysis.issues);
    }
    
    if (analysis.modernizationOpportunities.length > 0) {
      output += `## Migration to SwiftUI\n\n`;
      const swiftUIMigrations = analysis.modernizationOpportunities.filter(o => o.category === 'SwiftUI Migration');
      for (const migration of swiftUIMigrations) {
        output += `🔄 ${migration.description}\n`;
        output += `   📈 **Benefit:** ${migration.benefit}\n`;
        output += `   🛠️ **Implementation:** ${migration.implementation}\n\n`;
      }
    }
    
    return output;
  }

  private formatIssuesByCategory(issues: BestPracticeIssue[]): string {
    let output = '';
    
    const categories = ['performance', 'accessibility', 'architecture', 'memory'] as const;
    
    for (const category of categories) {
      const categoryIssues = issues.filter(i => i.type === category);
      if (categoryIssues.length === 0) continue;
      
      output += `## ${category.charAt(0).toUpperCase() + category.slice(1)} Issues (${categoryIssues.length})\n\n`;
      
      const critical = categoryIssues.filter(i => i.severity === 'critical');
      const high = categoryIssues.filter(i => i.severity === 'high');
      const medium = categoryIssues.filter(i => i.severity === 'medium');
      const low = categoryIssues.filter(i => i.severity === 'low');
      
      for (const issueGroup of [critical, high, medium, low]) {
        for (const issue of issueGroup) {
          const severityIcon = issue.severity === 'critical' ? '🔴' : 
                             issue.severity === 'high' ? '🟠' : 
                             issue.severity === 'medium' ? '🟡' : '🟢';
          
          output += `${severityIcon} **${issue.title}** in ${issue.file}`;
          if (issue.line) output += ` (Line ${issue.line})`;
          output += `\n`;
          output += `   📝 ${issue.description}\n`;
          output += `   🔧 **Solution:** ${issue.solution}\n`;
          
          if (issue.codeExample) {
            output += `   💡 **Example:**\n\`\`\`swift\n${issue.codeExample}\n\`\`\`\n`;
          }
          
          if (issue.learnMore) {
            output += `   📚 [Learn more](${issue.learnMore})\n`;
          }
          
          output += '\n';
        }
      }
    }
    
    return output;
  }
}