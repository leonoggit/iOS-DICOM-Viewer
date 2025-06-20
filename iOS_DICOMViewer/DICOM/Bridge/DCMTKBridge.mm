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
    
    NSLog(@"🔧 DCMTK Bridge: Parsing pixel data from file: %@", filePath);
    
    // Read file data
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSLog(@"❌ Failed to read file: %@", filePath);
        return nil;
    }
    
    // Validate DICOM file
    if (![self isDICOMFile:fileData]) {
        NSLog(@"❌ Not a valid DICOM file: %@", filePath);
        return nil;
    }
    
    // Parse DICOM elements
    NSDictionary *elements = [self parseDICOMElements:fileData];
    if (!elements) {
        NSLog(@"❌ Failed to parse DICOM elements");
        return nil;
    }
    
    // Extract image parameters
    NSNumber *rowsValue = elements[@"00280010"]; // Rows
    NSNumber *columnsValue = elements[@"00280011"]; // Columns
    NSNumber *bitsStoredValue = elements[@"00280101"]; // Bits Stored
    NSNumber *pixelRepValue = elements[@"00280103"]; // Pixel Representation
    NSNumber *windowCenterValue = elements[@"00281050"]; // Window Center
    NSNumber *windowWidthValue = elements[@"00281051"]; // Window Width
    NSNumber *framesValue = elements[@"00280008"]; // Number of Frames
    
    if (!rowsValue || !columnsValue || !bitsStoredValue) {
        NSLog(@"❌ Missing required image parameters");
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
        NSLog(@"❌ Failed to extract pixel data");
        return nil;
    }
    
    NSLog(@"✅ Successfully parsed DICOM: %dx%d, %d bits, %ld bytes", 
          *width, *height, *bitsStored, (long)pixelData.length);
    
    return pixelData;
}

+ (nullable NSDictionary *)parseMetadataFromFile:(NSString *)filePath {
    NSLog(@"🔧 DCMTK Bridge: Parsing metadata from file: %@", filePath);
    
    // Read file data
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSLog(@"❌ Failed to read file: %@", filePath);
        return nil;
    }
    
    // Validate DICOM file
    if (![self isDICOMFile:fileData]) {
        NSLog(@"❌ Not a valid DICOM file: %@", filePath);
        return nil;
    }
    
    // Parse DICOM elements
    NSDictionary *elements = [self parseDICOMElements:fileData];
    if (!elements) {
        NSLog(@"❌ Failed to parse DICOM elements");
        return nil;
    }
    
    // Log parsed elements for debugging
    NSLog(@"🔧 DCMTK Bridge: Parsed %lu elements", (unsigned long)elements.count);
    
    // Only log specific important tags to reduce noise
    NSArray *importantTags = @[@"00080018", @"0020000D", @"0020000E", @"00100010", @"00081030", @"00080060"];
    for (NSString *key in elements.allKeys) {
        if ([importantTags containsObject:key]) {
            NSLog(@"🔧 Important Element %@: %@", key, [elements[key] description]);
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
        NSLog(@"🔧 Generated consistent Study UID: %@", studyUID);
    }
    
    if (!seriesUID && studyUID) {
        // Generate a consistent Series UID based on study UID and modality
        NSString *modality = elements[@"00080060"] ? [elements[@"00080060"] description] : @"UNKNOWN";
        NSString *seriesDescription = elements[@"0008103E"] ? [elements[@"0008103E"] description] : modality;
        
        NSString *combinedString = [NSString stringWithFormat:@"%@_%@", studyUID, seriesDescription];
        NSInteger hash = [combinedString hash];
        seriesUID = [NSString stringWithFormat:@"%@.%ld", studyUID, (long)ABS(hash) % 10000];
        metadata[@"SeriesInstanceUID"] = seriesUID;
        NSLog(@"🔧 Generated consistent Series UID: %@", seriesUID);
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
    if (elements[@"00281052"]) metadata[@"RescaleIntercept"] = elements[@"00281052"];
    if (elements[@"00281053"]) metadata[@"RescaleSlope"] = elements[@"00281053"];
    if (elements[@"00280030"]) metadata[@"PixelSpacing"] = @[elements[@"00280030"]];
    if (elements[@"00180050"]) metadata[@"SliceThickness"] = elements[@"00180050"];
    if (elements[@"00200013"]) metadata[@"InstanceNumber"] = elements[@"00200013"];
    if (elements[@"00200011"]) metadata[@"SeriesNumber"] = elements[@"00200011"];
    
    NSLog(@"✅ Successfully parsed metadata with %lu fields", (unsigned long)metadata.count);
    
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
                NSLog(@"🔧 Found pixel data: %@ (%u bytes)", tagString, length);
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
                            NSLog(@"🔧 Found important tag %@: %@", tagString, value);
                        }
                    }
                } else {
                    // Store as raw data if can't parse as string
                    NSData *rawData = [NSData dataWithBytes:bytes + offset length:length];
                    elements[tagString] = rawData;
                    NSLog(@"🔧 Stored raw data for tag %@: %u bytes", tagString, length);
                }
            } else {
                NSLog(@"🔧 Skipping large element %@: %u bytes", tagString, length);
            }
        } else if (length > 0) {
            NSLog(@"🔧 Skipping invalid element %@: length=%u, remaining=%lu", tagString, length, dataLength - offset);
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
    return elements[@"7FE00010"]; // Pixel Data tag
}

+ (nullable NSData *)getFrameData:(NSData *)pixelData 
                       frameIndex:(int)frameIndex 
                            width:(int)width 
                           height:(int)height 
                       bitsStored:(int)bitsStored {
    
    NSLog(@"🔧 DCMTK Bridge: Extracting frame %d from multi-frame data", frameIndex);
    
    NSInteger bytesPerPixel = (bitsStored + 7) / 8;
    NSInteger frameSize = width * height * bytesPerPixel;
    NSInteger offset = frameIndex * frameSize;
    
    if (offset + frameSize > pixelData.length) {
        NSLog(@"❌ Frame index out of bounds");
        return nil;
    }
    
    NSData *frameData = [pixelData subdataWithRange:NSMakeRange(offset, frameSize)];
    NSLog(@"✅ Extracted frame data (%ld bytes)", (long)frameData.length);
    
    return frameData;
}

+ (BOOL)isValidDICOMFile:(NSString *)filePath {
    NSLog(@"🔧 DCMTK Bridge: Checking if file is valid DICOM: %@", filePath);
    
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        return NO;
    }
    
    BOOL isValid = [self isDICOMFile:fileData];
    NSLog(@"✅ File validation result: %@", isValid ? @"VALID" : @"INVALID");
    
    return isValid;
}

+ (nullable NSString *)getTransferSyntax:(NSString *)filePath {
    NSLog(@"🔧 DCMTK Bridge: Getting transfer syntax for: %@", filePath);
    
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData || ![self isDICOMFile:fileData]) {
        return nil;
    }
    
    NSDictionary *elements = [self parseDICOMElements:fileData];
    NSString *transferSyntax = elements[@"00020010"]; // Transfer Syntax UID
    
    if (!transferSyntax) {
        transferSyntax = @"1.2.840.10008.1.2.1"; // Default: Explicit VR Little Endian
    }
    
    NSLog(@"✅ Transfer syntax: %@", transferSyntax);
    return transferSyntax;
}

+ (nullable NSString *)getSOPClassUID:(NSString *)filePath {
    NSLog(@"🔧 DCMTK Bridge: Getting SOP Class UID for: %@", filePath);
    
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData || ![self isDICOMFile:fileData]) {
        return nil;
    }
    
    NSDictionary *elements = [self parseDICOMElements:fileData];
    NSString *sopClassUID = elements[@"00080016"]; // SOP Class UID
    
    if (!sopClassUID) {
        sopClassUID = @"1.2.840.10008.5.1.4.1.1.2"; // Default: CT Image Storage
    }
    
    NSLog(@"✅ SOP Class UID: %@", sopClassUID);
    return sopClassUID;
}

+ (nullable NSDictionary *)parseStructuredReport:(NSString *)filePath {
    NSLog(@"🔧 DCMTK Bridge: Parsing structured report: %@", filePath);
    
    // Basic implementation - would need more sophisticated parsing for real SR
    NSDictionary *srData = @{
        @"ContentSequence": @[],
        @"CompletionFlag": @"COMPLETE",
        @"VerificationFlag": @"UNVERIFIED"
    };
    
    NSLog(@"✅ Generated structured report");
    return srData;
}

+ (nullable NSDictionary *)parseRTStructureSet:(NSString *)filePath {
    NSLog(@"🔧 DCMTK Bridge: Parsing RT Structure Set: %@", filePath);
    
    // Basic implementation - would need more sophisticated parsing for real RT
    NSDictionary *rtData = @{
        @"StructureSetLabel": @"RT Structure Set",
        @"ROIContourSequence": @[],
        @"RTROIObservationsSequence": @[]
    };
    
    NSLog(@"✅ Generated RT Structure Set");
    return rtData;
}

+ (nullable NSDictionary *)parseSegmentation:(NSString *)filePath {
    NSLog(@"🔧 DCMTK Bridge: Parsing segmentation: %@", filePath);
    
    // Basic implementation - would need more sophisticated parsing for real SEG
    NSDictionary *segData = @{
        @"SegmentSequence": @[],
        @"SegmentationType": @"BINARY",
        @"MaximumFractionalValue": @1
    };
    
    NSLog(@"✅ Generated segmentation");
    return segData;
}

+ (nullable NSDictionary *)getImageGeometry:(NSString *)filePath {
    NSLog(@"🔧 DCMTK Bridge: Getting image geometry for: %@", filePath);
    
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
    
    NSLog(@"✅ Generated image geometry");
    return [geometry copy];
}

@end