import Foundation
import UniformTypeIdentifiers

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
            do {
                await processIncomingFile(url)
            } catch {
                print("❌ Failed to process incoming file: \(error)")
            }
        }
        return true
    }
    
    /// Process incoming file asynchronously
    private func processIncomingFile(_ url: URL) async {
        do {
            // Copy file to temp location if needed
            let workingURL = try await prepareFileForProcessing(url)
            
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
        // Check if we can access the file directly
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            
            // If it's already in our documents, use it directly
            if url.path.starts(with: documentsDirectory.path) {
                return url
            }
            
            // Copy to temp directory for processing
            let tempURL = tempDirectory.appendingPathComponent("DICOM")
                .appendingPathComponent(url.lastPathComponent)
            
            // Create temp directory if needed
            try fileManager.createDirectory(at: tempURL.deletingLastPathComponent(), 
                                          withIntermediateDirectories: true)
            
            // Copy file
            if fileManager.fileExists(atPath: tempURL.path) {
                try fileManager.removeItem(at: tempURL)
            }
            
            try fileManager.copyItem(at: url, to: tempURL)
            return tempURL
        }
        
        throw DICOMError.permissionDenied
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
        let instance1 = DICOMInstance(metadata: metadata1)
        let instance2 = DICOMInstance(metadata: metadata2)
        let instance3 = DICOMInstance(metadata: metadata3)
        
        // Create series
        let series1 = DICOMSeries(
            seriesInstanceUID: "1.2.3.4.5.6.7.8.1",
            seriesNumber: 1,
            seriesDescription: "Axial CT",
            modality: "CT",
            studyInstanceUID: "1.2.3.4.5.6.7.8"
        )
        
        let series2 = DICOMSeries(
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
        
        // Add generic data type as fallback
        types.append(.data)
        
        return types
    }
}
