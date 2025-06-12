/**
 * Utility functions for DICOM operations
 */

import { 
  DICOMMetadata, 
  DICOMError, 
  Modality, 
  TransferSyntax, 
  SOPClass,
  WindowLevelPreset,
  PixelDataStatistics
} from '../types/dicom.js';

/**
 * Convert DICOM tag to hex string
 */
export function tagToHex(group: number, element: number): string {
  return `(${group.toString(16).padStart(4, '0').toUpperCase()},${element.toString(16).padStart(4, '0').toUpperCase()})`;
}

/**
 * Parse DICOM tag from hex string
 */
export function parseTagHex(tagHex: string): { group: number; element: number } | null {
  const match = tagHex.match(/\(([0-9A-Fa-f]{4}),([0-9A-Fa-f]{4})\)/);
  if (!match) return null;
  
  return {
    group: parseInt(match[1], 16),
    element: parseInt(match[2], 16)
  };
}

/**
 * Get human-readable transfer syntax name
 */
export function getTransferSyntaxName(uid: string): string {
  const syntaxNames: { [key: string]: string } = {
    [TransferSyntax.IMPLICIT_VR_LITTLE_ENDIAN]: 'Implicit VR Little Endian',
    [TransferSyntax.EXPLICIT_VR_LITTLE_ENDIAN]: 'Explicit VR Little Endian',
    [TransferSyntax.EXPLICIT_VR_BIG_ENDIAN]: 'Explicit VR Big Endian',
    [TransferSyntax.DEFLATED_EXPLICIT_VR_LITTLE_ENDIAN]: 'Deflated Explicit VR Little Endian',
    [TransferSyntax.JPEG_BASELINE]: 'JPEG Baseline (Process 1)',
    [TransferSyntax.JPEG_EXTENDED]: 'JPEG Extended (Process 2 & 4)',
    [TransferSyntax.JPEG_LOSSLESS]: 'JPEG Lossless, Non-Hierarchical (Process 14)',
    [TransferSyntax.JPEG_LOSSLESS_SELECTION_VALUE_1]: 'JPEG Lossless, Non-Hierarchical, First-Order Prediction',
    [TransferSyntax.JPEG_LS_LOSSLESS]: 'JPEG-LS Lossless Image Compression',
    [TransferSyntax.JPEG_LS_LOSSY]: 'JPEG-LS Lossy (Near-Lossless) Image Compression',
    [TransferSyntax.JPEG_2000_LOSSLESS]: 'JPEG 2000 Image Compression (Lossless Only)',
    [TransferSyntax.JPEG_2000_LOSSY]: 'JPEG 2000 Image Compression',
    [TransferSyntax.RLE_LOSSLESS]: 'RLE Lossless'
  };
  
  return syntaxNames[uid] || `Unknown Transfer Syntax (${uid})`;
}

/**
 * Get SOP Class name from UID
 */
export function getSOPClassName(uid: string): string {
  const sopClassNames: { [key: string]: string } = {
    [SOPClass.CT_IMAGE_STORAGE]: 'CT Image Storage',
    [SOPClass.MR_IMAGE_STORAGE]: 'MR Image Storage',
    [SOPClass.ULTRASOUND_IMAGE_STORAGE]: 'Ultrasound Image Storage',
    [SOPClass.SECONDARY_CAPTURE_IMAGE_STORAGE]: 'Secondary Capture Image Storage',
    [SOPClass.SEGMENTATION_STORAGE]: 'Segmentation Storage',
    [SOPClass.RT_STRUCTURE_SET_STORAGE]: 'RT Structure Set Storage',
    [SOPClass.RT_PLAN_STORAGE]: 'RT Plan Storage',
    [SOPClass.RT_DOSE_STORAGE]: 'RT Dose Storage'
  };
  
  return sopClassNames[uid] || `Unknown SOP Class (${uid})`;
}

/**
 * Check if transfer syntax is compressed
 */
export function isCompressedTransferSyntax(uid: string): boolean {
  const compressedSyntaxes = [
    TransferSyntax.DEFLATED_EXPLICIT_VR_LITTLE_ENDIAN,
    TransferSyntax.JPEG_BASELINE,
    TransferSyntax.JPEG_EXTENDED,
    TransferSyntax.JPEG_LOSSLESS,
    TransferSyntax.JPEG_LOSSLESS_SELECTION_VALUE_1,
    TransferSyntax.JPEG_LS_LOSSLESS,
    TransferSyntax.JPEG_LS_LOSSY,
    TransferSyntax.JPEG_2000_LOSSLESS,
    TransferSyntax.JPEG_2000_LOSSY,
    TransferSyntax.RLE_LOSSLESS
  ];
  
  return compressedSyntaxes.includes(uid as TransferSyntax);
}

/**
 * Get window/level presets for different modalities
 */
export function getWindowLevelPresets(modality: string): WindowLevelPreset[] {
  const presets: { [key: string]: WindowLevelPreset[] } = {
    [Modality.CT]: [
      { name: 'Soft Tissue', windowCenter: 40, windowWidth: 400, description: 'General soft tissue viewing', modality: 'CT' },
      { name: 'Lung', windowCenter: -600, windowWidth: 1600, description: 'Lung parenchyma', modality: 'CT' },
      { name: 'Bone', windowCenter: 300, windowWidth: 1500, description: 'Bone structures', modality: 'CT' },
      { name: 'Brain', windowCenter: 40, windowWidth: 80, description: 'Brain tissue', modality: 'CT' },
      { name: 'Liver', windowCenter: 60, windowWidth: 160, description: 'Liver parenchyma', modality: 'CT' },
      { name: 'Mediastinum', windowCenter: 50, windowWidth: 350, description: 'Mediastinal structures', modality: 'CT' }
    ],
    [Modality.MR]: [
      { name: 'T1', windowCenter: 600, windowWidth: 1200, description: 'T1-weighted images', modality: 'MR' },
      { name: 'T2', windowCenter: 1000, windowWidth: 2000, description: 'T2-weighted images', modality: 'MR' },
      { name: 'FLAIR', windowCenter: 800, windowWidth: 1600, description: 'FLAIR images', modality: 'MR' },
      { name: 'DWI', windowCenter: 500, windowWidth: 1000, description: 'Diffusion-weighted images', modality: 'MR' }
    ]
  };
  
  return presets[modality] || [];
}

/**
 * Calculate optimal window/level from pixel data statistics
 */
export function calculateOptimalWindowLevel(stats: PixelDataStatistics): { center: number; width: number } {
  // Use mean as center and 2 standard deviations as width (covers ~95% of data)
  const center = Math.round(stats.mean);
  const width = Math.round(stats.standardDeviation * 2);
  
  return { center, width };
}

/**
 * Validate DICOM UID format
 */
export function isValidUID(uid: string): boolean {
  if (!uid || uid.length === 0 || uid.length > 64) {
    return false;
  }
  
  // UID should contain only digits and dots
  if (!/^[0-9.]+$/.test(uid)) {
    return false;
  }
  
  // Should not start or end with dot
  if (uid.startsWith('.') || uid.endsWith('.')) {
    return false;
  }
  
  // Should not have consecutive dots
  if (uid.includes('..')) {
    return false;
  }
  
  // Each component should be valid
  const components = uid.split('.');
  for (const component of components) {
    if (component.length === 0 || component.startsWith('0') && component.length > 1) {
      return false;
    }
  }
  
  return true;
}

/**
 * Format DICOM date (YYYYMMDD to human readable)
 */
export function formatDICOMDate(dateString: string): string {
  if (!dateString || dateString.length !== 8) {
    return dateString;
  }
  
  const year = dateString.substring(0, 4);
  const month = dateString.substring(4, 6);
  const day = dateString.substring(6, 8);
  
  return `${year}-${month}-${day}`;
}

/**
 * Format DICOM time (HHMMSS.FFFFFF to human readable)
 */
export function formatDICOMTime(timeString: string): string {
  if (!timeString || timeString.length < 6) {
    return timeString;
  }
  
  const hours = timeString.substring(0, 2);
  const minutes = timeString.substring(2, 4);
  const seconds = timeString.substring(4, 6);
  const fractional = timeString.length > 6 ? timeString.substring(6) : '';
  
  let formatted = `${hours}:${minutes}:${seconds}`;
  if (fractional) {
    formatted += `.${fractional}`;
  }
  
  return formatted;
}

/**
 * Format DICOM person name (Last^First^Middle^Prefix^Suffix)
 */
export function formatDICOMPersonName(nameString: string): string {
  if (!nameString) {
    return '';
  }
  
  const components = nameString.split('^');
  const last = components[0] || '';
  const first = components[1] || '';
  const middle = components[2] || '';
  const prefix = components[3] || '';
  const suffix = components[4] || '';
  
  let formatted = '';
  
  if (prefix) formatted += prefix + ' ';
  if (first) formatted += first + ' ';
  if (middle) formatted += middle + ' ';
  if (last) formatted += last;
  if (suffix) formatted += ', ' + suffix;
  
  return formatted.trim();
}

/**
 * Calculate pixel data statistics
 */
export function calculatePixelStatistics(pixelData: Uint8Array | Uint16Array | Int16Array): PixelDataStatistics {
  const values = Array.from(pixelData);
  const sorted = values.sort((a, b) => a - b);
  
  const min = sorted[0];
  const max = sorted[sorted.length - 1];
  const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
  
  // Calculate median
  const median = sorted.length % 2 === 0
    ? (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2
    : sorted[Math.floor(sorted.length / 2)];
  
  // Calculate standard deviation
  const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
  const standardDeviation = Math.sqrt(variance);
  
  // Create histogram (256 bins)
  const histogram = new Array(256).fill(0);
  const range = max - min;
  if (range > 0) {
    for (const value of values) {
      const binIndex = Math.min(255, Math.floor(((value - min) / range) * 255));
      histogram[binIndex]++;
    }
  }
  
  const dynamicRange = max - min;
  
  // Suggest window/level based on statistics
  const suggestedWindowCenter = Math.round(mean);
  const suggestedWindowWidth = Math.round(standardDeviation * 2);
  
  return {
    min,
    max,
    mean,
    median,
    standardDeviation,
    histogram,
    dynamicRange,
    suggestedWindowCenter,
    suggestedWindowWidth
  };
}

/**
 * Estimate memory requirement for DICOM image
 */
export function estimateMemoryRequirement(
  rows: number,
  columns: number,
  bitsAllocated: number,
  numberOfFrames: number = 1,
  samplesPerPixel: number = 1
): number {
  const bytesPerPixel = Math.ceil(bitsAllocated / 8);
  const pixelsPerFrame = rows * columns;
  const bytesPerFrame = pixelsPerFrame * bytesPerPixel * samplesPerPixel;
  const totalBytes = bytesPerFrame * numberOfFrames;
  
  // Add overhead for processing (typically 2-3x for decompression, windowing, etc.)
  return totalBytes * 3;
}

/**
 * Create a comprehensive DICOM error
 */
export function createDICOMError(
  code: string,
  message: string,
  severity: 'error' | 'warning' | 'info' = 'error',
  tag?: string,
  context?: string
): DICOMError {
  return {
    code,
    message,
    severity,
    tag,
    context
  };
}

/**
 * Format file size for human reading
 */
export function formatFileSize(bytes: number): string {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let size = bytes;
  let unitIndex = 0;
  
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  
  return `${size.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
}