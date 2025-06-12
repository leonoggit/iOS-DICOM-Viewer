/**
 * DICOM Compliance Checker
 * Validates DICOM files against standard compliance requirements
 */

import { 
  DICOMMetadata, 
  DICOMValidationResult, 
  DICOMComplianceCheck,
  SOPClass,
  Modality
} from '../types/dicom.js';
import { isValidUID } from '../utils/dicom-utils.js';

export interface ComplianceProfile {
  name: string;
  description: string;
  sopClasses: string[];
  requiredTags: ComplianceTag[];
  conditionalTags: ConditionalTag[];
  rules: ComplianceRule[];
}

export interface ComplianceTag {
  tag: string;
  name: string;
  vr: string; // Value Representation
  vm: string; // Value Multiplicity
  description: string;
  required: boolean;
}

export interface ConditionalTag extends ComplianceTag {
  condition: string;
  conditionDescription: string;
}

export interface ComplianceRule {
  id: string;
  description: string;
  validator: (metadata: DICOMMetadata) => ComplianceRuleResult;
}

export interface ComplianceRuleResult {
  passed: boolean;
  message: string;
  severity: 'error' | 'warning' | 'info';
}

export interface DetailedComplianceResult extends DICOMValidationResult {
  profile: string;
  sopClass: string;
  sopClassName: string;
  complianceScore: number; // 0-100
  ruleResults: ComplianceRuleResult[];
  tagCompliance: {
    required: { total: number; present: number; missing: string[] };
    conditional: { total: number; applicable: number; present: number; missing: string[] };
  };
}

export class DICOMComplianceChecker {
  private profiles: Map<string, ComplianceProfile> = new Map();

  constructor() {
    this.initializeStandardProfiles();
  }

  /**
   * Check DICOM compliance against appropriate profile
   */
  checkCompliance(metadata: DICOMMetadata): DetailedComplianceResult {
    const sopClass = metadata.sopClassUID || '';
    const profile = this.selectProfile(sopClass);
    
    if (!profile) {
      return this.createFailureResult(metadata, `No compliance profile found for SOP Class: ${sopClass}`);
    }

    return this.validateAgainstProfile(metadata, profile);
  }

  /**
   * Validate against specific compliance profile
   */
  validateAgainstProfile(metadata: DICOMMetadata, profile: ComplianceProfile): DetailedComplianceResult {
    const result: DetailedComplianceResult = {
      isValid: true,
      errors: [],
      warnings: [],
      missingRequiredTags: [],
      invalidValues: [],
      profile: profile.name,
      sopClass: metadata.sopClassUID || '',
      sopClassName: this.getSOPClassName(metadata.sopClassUID || ''),
      complianceScore: 0,
      ruleResults: [],
      tagCompliance: {
        required: { total: 0, present: 0, missing: [] },
        conditional: { total: 0, applicable: 0, present: 0, missing: [] }
      }
    };

    // Check required tags
    this.checkRequiredTags(metadata, profile.requiredTags, result);
    
    // Check conditional tags
    this.checkConditionalTags(metadata, profile.conditionalTags, result);
    
    // Apply compliance rules
    this.applyComplianceRules(metadata, profile.rules, result);
    
    // Calculate compliance score
    result.complianceScore = this.calculateComplianceScore(result);
    
    // Set overall validity
    result.isValid = result.errors.length === 0;

    return result;
  }

  /**
   * Get available compliance profiles
   */
  getAvailableProfiles(): string[] {
    return Array.from(this.profiles.keys());
  }

  /**
   * Get profile details
   */
  getProfileDetails(profileName: string): ComplianceProfile | null {
    return this.profiles.get(profileName) || null;
  }

  /**
   * Initialize standard DICOM compliance profiles
   */
  private initializeStandardProfiles(): void {
    // CT Image Storage Profile
    this.profiles.set('CT_IMAGE', {
      name: 'CT Image Storage',
      description: 'Standard CT Image Storage SOP Class compliance',
      sopClasses: [SOPClass.CT_IMAGE_STORAGE],
      requiredTags: [
        { tag: '(0008,0016)', name: 'SOP Class UID', vr: 'UI', vm: '1', description: 'SOP Class UID', required: true },
        { tag: '(0008,0018)', name: 'SOP Instance UID', vr: 'UI', vm: '1', description: 'SOP Instance UID', required: true },
        { tag: '(0008,0020)', name: 'Study Date', vr: 'DA', vm: '1', description: 'Study Date', required: true },
        { tag: '(0008,0030)', name: 'Study Time', vr: 'TM', vm: '1', description: 'Study Time', required: true },
        { tag: '(0008,0060)', name: 'Modality', vr: 'CS', vm: '1', description: 'Modality', required: true },
        { tag: '(0010,0010)', name: 'Patient Name', vr: 'PN', vm: '1', description: 'Patient Name', required: true },
        { tag: '(0010,0020)', name: 'Patient ID', vr: 'LO', vm: '1', description: 'Patient ID', required: true },
        { tag: '(0010,0030)', name: 'Patient Birth Date', vr: 'DA', vm: '1', description: 'Patient Birth Date', required: true },
        { tag: '(0010,0040)', name: 'Patient Sex', vr: 'CS', vm: '1', description: 'Patient Sex', required: true },
        { tag: '(0020,000D)', name: 'Study Instance UID', vr: 'UI', vm: '1', description: 'Study Instance UID', required: true },
        { tag: '(0020,000E)', name: 'Series Instance UID', vr: 'UI', vm: '1', description: 'Series Instance UID', required: true },
        { tag: '(0020,0010)', name: 'Study ID', vr: 'SH', vm: '1', description: 'Study ID', required: true },
        { tag: '(0020,0011)', name: 'Series Number', vr: 'IS', vm: '1', description: 'Series Number', required: true },
        { tag: '(0020,0013)', name: 'Instance Number', vr: 'IS', vm: '1', description: 'Instance Number', required: true },
        { tag: '(0028,0002)', name: 'Samples per Pixel', vr: 'US', vm: '1', description: 'Samples per Pixel', required: true },
        { tag: '(0028,0004)', name: 'Photometric Interpretation', vr: 'CS', vm: '1', description: 'Photometric Interpretation', required: true },
        { tag: '(0028,0010)', name: 'Rows', vr: 'US', vm: '1', description: 'Rows', required: true },
        { tag: '(0028,0011)', name: 'Columns', vr: 'US', vm: '1', description: 'Columns', required: true },
        { tag: '(0028,0100)', name: 'Bits Allocated', vr: 'US', vm: '1', description: 'Bits Allocated', required: true },
        { tag: '(0028,0101)', name: 'Bits Stored', vr: 'US', vm: '1', description: 'Bits Stored', required: true },
        { tag: '(0028,0102)', name: 'High Bit', vr: 'US', vm: '1', description: 'High Bit', required: true },
        { tag: '(0028,0103)', name: 'Pixel Representation', vr: 'US', vm: '1', description: 'Pixel Representation', required: true },
        { tag: '(7FE0,0010)', name: 'Pixel Data', vr: 'OW', vm: '1', description: 'Pixel Data', required: true }
      ],
      conditionalTags: [
        { 
          tag: '(0028,0030)', name: 'Pixel Spacing', vr: 'DS', vm: '2', description: 'Pixel Spacing',
          required: true, condition: 'if image calibration is available', 
          conditionDescription: 'Required if pixel spacing is known'
        },
        {
          tag: '(0018,0050)', name: 'Slice Thickness', vr: 'DS', vm: '1', description: 'Slice Thickness',
          required: true, condition: 'for volume data',
          conditionDescription: 'Required for 3D reconstruction'
        }
      ],
      rules: [
        {
          id: 'CT_MODALITY',
          description: 'Modality must be CT',
          validator: (metadata) => ({
            passed: metadata.modality === 'CT',
            message: metadata.modality === 'CT' ? 'Modality correctly set to CT' : `Invalid modality: ${metadata.modality}`,
            severity: metadata.modality === 'CT' ? 'info' : 'error'
          })
        },
        {
          id: 'CT_PHOTOMETRIC',
          description: 'Photometric Interpretation should be MONOCHROME2',
          validator: (metadata) => ({
            passed: metadata.photometricInterpretation === 'MONOCHROME2',
            message: metadata.photometricInterpretation === 'MONOCHROME2' 
              ? 'Correct photometric interpretation' 
              : `Unusual photometric interpretation: ${metadata.photometricInterpretation}`,
            severity: metadata.photometricInterpretation === 'MONOCHROME2' ? 'info' : 'warning'
          })
        }
      ]
    });

    // MR Image Storage Profile
    this.profiles.set('MR_IMAGE', {
      name: 'MR Image Storage',
      description: 'Standard MR Image Storage SOP Class compliance',
      sopClasses: [SOPClass.MR_IMAGE_STORAGE],
      requiredTags: [
        { tag: '(0008,0016)', name: 'SOP Class UID', vr: 'UI', vm: '1', description: 'SOP Class UID', required: true },
        { tag: '(0008,0018)', name: 'SOP Instance UID', vr: 'UI', vm: '1', description: 'SOP Instance UID', required: true },
        { tag: '(0008,0060)', name: 'Modality', vr: 'CS', vm: '1', description: 'Modality', required: true },
        { tag: '(0010,0010)', name: 'Patient Name', vr: 'PN', vm: '1', description: 'Patient Name', required: true },
        { tag: '(0010,0020)', name: 'Patient ID', vr: 'LO', vm: '1', description: 'Patient ID', required: true },
        { tag: '(0020,000D)', name: 'Study Instance UID', vr: 'UI', vm: '1', description: 'Study Instance UID', required: true },
        { tag: '(0020,000E)', name: 'Series Instance UID', vr: 'UI', vm: '1', description: 'Series Instance UID', required: true },
        { tag: '(0028,0010)', name: 'Rows', vr: 'US', vm: '1', description: 'Rows', required: true },
        { tag: '(0028,0011)', name: 'Columns', vr: 'US', vm: '1', description: 'Columns', required: true },
        { tag: '(7FE0,0010)', name: 'Pixel Data', vr: 'OW', vm: '1', description: 'Pixel Data', required: true }
      ],
      conditionalTags: [],
      rules: [
        {
          id: 'MR_MODALITY',
          description: 'Modality must be MR',
          validator: (metadata) => ({
            passed: metadata.modality === 'MR',
            message: metadata.modality === 'MR' ? 'Modality correctly set to MR' : `Invalid modality: ${metadata.modality}`,
            severity: metadata.modality === 'MR' ? 'info' : 'error'
          })
        }
      ]
    });

    // Secondary Capture Profile
    this.profiles.set('SC_IMAGE', {
      name: 'Secondary Capture Image Storage',
      description: 'Secondary Capture Image Storage SOP Class compliance',
      sopClasses: [SOPClass.SECONDARY_CAPTURE_IMAGE_STORAGE],
      requiredTags: [
        { tag: '(0008,0016)', name: 'SOP Class UID', vr: 'UI', vm: '1', description: 'SOP Class UID', required: true },
        { tag: '(0008,0018)', name: 'SOP Instance UID', vr: 'UI', vm: '1', description: 'SOP Instance UID', required: true },
        { tag: '(0008,0060)', name: 'Modality', vr: 'CS', vm: '1', description: 'Modality', required: true },
        { tag: '(0010,0010)', name: 'Patient Name', vr: 'PN', vm: '1', description: 'Patient Name', required: true },
        { tag: '(0010,0020)', name: 'Patient ID', vr: 'LO', vm: '1', description: 'Patient ID', required: true },
        { tag: '(0020,000D)', name: 'Study Instance UID', vr: 'UI', vm: '1', description: 'Study Instance UID', required: true },
        { tag: '(0020,000E)', name: 'Series Instance UID', vr: 'UI', vm: '1', description: 'Series Instance UID', required: true }
      ],
      conditionalTags: [],
      rules: [
        {
          id: 'SC_MODALITY',
          description: 'Modality must be SC',
          validator: (metadata) => ({
            passed: metadata.modality === 'SC',
            message: metadata.modality === 'SC' ? 'Modality correctly set to SC' : `Invalid modality: ${metadata.modality}`,
            severity: metadata.modality === 'SC' ? 'info' : 'error'
          })
        }
      ]
    });
  }

  /**
   * Select appropriate profile based on SOP Class
   */
  private selectProfile(sopClass: string): ComplianceProfile | null {
    for (const profile of this.profiles.values()) {
      if (profile.sopClasses.includes(sopClass)) {
        return profile;
      }
    }
    return null;
  }

  /**
   * Check required tags compliance
   */
  private checkRequiredTags(
    metadata: DICOMMetadata, 
    requiredTags: ComplianceTag[], 
    result: DetailedComplianceResult
  ): void {
    result.tagCompliance.required.total = requiredTags.length;

    for (const tag of requiredTags) {
      const value = this.getMetadataValue(metadata, tag.tag);
      
      if (value === undefined || value === null || value === '') {
        result.tagCompliance.required.missing.push(tag.name);
        result.missingRequiredTags?.push(tag.name);
        result.errors.push(`Missing required tag: ${tag.name} ${tag.tag}`);
      } else {
        result.tagCompliance.required.present++;
        
        // Validate specific tag values
        const validation = this.validateTagValue(tag, value);
        if (!validation.isValid) {
          result.invalidValues?.push({
            tag: tag.tag,
            value,
            reason: validation.reason
          });
          result.errors.push(`Invalid value for ${tag.name}: ${validation.reason}`);
        }
      }
    }
  }

  /**
   * Check conditional tags compliance
   */
  private checkConditionalTags(
    metadata: DICOMMetadata,
    conditionalTags: ConditionalTag[],
    result: DetailedComplianceResult
  ): void {
    result.tagCompliance.conditional.total = conditionalTags.length;

    for (const tag of conditionalTags) {
      const isApplicable = this.evaluateCondition(metadata, tag.condition);
      
      if (isApplicable) {
        result.tagCompliance.conditional.applicable++;
        
        const value = this.getMetadataValue(metadata, tag.tag);
        if (value === undefined || value === null || value === '') {
          result.tagCompliance.conditional.missing.push(tag.name);
          result.warnings.push(`Missing conditional tag: ${tag.name} ${tag.tag} (${tag.conditionDescription})`);
        } else {
          result.tagCompliance.conditional.present++;
        }
      }
    }
  }

  /**
   * Apply compliance rules
   */
  private applyComplianceRules(
    metadata: DICOMMetadata,
    rules: ComplianceRule[],
    result: DetailedComplianceResult
  ): void {
    for (const rule of rules) {
      const ruleResult = rule.validator(metadata);
      result.ruleResults.push(ruleResult);
      
      if (!ruleResult.passed) {
        if (ruleResult.severity === 'error') {
          result.errors.push(`Rule ${rule.id}: ${ruleResult.message}`);
        } else if (ruleResult.severity === 'warning') {
          result.warnings.push(`Rule ${rule.id}: ${ruleResult.message}`);
        }
      }
    }
  }

  /**
   * Calculate compliance score
   */
  private calculateComplianceScore(result: DetailedComplianceResult): number {
    let score = 0;
    let maxScore = 0;

    // Required tags score (60% weight)
    const requiredWeight = 0.6;
    if (result.tagCompliance.required.total > 0) {
      const requiredRatio = result.tagCompliance.required.present / result.tagCompliance.required.total;
      score += requiredRatio * 100 * requiredWeight;
    }
    maxScore += 100 * requiredWeight;

    // Conditional tags score (20% weight)
    const conditionalWeight = 0.2;
    if (result.tagCompliance.conditional.applicable > 0) {
      const conditionalRatio = result.tagCompliance.conditional.present / result.tagCompliance.conditional.applicable;
      score += conditionalRatio * 100 * conditionalWeight;
    } else if (result.tagCompliance.conditional.total === 0) {
      // No conditional tags applicable, give full credit
      score += 100 * conditionalWeight;
    }
    maxScore += 100 * conditionalWeight;

    // Rules score (20% weight)
    const rulesWeight = 0.2;
    if (result.ruleResults.length > 0) {
      const passedRules = result.ruleResults.filter(r => r.passed).length;
      const rulesRatio = passedRules / result.ruleResults.length;
      score += rulesRatio * 100 * rulesWeight;
    } else {
      score += 100 * rulesWeight;
    }
    maxScore += 100 * rulesWeight;

    return Math.round((score / maxScore) * 100);
  }

  /**
   * Get metadata value by tag
   */
  private getMetadataValue(metadata: DICOMMetadata, tag: string): any {
    // Map DICOM tags to metadata properties
    const tagMap: { [key: string]: keyof DICOMMetadata } = {
      '(0008,0016)': 'sopClassUID',
      '(0008,0018)': 'sopInstanceUID',
      '(0008,0020)': 'studyDate',
      '(0008,0030)': 'studyTime',
      '(0008,0060)': 'modality',
      '(0010,0010)': 'patientName',
      '(0010,0020)': 'patientID',
      '(0010,0030)': 'patientBirthDate',
      '(0010,0040)': 'patientSex',
      '(0020,000D)': 'studyInstanceUID',
      '(0020,000E)': 'seriesInstanceUID',
      '(0020,0011)': 'seriesNumber',
      '(0020,0013)': 'instanceNumber',
      '(0028,0002)': 'samplesPerPixel',
      '(0028,0004)': 'photometricInterpretation',
      '(0028,0010)': 'rows',
      '(0028,0011)': 'columns',
      '(0028,0030)': 'pixelSpacing',
      '(0028,0100)': 'bitsAllocated',
      '(0028,0101)': 'bitsStored',
      '(0028,0102)': 'highBit',
      '(0028,0103)': 'pixelRepresentation',
      '(0018,0050)': 'sliceThickness'
    };

    const property = tagMap[tag];
    return property ? metadata[property] : undefined;
  }

  /**
   * Validate tag value
   */
  private validateTagValue(tag: ComplianceTag, value: any): { isValid: boolean; reason: string } {
    // UID validation
    if (tag.vr === 'UI') {
      if (!isValidUID(value)) {
        return { isValid: false, reason: 'Invalid UID format' };
      }
    }

    // Numeric validation
    if (tag.vr === 'US' || tag.vr === 'IS') {
      if (isNaN(Number(value))) {
        return { isValid: false, reason: 'Not a valid number' };
      }
    }

    // Code string validation
    if (tag.vr === 'CS') {
      if (typeof value !== 'string') {
        return { isValid: false, reason: 'Code string must be a string' };
      }
    }

    return { isValid: true, reason: '' };
  }

  /**
   * Evaluate condition for conditional tags
   */
  private evaluateCondition(metadata: DICOMMetadata, condition: string): boolean {
    // Simple condition evaluation - can be extended
    switch (condition) {
      case 'if image calibration is available':
        return true; // Assume always applicable for now
      case 'for volume data':
        return metadata.numberOfFrames ? metadata.numberOfFrames > 1 : false;
      default:
        return false;
    }
  }

  /**
   * Get SOP Class name
   */
  private getSOPClassName(sopClassUID: string): string {
    const sopClassNames: { [key: string]: string } = {
      [SOPClass.CT_IMAGE_STORAGE]: 'CT Image Storage',
      [SOPClass.MR_IMAGE_STORAGE]: 'MR Image Storage',
      [SOPClass.SECONDARY_CAPTURE_IMAGE_STORAGE]: 'Secondary Capture Image Storage',
      [SOPClass.ULTRASOUND_IMAGE_STORAGE]: 'Ultrasound Image Storage'
    };
    
    return sopClassNames[sopClassUID] || `Unknown SOP Class (${sopClassUID})`;
  }

  /**
   * Create failure result
   */
  private createFailureResult(metadata: DICOMMetadata, error: string): DetailedComplianceResult {
    return {
      isValid: false,
      errors: [error],
      warnings: [],
      missingRequiredTags: [],
      invalidValues: [],
      profile: 'Unknown',
      sopClass: metadata.sopClassUID || '',
      sopClassName: this.getSOPClassName(metadata.sopClassUID || ''),
      complianceScore: 0,
      ruleResults: [],
      tagCompliance: {
        required: { total: 0, present: 0, missing: [] },
        conditional: { total: 0, applicable: 0, present: 0, missing: [] }
      }
    };
  }
}