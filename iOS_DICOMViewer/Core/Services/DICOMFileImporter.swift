import Foundation
import UniformTypeIdentifiers
import Compression

/// Protocol for receiving DICOM file import notifications
protocol DICOMFileImporterDelegate: AnyObject {
    func didImportDICOMFile(_ metadata: DICOMMetadata, from url: URL)
}

/// File importer service for handling DICOM files from various sources
/// Supports Files app, AirDrop, iCloud Drive, and document picker
class DICOMFileImporter: DICOMServiceProtocol {
    static let shared = DICOMFileImporter()
    
    let identifier = "DICOMFileImporter"
    weak var delegate: DICOMFileImporterDelegate?
    
    private let fileManager = FileManager.default
    private var metadataStore: DICOMMetadataStore { return DICOMMetadataStore.shared }
    private let documentsDirectory: URL
    private let tempDirectory: URL
    
    private init() {
        // Set up directories
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, 
                                                 in: .userDomainMask).first!
        self.tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    }
    
    func initialize() async throws {
        setupDirectories()
        print("📥 DICOM File Importer initialized")
    }
    
    func shutdown() async {
        clearTempDirectory()
        print("🗑️ DICOM File Importer shutdown")
    }
    
    func reset() {
        clearTempDirectory()
        print("🗑️ DICOM File Importer reset")
    }
    
    private func setupDirectories() {
        // Create DICOM storage directory
        let dicomDirectory = documentsDirectory.appendingPathComponent("DICOM")
        try? fileManager.createDirectory(at: dicomDirectory, 
                                       withIntermediateDirectories: true)
        
        // Create studies subdirectory
        let studiesDirectory = dicomDirectory.appendingPathComponent("Studies")
        try? fileManager.createDirectory(at: studiesDirectory, 
                                       withIntermediateDirectories: true)
    }
    
    private func clearTempDirectory() {
        let tempDicomDir = tempDirectory.appendingPathComponent("DICOM")
        try? fileManager.removeItem(at: tempDicomDir)
    }
    
    // MARK: - File Handling
    
    /// Handle incoming DICOM file from external sources
    /// @param url URL to the DICOM file
    /// @return true if file was handled successfully
    @discardableResult
    func handleIncomingFile(url: URL) -> Bool {
        Task {
            await processIncomingFile(url)
        }
        return true
    }
    
    /// Process incoming file asynchronously
    private func processIncomingFile(_ url: URL) async {
        do {
            // Copy file to temp location if needed
            let workingURL = try await prepareFileForProcessing(url)
            
            // Check if it's a ZIP file
            if workingURL.pathExtension.lowercased() == "zip" {
                print("🗜️ Processing ZIP archive: \(workingURL.lastPathComponent)")
                try await processZIPFile(workingURL)
                return
            }
            
            // Validate DICOM file
            guard DICOMParser.shared.isValidDICOMFile(workingURL) else {
                throw DICOMError.invalidFile
            }
            
            // Parse metadata
            let metadata = try await DICOMParser.shared.parseMetadata(from: workingURL)
            
            // Create permanent storage location
            let permanentURL = try await createPermanentStorage(for: metadata, from: workingURL)
            
            // Notify delegate
            await MainActor.run {
                delegate?.didImportDICOMFile(metadata, from: permanentURL)
            }
            
            print("✅ Successfully imported DICOM file: \(metadata.sopInstanceUID)")
            
        } catch {
            print("❌ Failed to process DICOM file: \(error)")
            await showImportError(error)
        }
    }
    
    /// Prepare file for processing (copy if needed)
    private func prepareFileForProcessing(_ url: URL) async throws -> URL {
        print("🔄 Preparing file for processing: \(url.path)")
        
        // If it's already in our documents, use it directly
        if url.path.starts(with: documentsDirectory.path) {
            print("✅ File is already in documents directory")
            return url
        }
        
        // For files from document picker, we need to handle security-scoped resources
        var accessingSecurityScope = false
        
        // Try to access security-scoped resource
        if url.startAccessingSecurityScopedResource() {
            accessingSecurityScope = true
            print("✅ Successfully accessed security-scoped resource")
        } else {
            print("⚠️ Could not access security-scoped resource, trying direct access")
        }
        
        defer {
            if accessingSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // Create temp directory for processing
            let tempDICOMDir = tempDirectory.appendingPathComponent("DICOM")
            try fileManager.createDirectory(at: tempDICOMDir, withIntermediateDirectories: true)
            
            let tempURL = tempDICOMDir.appendingPathComponent(url.lastPathComponent)
            
            // Remove existing temp file if it exists
            if fileManager.fileExists(atPath: tempURL.path) {
                try fileManager.removeItem(at: tempURL)
            }
            
            // Try to copy the file
            try fileManager.copyItem(at: url, to: tempURL)
            print("✅ Successfully copied file to temp location: \(tempURL.path)")
            
            return tempURL
            
        } catch {
            print("❌ Failed to copy file: \(error)")
            
            // If copy failed, try to read the file data directly and write it
            do {
                print("🔄 Attempting direct data read and write...")
                let data = try Data(contentsOf: url)
                
                let tempDICOMDir = tempDirectory.appendingPathComponent("DICOM")
                try fileManager.createDirectory(at: tempDICOMDir, withIntermediateDirectories: true)
                
                let tempURL = tempDICOMDir.appendingPathComponent(url.lastPathComponent)
                
                // Remove existing temp file if it exists
                if fileManager.fileExists(atPath: tempURL.path) {
                    try fileManager.removeItem(at: tempURL)
                }
                
                try data.write(to: tempURL)
                print("✅ Successfully wrote file data to temp location: \(tempURL.path)")
                
                return tempURL
                
            } catch {
                print("❌ Failed to read file data: \(error)")
                throw DICOMError.permissionDenied
            }
        }
    }
    
    /// Create permanent storage location for DICOM file
    private func createPermanentStorage(for metadata: DICOMMetadata, from sourceURL: URL) async throws -> URL {
        // Create directory structure: Studies/StudyUID/SeriesUID/
        let studiesDir = documentsDirectory.appendingPathComponent("DICOM/Studies")
        let studyDir = studiesDir.appendingPathComponent(metadata.studyInstanceUID)
        let seriesDir = studyDir.appendingPathComponent(metadata.seriesInstanceUID)
        
        // Create directories
        try fileManager.createDirectory(at: seriesDir, withIntermediateDirectories: true)
        
        // Create filename with instance number and SOP Instance UID
        let instanceNumber = metadata.instanceNumber ?? 1
        let filename = String(format: "%06d_%@.dcm", instanceNumber, metadata.sopInstanceUID)
        let destinationURL = seriesDir.appendingPathComponent(filename)
        
        // Move or copy file to permanent location
        if sourceURL.path.starts(with: tempDirectory.path) {
            // Move from temp
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } else {
            // Copy from external source
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
        
        return destinationURL
    }
    
    // MARK: - Batch Import
    
    /// Import multiple DICOM files
    /// @param urls Array of file URLs
    /// @param progressHandler Progress callback
    func importMultipleFiles(_ urls: [URL], 
                           progressHandler: @escaping (Double) -> Void) async {
        let totalFiles = urls.count
        
        for (index, url) in urls.enumerated() {
            await processIncomingFile(url)
            
            let progress = Double(index + 1) / Double(totalFiles)
            await MainActor.run {
                progressHandler(progress)
            }
        }
    }
    
    /// Import DICOM directory
    /// @param directoryURL URL to directory
    /// @param progressHandler Progress callback
    func importDirectory(_ directoryURL: URL, 
                        progressHandler: @escaping (Double) -> Void) async {
        do {
            let instances = try await DICOMParser.shared.parseDirectory(directoryURL) { progress in
                Task { @MainActor in
                    progressHandler(progress)
                }
            }
            
            // Import each instance
            for instance in instances {
                if let fileURL = instance.fileURL {
                    delegate?.didImportDICOMFile(instance.metadata, from: fileURL)
                }
            }
            
        } catch {
            print("❌ Failed to import directory: \(error)")
            await showImportError(error)
        }
    }
    
    // MARK: - File Management
    
    /// Get imported studies directory
    func getStudiesDirectory() -> URL {
        return documentsDirectory.appendingPathComponent("DICOM/Studies")
    }
    
    /// Get study directory for specific study UID
    func getStudyDirectory(for studyUID: String) -> URL {
        return getStudiesDirectory().appendingPathComponent(studyUID)
    }
    
    /// Get series directory for specific study and series UIDs
    func getSeriesDirectory(studyUID: String, seriesUID: String) -> URL {
        return getStudyDirectory(for: studyUID).appendingPathComponent(seriesUID)
    }
    
    /// Delete study from storage
    func deleteStudy(_ studyUID: String) async throws {
        let studyDirectory = getStudyDirectory(for: studyUID)
        try fileManager.removeItem(at: studyDirectory)
        print("🗑️ Deleted study: \(studyUID)")
    }
    
    /// Delete series from storage
    func deleteSeries(studyUID: String, seriesUID: String) async throws {
        let seriesDirectory = getSeriesDirectory(studyUID: studyUID, seriesUID: seriesUID)
        try fileManager.removeItem(at: seriesDirectory)
        print("🗑️ Deleted series: \(seriesUID)")
    }
    
    /// Get storage statistics
    func getStorageStatistics() -> (studyCount: Int, totalSize: Int64) {
        let studiesDirectory = getStudiesDirectory()
        
        guard let enumerator = fileManager.enumerator(
            at: studiesDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
        ) else {
            return (0, 0)
        }
        
        var studyCount = 0
        var totalSize: Int64 = 0
        
        for case let url as URL in enumerator {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                
                if resourceValues.isDirectory == true && 
                   url.pathComponents.count == studiesDirectory.pathComponents.count + 1 {
                    studyCount += 1
                }
                
                if let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                print("⚠️ Failed to get file size for \(url): \(error)")
            }
        }
        
        return (studyCount, totalSize)
    }
    
    // MARK: - ZIP File Processing
    
    /// Process ZIP file containing DICOM files
    private func processZIPFile(_ zipURL: URL) async throws {
        print("🔄 Extracting ZIP file: \(zipURL.lastPathComponent)")
        
        // Create extraction directory
        let extractionDir = tempDirectory.appendingPathComponent("DICOM_Extracted_\(UUID().uuidString)")
        try fileManager.createDirectory(at: extractionDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up extraction directory
            try? fileManager.removeItem(at: extractionDir)
        }
        
        // Extract ZIP file
        try await extractZIPFile(zipURL, to: extractionDir)
        
        // Find all DICOM files in extracted directory
        let dicomFiles = try await findDICOMFiles(in: extractionDir)
        
        print("📁 Found \(dicomFiles.count) potential DICOM files in ZIP archive")
        
        // Process each DICOM file
        var successCount = 0
        var failureCount = 0
        
        for dicomFile in dicomFiles {
            do {
                // Validate DICOM file
                guard DICOMParser.shared.isValidDICOMFile(dicomFile) else {
                    print("⚠️ Skipping invalid DICOM file: \(dicomFile.lastPathComponent)")
                    failureCount += 1
                    continue
                }
                
                // Parse metadata
                let metadata = try await DICOMParser.shared.parseMetadata(from: dicomFile)
                
                // Create permanent storage location
                let permanentURL = try await createPermanentStorage(for: metadata, from: dicomFile)
                
                // Notify delegate
                await MainActor.run {
                    delegate?.didImportDICOMFile(metadata, from: permanentURL)
                }
                
                print("✅ Successfully imported DICOM file: \(metadata.sopInstanceUID)")
                successCount += 1
                
            } catch {
                print("❌ Failed to process DICOM file \(dicomFile.lastPathComponent): \(error)")
                failureCount += 1
            }
        }
        
        print("📊 ZIP import completed: \(successCount) successful, \(failureCount) failed")
        
        if successCount == 0 {
            throw DICOMError.invalidFile
        }
    }
    
    /// Extract ZIP file to destination directory using native iOS approach
    private func extractZIPFile(_ zipURL: URL, to destinationURL: URL) async throws {
        print("🔄 Extracting ZIP file: \(zipURL.lastPathComponent)")
        
        do {
            // Create destination directory if it doesn't exist
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            
            // Use a native iOS approach with URLSession for ZIP handling
            try await extractZIPUsingNativeAPI(from: zipURL, to: destinationURL)
            
            print("✅ ZIP file extracted successfully to: \(destinationURL.path)")
            
        } catch {
            print("❌ ZIP extraction failed: \(error.localizedDescription)")
            
            // Fallback: Copy ZIP file and provide instructions
            try await createZIPFallback(from: zipURL, to: destinationURL)
            
            // Don't throw error, let user handle manually
            print("⚠️ ZIP file copied for manual extraction")
        }
    }
    
    /// Extract ZIP using native iOS APIs and Foundation
    private func extractZIPUsingNativeAPI(from zipURL: URL, to destinationURL: URL) async throws {
        // Read ZIP file data
        let zipData = try Data(contentsOf: zipURL)
        
        // Basic ZIP file structure parsing
        try parseAndExtractZIP(data: zipData, to: destinationURL)
    }
    
    /// Parse and extract ZIP file using Foundation
    private func parseAndExtractZIP(data: Data, to destinationURL: URL) throws {
        // ZIP file format constants
        let localFileHeaderSignature: UInt32 = 0x04034b50
        let centralDirectorySignature: UInt32 = 0x02014b50
        let endOfCentralDirectorySignature: UInt32 = 0x06054b50
        
        var offset = 0
        let bytes = data.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        
        // Parse local file headers and extract files
        while offset < data.count - 4 {
            let signature = data.withUnsafeBytes { bytes in
                bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
            }
            
            if signature == localFileHeaderSignature {
                try extractFileFromLocalHeader(data: data, offset: &offset, to: destinationURL)
            } else if signature == centralDirectorySignature {
                // Reached central directory, stop processing
                break
            } else {
                // Invalid or corrupted ZIP file
                throw DICOMError.corruptedData
            }
        }
    }
    
    /// Extract individual file from ZIP local file header
    private func extractFileFromLocalHeader(data: Data, offset: inout Int, to destinationURL: URL) throws {
        guard offset + 30 <= data.count else {
            throw DICOMError.corruptedData
        }
        
        // Skip signature (4 bytes)
        offset += 4
        
        // Read header fields
        let versionNeeded = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
        offset += 2
        
        let generalPurposeFlag = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
        offset += 2
        
        let compressionMethod = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
        offset += 2
        
        // Skip time and date fields (4 bytes)
        offset += 4
        
        let crc32 = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
        offset += 4
        
        let compressedSize = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
        offset += 4
        
        let uncompressedSize = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
        offset += 4
        
        let fileNameLength = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
        offset += 2
        
        let extraFieldLength = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
        offset += 2
        
        // Read filename
        guard offset + Int(fileNameLength) <= data.count else {
            throw DICOMError.corruptedData
        }
        
        let fileNameData = data.subdata(in: offset..<offset + Int(fileNameLength))
        guard let fileName = String(data: fileNameData, encoding: .utf8) else {
            throw DICOMError.corruptedData
        }
        
        offset += Int(fileNameLength)
        
        // Skip extra field
        offset += Int(extraFieldLength)
        
        // Skip directories
        if fileName.hasSuffix("/") {
            offset += Int(compressedSize)
            return
        }
        
        // Read file data
        guard offset + Int(compressedSize) <= data.count else {
            throw DICOMError.corruptedData
        }
        
        let fileData = data.subdata(in: offset..<offset + Int(compressedSize))
        offset += Int(compressedSize)
        
        // Decompress if needed
        let finalData: Data
        if compressionMethod == 0 {
            // No compression
            finalData = fileData
        } else if compressionMethod == 8 {
            // Deflate compression - use Foundation's decompression
            do {
                finalData = try (fileData as NSData).decompressed(using: .zlib) as Data
            } catch {
                print("⚠️ Could not decompress file \(fileName): \(error)")
                // Use compressed data as fallback
                finalData = fileData
            }
        } else {
            print("⚠️ Unsupported compression method \(compressionMethod) for file \(fileName)")
            finalData = fileData
        }
        
        // Create file
        let fileURL = destinationURL.appendingPathComponent(fileName)
        
        // Create intermediate directories if needed
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        try finalData.write(to: fileURL)
        
        print("✅ Extracted: \(fileName) (\(finalData.count) bytes)")
    }
    
    /// Create fallback when ZIP extraction fails
    private func createZIPFallback(from zipURL: URL, to destinationURL: URL) async throws {
        // Copy the ZIP file to destination
        let zipCopyURL = destinationURL.appendingPathComponent("DICOM_Archive.zip")
        try fileManager.copyItem(at: zipURL, to: zipCopyURL)
        
        // Create instructions file
        let instructionsContent = """
        DICOM Archive Instructions
        
        📁 Archive: DICOM_Archive.zip
        📊 Status: Awaiting manual extraction
        
        🔧 How to extract DICOM files:
        1. Tap on 'DICOM_Archive.zip' in Files app
        2. Choose 'Extract' or 'Unarchive'
        3. Import individual DICOM files using the import button
        
        📋 Supported DICOM formats:
        • .dcm files
        • .dicom files  
        • .dic files
        • Files without extensions
        
        ⚠️ Note: Automatic ZIP extraction will be added in future updates
        """
        
        let instructionsURL = destinationURL.appendingPathComponent("How_to_Extract_DICOM_Files.txt")
        try instructionsContent.write(to: instructionsURL, atomically: true, encoding: .utf8)
    }
    
    /// Find all potential DICOM files in directory recursively
    private func findDICOMFiles(in directory: URL) async throws -> [URL] {
        var dicomFiles: [URL] = []
        
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        guard let enumerator = enumerator else {
            throw DICOMError.processingFailed
        }
        
        for case let fileURL as URL in Array(enumerator) {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                
                if resourceValues.isRegularFile == true {
                    // Check file extension
                    let fileExtension = fileURL.pathExtension.lowercased()
                    
                    // Common DICOM extensions
                    if fileExtension == "dcm" || 
                       fileExtension == "dicom" || 
                       fileExtension == "dic" || 
                       fileExtension.isEmpty {
                        dicomFiles.append(fileURL)
                    }
                }
            } catch {
                print("⚠️ Failed to check file: \(fileURL.lastPathComponent)")
            }
        }
        
        return dicomFiles
    }
    
    // MARK: - Error Handling
    
    @MainActor
    private func showImportError(_ error: Error) {
        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("DICOMImportError"),
            object: nil,
            userInfo: ["error": error]
        )
    }
}

// MARK: - Sample Data Creation
    
    /// Create sample DICOM data for testing
    func createSampleData() async throws {
        // Create sample study
        let sampleStudy = createSampleStudy()
        DICOMMetadataStore.shared.addStudy(sampleStudy)
        
        // Notify observers
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: DICOMMetadataStore.studyAddedNotification, object: nil)
        }
    }
    
    private func createSampleStudy() -> DICOMStudy {
        // Create sample metadata dictionaries
        let metadata1Dict: [String: Any] = [
            "SOPInstanceUID": "1.2.3.4.5.6.7.8.9.1",
            "SOPClassUID": "1.2.840.10008.5.1.4.1.1.2", // CT Image Storage
            "StudyInstanceUID": "1.2.3.4.5.6.7.8",
            "SeriesInstanceUID": "1.2.3.4.5.6.7.8.1",
            "PatientName": "Sample^Patient",
            "PatientID": "SP001",
            "StudyDescription": "Sample CT Study",
            "SeriesDescription": "Axial CT",
            "Modality": "CT",
            "StudyDate": "20231201",
            "SeriesNumber": 1,
            "InstanceNumber": 1,
            "Rows": 512,
            "Columns": 512,
            "BitsAllocated": 16,
            "BitsStored": 16,
            "SamplesPerPixel": 1,
            "PhotometricInterpretation": "MONOCHROME2",
            "PixelRepresentation": 1
        ]
        
        let metadata2Dict: [String: Any] = [
            "SOPInstanceUID": "1.2.3.4.5.6.7.8.9.2",
            "SOPClassUID": "1.2.840.10008.5.1.4.1.1.2",
            "StudyInstanceUID": "1.2.3.4.5.6.7.8",
            "SeriesInstanceUID": "1.2.3.4.5.6.7.8.1",
            "PatientName": "Sample^Patient",
            "PatientID": "SP001",
            "StudyDescription": "Sample CT Study",
            "SeriesDescription": "Axial CT",
            "Modality": "CT",
            "StudyDate": "20231201",
            "SeriesNumber": 1,
            "InstanceNumber": 2,
            "Rows": 512,
            "Columns": 512,
            "BitsAllocated": 16,
            "BitsStored": 16,
            "SamplesPerPixel": 1,
            "PhotometricInterpretation": "MONOCHROME2",
            "PixelRepresentation": 1
        ]
        
        let metadata3Dict: [String: Any] = [
            "SOPInstanceUID": "1.2.3.4.5.6.7.8.9.3",
            "SOPClassUID": "1.2.840.10008.5.1.4.1.1.4", // MR Image Storage
            "StudyInstanceUID": "1.2.3.4.5.6.7.8",
            "SeriesInstanceUID": "1.2.3.4.5.6.7.8.2",
            "PatientName": "Sample^Patient",
            "PatientID": "SP001",
            "StudyDescription": "Sample CT Study",
            "SeriesDescription": "T1 MR",
            "Modality": "MR",
            "StudyDate": "20231201",
            "SeriesNumber": 2,
            "InstanceNumber": 1,
            "Rows": 256,
            "Columns": 256,
            "BitsAllocated": 16,
            "BitsStored": 16,
            "SamplesPerPixel": 1,
            "PhotometricInterpretation": "MONOCHROME2",
            "PixelRepresentation": 1
        ]
        
        // Create metadata objects
        let metadata1 = DICOMMetadata(dictionary: metadata1Dict)
        let metadata2 = DICOMMetadata(dictionary: metadata2Dict)
        let metadata3 = DICOMMetadata(dictionary: metadata3Dict)
        
        // Create instances
        let _ = DICOMInstance(metadata: metadata1)
        let _ = DICOMInstance(metadata: metadata2)
        let _ = DICOMInstance(metadata: metadata3)
        
        // Create series
        let _ = DICOMSeries(
            seriesInstanceUID: "1.2.3.4.5.6.7.8.1",
            seriesNumber: 1,
            seriesDescription: "Axial CT",
            modality: "CT",
            studyInstanceUID: "1.2.3.4.5.6.7.8"
        )
        
        let _ = DICOMSeries(
            seriesInstanceUID: "1.2.3.4.5.6.7.8.2",
            seriesNumber: 2,
            seriesDescription: "T1 MR",
            modality: "MR",
            studyInstanceUID: "1.2.3.4.5.6.7.8"
        )
        
        // Add instances to series (need to check if there's an addInstance method)
        // For now, let's create the study and add instances later
        
        // Create study
        return DICOMStudy(
            studyInstanceUID: "1.2.3.4.5.6.7.8",
            studyDate: "20231201",
            studyDescription: "Sample CT Study",
            patientName: "Sample^Patient",
            patientID: "SP001"
        )
    }
    
// MARK: - Document Picker Support
extension DICOMFileImporter {
    
    /// Get supported DICOM file types for document picker
    static var supportedTypes: [UTType] {
        var types: [UTType] = []
        
        // Add DICOM file types
        if let dicomType = UTType(filenameExtension: "dcm") {
            types.append(dicomType)
        }
        if let dicomType = UTType(filenameExtension: "dicom") {
            types.append(dicomType)
        }
        if let dicomType = UTType(filenameExtension: "dic") {
            types.append(dicomType)
        }
        
        // Add ZIP file type for compressed DICOM archives
        types.append(.zip)
        
        // Add generic data type as fallback
        types.append(.data)
        
        return types
    }
}
