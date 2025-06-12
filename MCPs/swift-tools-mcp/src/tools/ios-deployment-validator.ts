import * as fs from 'fs-extra';
import * as path from 'path';
import { execSync } from 'child_process';
import * as plist from 'plist';

export interface DeploymentValidationResult {
  isValid: boolean;
  issues: DeploymentIssue[];
  recommendations: DeploymentRecommendation[];
  infoPlist: InfoPlistAnalysis;
  capabilities: CapabilityAnalysis;
  certificates: CertificateStatus;
}

export interface DeploymentIssue {
  type: 'error' | 'warning' | 'info';
  category: string;
  message: string;
  impact: 'critical' | 'high' | 'medium' | 'low';
  solution?: string;
}

export interface DeploymentRecommendation {
  category: string;
  message: string;
  benefit: string;
  implementation: string;
}

export interface InfoPlistAnalysis {
  bundleId: string;
  version: string;
  buildNumber: string;
  minimumOSVersion: string;
  supportedDevices: string[];
  requiredCapabilities: string[];
  permissions: Permission[];
  urlSchemes: string[];
  backgroundModes: string[];
}

export interface Permission {
  key: string;
  description: string;
  required: boolean;
  privacy: 'low' | 'medium' | 'high';
}

export interface CapabilityAnalysis {
  entitlements: string[];
  sandboxEnabled: boolean;
  appGroups: string[];
  keychainGroups: string[];
  associatedDomains: string[];
  issues: string[];
}

export interface CertificateStatus {
  developmentCertificates: Certificate[];
  distributionCertificates: Certificate[];
  provisioningProfiles: ProvisioningProfile[];
  issues: string[];
}

export interface Certificate {
  name: string;
  team: string;
  expiryDate: Date;
  isValid: boolean;
}

export interface ProvisioningProfile {
  name: string;
  bundleId: string;
  team: string;
  expiryDate: Date;
  devices: string[];
  isValid: boolean;
  type: 'development' | 'adhoc' | 'appstore' | 'enterprise';
}

export class iOSDeploymentValidator {
  async validateDeployment(
    projectPath: string,
    targetVersion?: string,
    options: { validateCapabilities?: boolean } = {}
  ): Promise<any> {
    try {
      if (!await fs.pathExists(projectPath)) {
        throw new Error(`Project path does not exist: ${projectPath}`);
      }

      const result: DeploymentValidationResult = {
        isValid: true,
        issues: [],
        recommendations: [],
        infoPlist: await this.analyzeInfoPlist(projectPath),
        capabilities: await this.analyzeCapabilities(projectPath),
        certificates: await this.analyzeCertificates()
      };

      // Validate deployment target
      await this.validateDeploymentTarget(result, targetVersion);
      
      // Validate Info.plist
      await this.validateInfoPlist(result);
      
      // Validate capabilities if requested
      if (options.validateCapabilities !== false) {
        await this.validateCapabilities(result);
      }
      
      // Validate certificates and provisioning
      await this.validateCertificatesAndProvisioning(result);
      
      // Generate recommendations
      this.generateRecommendations(result);
      
      // Determine overall validity
      result.isValid = !result.issues.some(i => i.type === 'error');

      return {
        content: [{
          type: 'text',
          text: this.formatValidationResults(result),
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to validate iOS deployment: ${error}`,
        }],
        isError: true,
      };
    }
  }

  private async analyzeInfoPlist(projectPath: string): Promise<InfoPlistAnalysis> {
    try {
      // Find Info.plist file
      const infoPlistPath = await this.findInfoPlist(projectPath);
      if (!infoPlistPath) {
        throw new Error('Info.plist not found');
      }

      const plistContent = await fs.readFile(infoPlistPath, 'utf8');
      const plistData = plist.parse(plistContent) as any;

      return {
        bundleId: plistData.CFBundleIdentifier || '',
        version: plistData.CFBundleShortVersionString || '',
        buildNumber: plistData.CFBundleVersion || '',
        minimumOSVersion: plistData.LSMinimumSystemVersion || plistData.MinimumOSVersion || '',
        supportedDevices: this.extractSupportedDevices(plistData),
        requiredCapabilities: plistData.UIRequiredDeviceCapabilities || [],
        permissions: this.extractPermissions(plistData),
        urlSchemes: this.extractURLSchemes(plistData),
        backgroundModes: plistData.UIBackgroundModes || []
      };
    } catch (error) {
      throw new Error(`Failed to analyze Info.plist: ${error}`);
    }
  }

  private async analyzeCapabilities(projectPath: string): Promise<CapabilityAnalysis> {
    try {
      const entitlementsPath = await this.findEntitlementsFile(projectPath);
      let entitlements: string[] = [];
      
      if (entitlementsPath) {
        const entitlementsContent = await fs.readFile(entitlementsPath, 'utf8');
        const entitlementsData = plist.parse(entitlementsContent) as any;
        entitlements = Object.keys(entitlementsData);
      }

      return {
        entitlements,
        sandboxEnabled: entitlements.includes('com.apple.security.app-sandbox'),
        appGroups: this.extractAppGroups(entitlements),
        keychainGroups: this.extractKeychainGroups(entitlements),
        associatedDomains: this.extractAssociatedDomains(entitlements),
        issues: []
      };
    } catch (error) {
      return {
        entitlements: [],
        sandboxEnabled: false,
        appGroups: [],
        keychainGroups: [],
        associatedDomains: [],
        issues: [`Failed to analyze capabilities: ${error}`]
      };
    }
  }

  private async analyzeCertificates(): Promise<CertificateStatus> {
    try {
      const result: CertificateStatus = {
        developmentCertificates: [],
        distributionCertificates: [],
        provisioningProfiles: [],
        issues: []
      };

      try {
        // Get development certificates
        const devCertsOutput = execSync('security find-identity -v -p codesigning', { encoding: 'utf8' });
        result.developmentCertificates = this.parseCertificates(devCertsOutput, 'development');
      } catch (error) {
        result.issues.push('Failed to retrieve development certificates');
      }

      try {
        // Get provisioning profiles
        const profilesPath = path.join(process.env.HOME || '', 'Library/MobileDevice/Provisioning Profiles');
        if (await fs.pathExists(profilesPath)) {
          const profiles = await fs.readdir(profilesPath);
          for (const profile of profiles.filter(p => p.endsWith('.mobileprovision'))) {
            try {
              const profilePath = path.join(profilesPath, profile);
              const profileInfo = await this.parseProvisioningProfile(profilePath);
              if (profileInfo) {
                result.provisioningProfiles.push(profileInfo);
              }
            } catch (error) {
              // Skip invalid profiles
            }
          }
        }
      } catch (error) {
        result.issues.push('Failed to retrieve provisioning profiles');
      }

      return result;
    } catch (error) {
      return {
        developmentCertificates: [],
        distributionCertificates: [],
        provisioningProfiles: [],
        issues: [`Certificate analysis failed: ${error}`]
      };
    }
  }

  private async validateDeploymentTarget(result: DeploymentValidationResult, targetVersion?: string): Promise<void> {
    const minimumVersion = result.infoPlist.minimumOSVersion;
    
    if (!minimumVersion) {
      result.issues.push({
        type: 'error',
        category: 'Deployment Target',
        message: 'No minimum iOS version specified',
        impact: 'critical',
        solution: 'Set LSMinimumSystemVersion or MinimumOSVersion in Info.plist'
      });
      return;
    }

    const version = parseFloat(minimumVersion);
    
    if (version < 12.0) {
      result.issues.push({
        type: 'warning',
        category: 'Deployment Target',
        message: `iOS ${minimumVersion} is very old and limits available features`,
        impact: 'medium',
        solution: 'Consider updating minimum iOS version to 13.0 or later'
      });
    }

    if (targetVersion) {
      const targetVer = parseFloat(targetVersion);
      if (version < targetVer) {
        result.issues.push({
          type: 'error',
          category: 'Deployment Target',
          message: `Minimum iOS version (${minimumVersion}) is lower than target version (${targetVersion})`,
          impact: 'high',
          solution: `Update minimum iOS version to ${targetVersion} or adjust target`
        });
      }
    }

    // Check for iOS version compatibility with modern features
    if (version < 13.0) {
      result.issues.push({
        type: 'info',
        category: 'Feature Compatibility',
        message: 'Some modern iOS features may not be available',
        impact: 'low',
        solution: 'Consider using availability checks for newer features'
      });
    }
  }

  private async validateInfoPlist(result: DeploymentValidationResult): Promise<void> {
    const plist = result.infoPlist;
    
    // Validate bundle identifier
    if (!plist.bundleId) {
      result.issues.push({
        type: 'error',
        category: 'Bundle Identifier',
        message: 'Bundle identifier is missing',
        impact: 'critical',
        solution: 'Set CFBundleIdentifier in Info.plist'
      });
    } else if (!this.isValidBundleId(plist.bundleId)) {
      result.issues.push({
        type: 'error',
        category: 'Bundle Identifier',
        message: 'Bundle identifier format is invalid',
        impact: 'critical',
        solution: 'Use reverse domain notation (e.g., com.company.appname)'
      });
    }

    // Validate version information
    if (!plist.version) {
      result.issues.push({
        type: 'error',
        category: 'Version',
        message: 'App version is missing',
        impact: 'critical',
        solution: 'Set CFBundleShortVersionString in Info.plist'
      });
    }

    if (!plist.buildNumber) {
      result.issues.push({
        type: 'error',
        category: 'Build Number',
        message: 'Build number is missing',
        impact: 'critical',
        solution: 'Set CFBundleVersion in Info.plist'
      });
    }

    // Validate privacy permissions
    this.validatePrivacyPermissions(result);
    
    // Validate URL schemes
    this.validateURLSchemes(result);
  }

  private validatePrivacyPermissions(result: DeploymentValidationResult): void {
    const sensitivePermissions = [
      'NSCameraUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSLocationWhenInUseUsageDescription',
      'NSLocationAlwaysAndWhenInUseUsageDescription',
      'NSPhotoLibraryUsageDescription',
      'NSContactsUsageDescription',
      'NSCalendarsUsageDescription',
      'NSRemindersUsageDescription',
      'NSMotionUsageDescription',
      'NSHealthUpdateUsageDescription',
      'NSHealthShareUsageDescription'
    ];

    for (const permission of result.infoPlist.permissions) {
      if (sensitivePermissions.includes(permission.key)) {
        if (!permission.description || permission.description.trim().length < 10) {
          result.issues.push({
            type: 'warning',
            category: 'Privacy',
            message: `Insufficient privacy description for ${permission.key}`,
            impact: 'medium',
            solution: 'Provide a clear, user-friendly explanation of why this permission is needed'
          });
        }
      }
    }
  }

  private validateURLSchemes(result: DeploymentValidationResult): void {
    if (result.infoPlist.urlSchemes.length > 0) {
      for (const scheme of result.infoPlist.urlSchemes) {
        if (scheme.length < 3 || !scheme.match(/^[a-zA-Z][a-zA-Z0-9+.-]*$/)) {
          result.issues.push({
            type: 'warning',
            category: 'URL Scheme',
            message: `URL scheme '${scheme}' may not be valid`,
            impact: 'low',
            solution: 'Use a unique, well-formed URL scheme'
          });
        }
      }
    }
  }

  private async validateCapabilities(result: DeploymentValidationResult): Promise<void> {
    const capabilities = result.capabilities;
    
    // Check for common capability issues
    if (capabilities.entitlements.includes('com.apple.developer.healthkit') && 
        !result.infoPlist.permissions.some(p => p.key.includes('Health'))) {
      result.issues.push({
        type: 'warning',
        category: 'Capabilities',
        message: 'HealthKit capability enabled but no health permissions in Info.plist',
        impact: 'medium',
        solution: 'Add health usage descriptions to Info.plist'
      });
    }

    // Validate app groups
    if (capabilities.appGroups.length > 0) {
      for (const group of capabilities.appGroups) {
        if (!group.startsWith('group.')) {
          result.issues.push({
            type: 'error',
            category: 'App Groups',
            message: `App group '${group}' should start with 'group.'`,
            impact: 'high',
            solution: 'Use proper app group naming convention'
          });
        }
      }
    }
  }

  private async validateCertificatesAndProvisioning(result: DeploymentValidationResult): Promise<void> {
    const certs = result.certificates;
    
    // Check for expired certificates
    const now = new Date();
    
    for (const cert of certs.developmentCertificates) {
      if (cert.expiryDate < now) {
        result.issues.push({
          type: 'error',
          category: 'Certificates',
          message: `Development certificate '${cert.name}' has expired`,
          impact: 'high',
          solution: 'Renew or create a new development certificate'
        });
      } else if (cert.expiryDate.getTime() - now.getTime() < 30 * 24 * 60 * 60 * 1000) {
        result.issues.push({
          type: 'warning',
          category: 'Certificates',
          message: `Development certificate '${cert.name}' expires soon`,
          impact: 'medium',
          solution: 'Consider renewing the certificate before it expires'
        });
      }
    }

    // Check provisioning profiles
    for (const profile of certs.provisioningProfiles) {
      if (profile.expiryDate < now) {
        result.issues.push({
          type: 'error',
          category: 'Provisioning',
          message: `Provisioning profile '${profile.name}' has expired`,
          impact: 'high',
          solution: 'Renew or create a new provisioning profile'
        });
      }
    }
  }

  private generateRecommendations(result: DeploymentValidationResult): void {
    // App Store optimization recommendations
    if (result.infoPlist.minimumOSVersion && parseFloat(result.infoPlist.minimumOSVersion) >= 14.0) {
      result.recommendations.push({
        category: 'App Store Optimization',
        message: 'Consider implementing App Clips for better user acquisition',
        benefit: 'Faster user onboarding and discovery',
        implementation: 'Create an App Clip target in your Xcode project'
      });
    }

    // Privacy recommendations
    if (result.infoPlist.permissions.length > 5) {
      result.recommendations.push({
        category: 'Privacy',
        message: 'Review if all requested permissions are necessary',
        benefit: 'Better user trust and App Store review',
        implementation: 'Remove unused permissions and implement progressive permission requests'
      });
    }

    // Performance recommendations
    if (result.infoPlist.backgroundModes.length > 0) {
      result.recommendations.push({
        category: 'Performance',
        message: 'Optimize background processing for better battery life',
        benefit: 'Improved user experience and App Store rating',
        implementation: 'Use background app refresh efficiently and implement proper background task handling'
      });
    }

    // Medical imaging specific recommendations
    if (result.infoPlist.bundleId.toLowerCase().includes('dicom') || 
        result.infoPlist.bundleId.toLowerCase().includes('medical')) {
      result.recommendations.push({
        category: 'Medical Compliance',
        message: 'Ensure HIPAA compliance for medical data handling',
        benefit: 'Legal compliance and user trust',
        implementation: 'Implement proper data encryption, audit logging, and user consent mechanisms'
      });
    }
  }

  private async findInfoPlist(projectPath: string): Promise<string | null> {
    const projectDir = path.dirname(projectPath);
    const projectName = path.basename(projectPath, path.extname(projectPath));
    
    const possiblePaths = [
      path.join(projectDir, projectName, 'Info.plist'),
      path.join(projectDir, 'Info.plist'),
      path.join(projectDir, `${projectName}/Info.plist`),
      path.join(projectDir, `${projectName}/Resources/Info.plist`)
    ];
    
    for (const plistPath of possiblePaths) {
      if (await fs.pathExists(plistPath)) {
        return plistPath;
      }
    }
    
    return null;
  }

  private async findEntitlementsFile(projectPath: string): Promise<string | null> {
    const projectDir = path.dirname(projectPath);
    
    try {
      const entitlementsFiles = await fs.readdir(projectDir);
      const entitlementsFile = entitlementsFiles.find(f => f.endsWith('.entitlements'));
      
      if (entitlementsFile) {
        return path.join(projectDir, entitlementsFile);
      }
    } catch (error) {
      // Directory doesn't exist or can't be read
    }
    
    return null;
  }

  private extractSupportedDevices(plistData: any): string[] {
    const devices: string[] = [];
    
    if (plistData.UISupportedInterfaceOrientations) {
      devices.push('iPhone');
    }
    
    if (plistData.UISupportedInterfaceOrientations_iPad) {
      devices.push('iPad');
    }
    
    if (plistData.UIDeviceFamily) {
      const families = Array.isArray(plistData.UIDeviceFamily) 
        ? plistData.UIDeviceFamily 
        : [plistData.UIDeviceFamily];
      
      if (families.includes(1)) devices.push('iPhone');
      if (families.includes(2)) devices.push('iPad');
      if (families.includes(3)) devices.push('Apple TV');
      if (families.includes(4)) devices.push('Apple Watch');
    }
    
    return [...new Set(devices)];
  }

  private extractPermissions(plistData: any): Permission[] {
    const permissions: Permission[] = [];
    const permissionKeys = Object.keys(plistData).filter(key => key.includes('UsageDescription'));
    
    for (const key of permissionKeys) {
      permissions.push({
        key,
        description: plistData[key],
        required: true,
        privacy: this.getPrivacyLevel(key)
      });
    }
    
    return permissions;
  }

  private extractURLSchemes(plistData: any): string[] {
    const schemes: string[] = [];
    
    if (plistData.CFBundleURLTypes) {
      for (const urlType of plistData.CFBundleURLTypes) {
        if (urlType.CFBundleURLSchemes) {
          schemes.push(...urlType.CFBundleURLSchemes);
        }
      }
    }
    
    return schemes;
  }

  private extractAppGroups(entitlements: string[]): string[] {
    return entitlements.filter(e => e.startsWith('group.'));
  }

  private extractKeychainGroups(entitlements: string[]): string[] {
    return entitlements.filter(e => e.includes('keychain'));
  }

  private extractAssociatedDomains(entitlements: string[]): string[] {
    return entitlements.filter(e => e.includes('associated-domains'));
  }

  private getPrivacyLevel(permissionKey: string): 'low' | 'medium' | 'high' {
    const highPrivacy = ['Camera', 'Microphone', 'Location', 'Contacts', 'Health'];
    const mediumPrivacy = ['Photos', 'Calendar', 'Reminders', 'Motion'];
    
    if (highPrivacy.some(p => permissionKey.includes(p))) return 'high';
    if (mediumPrivacy.some(p => permissionKey.includes(p))) return 'medium';
    return 'low';
  }

  private isValidBundleId(bundleId: string): boolean {
    const pattern = /^[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+$/;
    return pattern.test(bundleId) && !bundleId.includes('..') && !bundleId.startsWith('.') && !bundleId.endsWith('.');
  }

  private parseCertificates(output: string, type: 'development' | 'distribution'): Certificate[] {
    const certificates: Certificate[] = [];
    const lines = output.split('\n');
    
    for (const line of lines) {
      const match = line.match(/\d+\)\s+([A-F0-9]+)\s+"([^"]+)"/);
      if (match) {
        const [, hash, name] = match;
        
        certificates.push({
          name,
          team: this.extractTeamFromCertName(name),
          expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), // Placeholder
          isValid: true
        });
      }
    }
    
    return certificates;
  }

  private async parseProvisioningProfile(profilePath: string): Promise<ProvisioningProfile | null> {
    try {
      // This is a simplified implementation
      // Real implementation would parse the provisioning profile binary format
      return null;
    } catch (error) {
      return null;
    }
  }

  private extractTeamFromCertName(certName: string): string {
    const match = certName.match(/\(([^)]+)\)$/);
    return match ? match[1] : 'Unknown';
  }

  private formatValidationResults(result: DeploymentValidationResult): string {
    let output = `# iOS Deployment Validation\n\n`;
    
    // Overall status
    if (result.isValid) {
      output += `✅ **Status:** Ready for deployment\n\n`;
    } else {
      output += `❌ **Status:** Issues found that prevent deployment\n\n`;
    }
    
    // App information
    output += `## App Information\n\n`;
    output += `- **Bundle ID:** ${result.infoPlist.bundleId}\n`;
    output += `- **Version:** ${result.infoPlist.version}\n`;
    output += `- **Build:** ${result.infoPlist.buildNumber}\n`;
    output += `- **Min iOS:** ${result.infoPlist.minimumOSVersion}\n`;
    output += `- **Supported Devices:** ${result.infoPlist.supportedDevices.join(', ')}\n\n`;
    
    // Issues summary
    const errors = result.issues.filter(i => i.type === 'error');
    const warnings = result.issues.filter(i => i.type === 'warning');
    const info = result.issues.filter(i => i.type === 'info');
    
    output += `## Issues Summary\n\n`;
    output += `- **Errors:** ${errors.length}\n`;
    output += `- **Warnings:** ${warnings.length}\n`;
    output += `- **Info:** ${info.length}\n\n`;
    
    // Detailed issues
    if (result.issues.length > 0) {
      if (errors.length > 0) {
        output += `### Critical Issues (${errors.length})\n\n`;
        for (const issue of errors) {
          output += `❌ **${issue.category}:** ${issue.message}\n`;
          if (issue.solution) {
            output += `   🔧 *Solution: ${issue.solution}*\n`;
          }
          output += '\n';
        }
      }
      
      if (warnings.length > 0) {
        output += `### Warnings (${warnings.length})\n\n`;
        for (const issue of warnings) {
          output += `⚠️ **${issue.category}:** ${issue.message}\n`;
          if (issue.solution) {
            output += `   🔧 *Solution: ${issue.solution}*\n`;
          }
          output += '\n';
        }
      }
      
      if (info.length > 0) {
        output += `### Information (${info.length})\n\n`;
        for (const issue of info) {
          output += `ℹ️ **${issue.category}:** ${issue.message}\n`;
          if (issue.solution) {
            output += `   💡 *Suggestion: ${issue.solution}*\n`;
          }
          output += '\n';
        }
      }
    }
    
    // Capabilities
    if (result.capabilities.entitlements.length > 0) {
      output += `## App Capabilities\n\n`;
      for (const entitlement of result.capabilities.entitlements) {
        output += `- ${entitlement}\n`;
      }
      output += '\n';
    }
    
    // Permissions
    if (result.infoPlist.permissions.length > 0) {
      output += `## Privacy Permissions\n\n`;
      for (const permission of result.infoPlist.permissions) {
        const privacyIcon = permission.privacy === 'high' ? '🔴' : permission.privacy === 'medium' ? '🟡' : '🟢';
        output += `${privacyIcon} **${permission.key}**\n`;
        output += `   ${permission.description}\n\n`;
      }
    }
    
    // Recommendations
    if (result.recommendations.length > 0) {
      output += `## Recommendations (${result.recommendations.length})\n\n`;
      for (const rec of result.recommendations) {
        output += `💡 **${rec.category}:** ${rec.message}\n`;
        output += `   📈 *Benefit: ${rec.benefit}*\n`;
        output += `   🛠️ *Implementation: ${rec.implementation}*\n\n`;
      }
    }
    
    return output;
  }
}