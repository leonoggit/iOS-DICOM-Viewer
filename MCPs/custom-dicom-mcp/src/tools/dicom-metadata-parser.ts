/**
 * DICOM Metadata Parser Tool
 * Provides comprehensive DICOM file parsing and metadata extraction
 */

import * as fs from 'fs';
import * as path from 'path';
import * as dicomParser from 'dicom-parser';
import { 
  DICOMMetadata, 
  DICOMValidationResult, 
  DICOMPixelData,
  DICOMError,
  DICOMFileInfo
} from '../types/dicom.js';
import { 
  tagToHex, 
  getTransferSyntaxName, 
  getSOPClassName,
  isValidUID,
  formatDICOMDate,
  formatDICOMTime,
  formatDICOMPersonName,
  createDICOMError,
  formatFileSize
} from '../utils/dicom-utils.js';

export class DICOMMetadataParser {
  /**
   * Parse DICOM file and extract metadata
   */
  async parseDICOMFile(filePath: string): Promise<{
    metadata: DICOMMetadata;
    validation: DICOMValidationResult;
    fileInfo: DICOMFileInfo;
  }> {
    try {
      // Check if file exists
      if (!fs.existsSync(filePath)) {
        throw new Error(`File not found: ${filePath}`);
      }

      const fileStats = fs.statSync(filePath);
      const fileBuffer = fs.readFileSync(filePath);
      
      // Initialize file info
      const fileInfo: DICOMFileInfo = {
        filename: path.basename(filePath),
        size: fileStats.size,
        isDICOM: false,
        format: 'Unknown',
        hasPixelData: false,
        isCompressed: false
      };

      // Try to parse as DICOM
      let dataSet: dicomParser.DataSet;
      try {
        dataSet = dicomParser.parseDicom(fileBuffer);
        fileInfo.isDICOM = true;
        fileInfo.format = 'DICOM';
      } catch (parseError) {
        // Check if it's a DICOM file with different structure
        const isDICOMFile = await this.detectDICOMFile(fileBuffer);
        fileInfo.isDICOM = isDICOMFile;
        
        if (!isDICOMFile) {
          throw new Error(`Not a valid DICOM file: ${parseError}`);
        } else {
          throw new Error(`DICOM parsing failed: ${parseError}`);
        }
      }

      // Extract metadata
      const metadata = this.extractMetadata(dataSet);
      
      // Update file info with parsed data
      if (metadata.transferSyntaxUID) {
        fileInfo.transferSyntax = metadata.transferSyntaxUID;
        fileInfo.isCompressed = this.isCompressedTransferSyntax(metadata.transferSyntaxUID);
      }
      
      fileInfo.sopClassUID = metadata.sopClassUID;
      fileInfo.modality = metadata.modality;
      fileInfo.studyInstanceUID = metadata.studyInstanceUID;
      fileInfo.seriesInstanceUID = metadata.seriesInstanceUID;
      fileInfo.sopInstanceUID = metadata.sopInstanceUID;
      fileInfo.hasPixelData = dataSet.elements.x7fe00010 !== undefined;

      // Validate DICOM data
      const validation = this.validateDICOMData(dataSet, metadata);

      return {
        metadata,
        validation,
        fileInfo
      };
      
    } catch (error) {
      throw new Error(`Failed to parse DICOM file: ${error}`);
    }
  }

  /**
   * Extract comprehensive metadata from DICOM dataset
   */
  private extractMetadata(dataSet: dicomParser.DataSet): DICOMMetadata {
    const metadata: DICOMMetadata = {};

    // Patient Information
    metadata.patientName = this.getStringValue(dataSet, 'x00100010');
    metadata.patientID = this.getStringValue(dataSet, 'x00100020');
    metadata.patientBirthDate = this.getStringValue(dataSet, 'x00100030');
    metadata.patientSex = this.getStringValue(dataSet, 'x00100040');
    metadata.patientAge = this.getStringValue(dataSet, 'x00101010');

    // Study Information
    metadata.studyInstanceUID = this.getStringValue(dataSet, 'x0020000d');
    metadata.studyDate = this.getStringValue(dataSet, 'x00080020');
    metadata.studyTime = this.getStringValue(dataSet, 'x00080030');
    metadata.studyDescription = this.getStringValue(dataSet, 'x00081030');
    metadata.accessionNumber = this.getStringValue(dataSet, 'x00080050');

    // Series Information
    metadata.seriesInstanceUID = this.getStringValue(dataSet, 'x0020000e');
    metadata.seriesNumber = this.getStringValue(dataSet, 'x00200011');
    metadata.seriesDescription = this.getStringValue(dataSet, 'x0008103e');
    metadata.modality = this.getStringValue(dataSet, 'x00080060');

    // Instance Information
    metadata.sopInstanceUID = this.getStringValue(dataSet, 'x00080018');
    metadata.sopClassUID = this.getStringValue(dataSet, 'x00080016');
    metadata.instanceNumber = this.getStringValue(dataSet, 'x00200013');

    // Image Information
    metadata.rows = this.getNumberValue(dataSet, 'x00280010');
    metadata.columns = this.getNumberValue(dataSet, 'x00280011');
    
    const pixelSpacingStr = this.getStringValue(dataSet, 'x00280030');
    if (pixelSpacingStr) {
      const spacing = pixelSpacingStr.split('\\').map(Number);
      if (spacing.length >= 2) {
        metadata.pixelSpacing = [spacing[0], spacing[1]];
      }
    }
    
    metadata.sliceThickness = this.getNumberValue(dataSet, 'x00180050');
    
    const imageOrientationStr = this.getStringValue(dataSet, 'x00200037');
    if (imageOrientationStr) {
      metadata.imageOrientation = imageOrientationStr.split('\\').map(Number);
    }
    
    const imagePositionStr = this.getStringValue(dataSet, 'x00200032');
    if (imagePositionStr) {
      metadata.imagePosition = imagePositionStr.split('\\').map(Number);
    }

    // Window/Level Information
    const windowCenterStr = this.getStringValue(dataSet, 'x00281050');
    if (windowCenterStr) {
      const centers = windowCenterStr.split('\\').map(Number);
      metadata.windowCenter = centers.length === 1 ? centers[0] : centers;
    }
    
    const windowWidthStr = this.getStringValue(dataSet, 'x00281051');
    if (windowWidthStr) {
      const widths = windowWidthStr.split('\\').map(Number);
      metadata.windowWidth = widths.length === 1 ? widths[0] : widths;
    }
    
    metadata.rescaleIntercept = this.getNumberValue(dataSet, 'x00281052');
    metadata.rescaleSlope = this.getNumberValue(dataSet, 'x00281053');

    // Transfer Syntax
    metadata.transferSyntaxUID = this.getStringValue(dataSet, 'x00020010');

    // Equipment Information
    metadata.manufacturer = this.getStringValue(dataSet, 'x00080070');
    metadata.manufacturerModelName = this.getStringValue(dataSet, 'x00081090');
    metadata.softwareVersion = this.getStringValue(dataSet, 'x00181020');

    // Additional commonly used tags
    metadata.bitsAllocated = this.getNumberValue(dataSet, 'x00280100');
    metadata.bitsStored = this.getNumberValue(dataSet, 'x00280101');
    metadata.highBit = this.getNumberValue(dataSet, 'x00280102');
    metadata.pixelRepresentation = this.getNumberValue(dataSet, 'x00280103');
    metadata.samplesPerPixel = this.getNumberValue(dataSet, 'x00280002');
    metadata.photometricInterpretation = this.getStringValue(dataSet, 'x00280004');
    metadata.planarConfiguration = this.getNumberValue(dataSet, 'x00280006');
    metadata.numberOfFrames = this.getNumberValue(dataSet, 'x00280008');

    return metadata;
  }

  /**
   * Validate DICOM data and check for compliance
   */
  private validateDICOMData(dataSet: dicomParser.DataSet, metadata: DICOMMetadata): DICOMValidationResult {
    const result: DICOMValidationResult = {
      isValid: true,
      errors: [],
      warnings: [],
      missingRequiredTags: [],
      invalidValues: []
    };

    // Check required tags for all DICOM files
    const requiredTags = [
      { tag: 'x00080016', name: 'SOP Class UID', value: metadata.sopClassUID },
      { tag: 'x00080018', name: 'SOP Instance UID', value: metadata.sopInstanceUID },
      { tag: 'x0020000d', name: 'Study Instance UID', value: metadata.studyInstanceUID },
      { tag: 'x0020000e', name: 'Series Instance UID', value: metadata.seriesInstanceUID }
    ];

    for (const { tag, name, value } of requiredTags) {
      if (!value) {
        result.missingRequiredTags?.push(name);
        result.errors.push(`Missing required tag: ${name} (${tag})`);
        result.isValid = false;
      } else if (!isValidUID(value)) {
        result.invalidValues?.push({
          tag,
          value,
          reason: `Invalid UID format: ${name}`
        });
        result.errors.push(`Invalid UID format for ${name}: ${value}`);
        result.isValid = false;
      }
    }

    // Check patient information presence
    if (!metadata.patientName && !metadata.patientID) {
      result.warnings.push('No patient identification information found');
    }

    // Check image-specific requirements
    if (metadata.rows && metadata.columns) {
      if (metadata.rows <= 0 || metadata.columns <= 0) {
        result.errors.push('Invalid image dimensions');
        result.isValid = false;
      }
      
      if (metadata.rows > 65535 || metadata.columns > 65535) {
        result.warnings.push('Very large image dimensions detected');
      }
    }

    // Check transfer syntax
    if (metadata.transferSyntaxUID) {
      const syntaxName = getTransferSyntaxName(metadata.transferSyntaxUID);
      if (syntaxName.startsWith('Unknown')) {
        result.warnings.push(`Unknown transfer syntax: ${metadata.transferSyntaxUID}`);
      }
    }

    // Check modality-specific requirements
    if (metadata.modality) {
      this.validateModalitySpecificRequirements(metadata, result);
    }

    return result;
  }

  /**
   * Validate modality-specific requirements
   */
  private validateModalitySpecificRequirements(metadata: DICOMMetadata, result: DICOMValidationResult): void {
    switch (metadata.modality) {
      case 'CT':
        if (!metadata.pixelSpacing) {
          result.warnings.push('CT images should have pixel spacing information');
        }
        if (!metadata.sliceThickness) {
          result.warnings.push('CT images should have slice thickness information');
        }
        break;
        
      case 'MR':
        if (!metadata.pixelSpacing) {
          result.warnings.push('MR images should have pixel spacing information');
        }
        break;
        
      case 'US':
        // Ultrasound-specific checks
        break;
        
      default:
        // Generic checks for other modalities
        break;
    }
  }

  /**
   * Detect if buffer contains DICOM data
   */
  private async detectDICOMFile(buffer: Buffer): Promise<boolean> {
    // Check for DICOM preamble and prefix
    if (buffer.length < 132) return false;
    
    // DICOM files should have "DICM" at byte 128
    const dicmSignature = buffer.slice(128, 132).toString('ascii');
    if (dicmSignature === 'DICM') return true;
    
    // Some DICOM files don't have preamble, check for common tags
    try {
      const dataSet = dicomParser.parseDicom(buffer);
      return dataSet.elements.x00080016 !== undefined; // SOP Class UID
    } catch {
      return false;
    }
  }

  /**
   * Check if transfer syntax is compressed
   */
  private isCompressedTransferSyntax(uid: string): boolean {
    const compressedSyntaxes = [
      '1.2.840.10008.1.2.1.99', // Deflated Explicit VR Little Endian
      '1.2.840.10008.1.2.4.50', // JPEG Baseline
      '1.2.840.10008.1.2.4.51', // JPEG Extended
      '1.2.840.10008.1.2.4.57', // JPEG Lossless
      '1.2.840.10008.1.2.4.70', // JPEG Lossless Selection Value 1
      '1.2.840.10008.1.2.4.80', // JPEG-LS Lossless
      '1.2.840.10008.1.2.4.81', // JPEG-LS Lossy
      '1.2.840.10008.1.2.4.90', // JPEG 2000 Lossless
      '1.2.840.10008.1.2.4.91', // JPEG 2000 Lossy
      '1.2.840.10008.1.2.5'     // RLE Lossless
    ];
    
    return compressedSyntaxes.includes(uid);
  }

  /**
   * Get string value from dataset
   */
  private getStringValue(dataSet: dicomParser.DataSet, tag: string): string | undefined {
    const element = dataSet.elements[tag];
    if (!element) return undefined;
    
    try {
      let value = dataSet.string(tag);
      
      // Handle person names specially
      if (tag === 'x00100010') { // Patient Name
        value = formatDICOMPersonName(value || '');
      }
      
      // Handle dates
      if (tag === 'x00080020' || tag === 'x00100030') { // Study Date, Patient Birth Date
        value = formatDICOMDate(value || '');
      }
      
      // Handle times
      if (tag === 'x00080030') { // Study Time
        value = formatDICOMTime(value || '');
      }
      
      return value?.trim();
    } catch {
      return undefined;
    }
  }

  /**
   * Get numeric value from dataset
   */
  private getNumberValue(dataSet: dicomParser.DataSet, tag: string): number | undefined {
    const element = dataSet.elements[tag];
    if (!element) return undefined;
    
    try {
      const value = dataSet.string(tag);
      if (!value) return undefined;
      
      const num = parseFloat(value);
      return isNaN(num) ? undefined : num;
    } catch {
      return undefined;
    }
  }

  /**
   * Extract pixel data from DICOM dataset
   */
  extractPixelData(dataSet: dicomParser.DataSet): DICOMPixelData | null {
    const pixelDataElement = dataSet.elements.x7fe00010;
    if (!pixelDataElement) return null;

    const rows = this.getNumberValue(dataSet, 'x00280010') || 0;
    const columns = this.getNumberValue(dataSet, 'x00280011') || 0;
    const bitsAllocated = this.getNumberValue(dataSet, 'x00280100') || 16;
    const bitsStored = this.getNumberValue(dataSet, 'x00280101') || bitsAllocated;
    const highBit = this.getNumberValue(dataSet, 'x00280102') || (bitsStored - 1);
    const pixelRepresentation = this.getNumberValue(dataSet, 'x00280103') || 0;
    const samplesPerPixel = this.getNumberValue(dataSet, 'x00280002') || 1;
    const planarConfiguration = this.getNumberValue(dataSet, 'x00280006');
    const photometricInterpretation = this.getStringValue(dataSet, 'x00280004') || 'MONOCHROME2';

    try {
      let pixelData: Uint8Array | Uint16Array | Int16Array;
      
      if (bitsAllocated <= 8) {
        pixelData = new Uint8Array(dataSet.byteArray.buffer, pixelDataElement.dataOffset, pixelDataElement.length);
      } else if (bitsAllocated <= 16) {
        if (pixelRepresentation === 1) {
          // Signed 16-bit
          pixelData = new Int16Array(dataSet.byteArray.buffer, pixelDataElement.dataOffset, pixelDataElement.length / 2);
        } else {
          // Unsigned 16-bit
          pixelData = new Uint16Array(dataSet.byteArray.buffer, pixelDataElement.dataOffset, pixelDataElement.length / 2);
        }
      } else {
        throw new Error(`Unsupported bits allocated: ${bitsAllocated}`);
      }

      return {
        data: pixelData,
        rows,
        columns,
        samplesPerPixel,
        bitsAllocated,
        bitsStored,
        highBit,
        pixelRepresentation,
        planarConfiguration,
        photometricInterpretation
      };
    } catch (error) {
      console.error('Failed to extract pixel data:', error);
      return null;
    }
  }
}