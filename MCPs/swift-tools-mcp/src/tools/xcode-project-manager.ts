import * as fs from 'fs-extra';
import * as path from 'path';
import { execSync } from 'child_process';
import * as plist from 'plist';
import glob from 'fast-glob';

export interface XcodeProjectAnalysis {
  projectPath: string;
  projectName: string;
  targets: XcodeTarget[];
  schemes: XcodeScheme[];
  configurations: string[];
  buildSettings: Record<string, any>;
  dependencies: XcodeDependency[];
  issues: ProjectIssue[];
}

export interface XcodeTarget {
  name: string;
  type: string;
  platform: string;
  deploymentTarget: string;
  bundleIdentifier?: string;
  buildSettings: Record<string, any>;
  dependencies: string[];
  capabilities: string[];
}

export interface XcodeScheme {
  name: string;
  buildTargets: string[];
  testTargets: string[];
  archiveTarget?: string;
}

export interface XcodeDependency {
  name: string;
  type: 'framework' | 'library' | 'package' | 'cocoapod';
  version?: string;
  source?: string;
}

export interface ProjectIssue {
  type: 'warning' | 'error' | 'info';
  category: string;
  message: string;
  file?: string;
  line?: number;
  suggestion?: string;
}

export class XcodeProjectManager {
  async analyzeProject(projectPath: string, options: {
    analyzeTargets?: boolean;
    analyzeSchemes?: boolean;
  } = {}): Promise<any> {
    try {
      if (!await fs.pathExists(projectPath)) {
        throw new Error(`Project path does not exist: ${projectPath}`);
      }

      const isWorkspace = projectPath.endsWith('.xcworkspace');
      const projectName = path.basename(projectPath, isWorkspace ? '.xcworkspace' : '.xcodeproj');
      
      const analysis: XcodeProjectAnalysis = {
        projectPath,
        projectName,
        targets: [],
        schemes: [],
        configurations: [],
        buildSettings: {},
        dependencies: [],
        issues: []
      };

      // Get basic project information
      await this.analyzeProjectStructure(analysis);
      
      if (options.analyzeTargets !== false) {
        await this.analyzeTargets(analysis);
      }
      
      if (options.analyzeSchemes !== false) {
        await this.analyzeSchemes(analysis);
      }

      await this.analyzeDependencies(analysis);
      await this.validateProjectHealth(analysis);

      return {
        content: [{
          type: 'text',
          text: this.formatProjectAnalysis(analysis),
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to analyze Xcode project: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async validateBuildSettings(projectPath: string, target?: string, configuration?: string): Promise<any> {
    try {
      const issues: ProjectIssue[] = [];
      const buildSettings = await this.getBuildSettings(projectPath, target, configuration);

      // Validate deployment target
      this.validateDeploymentTarget(buildSettings, issues);
      
      // Validate code signing
      this.validateCodeSigning(buildSettings, issues);
      
      // Validate compiler settings
      this.validateCompilerSettings(buildSettings, issues);
      
      // Validate architecture settings
      this.validateArchitectureSettings(buildSettings, issues);

      // Validate Metal-specific settings (for DICOM viewer)
      this.validateMetalSettings(buildSettings, issues);

      return {
        content: [{
          type: 'text',
          text: this.formatBuildSettingsValidation(buildSettings, issues),
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to validate build settings: ${error}`,
        }],
        isError: true,
      };
    }
  }

  async getBuildSettings(projectPath: string, target?: string, configuration?: string): Promise<Record<string, any>> {
    try {
      const args = ['xcodebuild', '-showBuildSettings'];
      
      if (projectPath.endsWith('.xcworkspace')) {
        args.push('-workspace', projectPath);
      } else {
        args.push('-project', projectPath);
      }
      
      if (target) args.push('-target', target);
      if (configuration) args.push('-configuration', configuration);

      const output = execSync(args.join(' '), { encoding: 'utf8' });
      return this.parseBuildSettings(output);
    } catch (error) {
      throw new Error(`Failed to get build settings: ${error}`);
    }
  }

  async getProjectInfo(projectPath: string): Promise<any> {
    try {
      const isWorkspace = projectPath.endsWith('.xcworkspace');
      const projectName = path.basename(projectPath, isWorkspace ? '.xcworkspace' : '.xcodeproj');
      
      // Get list of targets
      const args = ['xcodebuild', '-list'];
      if (isWorkspace) {
        args.push('-workspace', projectPath);
      } else {
        args.push('-project', projectPath);
      }

      const output = execSync(args.join(' '), { encoding: 'utf8' });
      const info = this.parseProjectList(output);

      return {
        projectName,
        projectPath,
        type: isWorkspace ? 'workspace' : 'project',
        ...info
      };
    } catch (error) {
      throw new Error(`Failed to get project info: ${error}`);
    }
  }

  private async analyzeProjectStructure(analysis: XcodeProjectAnalysis): Promise<void> {
    // Get project configurations
    try {
      const projectInfo = await this.getProjectInfo(analysis.projectPath);
      analysis.configurations = projectInfo.configurations || [];
    } catch (error) {
      analysis.issues.push({
        type: 'warning',
        category: 'Project Structure',
        message: `Could not read project configurations: ${error}`
      });
    }
  }

  private async analyzeTargets(analysis: XcodeProjectAnalysis): Promise<void> {
    try {
      const projectInfo = await this.getProjectInfo(analysis.projectPath);
      
      for (const targetName of projectInfo.targets || []) {
        try {
          const buildSettings = await this.getBuildSettings(analysis.projectPath, targetName);
          
          const target: XcodeTarget = {
            name: targetName,
            type: this.getTargetType(buildSettings),
            platform: buildSettings.PLATFORM_NAME || 'unknown',
            deploymentTarget: buildSettings.IPHONEOS_DEPLOYMENT_TARGET || 'unknown',
            bundleIdentifier: buildSettings.PRODUCT_BUNDLE_IDENTIFIER,
            buildSettings,
            dependencies: [],
            capabilities: []
          };
          
          analysis.targets.push(target);
        } catch (error) {
          analysis.issues.push({
            type: 'error',
            category: 'Target Analysis',
            message: `Failed to analyze target ${targetName}: ${error}`
          });
        }
      }
    } catch (error) {
      analysis.issues.push({
        type: 'error',
        category: 'Target Analysis',
        message: `Failed to analyze targets: ${error}`
      });
    }
  }

  private async analyzeSchemes(analysis: XcodeProjectAnalysis): Promise<void> {
    try {
      const projectInfo = await this.getProjectInfo(analysis.projectPath);
      
      for (const schemeName of projectInfo.schemes || []) {
        const scheme: XcodeScheme = {
          name: schemeName,
          buildTargets: [],
          testTargets: []
        };
        
        analysis.schemes.push(scheme);
      }
    } catch (error) {
      analysis.issues.push({
        type: 'warning',
        category: 'Scheme Analysis',
        message: `Failed to analyze schemes: ${error}`
      });
    }
  }

  private async analyzeDependencies(analysis: XcodeProjectAnalysis): Promise<void> {
    const projectDir = path.dirname(analysis.projectPath);
    
    // Check for CocoaPods
    const podfilePath = path.join(projectDir, 'Podfile');
    if (await fs.pathExists(podfilePath)) {
      try {
        const podfile = await fs.readFile(podfilePath, 'utf8');
        const pods = this.parsePodfile(podfile);
        analysis.dependencies.push(...pods);
      } catch (error) {
        analysis.issues.push({
          type: 'warning',
          category: 'Dependencies',
          message: `Failed to parse Podfile: ${error}`
        });
      }
    }

    // Check for Swift Package Manager
    const packagePath = path.join(projectDir, 'Package.swift');
    if (await fs.pathExists(packagePath)) {
      try {
        const packageSwift = await fs.readFile(packagePath, 'utf8');
        const packages = this.parsePackageSwift(packageSwift);
        analysis.dependencies.push(...packages);
      } catch (error) {
        analysis.issues.push({
          type: 'warning',
          category: 'Dependencies',
          message: `Failed to parse Package.swift: ${error}`
        });
      }
    }
  }

  private async validateProjectHealth(analysis: XcodeProjectAnalysis): Promise<void> {
    // Check for common issues
    this.checkDeploymentTargetConsistency(analysis);
    this.checkBundleIdentifierConsistency(analysis);
    this.checkCodeSigningConsistency(analysis);
    this.checkSwiftVersionConsistency(analysis);
  }

  private validateDeploymentTarget(buildSettings: Record<string, any>, issues: ProjectIssue[]): void {
    const deploymentTarget = buildSettings.IPHONEOS_DEPLOYMENT_TARGET;
    
    if (!deploymentTarget) {
      issues.push({
        type: 'warning',
        category: 'Deployment Target',
        message: 'No iOS deployment target specified',
        suggestion: 'Set IPHONEOS_DEPLOYMENT_TARGET to minimum supported iOS version'
      });
      return;
    }

    const version = parseFloat(deploymentTarget);
    if (version < 13.0) {
      issues.push({
        type: 'warning',
        category: 'Deployment Target',
        message: `iOS deployment target ${deploymentTarget} is quite old`,
        suggestion: 'Consider updating to iOS 13.0 or later for better features and performance'
      });
    }

    if (version > 17.0) {
      issues.push({
        type: 'info',
        category: 'Deployment Target',
        message: `iOS deployment target ${deploymentTarget} is very recent`,
        suggestion: 'Ensure this doesn\'t limit your app\'s compatibility unnecessarily'
      });
    }
  }

  private validateCodeSigning(buildSettings: Record<string, any>, issues: ProjectIssue[]): void {
    const codeSignIdentity = buildSettings.CODE_SIGN_IDENTITY;
    const developmentTeam = buildSettings.DEVELOPMENT_TEAM;
    
    if (!codeSignIdentity && !developmentTeam) {
      issues.push({
        type: 'warning',
        category: 'Code Signing',
        message: 'No code signing configuration found',
        suggestion: 'Configure code signing for distribution builds'
      });
    }

    if (buildSettings.CODE_SIGN_STYLE === 'Manual' && !buildSettings.PROVISIONING_PROFILE_SPECIFIER) {
      issues.push({
        type: 'warning',
        category: 'Code Signing',
        message: 'Manual code signing enabled but no provisioning profile specified',
        suggestion: 'Set PROVISIONING_PROFILE_SPECIFIER or use automatic code signing'
      });
    }
  }

  private validateCompilerSettings(buildSettings: Record<string, any>, issues: ProjectIssue[]): void {
    // Check Swift version
    const swiftVersion = buildSettings.SWIFT_VERSION;
    if (swiftVersion && parseFloat(swiftVersion) < 5.0) {
      issues.push({
        type: 'warning',
        category: 'Compiler',
        message: `Swift version ${swiftVersion} is outdated`,
        suggestion: 'Update to Swift 5.0 or later for better performance and features'
      });
    }

    // Check optimization settings
    if (buildSettings.SWIFT_OPTIMIZATION_LEVEL === '-Onone' && buildSettings.CONFIGURATION === 'Release') {
      issues.push({
        type: 'warning',
        category: 'Compiler',
        message: 'No optimization enabled for Release build',
        suggestion: 'Enable optimization (-O) for Release builds'
      });
    }

    // Check debug information
    if (buildSettings.DEBUG_INFORMATION_FORMAT === 'dwarf' && buildSettings.CONFIGURATION === 'Release') {
      issues.push({
        type: 'info',
        category: 'Compiler',
        message: 'Debug information included in Release build',
        suggestion: 'Consider using dwarf-with-dsym for Release builds'
      });
    }
  }

  private validateArchitectureSettings(buildSettings: Record<string, any>, issues: ProjectIssue[]): void {
    const validArchs = buildSettings.VALID_ARCHS;
    const archs = buildSettings.ARCHS;

    if (validArchs && validArchs.includes('armv7')) {
      issues.push({
        type: 'info',
        category: 'Architecture',
        message: '32-bit architecture (armv7) is supported',
        suggestion: 'Consider dropping 32-bit support if targeting iOS 11+ only'
      });
    }

    if (!archs || !archs.includes('arm64')) {
      issues.push({
        type: 'error',
        category: 'Architecture',
        message: 'arm64 architecture not supported',
        suggestion: 'Add arm64 architecture support for 64-bit devices'
      });
    }
  }

  private validateMetalSettings(buildSettings: Record<string, any>, issues: ProjectIssue[]): void {
    // Check Metal settings for DICOM viewer
    const metalEnabled = buildSettings.MTL_ENABLE_DEBUG_INFO;
    
    if (buildSettings.CONFIGURATION === 'Debug' && metalEnabled !== 'INCLUDE_SOURCE') {
      issues.push({
        type: 'info',
        category: 'Metal',
        message: 'Metal debug info not fully enabled for Debug builds',
        suggestion: 'Set MTL_ENABLE_DEBUG_INFO to INCLUDE_SOURCE for better Metal debugging'
      });
    }

    if (buildSettings.CONFIGURATION === 'Release' && metalEnabled !== 'NO') {
      issues.push({
        type: 'info',
        category: 'Metal',
        message: 'Metal debug info enabled in Release build',
        suggestion: 'Disable Metal debug info (MTL_ENABLE_DEBUG_INFO = NO) for Release builds'
      });
    }
  }

  private getTargetType(buildSettings: Record<string, any>): string {
    const productType = buildSettings.PRODUCT_TYPE;
    if (productType) {
      if (productType.includes('application')) return 'Application';
      if (productType.includes('framework')) return 'Framework';
      if (productType.includes('library')) return 'Library';
      if (productType.includes('bundle')) return 'Bundle';
      if (productType.includes('test')) return 'Test';
    }
    return 'Unknown';
  }

  private parseBuildSettings(output: string): Record<string, any> {
    const settings: Record<string, any> = {};
    const lines = output.split('\n');
    
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.includes(' = ')) {
        const [key, ...valueParts] = trimmed.split(' = ');
        const value = valueParts.join(' = ').trim();
        settings[key.trim()] = value;
      }
    }
    
    return settings;
  }

  private parseProjectList(output: string): any {
    const result: any = {};
    const lines = output.split('\n');
    let currentSection = '';
    
    for (const line of lines) {
      const trimmed = line.trim();
      
      if (trimmed.endsWith(':')) {
        currentSection = trimmed.slice(0, -1).toLowerCase();
        result[currentSection] = [];
      } else if (trimmed && currentSection) {
        result[currentSection].push(trimmed);
      }
    }
    
    return result;
  }

  private parsePodfile(content: string): XcodeDependency[] {
    const dependencies: XcodeDependency[] = [];
    const lines = content.split('\n');
    
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('pod ')) {
        const match = trimmed.match(/pod\s+['"]([^'"]+)['"](?:\s*,\s*['"]([^'"]+)['"])?/);
        if (match) {
          dependencies.push({
            name: match[1],
            type: 'cocoapod',
            version: match[2]
          });
        }
      }
    }
    
    return dependencies;
  }

  private parsePackageSwift(content: string): XcodeDependency[] {
    const dependencies: XcodeDependency[] = [];
    // Simple regex-based parsing for Package.swift dependencies
    const dependencyMatches = content.match(/\.package\([^)]+\)/g) || [];
    
    for (const match of dependencyMatches) {
      const urlMatch = match.match(/url:\s*"([^"]+)"/);
      const versionMatch = match.match(/from:\s*"([^"]+)"/);
      
      if (urlMatch) {
        const name = path.basename(urlMatch[1], '.git');
        dependencies.push({
          name,
          type: 'package',
          version: versionMatch?.[1],
          source: urlMatch[1]
        });
      }
    }
    
    return dependencies;
  }

  private checkDeploymentTargetConsistency(analysis: XcodeProjectAnalysis): void {
    const deploymentTargets = new Set(
      analysis.targets.map(t => t.deploymentTarget).filter(dt => dt !== 'unknown')
    );
    
    if (deploymentTargets.size > 1) {
      analysis.issues.push({
        type: 'warning',
        category: 'Consistency',
        message: `Inconsistent deployment targets: ${Array.from(deploymentTargets).join(', ')}`,
        suggestion: 'Use the same deployment target across all targets for consistency'
      });
    }
  }

  private checkBundleIdentifierConsistency(analysis: XcodeProjectAnalysis): void {
    const bundleIds = analysis.targets
      .map(t => t.bundleIdentifier)
      .filter(id => id && !id.includes('$('));
    
    const duplicates = bundleIds.filter((id, index) => bundleIds.indexOf(id) !== index);
    
    if (duplicates.length > 0) {
      analysis.issues.push({
        type: 'error',
        category: 'Bundle Identifier',
        message: `Duplicate bundle identifiers found: ${duplicates.join(', ')}`,
        suggestion: 'Ensure each target has a unique bundle identifier'
      });
    }
  }

  private checkCodeSigningConsistency(analysis: XcodeProjectAnalysis): void {
    const codeSignStyles = new Set(
      analysis.targets
        .map(t => t.buildSettings.CODE_SIGN_STYLE)
        .filter(style => style)
    );
    
    if (codeSignStyles.size > 1) {
      analysis.issues.push({
        type: 'warning',
        category: 'Code Signing',
        message: `Mixed code signing styles: ${Array.from(codeSignStyles).join(', ')}`,
        suggestion: 'Use consistent code signing style across all targets'
      });
    }
  }

  private checkSwiftVersionConsistency(analysis: XcodeProjectAnalysis): void {
    const swiftVersions = new Set(
      analysis.targets
        .map(t => t.buildSettings.SWIFT_VERSION)
        .filter(version => version)
    );
    
    if (swiftVersions.size > 1) {
      analysis.issues.push({
        type: 'warning',
        category: 'Swift Version',
        message: `Mixed Swift versions: ${Array.from(swiftVersions).join(', ')}`,
        suggestion: 'Use the same Swift version across all targets'
      });
    }
  }

  private formatProjectAnalysis(analysis: XcodeProjectAnalysis): string {
    let output = `# Xcode Project Analysis: ${analysis.projectName}\n\n`;
    
    output += `**Project Path:** ${analysis.projectPath}\n\n`;
    
    if (analysis.targets.length > 0) {
      output += `## Targets (${analysis.targets.length})\n\n`;
      for (const target of analysis.targets) {
        output += `### ${target.name}\n`;
        output += `- **Type:** ${target.type}\n`;
        output += `- **Platform:** ${target.platform}\n`;
        output += `- **Deployment Target:** ${target.deploymentTarget}\n`;
        if (target.bundleIdentifier) {
          output += `- **Bundle ID:** ${target.bundleIdentifier}\n`;
        }
        output += '\n';
      }
    }
    
    if (analysis.schemes.length > 0) {
      output += `## Schemes (${analysis.schemes.length})\n\n`;
      for (const scheme of analysis.schemes) {
        output += `- ${scheme.name}\n`;
      }
      output += '\n';
    }
    
    if (analysis.configurations.length > 0) {
      output += `## Build Configurations\n\n`;
      for (const config of analysis.configurations) {
        output += `- ${config}\n`;
      }
      output += '\n';
    }
    
    if (analysis.dependencies.length > 0) {
      output += `## Dependencies (${analysis.dependencies.length})\n\n`;
      for (const dep of analysis.dependencies) {
        output += `- **${dep.name}** (${dep.type})`;
        if (dep.version) output += ` - v${dep.version}`;
        output += '\n';
      }
      output += '\n';
    }
    
    if (analysis.issues.length > 0) {
      output += `## Issues Found (${analysis.issues.length})\n\n`;
      
      const errors = analysis.issues.filter(i => i.type === 'error');
      const warnings = analysis.issues.filter(i => i.type === 'warning');
      const info = analysis.issues.filter(i => i.type === 'info');
      
      if (errors.length > 0) {
        output += `### Errors (${errors.length})\n\n`;
        for (const issue of errors) {
          output += `❌ **${issue.category}:** ${issue.message}\n`;
          if (issue.suggestion) {
            output += `   💡 *${issue.suggestion}*\n`;
          }
          output += '\n';
        }
      }
      
      if (warnings.length > 0) {
        output += `### Warnings (${warnings.length})\n\n`;
        for (const issue of warnings) {
          output += `⚠️ **${issue.category}:** ${issue.message}\n`;
          if (issue.suggestion) {
            output += `   💡 *${issue.suggestion}*\n`;
          }
          output += '\n';
        }
      }
      
      if (info.length > 0) {
        output += `### Info (${info.length})\n\n`;
        for (const issue of info) {
          output += `ℹ️ **${issue.category}:** ${issue.message}\n`;
          if (issue.suggestion) {
            output += `   💡 *${issue.suggestion}*\n`;
          }
          output += '\n';
        }
      }
    } else {
      output += '✅ No issues found in project analysis.\n\n';
    }
    
    return output;
  }

  private formatBuildSettingsValidation(buildSettings: Record<string, any>, issues: ProjectIssue[]): string {
    let output = '# Build Settings Validation\n\n';
    
    // Key settings summary
    output += '## Key Build Settings\n\n';
    const keySettings = [
      'IPHONEOS_DEPLOYMENT_TARGET',
      'SWIFT_VERSION',
      'CODE_SIGN_STYLE',
      'DEVELOPMENT_TEAM',
      'PRODUCT_BUNDLE_IDENTIFIER',
      'ARCHS',
      'SWIFT_OPTIMIZATION_LEVEL'
    ];
    
    for (const setting of keySettings) {
      if (buildSettings[setting]) {
        output += `- **${setting}:** ${buildSettings[setting]}\n`;
      }
    }
    output += '\n';
    
    if (issues.length > 0) {
      output += `## Validation Results (${issues.length} issues)\n\n`;
      
      const errors = issues.filter(i => i.type === 'error');
      const warnings = issues.filter(i => i.type === 'warning');
      const info = issues.filter(i => i.type === 'info');
      
      if (errors.length > 0) {
        output += `### Errors (${errors.length})\n\n`;
        for (const issue of errors) {
          output += `❌ **${issue.category}:** ${issue.message}\n`;
          if (issue.suggestion) {
            output += `   💡 *${issue.suggestion}*\n`;
          }
          output += '\n';
        }
      }
      
      if (warnings.length > 0) {
        output += `### Warnings (${warnings.length})\n\n`;
        for (const issue of warnings) {
          output += `⚠️ **${issue.category}:** ${issue.message}\n`;
          if (issue.suggestion) {
            output += `   💡 *${issue.suggestion}*\n`;
          }
          output += '\n';
        }
      }
      
      if (info.length > 0) {
        output += `### Recommendations (${info.length})\n\n`;
        for (const issue of info) {
          output += `ℹ️ **${issue.category}:** ${issue.message}\n`;
          if (issue.suggestion) {
            output += `   💡 *${issue.suggestion}*\n`;
          }
          output += '\n';
        }
      }
    } else {
      output += '✅ All build settings validation passed.\n\n';
    }
    
    return output;
  }
}