import Foundation

/// Swift interface for DICOM parsing using DCMTK bridge
/// Provides async/await interface and Swift-friendly error handling
class DICOMParser {
    static let shared = DICOMParser()
    private let complianceManager = ClinicalComplianceManager.shared
    
    private init() {}
    
    /// Parse a DICOM file and extract metadata
    /// @param fileURL URL to the DICOM file
    /// @return DICOMMetadata object containing parsed information
    func parseMetadata(from fileURL: URL) async throws -> DICOMMetadata {
        print("🔍 DICOMParser: Starting metadata parsing for: \(fileURL.lastPathComponent)")
        print("🔍 DICOMParser: File path: \(fileURL.path)")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                print("🔍 DICOMParser: Calling DCMTKBridge.parseMetadata...")
                
                guard let metadataDict = DCMTKBridge.parseMetadata(fromFile: fileURL.path) else {
                    print("❌ DICOMParser: DCMTKBridge.parseMetadata returned nil")
                    continuation.resume(throwing: DICOMError.failedToParseMetadata)
                    return
                }
                
                print("✅ DICOMParser: DCMTKBridge returned metadata with \(metadataDict.count) fields")
                
                // Convert [AnyHashable: Any] to [String: Any]
                let stringKeyedDict = Dictionary(uniqueKeysWithValues: 
                    metadataDict.compactMap { key, value in
                        if let stringKey = key as? String {
                            return (stringKey, value)
                        }
                        return nil
                    }
                )
                
                print("🔍 DICOMParser: Converted to \(stringKeyedDict.count) string-keyed fields")
                
                let metadata = DICOMMetadata(dictionary: stringKeyedDict)
                
                print("🔍 DICOMParser: Created DICOMMetadata object")
                print("🔍 DICOMParser: SOP Instance UID: \(metadata.sopInstanceUID)")
                print("🔍 DICOMParser: Study Instance UID: \(metadata.studyInstanceUID)")
                
                print("✅ DICOMParser: Metadata validation passed")
                print("🔍 DICOMParser: Final metadata - Study UID: \(metadata.studyInstanceUID), Series UID: \(metadata.seriesInstanceUID)")
                continuation.resume(returning: metadata)
            }
        }
    }
    
    /// Parse pixel data from a DICOM file
    /// @param fileURL URL to the DICOM file
    /// @return Raw pixel data
    func parsePixelData(from fileURL: URL) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var width: Int32 = 0
                var height: Int32 = 0
                var bitsStored: Int32 = 0
                var isSigned: ObjCBool = false
                var windowCenter: Double = 0
                var windowWidth: Double = 0
                var numberOfFrames: Int32 = 0
                
                guard let pixelData = DCMTKBridge.parsePixelData(
                    fromFile: fileURL.path,
                    width: &width,
                    height: &height,
                    bitsStored: &bitsStored,
                    isSigned: &isSigned,
                    windowCenter: &windowCenter,
                    windowWidth: &windowWidth,
                    numberOfFrames: &numberOfFrames
                ) else {
                    continuation.resume(throwing: DICOMError.failedToParse)
                    return
                }
                
                continuation.resume(returning: pixelData)
            }
        }
    }
    
    /// Parse complete DICOM file (metadata + pixel data)
    /// @param fileURL URL to the DICOM file
    /// @return DICOMInstance with loaded pixel data
    func parseComplete(from fileURL: URL) async throws -> DICOMInstance {
        // First parse metadata
        let metadata = try await parseMetadata(from: fileURL)
        
        // Create instance
        let instance = DICOMInstance(metadata: metadata, fileURL: fileURL)
        
        // Load pixel data
        try await instance.loadPixelData()
        
        return instance
    }
    
    /// Validate if a file is a valid DICOM file
    /// @param fileURL URL to check
    /// @return true if file is valid DICOM
    func isValidDICOMFile(_ fileURL: URL) -> Bool {
        return DCMTKBridge.isValidDICOMFile(fileURL.path)
    }
    
    /// Get transfer syntax information
    /// @param fileURL URL to the DICOM file
    /// @return Transfer syntax string
    func getTransferSyntax(from fileURL: URL) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let transferSyntax = DCMTKBridge.getTransferSyntax(fileURL.path)
                continuation.resume(returning: transferSyntax)
            }
        }
    }
    
    /// Get SOP Class UID
    /// @param fileURL URL to the DICOM file
    /// @return SOP Class UID string
    func getSOPClassUID(from fileURL: URL) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let sopClassUID = DCMTKBridge.getSOPClassUID(fileURL.path)
                continuation.resume(returning: sopClassUID)
            }
        }
    }
    
    /// Get image geometry information for 3D reconstruction
    /// @param fileURL URL to the DICOM file
    /// @return Dictionary with geometry information
    func getImageGeometry(from fileURL: URL) async -> [String: Any]? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let geometry = DCMTKBridge.getImageGeometry(fileURL.path)
                // Convert [AnyHashable: Any] to [String: Any]
                var stringKeyedGeometry: [String: Any]?
                if let dict = geometry {
                    stringKeyedGeometry = Dictionary(uniqueKeysWithValues: 
                        dict.compactMap { key, value in
                            if let stringKey = key as? String {
                                return (stringKey, value)
                            }
                            return nil
                        }
                    )
                }
                continuation.resume(returning: stringKeyedGeometry)
            }
        }
    }
    
    /// Extract specific frame data from multi-frame instance
    /// @param pixelData Complete pixel data
    /// @param frameIndex Frame index to extract (0-based)
    /// @param width Image width
    /// @param height Image height
    /// @param bitsStored Bits stored per pixel
    /// @return Frame data
    func extractFrameData(from pixelData: Data, 
                         frameIndex: Int, 
                         width: Int, 
                         height: Int, 
                         bitsStored: Int) -> Data? {
        return DCMTKBridge.getFrameData(
            pixelData,
            frameIndex: Int32(frameIndex),
            width: Int32(width),
            height: Int32(height),
            bitsStored: Int32(bitsStored)
        )
    }
    
    /// Batch parse multiple DICOM files
    /// @param fileURLs Array of DICOM file URLs
    /// @param progressHandler Optional progress callback
    /// @return Array of DICOMInstance objects
    func parseBatch(_ fileURLs: [URL], 
                   progressHandler: ((Double) -> Void)? = nil) async throws -> [DICOMInstance] {
        var instances: [DICOMInstance] = []
        let totalFiles = fileURLs.count
        
        for (index, fileURL) in fileURLs.enumerated() {
            do {
                let instance = try await parseComplete(from: fileURL)
                instances.append(instance)
                
                // Report progress
                let progress = Double(index + 1) / Double(totalFiles)
                await MainActor.run {
                    progressHandler?(progress)
                }
            } catch {
                print("⚠️ Failed to parse DICOM file \(fileURL.lastPathComponent): \(error)")
                // Continue with other files
            }
        }
        
        return instances
    }
    
    /// Parse DICOM directory recursively
    /// @param directoryURL URL to directory containing DICOM files
    /// @param progressHandler Optional progress callback
    /// @return Array of DICOMInstance objects
    func parseDirectory(_ directoryURL: URL, 
                       progressHandler: ((Double) -> Void)? = nil) async throws -> [DICOMInstance] {
        let fileManager = FileManager.default
        
        // Get all files in directory recursively
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw DICOMError.invalidFile
        }
        
        var dicomFiles: [URL] = []
        
        for case let fileURL as URL in enumerator {
            // Check if it's a regular file
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues.isRegularFile == true {
                // Quick check if it might be a DICOM file
                if isValidDICOMFile(fileURL) {
                    dicomFiles.append(fileURL)
                }
            }
        }
        
        print("📁 Found \(dicomFiles.count) DICOM files in directory")
        
        return try await parseBatch(dicomFiles, progressHandler: progressHandler)
    }
}

// MARK: - DICOM File Type Detection
extension DICOMParser {
    
    /// Detect DICOM file type based on SOP Class UID
    enum DICOMFileType {
        case image                  // Standard DICOM image
        case multiframe            // Multi-frame image
        case structuredReport      // DICOM SR
        case rtStructureSet        // RT Structure Set
        case segmentation          // DICOM SEG
        case parametricMap         // DICOM Parametric Map
        case unknown
    }
    
    /// Determine DICOM file type
    /// @param fileURL URL to the DICOM file
    /// @return DICOMFileType enum value
    func detectFileType(_ fileURL: URL) async -> DICOMFileType {
        guard let sopClassUID = await getSOPClassUID(from: fileURL) else {
            return .unknown
        }
        
        // Standard image SOP classes
        let imageSopClasses = [
            "1.2.840.10008.5.1.4.1.1.2",      // CT Image Storage
            "1.2.840.10008.5.1.4.1.1.4",      // MR Image Storage
            "1.2.840.10008.5.1.4.1.1.20",     // NM Image Storage
            "1.2.840.10008.5.1.4.1.1.128",    // PET Image Storage
            "1.2.840.10008.5.1.4.1.1.7",      // Secondary Capture Image Storage
        ]
        
        // Multi-frame SOP classes
        let multiframeSopClasses = [
            "1.2.840.10008.5.1.4.1.1.2.1",    // Enhanced CT Image Storage
            "1.2.840.10008.5.1.4.1.1.4.1",    // Enhanced MR Image Storage
            "1.2.840.10008.5.1.4.1.1.130",    // Enhanced PET Image Storage
        ]
        
        if imageSopClasses.contains(sopClassUID) {
            return .image
        } else if multiframeSopClasses.contains(sopClassUID) {
            return .multiframe
        } else if sopClassUID == "1.2.840.10008.5.1.4.1.1.88.59" { // Basic Text SR
            return .structuredReport
        } else if sopClassUID == "1.2.840.10008.5.1.4.1.1.481.3" { // RT Structure Set
            return .rtStructureSet
        } else if sopClassUID == "1.2.840.10008.5.1.4.1.1.66.4" { // Segmentation Storage
            return .segmentation
        } else if sopClassUID == "1.2.840.10008.5.1.4.1.1.30" { // Parametric Map Storage
            return .parametricMap
        }
        
        return .unknown
    }
}
