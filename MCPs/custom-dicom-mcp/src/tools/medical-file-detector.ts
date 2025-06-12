/**
 * Medical Imaging File Type Detector
 * Detects and analyzes various medical imaging file formats
 */

import * as fs from 'fs';
import * as path from 'path';
import { DICOMFileInfo } from '../types/dicom.js';
import { formatFileSize } from '../utils/dicom-utils.js';

export interface MedicalFileDetectionResult {
  filename: string;
  size: number;
  formattedSize: string;
  fileType: MedicalFileType;
  confidence: number; // 0-1 scale
  characteristics: FileCharacteristics;
  recommendations: string[];
  warnings: string[];
}

export enum MedicalFileType {
  DICOM = 'DICOM',
  NIFTI = 'NIfTI',
  ANALYZE = 'Analyze',
  MINC = 'MINC',
  NRRD = 'NRRD',
  METAIMAGE = 'MetaImage',
  VTK = 'VTK',
  STL = 'STL',
  PLY = 'PLY',
  UNKNOWN = 'Unknown'
}

export interface FileCharacteristics {
  hasHeader: boolean;
  isCompressed: boolean;
  isBigEndian?: boolean;
  estimatedDimensions?: number;
  estimatedDataType?: string;
  possibleModality?: string;
  fileExtension: string;
}

export class MedicalFileDetector {
  private static readonly FILE_SIGNATURES = new Map<string, { type: MedicalFileType; offset: number }>([
    // DICOM signatures
    ['DICM', { type: MedicalFileType.DICOM, offset: 128 }],
    
    // NIfTI signatures
    ['ni1\0', { type: MedicalFileType.NIFTI, offset: 0 }],
    ['n+1\0', { type: MedicalFileType.NIFTI, offset: 0 }],
    
    // Analyze signatures
    ['ANALYZE', { type: MedicalFileType.ANALYZE, offset: 0 }],
    
    // MINC signatures
    ['CDF\x01', { type: MedicalFileType.MINC, offset: 0 }],
    ['CDF\x02', { type: MedicalFileType.MINC, offset: 0 }],
    
    // NRRD signatures
    ['NRRD', { type: MedicalFileType.NRRD, offset: 0 }],
    
    // MetaImage signatures
    ['ObjectType', { type: MedicalFileType.METAIMAGE, offset: 0 }],
    
    // VTK signatures
    ['# vtk DataFile', { type: MedicalFileType.VTK, offset: 0 }],
    
    // STL signatures (binary)
    ['\x00\x00\x00\x00', { type: MedicalFileType.STL, offset: 80 }], // Approximate binary STL check
    
    // PLY signatures
    ['ply\n', { type: MedicalFileType.PLY, offset: 0 }],
    ['ply\r\n', { type: MedicalFileType.PLY, offset: 0 }]
  ]);

  private static readonly EXTENSION_MAPPINGS = new Map<string, MedicalFileType>([
    ['.dcm', MedicalFileType.DICOM],
    ['.dic', MedicalFileType.DICOM],
    ['.dicom', MedicalFileType.DICOM],
    ['.nii', MedicalFileType.NIFTI],
    ['.nii.gz', MedicalFileType.NIFTI],
    ['.hdr', MedicalFileType.ANALYZE],
    ['.img', MedicalFileType.ANALYZE],
    ['.mnc', MedicalFileType.MINC],
    ['.nrrd', MedicalFileType.NRRD],
    ['.nhdr', MedicalFileType.NRRD],
    ['.mhd', MedicalFileType.METAIMAGE],
    ['.mha', MedicalFileType.METAIMAGE],
    ['.vtk', MedicalFileType.VTK],
    ['.stl', MedicalFileType.STL],
    ['.ply', MedicalFileType.PLY]
  ]);

  /**
   * Detect medical imaging file type
   */
  async detectFileType(filePath: string): Promise<MedicalFileDetectionResult> {
    try {
      if (!fs.existsSync(filePath)) {
        throw new Error(`File not found: ${filePath}`);
      }

      const stats = fs.statSync(filePath);
      const filename = path.basename(filePath);
      const fileExtension = this.getFullExtension(filename);

      // Read first part of file for signature detection
      const bufferSize = Math.min(1024, stats.size);
      const buffer = Buffer.alloc(bufferSize);
      const fd = fs.openSync(filePath, 'r');
      fs.readSync(fd, buffer, 0, bufferSize, 0);
      fs.closeSync(fd);

      // Detect file type using multiple methods
      const signatureResult = this.detectBySignature(buffer);
      const extensionResult = this.detectByExtension(fileExtension);
      const contentResult = await this.detectByContent(filePath, buffer);

      // Combine results with confidence scoring
      let finalType = MedicalFileType.UNKNOWN;
      let confidence = 0;

      if (signatureResult.type !== MedicalFileType.UNKNOWN) {
        finalType = signatureResult.type;
        confidence = 0.9;
      } else if (extensionResult !== MedicalFileType.UNKNOWN) {
        finalType = extensionResult;
        confidence = 0.7;
      } else if (contentResult.type !== MedicalFileType.UNKNOWN) {
        finalType = contentResult.type;
        confidence = contentResult.confidence;
      }

      // Analyze file characteristics
      const characteristics = await this.analyzeCharacteristics(filePath, buffer, finalType);
      
      // Generate recommendations and warnings
      const recommendations = this.generateRecommendations(finalType, characteristics, stats.size);
      const warnings = this.generateWarnings(finalType, characteristics, stats.size);

      return {
        filename,
        size: stats.size,
        formattedSize: formatFileSize(stats.size),
        fileType: finalType,
        confidence,
        characteristics,
        recommendations,
        warnings
      };

    } catch (error) {
      throw new Error(`Failed to detect file type: ${error}`);
    }
  }

  /**
   * Batch detect multiple files
   */
  async batchDetectFiles(filePaths: string[]): Promise<MedicalFileDetectionResult[]> {
    const results: MedicalFileDetectionResult[] = [];
    
    for (const filePath of filePaths) {
      try {
        const result = await this.detectFileType(filePath);
        results.push(result);
      } catch (error) {
        // Continue with other files even if one fails
        results.push({
          filename: path.basename(filePath),
          size: 0,
          formattedSize: '0 B',
          fileType: MedicalFileType.UNKNOWN,
          confidence: 0,
          characteristics: {
            hasHeader: false,
            isCompressed: false,
            fileExtension: this.getFullExtension(path.basename(filePath))
          },
          recommendations: [],
          warnings: [`Failed to analyze file: ${error}`]
        });
      }
    }
    
    return results;
  }

  /**
   * Detect file type by binary signature
   */
  private detectBySignature(buffer: Buffer): { type: MedicalFileType; confidence: number } {
    for (const [signature, info] of MedicalFileDetector.FILE_SIGNATURES) {
      const signatureBuffer = Buffer.from(signature, 'ascii');
      
      if (buffer.length >= info.offset + signatureBuffer.length) {
        const fileSection = buffer.slice(info.offset, info.offset + signatureBuffer.length);
        
        if (fileSection.equals(signatureBuffer)) {
          return { type: info.type, confidence: 0.95 };
        }
        
        // Also check for partial matches (for text-based formats)
        if (signature.length > 3 && fileSection.toString('ascii').includes(signature.substring(0, 4))) {
          return { type: info.type, confidence: 0.8 };
        }
      }
    }
    
    return { type: MedicalFileType.UNKNOWN, confidence: 0 };
  }

  /**
   * Detect file type by extension
   */
  private detectByExtension(extension: string): MedicalFileType {
    const lowerExt = extension.toLowerCase();
    return MedicalFileDetector.EXTENSION_MAPPINGS.get(lowerExt) || MedicalFileType.UNKNOWN;
  }

  /**
   * Detect file type by content analysis
   */
  private async detectByContent(filePath: string, buffer: Buffer): Promise<{ type: MedicalFileType; confidence: number }> {
    const text = buffer.toString('ascii', 0, Math.min(512, buffer.length));
    
    // Check for DICOM-like structure without proper header
    if (this.hasDICOMStructure(buffer)) {
      return { type: MedicalFileType.DICOM, confidence: 0.6 };
    }
    
    // Check for NIfTI-like structure
    if (this.hasNIfTIStructure(buffer)) {
      return { type: MedicalFileType.NIFTI, confidence: 0.6 };
    }
    
    // Check for text-based formats
    if (text.includes('NRRD')) {
      return { type: MedicalFileType.NRRD, confidence: 0.8 };
    }
    
    if (text.includes('ObjectType') || text.includes('NDims') || text.includes('DimSize')) {
      return { type: MedicalFileType.METAIMAGE, confidence: 0.7 };
    }
    
    if (text.toLowerCase().includes('solid ') && text.toLowerCase().includes('facet')) {
      return { type: MedicalFileType.STL, confidence: 0.7 }; // ASCII STL
    }
    
    return { type: MedicalFileType.UNKNOWN, confidence: 0 };
  }

  /**
   * Check if buffer has DICOM-like structure
   */
  private hasDICOMStructure(buffer: Buffer): boolean {
    // Look for common DICOM tags in the first part of the file
    const commonTags = [
      Buffer.from([0x08, 0x00, 0x16, 0x00]), // SOP Class UID
      Buffer.from([0x08, 0x00, 0x18, 0x00]), // SOP Instance UID
      Buffer.from([0x20, 0x00, 0x0d, 0x00]), // Study Instance UID
      Buffer.from([0x20, 0x00, 0x0e, 0x00])  // Series Instance UID
    ];
    
    for (const tag of commonTags) {
      if (buffer.includes(tag)) {
        return true;
      }
    }
    
    return false;
  }

  /**
   * Check if buffer has NIfTI-like structure
   */
  private hasNIfTIStructure(buffer: Buffer): boolean {
    if (buffer.length < 348) return false; // NIfTI header is 348 bytes
    
    // Check for NIfTI magic numbers at different positions
    const magic1 = buffer.readInt32LE(0);
    const magic2 = buffer.readInt32LE(344);
    
    return magic1 === 348 || magic2 === 0x006E2B31 || magic2 === 0x0031696E;
  }

  /**
   * Analyze file characteristics
   */
  private async analyzeCharacteristics(filePath: string, buffer: Buffer, fileType: MedicalFileType): Promise<FileCharacteristics> {
    const extension = this.getFullExtension(path.basename(filePath));
    const characteristics: FileCharacteristics = {
      hasHeader: false,
      isCompressed: extension.includes('.gz') || extension.includes('.zip'),
      fileExtension: extension
    };

    switch (fileType) {
      case MedicalFileType.DICOM:
        characteristics.hasHeader = true;
        characteristics.possibleModality = this.guessDICOMModality(buffer);
        break;
        
      case MedicalFileType.NIFTI:
        characteristics.hasHeader = true;
        characteristics.estimatedDimensions = this.estimateNIfTIDimensions(buffer);
        characteristics.isBigEndian = this.isNIfTIBigEndian(buffer);
        break;
        
      case MedicalFileType.ANALYZE:
        characteristics.hasHeader = true;
        break;
        
      case MedicalFileType.NRRD:
      case MedicalFileType.METAIMAGE:
      case MedicalFileType.VTK:
        characteristics.hasHeader = true;
        break;
        
      case MedicalFileType.STL:
      case MedicalFileType.PLY:
        characteristics.estimatedDimensions = 3; // 3D mesh data
        break;
    }

    return characteristics;
  }

  /**
   * Guess DICOM modality from buffer
   */
  private guessDICOMModality(buffer: Buffer): string | undefined {
    const text = buffer.toString('ascii');
    
    // Look for modality strings in the buffer
    const modalities = ['CT', 'MR', 'US', 'CR', 'DR', 'DX', 'XA', 'RF', 'NM', 'PT', 'MG', 'SC'];
    
    for (const modality of modalities) {
      if (text.includes(modality)) {
        return modality;
      }
    }
    
    return undefined;
  }

  /**
   * Estimate NIfTI dimensions
   */
  private estimateNIfTIDimensions(buffer: Buffer): number | undefined {
    if (buffer.length < 42) return undefined;
    
    try {
      const dim0 = buffer.readInt16LE(40); // Number of dimensions
      return dim0;
    } catch {
      return undefined;
    }
  }

  /**
   * Check if NIfTI file is big endian
   */
  private isNIfTIBigEndian(buffer: Buffer): boolean | undefined {
    if (buffer.length < 4) return undefined;
    
    const headerSize = buffer.readInt32LE(0);
    return headerSize !== 348; // If not 348 in little endian, might be big endian
  }

  /**
   * Generate recommendations based on file analysis
   */
  private generateRecommendations(fileType: MedicalFileType, characteristics: FileCharacteristics, fileSize: number): string[] {
    const recommendations: string[] = [];

    switch (fileType) {
      case MedicalFileType.DICOM:
        recommendations.push('Use DICOM libraries (DCMTK, dcmjs) for proper parsing');
        if (fileSize > 100 * 1024 * 1024) { // > 100MB
          recommendations.push('Consider progressive loading for large DICOM files');
        }
        if (characteristics.possibleModality) {
          recommendations.push(`Apply ${characteristics.possibleModality}-specific window/level presets`);
        }
        break;
        
      case MedicalFileType.NIFTI:
        recommendations.push('Use NIfTI libraries for proper orientation handling');
        if (characteristics.isCompressed) {
          recommendations.push('Decompress .gz files for faster random access');
        }
        break;
        
      case MedicalFileType.STL:
      case MedicalFileType.PLY:
        recommendations.push('Use 3D mesh processing libraries for visualization');
        recommendations.push('Consider mesh optimization for real-time rendering');
        break;
        
      case MedicalFileType.UNKNOWN:
        recommendations.push('Verify file integrity and format compatibility');
        recommendations.push('Check file extension and header information');
        break;
    }

    // General recommendations
    if (fileSize > 1024 * 1024 * 1024) { // > 1GB
      recommendations.push('Implement memory-efficient streaming for large files');
    }

    return recommendations;
  }

  /**
   * Generate warnings based on file analysis
   */
  private generateWarnings(fileType: MedicalFileType, characteristics: FileCharacteristics, fileSize: number): string[] {
    const warnings: string[] = [];

    if (fileType === MedicalFileType.UNKNOWN) {
      warnings.push('Unknown file format - may not be supported');
    }

    if (fileSize === 0) {
      warnings.push('Empty file detected');
    }

    if (fileSize > 2 * 1024 * 1024 * 1024) { // > 2GB
      warnings.push('Very large file - may cause memory issues');
    }

    if (characteristics.isCompressed && fileType === MedicalFileType.DICOM) {
      warnings.push('Compressed DICOM file - requires decompression support');
    }

    return warnings;
  }

  /**
   * Get full file extension (including compound extensions like .nii.gz)
   */
  private getFullExtension(filename: string): string {
    const parts = filename.split('.');
    
    if (parts.length >= 3 && parts[parts.length - 1] === 'gz') {
      return '.' + parts.slice(-2).join('.');
    }
    
    if (parts.length >= 2) {
      return '.' + parts[parts.length - 1];
    }
    
    return '';
  }
}