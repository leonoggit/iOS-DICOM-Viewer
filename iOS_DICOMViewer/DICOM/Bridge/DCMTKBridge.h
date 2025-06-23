#ifndef DCMTKBridge_h
#define DCMTKBridge_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DCMTKBridge : NSObject

/// Parse DICOM file and extract pixel data along with key metadata
/// @param filePath Path to the DICOM file
/// @param width Output parameter for image width
/// @param height Output parameter for image height
/// @param bitsStored Output parameter for bits stored per pixel
/// @param isSigned Output parameter indicating if pixel values are signed
/// @param windowCenter Output parameter for default window center
/// @param windowWidth Output parameter for default window width
/// @param numberOfFrames Output parameter for number of frames (multi-frame support)
/// @return Raw pixel data as NSData, or nil if parsing failed
+ (nullable NSData *)parsePixelDataFromFile:(NSString *)filePath 
                                      width:(int *)width 
                                     height:(int *)height 
                                 bitsStored:(int *)bitsStored 
                                   isSigned:(BOOL *)isSigned 
                                windowCenter:(double *)windowCenter 
                                 windowWidth:(double *)windowWidth
                               numberOfFrames:(int *)numberOfFrames;

/// Parse DICOM metadata without extracting pixel data (faster for thumbnails)
/// @param filePath Path to the DICOM file
/// @return Dictionary containing DICOM metadata
+ (nullable NSDictionary *)parseMetadataFromFile:(NSString *)filePath;

/// Extract specific frame data from multi-frame pixel data
/// @param pixelData Complete pixel data
/// @param frameIndex Index of the frame to extract (0-based)
/// @param width Image width
/// @param height Image height
/// @param bitsStored Bits stored per pixel
/// @return Frame data as NSData, or nil if extraction failed
+ (nullable NSData *)getFrameData:(NSData *)pixelData 
                       frameIndex:(int)frameIndex 
                            width:(int)width 
                           height:(int)height 
                       bitsStored:(int)bitsStored;

/// Check if file is a valid DICOM file
/// @param filePath Path to check
/// @return YES if file appears to be valid DICOM
+ (BOOL)isValidDICOMFile:(NSString *)filePath;

/// Get transfer syntax information
/// @param filePath Path to the DICOM file
/// @return Transfer syntax UID string
+ (nullable NSString *)getTransferSyntax:(NSString *)filePath;

/// Get SOP Class UID for determining file type capabilities
/// @param filePath Path to the DICOM file
/// @return SOP Class UID string
+ (nullable NSString *)getSOPClassUID:(NSString *)filePath;

/// Parse structured report content (for future segmentation support)
/// @param filePath Path to the DICOM SR file
/// @return Structured report data as dictionary
+ (nullable NSDictionary *)parseStructuredReport:(NSString *)filePath;

/// Parse DICOM RT Structure Set (for radiotherapy structures)
/// @param filePath Path to the DICOM RT Structure Set file
/// @return Structure set data as dictionary
+ (nullable NSDictionary *)parseRTStructureSet:(NSString *)filePath;

/// Parse DICOM Segmentation object
/// @param filePath Path to the DICOM SEG file
/// @return Segmentation data as dictionary
+ (nullable NSDictionary *)parseSegmentation:(NSString *)filePath;

/// Get image orientation and position for 3D reconstruction
/// @param filePath Path to the DICOM file
/// @return Dictionary with orientation and position data
+ (nullable NSDictionary *)getImageGeometry:(NSString *)filePath;

/// Diagnostic method for debugging pixel data issues
/// @param filePath Path to the DICOM file to diagnose
+ (void)diagnosePixelDataIssue:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END

#endif /* DCMTKBridge_h */
