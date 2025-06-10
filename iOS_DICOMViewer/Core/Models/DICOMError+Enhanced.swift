//
//  DICOMError+Enhanced.swift
//  iOS_DICOMViewer
//
//  Enhanced error handling for clinical compliance and detailed diagnostics
//  Provides comprehensive error categorization and recovery suggestions
//

import Foundation

enum DICOMError: LocalizedError {
    case invalidFile(reason: InvalidFileReason)
    case failedToParse(details: ParseError)
    case failedToParseMetadata(tag: String)
    case unsupportedFormat(format: String)
    case unsupportedTransferSyntax(syntax: String, suggestion: String)
    case missingPixelData(sopInstanceUID: String)
    case invalidPixelData(details: PixelDataError)
    case memoryAllocationFailed(requiredBytes: Int64)
    case fileNotFound(path: String)
    case permissionDenied(path: String)
    case corruptedData(details: String)
    case networkError(underlyingError: Error)
    case unknownSOPClass(sopClass: String, knownClasses: [String])
    
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
        case invalidDataElement(tag: String)
        case unexpectedEndOfFile
        case invalidVR(vr: String)
        case exceedsMaxLength(length: Int64)
        
        var localizedDescription: String {
            switch self {
            case .invalidDataElement(let tag):
                return "Invalid data element at tag \(tag)"
            case .unexpectedEndOfFile:
                return "Unexpected end of file"
            case .invalidVR(let vr):
                return "Invalid value representation: \(vr)"
            case .exceedsMaxLength(let length):
                return "Data element exceeds maximum length: \(length)"
            }
        }
    }
    
    enum PixelDataError {
        case inconsistentDimensions
        case unsupportedBitsAllocated(bits: Int)
        case compressedDataError
        case invalidPhotometricInterpretation(value: String)
        
        var localizedDescription: String {
            switch self {
            case .inconsistentDimensions:
                return "Inconsistent image dimensions"
            case .unsupportedBitsAllocated(let bits):
                return "Unsupported bits allocated: \(bits)"
            case .compressedDataError:
                return "Error decompressing pixel data"
            case .invalidPhotometricInterpretation(let value):
                return "Invalid photometric interpretation: \(value)"
            }
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidFile(let reason):
            return "Invalid DICOM file: \(reason.localizedDescription)"
        case .failedToParse(let details):
            return "Failed to parse DICOM file: \(details.localizedDescription)"
        case .failedToParseMetadata(let tag):
            return "Failed to parse metadata for tag: \(tag)"
        case .unsupportedFormat(let format):
            return "Unsupported DICOM format: \(format)"
        case .unsupportedTransferSyntax(let syntax, _):
            return "Unsupported transfer syntax: \(syntax)"
        case .missingPixelData(let uid):
            return "Missing pixel data for instance: \(uid)"
        case .invalidPixelData(let details):
            return "Invalid pixel data: \(details.localizedDescription)"
        case .memoryAllocationFailed(let bytes):
            return "Failed to allocate \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory))"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .corruptedData(let details):
            return "Corrupted data: \(details)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknownSOPClass(let sopClass, _):
            return "Unknown SOP Class: \(sopClass)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unsupportedTransferSyntax(_, let suggestion):
            return suggestion
        case .memoryAllocationFailed:
            return "Try closing other applications or reducing the image quality"
        case .unknownSOPClass(_, let knownClasses):
            return "Supported SOP Classes: \(knownClasses.joined(separator: ", "))"
        default:
            return nil
        }
    }
}
