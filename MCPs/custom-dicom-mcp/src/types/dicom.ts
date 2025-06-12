/**
 * DICOM-specific types and interfaces for the MCP server
 */

export interface DICOMMetadata {
  // Patient Information
  patientName?: string;
  patientID?: string;
  patientBirthDate?: string;
  patientSex?: string;
  patientAge?: string;
  
  // Study Information
  studyInstanceUID?: string;
  studyDate?: string;
  studyTime?: string;
  studyDescription?: string;
  accessionNumber?: string;
  
  // Series Information
  seriesInstanceUID?: string;
  seriesNumber?: string;
  seriesDescription?: string;
  modality?: string;
  
  // Instance Information
  sopInstanceUID?: string;
  instanceNumber?: string;
  
  // Image Information
  rows?: number;
  columns?: number;
  pixelSpacing?: [number, number];
  sliceThickness?: number;
  imageOrientation?: number[];
  imagePosition?: number[];
  
  // Display Information
  windowCenter?: number | number[];
  windowWidth?: number | number[];
  rescaleIntercept?: number;
  rescaleSlope?: number;
  
  // Transfer Syntax
  transferSyntaxUID?: string;
  
  // Additional metadata
  manufacturer?: string;
  manufacturerModelName?: string;
  softwareVersion?: string;
  
  // Custom properties for additional data
  [key: string]: any;
}

export interface DICOMPixelData {
  data: Uint8Array | Uint16Array | Int16Array;
  rows: number;
  columns: number;
  samplesPerPixel: number;
  bitsAllocated: number;
  bitsStored: number;
  highBit: number;
  pixelRepresentation: number;
  planarConfiguration?: number;
  photometricInterpretation: string;
}

export interface DICOMValidationResult {
  isValid: boolean;
  errors: string[];
  warnings: string[];
  conformanceProfile?: string;
  missingRequiredTags?: string[];
  invalidValues?: Array<{
    tag: string;
    value: any;
    reason: string;
  }>;
}

export interface DICOMComplianceCheck {
  sopClassUID: string;
  requiredTags: string[];
  optionalTags: string[];
  conditionalTags: Array<{
    tag: string;
    condition: string;
    required: boolean;
  }>;
}

export interface MedicalTerminology {
  code: string;
  meaning: string;
  codingScheme: string;
  category?: string;
  definition?: string;
  synonyms?: string[];
}

export interface DICOMAnalysisResult {
  fileSize: number;
  transferSyntax: string;
  compression: string;
  pixelDataSize?: number;
  numberOfFrames: number;
  isMultiframe: boolean;
  modality: string;
  sopClassUID: string;
  sopClassName: string;
  estimatedLoadTime: number;
  memoryRequirement: number;
  recommendations: string[];
}

export interface WindowLevelPreset {
  name: string;
  windowCenter: number;
  windowWidth: number;
  description: string;
  modality: string;
}

export interface DICOMFileInfo {
  filename: string;
  size: number;
  isDICOM: boolean;
  format: string;
  hasPixelData: boolean;
  isCompressed: boolean;
  transferSyntax?: string;
  sopClassUID?: string;
  modality?: string;
  studyInstanceUID?: string;
  seriesInstanceUID?: string;
  sopInstanceUID?: string;
}

export interface PixelDataStatistics {
  min: number;
  max: number;
  mean: number;
  median: number;
  standardDeviation: number;
  histogram: number[];
  dynamicRange: number;
  suggestedWindowCenter: number;
  suggestedWindowWidth: number;
}

export interface DICOMError {
  code: string;
  message: string;
  severity: 'error' | 'warning' | 'info';
  tag?: string;
  context?: string;
}

// Enums for common DICOM values
export enum Modality {
  CT = 'CT',
  MR = 'MR',
  US = 'US',
  CR = 'CR',
  DR = 'DR',
  DX = 'DX',
  XA = 'XA',
  RF = 'RF',
  NM = 'NM',
  PT = 'PT',
  MG = 'MG',
  SC = 'SC',
  SEG = 'SEG',
  RTSTRUCT = 'RTSTRUCT',
  RTPLAN = 'RTPLAN',
  RTDOSE = 'RTDOSE'
}

export enum TransferSyntax {
  IMPLICIT_VR_LITTLE_ENDIAN = '1.2.840.10008.1.2',
  EXPLICIT_VR_LITTLE_ENDIAN = '1.2.840.10008.1.2.1',
  EXPLICIT_VR_BIG_ENDIAN = '1.2.840.10008.1.2.2',
  DEFLATED_EXPLICIT_VR_LITTLE_ENDIAN = '1.2.840.10008.1.2.1.99',
  JPEG_BASELINE = '1.2.840.10008.1.2.4.50',
  JPEG_EXTENDED = '1.2.840.10008.1.2.4.51',
  JPEG_LOSSLESS = '1.2.840.10008.1.2.4.57',
  JPEG_LOSSLESS_SELECTION_VALUE_1 = '1.2.840.10008.1.2.4.70',
  JPEG_LS_LOSSLESS = '1.2.840.10008.1.2.4.80',
  JPEG_LS_LOSSY = '1.2.840.10008.1.2.4.81',
  JPEG_2000_LOSSLESS = '1.2.840.10008.1.2.4.90',
  JPEG_2000_LOSSY = '1.2.840.10008.1.2.4.91',
  RLE_LOSSLESS = '1.2.840.10008.1.2.5'
}

export enum SOPClass {
  CT_IMAGE_STORAGE = '1.2.840.10008.5.1.4.1.1.2',
  MR_IMAGE_STORAGE = '1.2.840.10008.5.1.4.1.1.4',
  ULTRASOUND_IMAGE_STORAGE = '1.2.840.10008.5.1.4.1.1.6.1',
  SECONDARY_CAPTURE_IMAGE_STORAGE = '1.2.840.10008.5.1.4.1.1.7',
  SEGMENTATION_STORAGE = '1.2.840.10008.5.1.4.1.1.66.4',
  RT_STRUCTURE_SET_STORAGE = '1.2.840.10008.5.1.4.1.1.481.3',
  RT_PLAN_STORAGE = '1.2.840.10008.5.1.4.1.1.481.5',
  RT_DOSE_STORAGE = '1.2.840.10008.5.1.4.1.1.481.2'
}