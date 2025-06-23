#import "DCMTKBridge.h"
#import <Foundation/Foundation.h>

// DICOM constants
static const char DICOM_MAGIC[] = "DICM";
static const NSUInteger DICOM_PREAMBLE_SIZE = 128;
static const NSUInteger DICOM_MAGIC_SIZE = 4;

// DICOM VR (Value Representation) types
typedef enum {
    VR_UNKNOWN = 0,
    VR_AE, VR_AS, VR_AT, VR_CS, VR_DA, VR_DS, VR_DT, VR_FL, VR_FD,
    VR_IS, VR_LO, VR_LT, VR_OB, VR_OD, VR_OF, VR_OL, VR_OV, VR_OW,
    VR_PN, VR_SH, VR_SL, VR_SQ, VR_SS, VR_ST, VR_SV, VR_TM, VR_UC,
    VR_UI, VR_UL, VR_UN, VR_UR, VR_US, VR_UT, VR_UV
} DICOMValueRepresentation;

// DICOM Tag structure
typedef struct {
    uint16_t group;
    uint16_t element;
} DICOMTag;

// Common DICOM tags
static const DICOMTag TAG_TRANSFER_SYNTAX = {0x0002, 0x0010};
static const DICOMTag TAG_SOP_CLASS_UID = {0x0008, 0x0016};
static const DICOMTag TAG_PATIENT_NAME = {0x0010, 0x0010};
static const DICOMTag TAG_PATIENT_ID = {0x0010, 0x0020};
static const DICOMTag TAG_STUDY_INSTANCE_UID = {0x0020, 0x000D};
static const DICOMTag TAG_SERIES_INSTANCE_UID = {0x0020, 0x000E};
static const DICOMTag TAG_SOP_INSTANCE_UID = {0x0008, 0x0018};
static const DICOMTag TAG_STUDY_DESCRIPTION = {0x0008, 0x1030};
static const DICOMTag TAG_SERIES_DESCRIPTION = {0x0008, 0x103E};
static const DICOMTag TAG_MODALITY = {0x0008, 0x0060};
static const DICOMTag TAG_ROWS = {0x0028, 0x0010};
static const DICOMTag TAG_COLUMNS = {0x0028, 0x0011};
static const DICOMTag TAG_BITS_ALLOCATED = {0x0028, 0x0100};
static const DICOMTag TAG_BITS_STORED = {0x0028, 0x0101};
static const DICOMTag TAG_SAMPLES_PER_PIXEL = {0x0028, 0x0002};
static const DICOMTag TAG_PHOTOMETRIC_INTERPRETATION = {0x0028, 0x0004};
static const DICOMTag TAG_PIXEL_REPRESENTATION = {0x0028, 0x0103};
static const DICOMTag TAG_WINDOW_CENTER = {0x0028, 0x1050};
static const DICOMTag TAG_WINDOW_WIDTH = {0x0028, 0x1051};
static const DICOMTag TAG_RESCALE_INTERCEPT = {0x0028, 0x1052};
static const DICOMTag TAG_RESCALE_SLOPE = {0x0028, 0x1053};
static const DICOMTag TAG_PIXEL_SPACING = {0x0028, 0x0030};
static const DICOMTag TAG_SLICE_THICKNESS = {0x0018, 0x0050};
static const DICOMTag TAG_INSTANCE_NUMBER = {0x0020, 0x0013};
static const DICOMTag TAG_SERIES_NUMBER = {0x0020, 0x0011};
static const DICOMTag TAG_PIXEL_DATA = {0x7FE0, 0x0010};
static const DICOMTag TAG_NUMBER_OF_FRAMES = {0x0028, 0x0008};

@interface DCMTKBridge ()
+ (BOOL)isDICOMFile:(NSData *)data;
+ (NSDictionary *)parseDICOMElements:(NSData *)data;
+ (NSData *)readPixelData:(NSDictionary *)elements;
@end

@implementation DCMTKBridge

+ (nullable NSData *)parsePixelDataFromFile:(NSString *)filePath 
                                      width:(int *)width 
                                     height:(int *)height 
                                 bitsStored:(int *)bitsStored 
                                   isSigned:(BOOL *)isSigned 
                                windowCenter:(double *)windowCenter 
                                 windowWidth:(double *)windowWidth
                               numberOfFrames:(int *)numberOfFrames {
    
    NSLog(@"[LOG] DCMTK Bridge: Parsing pixel data from file: %@", filePath);
    
    // Read file data
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSLog(@"[ERROR] Failed to read file: %@", filePath);
        return nil;
    }
    
    NSLog(@"[LOG] DCMTK Bridge: File size: %lu bytes", (unsigned long)fileData.length);
    
    // Validate DICOM file
    if (![self isDICOMFile:fileData]) {
        NSLog(@"[ERROR] Not a valid DICOM file: %@", filePath);
        return nil;
    }
    
    NSLog(@"[OK] DCMTK Bridge: Valid DICOM file confirmed");
    
    // Parse DICOM elements
    NSDictionary *elements = [self parseDICOMElements:fileData];
    if (!elements) {
        NSLog(@"[ERROR] Failed to parse DICOM elements");
        return nil;
    }
    
    NSLog(@"[LOG] DCMTK Bridge: Parsed %lu DICOM elements", (unsigned long)elements.count);
    
    // Extract image parameters - try different formats
    NSNumber *rowsValue = elements[@"00280010"] ?: elements[@"280010"]; // Rows
    NSNumber *columnsValue = elements[@"00280011"] ?: elements[@"280011"]; // Columns
    NSNumber *bitsStoredValue = elements[@"00280101"] ?: elements[@"280101"]; // Bits Stored
    NSNumber *pixelRepValue = elements[@"00280103"] ?: elements[@"280103"]; // Pixel Representation
    NSNumber *windowCenterValue = elements[@"00281050"] ?: elements[@"281050"]; // Window Center
    NSNumber *windowWidthValue = elements[@"00281051"] ?: elements[@"281051"]; // Window Width
    NSNumber *framesValue = elements[@"00280008"] ?: elements[@"280008"]; // Number of Frames
    NSNumber *bitsAllocatedValue = elements[@"00280100"] ?: elements[@"280100"]; // Bits Allocated
    
    NSLog(@"[LOG] DCMTK Bridge: Image params - Rows: %@, Cols: %@, BitsStored: %@, BitsAllocated: %@", 
          rowsValue, columnsValue, bitsStoredValue, bitsAllocatedValue);
    
    if (!rowsValue || !columnsValue || !bitsStoredValue) {
        NSLog(@"[ERROR] Missing required image parameters");
        return nil;
    }
    
    *height = rowsValue.intValue;
    *width = columnsValue.intValue;
    *bitsStored = bitsStoredValue.intValue;
    *isSigned = pixelRepValue ? pixelRepValue.boolValue : NO;
    *windowCenter = windowCenterValue ? windowCenterValue.doubleValue : 32768.0;
    *windowWidth = windowWidthValue ? windowWidthValue.doubleValue : 65536.0;
    *numberOfFrames = framesValue ? framesValue.intValue : 1;
    
    // Extract pixel data
    NSData *pixelData = [self readPixelData:elements];
    if (!pixelData) {
        NSLog(@"[ERROR] Failed to extract pixel data");
        return nil;
    }
    
    NSLog(@"[OK] Successfully parsed DICOM: %dx%d, %d bits, %ld bytes", 
          *width, *height, *bitsStored, (long)pixelData.length);
    
    return pixelData;
}

+ (nullable NSDictionary *)parseMetadataFromFile:(NSString *)filePath {
    NSLog(@"[LOG] DCMTK Bridge: Parsing metadata from file: %@", filePath);
    
    // Read file data
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSLog(@"[ERROR] Failed to read file: %@", filePath);
        return nil;
    }
    
    // Validate DICOM file
    if (![self isDICOMFile:fileData]) {
        NSLog(@"[ERROR] Not a valid DICOM file: %@", filePath);
        return nil;
    }
    
    // Parse DICOM elements
    NSDictionary *elements = [self parseDICOMElements:fileData];
    if (!elements) {
        NSLog(@"[ERROR] Failed to parse DICOM elements");
        return nil;
    }
    
    // Log parsed elements for debugging
    NSLog(@"[LOG] DCMTK Bridge: Parsed %lu elements", (unsigned long)elements.count);
    
    // Only log specific important tags to reduce noise
    NSArray *importantTags = @[@"00080018", @"0020000D", @"0020000E", @"00100010", @"00081030", @"00080060"];
    for (NSString *key in elements.allKeys) {
        if ([importantTags containsObject:key]) {
            NSLog(@"[LOG] Important Element %@: %@", key, [elements[key] description]);
        }
    }
    
    // Convert to user-friendly metadata
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    
    // Patient information
    if (elements[@"00100010"]) metadata[@"PatientName"] = elements[@"00100010"];
    if (elements[@"00100020"]) metadata[@"PatientID"] = elements[@"00100020"];
    
    // Study information - Try multiple possible representations of Study Instance UID
    NSString *studyUID = nil;
    NSArray *studyUIDKeys = @[@"0020000D", @"20000D", @"0020000d", @"20000d"];
    for (NSString *key in studyUIDKeys) {
        if (elements[key]) {
            studyUID = [elements[key] description];
            break;
        }
    }
    if (studyUID) {
        metadata[@"StudyInstanceUID"] = studyUID;
    }
    
    // Series information - Try multiple possible representations
    NSString *seriesUID = nil;
    NSArray *seriesUIDKeys = @[@"0020000E", @"20000E", @"0020000e", @"20000e"];
    for (NSString *key in seriesUIDKeys) {
        if (elements[key]) {
            seriesUID = [elements[key] description];
            break;
        }
    }
    if (seriesUID) {
        metadata[@"SeriesInstanceUID"] = seriesUID;
    }
    
    // SOP Instance UID - Try multiple possible representations
    NSString *sopUID = nil;
    NSArray *sopUIDKeys = @[@"00080018", @"80018", @"0008018", @"8018"];
    for (NSString *key in sopUIDKeys) {
        if (elements[key]) {
            sopUID = [elements[key] description];
            break;
        }
    }
    if (sopUID) {
        metadata[@"SOPInstanceUID"] = sopUID;
    }
    
    // If we don't have Study or Series UIDs, generate consistent ones based on other metadata
    if (!studyUID) {
        // Try to create a consistent Study UID based on patient and study information
        NSString *patientID = elements[@"00100020"] ? [elements[@"00100020"] description] : @"UNKNOWN";
        NSString *studyDescription = elements[@"00081030"] ? [elements[@"00081030"] description] : @"UNKNOWN_STUDY";
        NSString *studyDate = elements[@"00080020"] ? [elements[@"00080020"] description] : @"UNKNOWN_DATE";
        
        // Create a hash-based consistent UID
        NSString *combinedString = [NSString stringWithFormat:@"%@_%@_%@", patientID, studyDescription, studyDate];
        NSInteger hash = [combinedString hash];
        studyUID = [NSString stringWithFormat:@"1.2.3.4.5.6.7.8.%ld", (long)ABS(hash) % 100000];
        metadata[@"StudyInstanceUID"] = studyUID;
        NSLog(@"[LOG] Generated consistent Study UID: %@", studyUID);
    }
    
    if (!seriesUID && studyUID) {
        // Generate a consistent Series UID based on study UID and modality
        NSString *modality = elements[@"00080060"] ? [elements[@"00080060"] description] : @"UNKNOWN";
        NSString *seriesDescription = elements[@"0008103E"] ? [elements[@"0008103E"] description] : modality;
        
        NSString *combinedString = [NSString stringWithFormat:@"%@_%@", studyUID, seriesDescription];
        NSInteger hash = [combinedString hash];
        seriesUID = [NSString stringWithFormat:@"%@.%ld", studyUID, (long)ABS(hash) % 10000];
        metadata[@"SeriesInstanceUID"] = seriesUID;
        NSLog(@"[LOG] Generated consistent Series UID: %@", seriesUID);
    }
    
    if (elements[@"00081030"]) metadata[@"StudyDescription"] = elements[@"00081030"];
    if (elements[@"0008103E"]) metadata[@"SeriesDescription"] = elements[@"0008103E"];
    if (elements[@"00080060"]) metadata[@"Modality"] = elements[@"00080060"];
    
    // Image information
    if (elements[@"00280010"]) metadata[@"Rows"] = elements[@"00280010"];
    if (elements[@"00280011"]) metadata[@"Columns"] = elements[@"00280011"];
    if (elements[@"00280100"]) metadata[@"BitsAllocated"] = elements[@"00280100"];
    if (elements[@"00280101"]) metadata[@"BitsStored"] = elements[@"00280101"];
    if (elements[@"00280002"]) metadata[@"SamplesPerPixel"] = elements[@"00280002"];
    if (elements[@"00280004"]) metadata[@"PhotometricInterpretation"] = elements[@"00280004"];
    if (elements[@"00280103"]) metadata[@"PixelRepresentation"] = elements[@"00280103"];
    if (elements[@"00281050"]) metadata[@"WindowCenter"] = @[elements[@"00281050"]];
    if (elements[@"00281051"]) metadata[@"WindowWidth"] = @[elements[@"00281051"]];
    
    // Rescale values - try different key formats
    NSNumber *rescaleIntercept = elements[@"00281052"] ?: elements[@"281052"];
    NSNumber *rescaleSlope = elements[@"00281053"] ?: elements[@"281053"];
    
    if (rescaleIntercept) {
        metadata[@"RescaleIntercept"] = rescaleIntercept;
        NSLog(@"[LOG] Found RescaleIntercept: %@", rescaleIntercept);
    }
    if (rescaleSlope) {
        metadata[@"RescaleSlope"] = rescaleSlope;
        NSLog(@"[LOG] Found RescaleSlope: %@", rescaleSlope);
    }
    if (elements[@"00280030"]) metadata[@"PixelSpacing"] = @[elements[@"00280030"]];
    if (elements[@"00180050"]) metadata[@"SliceThickness"] = elements[@"00180050"];
    if (elements[@"00200013"]) metadata[@"InstanceNumber"] = elements[@"00200013"];
    if (elements[@"00200011"]) metadata[@"SeriesNumber"] = elements[@"00200011"];
    
    NSLog(@"[OK] Successfully parsed metadata with %lu fields", (unsigned long)metadata.count);
    
    return [metadata copy];
}

+ (BOOL)isDICOMFile:(NSData *)data {
    if (data.length < DICOM_PREAMBLE_SIZE + DICOM_MAGIC_SIZE) {
        return NO;
    }
    
    // Check for DICOM magic number at offset 128
    const char *bytes = (const char *)data.bytes;
    return memcmp(bytes + DICOM_PREAMBLE_SIZE, DICOM_MAGIC, DICOM_MAGIC_SIZE) == 0;
}

+ (NSDictionary *)parseDICOMElements:(NSData *)data {
    NSMutableDictionary *elements = [NSMutableDictionary dictionary];
    
    // Skip preamble and magic
    NSUInteger offset = DICOM_PREAMBLE_SIZE + DICOM_MAGIC_SIZE;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger dataLength = data.length;
    
    BOOL isLittleEndian = YES; // Most DICOM files are little endian
    BOOL isExplicitVR = YES;   // Assume explicit VR initially
    
    // Check for transfer syntax in the first few elements to determine endianness and VR
    // This is a simplified check - a full implementation would parse the meta information properly
    NSString *transferSyntax = elements[@"00020010"];
    if (transferSyntax) {
        NSLog(@"[LOG] Transfer Syntax: %@", transferSyntax);
        // 1.2.840.10008.1.2 = Implicit VR Little Endian
        // 1.2.840.10008.1.2.1 = Explicit VR Little Endian
        // 1.2.840.10008.1.2.2 = Explicit VR Big Endian
        if ([transferSyntax containsString:@"1.2.840.10008.1.2.2"]) {
            isLittleEndian = NO;
        } else if ([transferSyntax containsString:@"1.2.840.10008.1.2"] && ![transferSyntax containsString:@"1.2.840.10008.1.2.1"]) {
            isExplicitVR = NO;
        }
    }
    
    while (offset < dataLength - 8) {
        // Read tag
        if (offset + 4 > dataLength) break;
        
        uint16_t group = isLittleEndian ? 
            (bytes[offset] | (bytes[offset+1] << 8)) :
            (bytes[offset+1] | (bytes[offset] << 8));
        uint16_t element = isLittleEndian ?
            (bytes[offset+2] | (bytes[offset+3] << 8)) :
            (bytes[offset+3] | (bytes[offset+2] << 8));
        
        offset += 4;
        
        // Create tag string
        NSString *tagString = [NSString stringWithFormat:@"%04X%04X", group, element];
        
        // Debug logging for pixel data tag
        if (group == 0x7FE0 && element == 0x0010) {
            NSLog(@"[DEBUG] Found pixel data tag! Group: 0x%04X, Element: 0x%04X, Tag String: %@", group, element, tagString);
        }
        
        // Read VR and length
        uint32_t length = 0;
        NSUInteger valueOffset = offset;
        
        if (isExplicitVR && group != 0xFFFE) {
            // Explicit VR
            if (offset + 2 > dataLength) break;
            
            char vr[3] = {static_cast<char>(bytes[offset]), static_cast<char>(bytes[offset+1]), 0};
            offset += 2;
            
            // Check if this VR uses 32-bit length
            if (strcmp(vr, "OB") == 0 || strcmp(vr, "OW") == 0 || 
                strcmp(vr, "OF") == 0 || strcmp(vr, "SQ") == 0 ||
                strcmp(vr, "UT") == 0 || strcmp(vr, "UN") == 0) {
                // Skip reserved bytes
                offset += 2;
                if (offset + 4 > dataLength) break;
                length = isLittleEndian ?
                    (bytes[offset] | (bytes[offset+1] << 8) | (bytes[offset+2] << 16) | (bytes[offset+3] << 24)) :
                    (bytes[offset+3] | (bytes[offset+2] << 8) | (bytes[offset+1] << 16) | (bytes[offset] << 24));
                offset += 4;
            } else {
                // 16-bit length
                if (offset + 2 > dataLength) break;
                length = isLittleEndian ?
                    (bytes[offset] | (bytes[offset+1] << 8)) :
                    (bytes[offset+1] | (bytes[offset] << 8));
                offset += 2;
            }
        } else {
            // Implicit VR
            if (offset + 4 > dataLength) break;
            length = isLittleEndian ?
                (bytes[offset] | (bytes[offset+1] << 8) | (bytes[offset+2] << 16) | (bytes[offset+3] << 24)) :
                (bytes[offset+3] | (bytes[offset+2] << 8) | (bytes[offset+1] << 16) | (bytes[offset] << 24));
            offset += 4;
        }
        
        // Read value
        if (length > 0 && offset + length <= dataLength && length < 0x7FFFFFFF) { // Sanity check for length
            if (group == 0x7FE0 && element == 0x0010) {
                // Pixel data - store as NSData
                NSData *pixelData = [NSData dataWithBytes:bytes + offset length:length];
                elements[tagString] = pixelData;
                NSLog(@"[LOG] Found pixel data with tag %@: (%u bytes)", tagString, length);
                NSLog(@"[LOG] Pixel data tag format check - group: 0x%04X, element: 0x%04X -> tag: %@", group, element, tagString);
            } else if (length < 10240) { // Increased limit for text data (some UIDs can be long)
                // Try to parse as string for metadata
                NSString *value = [[NSString alloc] initWithBytes:bytes + offset 
                                                           length:length 
                                                         encoding:NSUTF8StringEncoding];
                if (!value) {
                    value = [[NSString alloc] initWithBytes:bytes + offset 
                                                     length:length 
                                                   encoding:NSASCIIStringEncoding];
                }
                
                if (value) {
                    // Clean up string (remove null terminators and trim)
                    value = [value stringByReplacingOccurrencesOfString:@"\0" withString:@""];
                    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
                    if (value.length > 0) {
                        // Try to convert to number if it looks like one
                        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                        NSNumber *numberValue = [formatter numberFromString:value];
                        elements[tagString] = numberValue ?: value;
                        
                        // Log important tags (including all possible formats)
                        if ([tagString isEqualToString:@"0020000D"] || [tagString isEqualToString:@"20000D"] || 
                            [tagString isEqualToString:@"0020000E"] || [tagString isEqualToString:@"20000E"] || 
                            [tagString isEqualToString:@"00080018"] || [tagString isEqualToString:@"80018"] ||
                            [tagString isEqualToString:@"00100010"] || [tagString isEqualToString:@"100010"] ||
                            [tagString isEqualToString:@"00081030"] || [tagString isEqualToString:@"81030"]) {
                            NSLog(@"[LOG] Found important tag %@: %@", tagString, value);
                        }
                    }
                } else {
                    // Store as raw data if can't parse as string
                    NSData *rawData = [NSData dataWithBytes:bytes + offset length:length];
                    elements[tagString] = rawData;
                    NSLog(@"[LOG] Stored raw data for tag %@: %u bytes", tagString, length);
                }
            } else {
                // For large elements that aren't pixel data, just store a placeholder
                // This prevents memory issues while still allowing the parser to continue
                NSLog(@"[LOG] Large element %@: %u bytes (storing placeholder)", tagString, length);
                elements[tagString] = [NSString stringWithFormat:@"<Large Data: %u bytes>", length];
            }
        } else if (length > 0) {
            NSLog(@"[LOG] Skipping invalid element %@: length=%u, remaining=%lu", tagString, length, dataLength - offset);
        }
        
        offset += length;
        
        // Handle odd length padding
        if (length % 2 == 1 && offset < dataLength) {
            offset++;
        }
    }
    
    return [elements copy];
}

+ (NSData *)readPixelData:(NSDictionary *)elements {
    // Log all element keys to debug
    NSLog(@"[DEBUG] DCMTK Bridge: Looking for pixel data in elements dictionary with %lu keys", (unsigned long)elements.count);
    
    // Check for pixel data with different key formats
    NSArray *pixelDataKeys = @[@"7FE00010", @"7fe00010", @"7FE00010", @"7fe00010"];
    for (NSString *key in pixelDataKeys) {
        id value = elements[key];
        if (value) {
            if ([value isKindOfClass:[NSData class]]) {
                NSData *pixelData = (NSData *)value;
                NSLog(@"[OK] DCMTK Bridge: Found pixel data with key %@: %lu bytes", key, (unsigned long)pixelData.length);
                return pixelData;
            } else {
                NSLog(@"[WARN] DCMTK Bridge: Found key %@ but value is not NSData: %@", key, [value class]);
            }
        }
    }
    
    // Debug: Log some keys to see the format
    int logCount = 0;
    for (NSString *key in elements.allKeys) {
        if (logCount < 10 || [key rangeOfString:@"7FE0"].location != NSNotFound || [key rangeOfString:@"7fe0"].location != NSNotFound) {
            id value = elements[key];
            if ([value isKindOfClass:[NSData class]]) {
                NSLog(@"[DEBUG] Key: %@ -> NSData (%lu bytes)", key, (unsigned long)[(NSData *)value length]);
            } else {
                NSLog(@"[DEBUG] Key: %@ -> %@", key, [value class]);
            }
        }
        logCount++;
        if (logCount > 20) break;
    }
    
    NSLog(@"[ERROR] DCMTK Bridge: No pixel data found in elements dictionary");
    return nil;
}

+ (nullable NSData *)getFrameData:(NSData *)pixelData 
                       frameIndex:(int)frameIndex 
                            width:(int)width 
                           height:(int)height 
                       bitsStored:(int)bitsStored {
    
    NSLog(@"[LOG] DCMTK Bridge: Extracting frame %d from multi-frame data", frameIndex);
    
    NSInteger bytesPerPixel = (bitsStored + 7) / 8;
    NSInteger frameSize = width * height * bytesPerPixel;
    NSInteger offset = frameIndex * frameSize;
    
    if (offset + frameSize > pixelData.length) {
        NSLog(@"[ERROR] Frame index out of bounds");
        return nil;
    }
    
    NSData *frameData = [pixelData subdataWithRange:NSMakeRange(offset, frameSize)];
    NSLog(@"[OK] Extracted frame data (%ld bytes)", (long)frameData.length);
    
    return frameData;
}

+ (BOOL)isValidDICOMFile:(NSString *)filePath {
    NSLog(@"[LOG] DCMTK Bridge: Checking if file is valid DICOM: %@", filePath);
    
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        return NO;
    }
    
    BOOL isValid = [self isDICOMFile:fileData];
    NSLog(@"[OK] File validation result: %@", isValid ? @"VALID" : @"INVALID");
    
    return isValid;
}

+ (nullable NSString *)getTransferSyntax:(NSString *)filePath {
    NSLog(@"[LOG] DCMTK Bridge: Getting transfer syntax for: %@", filePath);
    
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData || ![self isDICOMFile:fileData]) {
        return nil;
    }
    
    NSDictionary *elements = [self parseDICOMElements:fileData];
    NSString *transferSyntax = elements[@"00020010"]; // Transfer Syntax UID
    
    if (!transferSyntax) {
        transferSyntax = @"1.2.840.10008.1.2.1"; // Default: Explicit VR Little Endian
    }
    
    NSLog(@"[OK] Transfer syntax: %@", transferSyntax);
    return transferSyntax;
}

+ (nullable NSString *)getSOPClassUID:(NSString *)filePath {
    NSLog(@"[LOG] DCMTK Bridge: Getting SOP Class UID for: %@", filePath);
    
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData || ![self isDICOMFile:fileData]) {
        return nil;
    }
    
    NSDictionary *elements = [self parseDICOMElements:fileData];
    NSString *sopClassUID = elements[@"00080016"]; // SOP Class UID
    
    if (!sopClassUID) {
        sopClassUID = @"1.2.840.10008.5.1.4.1.1.2"; // Default: CT Image Storage
    }
    
    NSLog(@"[OK] SOP Class UID: %@", sopClassUID);
    return sopClassUID;
}

+ (nullable NSDictionary *)parseStructuredReport:(NSString *)filePath {
    NSLog(@"[LOG] DCMTK Bridge: Parsing structured report: %@", filePath);
    
    // Basic implementation - would need more sophisticated parsing for real SR
    NSDictionary *srData = @{
        @"ContentSequence": @[],
        @"CompletionFlag": @"COMPLETE",
        @"VerificationFlag": @"UNVERIFIED"
    };
    
    NSLog(@"[OK] Generated structured report");
    return srData;
}

+ (nullable NSDictionary *)parseRTStructureSet:(NSString *)filePath {
    NSLog(@"[LOG] DCMTK Bridge: Parsing RT Structure Set: %@", filePath);
    
    // Basic implementation - would need more sophisticated parsing for real RT
    NSDictionary *rtData = @{
        @"StructureSetLabel": @"RT Structure Set",
        @"ROIContourSequence": @[],
        @"RTROIObservationsSequence": @[]
    };
    
    NSLog(@"[OK] Generated RT Structure Set");
    return rtData;
}

+ (nullable NSDictionary *)parseSegmentation:(NSString *)filePath {
    NSLog(@"[LOG] DCMTK Bridge: Parsing segmentation: %@", filePath);
    
    // Basic implementation - would need more sophisticated parsing for real SEG
    NSDictionary *segData = @{
        @"SegmentSequence": @[],
        @"SegmentationType": @"BINARY",
        @"MaximumFractionalValue": @1
    };
    
    NSLog(@"[OK] Generated segmentation");
    return segData;
}

+ (nullable NSDictionary *)getImageGeometry:(NSString *)filePath {
    NSLog(@"[LOG] DCMTK Bridge: Getting image geometry for: %@", filePath);
    
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData || ![self isDICOMFile:fileData]) {
        return nil;
    }
    
    NSDictionary *elements = [self parseDICOMElements:fileData];
    
    NSMutableDictionary *geometry = [NSMutableDictionary dictionary];
    
    // Image orientation and position would be parsed from specific DICOM tags
    // This is a simplified implementation
    if (elements[@"00200037"]) geometry[@"ImageOrientationPatient"] = elements[@"00200037"];
    if (elements[@"00200032"]) geometry[@"ImagePositionPatient"] = elements[@"00200032"];
    if (elements[@"00280030"]) geometry[@"PixelSpacing"] = elements[@"00280030"];
    if (elements[@"00180050"]) geometry[@"SliceThickness"] = elements[@"00180050"];
    
    NSLog(@"[OK] Generated image geometry");
    return [geometry copy];
}

+ (void)diagnosePixelDataIssue:(NSString *)filePath {
    NSLog(@"\n===== DICOM DIAGNOSTIC REPORT =====");
    NSLog(@"[FILE] File: %@", filePath);
    
    // Check file exists and size
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:filePath]) {
        NSLog(@"[ERROR] File does not exist!");
        return;
    }
    
    NSDictionary *attrs = [fm attributesOfItemAtPath:filePath error:nil];
    NSLog(@"[STATS] File size: %lld bytes", [attrs fileSize]);
    
    // Read and validate file
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSLog(@"[ERROR] Cannot read file!");
        return;
    }
    
    BOOL isValid = [self isDICOMFile:fileData];
    NSLog(@"[CHECK] DICOM validation: %@", isValid ? @"VALID" : @"INVALID");
    
    if (!isValid) {
        NSLog(@"[ERROR] Not a valid DICOM file - missing DICM magic number at offset 128");
        return;
    }
    
    // Parse elements
    NSDictionary *elements = [self parseDICOMElements:fileData];
    NSLog(@"[INFO] Total elements parsed: %lu", (unsigned long)elements.count);
    
    // Check critical image parameters
    NSLog(@"\n[PARAMS] IMAGE PARAMETERS:");
    NSNumber *rows = elements[@"00280010"] ?: elements[@"280010"];
    NSNumber *cols = elements[@"00280011"] ?: elements[@"280011"];
    NSNumber *bitsStored = elements[@"00280101"] ?: elements[@"280101"];
    NSNumber *bitsAllocated = elements[@"00280100"] ?: elements[@"280100"];
    NSNumber *pixelRep = elements[@"00280103"] ?: elements[@"280103"];
    
    NSLog(@"  Rows: %@", rows ?: @"MISSING");
    NSLog(@"  Columns: %@", cols ?: @"MISSING");
    NSLog(@"  Bits Stored: %@", bitsStored ?: @"MISSING");
    NSLog(@"  Bits Allocated: %@", bitsAllocated ?: @"MISSING");
    NSLog(@"  Pixel Representation: %@ (%@)", pixelRep ?: @"MISSING", pixelRep ? (pixelRep.intValue ? @"signed" : @"unsigned") : @"?");
    
    // Check window/level
    NSNumber *windowCenter = elements[@"00281050"] ?: elements[@"281050"];
    NSNumber *windowWidth = elements[@"00281051"] ?: elements[@"281051"];
    NSLog(@"\n[DEBUG] WINDOW/LEVEL:");
    NSLog(@"  Window Center: %@", windowCenter ?: @"MISSING");
    NSLog(@"  Window Width: %@", windowWidth ?: @"MISSING");
    
    // Check rescale values
    NSNumber *rescaleInt = elements[@"00281052"] ?: elements[@"281052"];
    NSNumber *rescaleSlope = elements[@"00281053"] ?: elements[@"281053"];
    NSLog(@"\n[RESCALE] RESCALE VALUES:");
    NSLog(@"  Rescale Intercept: %@", rescaleInt ?: @"MISSING (will use 0)");
    NSLog(@"  Rescale Slope: %@", rescaleSlope ?: @"MISSING (will use 1)");
    
    // Check for pixel data
    NSLog(@"\n[DATA] PIXEL DATA:");
    NSData *pixelData = [self readPixelData:elements];
    if (pixelData) {
        NSLog(@"  [OK] Pixel data found: %lu bytes", (unsigned long)pixelData.length);
        
        // Calculate expected size
        if (rows && cols && bitsAllocated) {
            NSInteger expectedSize = rows.integerValue * cols.integerValue * (bitsAllocated.integerValue / 8);
            NSLog(@"  Expected size: %ld bytes", (long)expectedSize);
            NSLog(@"  Size match: %@", (pixelData.length == expectedSize) ? @"YES" : @"NO");
            
            if (pixelData.length != expectedSize) {
                NSLog(@"  [WARN] Size mismatch! Actual: %lu, Expected: %ld", (unsigned long)pixelData.length, (long)expectedSize);
            }
        }
        
        // Sample some pixel values
        if (pixelData.length >= 20) {
            const uint16_t *pixels = (const uint16_t *)pixelData.bytes;
            NSLog(@"\n  Sample pixel values (first 10):");
            for (int i = 0; i < 10 && i < pixelData.length/2; i++) {
                NSLog(@"    Pixel[%d]: %u", i, pixels[i]);
            }
        }
    } else {
        NSLog(@"  [ERROR] NO PIXEL DATA FOUND!");
        
        // Debug: Look for pixel data tag in different formats
        NSArray *possibleKeys = @[@"7FE00010", @"7fe00010", @"7FE00010", @"7fe00010"];
        for (NSString *key in possibleKeys) {
            if (elements[key]) {
                NSLog(@"  [DEBUG] Found data with key '%@'", key);
                break;
            }
        }
    }
    
    // Check transfer syntax
    NSString *transferSyntax = [self getTransferSyntax:filePath];
    NSLog(@"\n[SYNTAX] Transfer Syntax: %@", transferSyntax);
    
    NSLog(@"\n===== END DIAGNOSTIC REPORT =====\n");
}

@end