//
//  DICOMError+Enhanced.swift
//  iOS_DICOMViewer
//
//  Enhanced error handling for clinical compliance and detailed diagnostics
//  Provides comprehensive error categorization and recovery suggestions
//

import Foundation

// MARK: - Enhanced Error Support Types

extension DICOMError {
    
    enum InvalidFileReason {
        case notDICOM
        case missingMetaHeader
        case invalidMagicNumber
        case unsupportedVersion
        
        var localizedDescription: String {
            switch self {
            case .notDICOM:
                return "Not a DICOM file"
            case .missingMetaHeader:
                return "Missing DICOM meta header"
            case .invalidMagicNumber:
                return "Invalid DICM magic number"
            case .unsupportedVersion:
                return "Unsupported DICOM version"
            }
        }
    }
    
    enum ParseError {
        case malformedHeader
        case invalidDataElement
        case unsupportedEncoding
        case truncatedFile
        
        var localizedDescription: String {
            switch self {
            case .malformedHeader:
                return "Malformed DICOM header"
            case .invalidDataElement:
                return "Invalid data element"
            case .unsupportedEncoding:
                return "Unsupported character encoding"
            case .truncatedFile:
                return "File appears truncated"
            }
        }
    }
    
    enum PixelDataError {
        case invalidBitsAllocated
        case unsupportedPhotometricInterpretation
        case compressionError
        case invalidDimensions
        
        var localizedDescription: String {
            switch self {
            case .invalidBitsAllocated:
                return "Invalid bits allocated for pixel data"
            case .unsupportedPhotometricInterpretation:
                return "Unsupported photometric interpretation"
            case .compressionError:
                return "Error decompressing pixel data"
            case .invalidDimensions:
                return "Invalid image dimensions"
            }
        }
    }
}

// MARK: - Enhanced Error Creation Methods

extension DICOMError {
    
    static func invalidFileEnhanced(reason: InvalidFileReason) -> DICOMError {
        return .invalidFile
    }
    
    static func failedToParseEnhanced(details: ParseError) -> DICOMError {
        return .failedToParse
    }
    
    static func invalidPixelDataEnhanced(details: PixelDataError) -> DICOMError {
        return .invalidPixelData
    }
    
    static func memoryAllocationFailedEnhanced(requiredBytes: Int64) -> DICOMError {
        return .memoryAllocationFailed
    }
}

// MARK: - Clinical Compliance Extensions

extension DICOMError {
    
    /// Returns whether this error should be reported for clinical compliance
    var requiresComplianceReporting: Bool {
        switch self {
        case .invalidFile, .failedToParse, .corruptedData:
            return true
        case .fileNotFound, .permissionDenied, .networkError:
            return false
        default:
            return false
        }
    }
    
    /// Returns suggested recovery actions for clinical environments
    var clinicalRecoveryActions: [String] {
        switch self {
        case .invalidFile:
            return ["Verify file is a valid DICOM", "Check file source", "Contact IT support"]
        case .failedToParse:
            return ["Try re-exporting from PACS", "Check DICOM conformance", "Update software"]
        case .unsupportedFormat:
            return ["Convert to supported format", "Update viewer software", "Check modality settings"]
        case .memoryAllocationFailed:
            return ["Close other applications", "Restart application", "Use smaller image series"]
        case .networkError:
            return ["Check network connection", "Retry operation", "Contact system administrator"]
        default:
            return ["Contact technical support"]
        }
    }
}