import Foundation

/// DICOM Error types for comprehensive error handling
enum DICOMError: Error, LocalizedError {
    case invalidFile
    case failedToParse
    case failedToParseMetadata
    case unsupportedFormat
    case unsupportedTransferSyntax(String)
    case missingPixelData
    case invalidPixelData
    case memoryAllocationFailed
    case fileNotFound
    case permissionDenied
    case corruptedData
    case networkError
    case unknownSOPClass(String)
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "Invalid DICOM file format"
        case .failedToParse:
            return "Failed to parse DICOM file"
        case .failedToParseMetadata:
            return "Failed to parse DICOM metadata"
        case .unsupportedFormat:
            return "Unsupported DICOM format"
        case .unsupportedTransferSyntax(let syntax):
            return "Unsupported transfer syntax: \(syntax)"
        case .missingPixelData:
            return "DICOM file contains no pixel data"
        case .invalidPixelData:
            return "Invalid or corrupted pixel data"
        case .memoryAllocationFailed:
            return "Failed to allocate memory for image data"
        case .fileNotFound:
            return "DICOM file not found"
        case .permissionDenied:
            return "Permission denied accessing DICOM file"
        case .corruptedData:
            return "DICOM file appears to be corrupted"
        case .networkError:
            return "Network error while retrieving DICOM data"
        case .unknownSOPClass(let sopClass):
            return "Unknown SOP Class: \(sopClass)"
        case .processingFailed:
            return "Processing failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidFile, .unsupportedFormat:
            return "Please ensure the file is a valid DICOM file with a supported format"
        case .failedToParse, .failedToParseMetadata:
            return "The DICOM file may be corrupted. Try with a different file"
        case .missingPixelData:
            return "This DICOM file does not contain viewable image data"
        case .memoryAllocationFailed:
            return "Close other applications to free up memory and try again"
        case .fileNotFound:
            return "Check that the file exists and try again"
        case .permissionDenied:
            return "Grant file access permission and try again"
        case .networkError:
            return "Check your network connection and try again"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
}
