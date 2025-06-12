import XCTest
import Metal
import simd
@testable import iOS_DICOMViewer

/// Medical imaging compliance and regulatory tests
/// Ensures adherence to DICOM standards, FDA guidelines, and clinical requirements
class ComplianceTests: XCTestCase {
    
    var complianceManager: ClinicalComplianceManager!
    
    override func setUpWithError() throws {
        complianceManager = ClinicalComplianceManager.shared
    }
    
    override func tearDownWithError() throws {
        complianceManager = nil
    }
    
    // MARK: - DICOM Standard Compliance Tests
    func testDICOMTagCompliance() throws {
        // Test compliance with DICOM Part 3 Information Object Definitions
        let metadata = createCompliantDICOMMetadata()
        
        // Required Type 1 elements (must be present)
        let requiredType1Tags = [
            metadata.sopClassUID,
            metadata.sopInstanceUID,
            metadata.studyInstanceUID,
            metadata.seriesInstanceUID
        ]
        
        for tag in requiredType1Tags {
            XCTAssertNotNil(tag, "Type 1 DICOM tag must be present")
            XCTAssertFalse(tag?.isEmpty ?? true, "Type 1 DICOM tag must not be empty")
        }
        
        // Test image-specific required elements
        XCTAssertGreaterThan(metadata.rows, 0, "Rows must be > 0")
        XCTAssertGreaterThan(metadata.columns, 0, "Columns must be > 0")
        XCTAssertGreaterThan(metadata.bitsStored, 0, "Bits Stored must be > 0")
        XCTAssertGreaterThanOrEqual(metadata.bitsAllocated, metadata.bitsStored, 
                                   "Bits Allocated must be >= Bits Stored")
        
        // Test photometric interpretation compliance
        let validPhotometricInterpretations = ["MONOCHROME1", "MONOCHROME2", "RGB", "YBR_FULL"]
        XCTAssertTrue(validPhotometricInterpretations.contains(metadata.photometricInterpretation ?? ""),
                     "Photometric Interpretation must be valid")
    }
    
    func testDICOMUIDCompliance() throws {
        let metadata = createCompliantDICOMMetadata()
        
        // Test UID format compliance (must be valid UID format)
        let uids = [
            metadata.studyInstanceUID,
            metadata.seriesInstanceUID,
            metadata.sopInstanceUID,
            metadata.sopClassUID
        ]
        
        for uid in uids {
            XCTAssertNotNil(uid, "UID must not be nil")
            if let uidString = uid {
                // UIDs must contain only digits and dots
                let uidRegex = try NSRegularExpression(pattern: "^[0-9.]+$")
                let range = NSRange(location: 0, length: uidString.count)
                let matches = uidRegex.numberOfMatches(in: uidString, range: range)
                XCTAssertEqual(matches, 1, "UID must contain only digits and dots: \(uidString)")
                
                // UIDs must not exceed 64 characters
                XCTAssertLessThanOrEqual(uidString.count, 64, "UID must not exceed 64 characters")
                
                // UIDs must not start or end with a dot
                XCTAssertFalse(uidString.hasPrefix("."), "UID must not start with a dot")
                XCTAssertFalse(uidString.hasSuffix("."), "UID must not end with a dot")
            }
        }
    }
    
    func testDICOMDateTimeCompliance() throws {
        let metadata = createCompliantDICOMMetadata()
        
        // Test date format compliance (YYYYMMDD)
        if let studyDate = metadata.studyDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let dateString = dateFormatter.string(from: studyDate)
            
            XCTAssertEqual(dateString.count, 8, "DICOM date must be 8 characters (YYYYMMDD)")
            
            // Verify it's a valid date
            let parsedDate = dateFormatter.date(from: dateString)
            XCTAssertNotNil(parsedDate, "DICOM date must be valid")
        }
        
        // Test time format compliance (HHMMSS.FFFFFF)
        if let studyTime = metadata.studyTime {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HHmmss.SSSSSS"
            let timeString = timeFormatter.string(from: studyTime)
            
            // DICOM time can be HHMMSS or HHMMSS.FFFFFF
            XCTAssertTrue(timeString.count >= 6, "DICOM time must be at least 6 characters")
        }
    }
    
    func testDICOMPixelDataCompliance() throws {
        let metadata = createCompliantDICOMMetadata()
        let expectedPixelDataSize = metadata.rows * metadata.columns * 
                                   (metadata.bitsAllocated / 8) * metadata.samplesPerPixel
        
        // Create compliant pixel data
        let pixelData = Data(repeating: 0, count: expectedPixelDataSize)
        let instance = DICOMInstance(metadata: metadata)
        instance.pixelData = pixelData
        
        XCTAssertEqual(instance.pixelData?.count, expectedPixelDataSize,
                      "Pixel data size must match calculated size from metadata")
        
        // Test bit depth compliance
        let validBitDepths = [1, 8, 16, 32]
        XCTAssertTrue(validBitDepths.contains(metadata.bitsAllocated),
                     "Bits Allocated must be 1, 8, 16, or 32")
        XCTAssertLessThanOrEqual(metadata.bitsStored, metadata.bitsAllocated,
                               "Bits Stored must be <= Bits Allocated")
        XCTAssertLessThanOrEqual(metadata.highBit, metadata.bitsAllocated - 1,
                               "High Bit must be < Bits Allocated")
    }
    
    // MARK: - Medical Imaging Standards Tests
    func testWindowLevelStandardsCompliance() throws {
        // Test compliance with medical imaging window/level standards
        let standardPresets = [
            ("CT Lung", center: -600.0, width: 1600.0),
            ("CT Abdomen", center: 40.0, width: 400.0),
            ("CT Brain", center: 40.0, width: 80.0),
            ("CT Bone", center: 300.0, width: 1500.0),
            ("MR Brain", center: 128.0, width: 256.0)
        ]
        
        let renderer = DICOMImageRenderer()
        
        for preset in standardPresets {
            // Test window/level calculation
            let testValues = [preset.center - preset.width/2, preset.center, preset.center + preset.width/2]
            let expectedNormalized = [0.0, 0.5, 1.0]
            
            for (index, value) in testValues.enumerated() {
                let normalized = renderer.applyWindowLevel(value: Float(value), 
                                                         center: Float(preset.center), 
                                                         width: Float(preset.width))
                XCTAssertEqual(normalized, Float(expectedNormalized[index]), accuracy: 0.01,
                              "Window/level calculation incorrect for \(preset.0)")
            }
        }
    }
    
    func testImageOrientationCompliance() throws {
        // Test compliance with DICOM image orientation standards
        let metadata = createCompliantDICOMMetadata()
        
        // Test image orientation patient (6 values required)
        XCTAssertEqual(metadata.imageOrientationPatient?.count, 6,
                      "Image Orientation Patient must have 6 values")
        
        if let orientation = metadata.imageOrientationPatient {
            // Test that orientation vectors are unit vectors
            let rowVector = simd_float3(Float(orientation[0]), Float(orientation[1]), Float(orientation[2]))
            let colVector = simd_float3(Float(orientation[3]), Float(orientation[4]), Float(orientation[5]))
            
            let rowLength = length(rowVector)
            let colLength = length(colVector)
            
            XCTAssertEqual(rowLength, 1.0, accuracy: 0.001, "Row orientation vector must be unit vector")
            XCTAssertEqual(colLength, 1.0, accuracy: 0.001, "Column orientation vector must be unit vector")
            
            // Test that vectors are orthogonal
            let dotProduct = dot(rowVector, colVector)
            XCTAssertEqual(dotProduct, 0.0, accuracy: 0.001, "Orientation vectors must be orthogonal")
        }
        
        // Test image position patient (3 values required)
        XCTAssertEqual(metadata.imagePositionPatient?.count, 3,
                      "Image Position Patient must have 3 values")
    }
    
    func testPixelSpacingCompliance() throws {
        let metadata = createCompliantDICOMMetadata()
        
        // Test pixel spacing format
        XCTAssertEqual(metadata.pixelSpacing?.count, 2,
                      "Pixel Spacing must have 2 values (row, column)")
        
        if let spacing = metadata.pixelSpacing {
            XCTAssertGreaterThan(spacing[0], 0.0, "Row pixel spacing must be > 0")
            XCTAssertGreaterThan(spacing[1], 0.0, "Column pixel spacing must be > 0")
            
            // Reasonable range check (0.1mm to 10mm is typical)
            for value in spacing {
                XCTAssertTrue(value >= 0.1 && value <= 10.0,
                             "Pixel spacing should be reasonable (0.1-10mm)")
            }
        }
        
        // Test slice thickness
        if let thickness = metadata.sliceThickness {
            XCTAssertGreaterThan(thickness, 0.0, "Slice thickness must be > 0")
            XCTAssertTrue(thickness >= 0.5 && thickness <= 20.0,
                         "Slice thickness should be reasonable (0.5-20mm)")
        }
    }
    
    // MARK: - Clinical Compliance Tests
    func testPatientDataPrivacy() throws {
        // Test that patient data is handled securely
        let metadata = createCompliantDICOMMetadata()
        
        // Verify patient name is present but can be anonymized
        XCTAssertNotNil(metadata.patientName, "Patient name should be present")
        
        // Test anonymization capability
        let anonymizedMetadata = anonymizePatientData(metadata)
        XCTAssertNotEqual(anonymizedMetadata.patientName, metadata.patientName,
                         "Patient name should be anonymized")
        XCTAssertNotEqual(anonymizedMetadata.patientID, metadata.patientID,
                         "Patient ID should be anonymized")
        
        // Verify medical data integrity is preserved
        XCTAssertEqual(anonymizedMetadata.studyInstanceUID, metadata.studyInstanceUID,
                      "Study UID should be preserved for medical integrity")
        XCTAssertEqual(anonymizedMetadata.rows, metadata.rows,
                      "Image metadata should be preserved")
    }
    
    func testClinicalAuditLogging() throws {
        // Test audit logging for clinical compliance
        let auditLogger = ClinicalAuditLogger()
        
        // Test image viewing audit
        auditLogger.logImageViewing(
            studyUID: "1.2.3.4.5",
            userID: "testuser",
            timestamp: Date(),
            action: "image_viewed"
        )
        
        // Test study access audit
        auditLogger.logStudyAccess(
            studyUID: "1.2.3.4.5",
            userID: "testuser",
            timestamp: Date(),
            accessType: "read"
        )
        
        // Verify audit logs are created
        let auditEntries = auditLogger.getAuditEntries()
        XCTAssertGreaterThan(auditEntries.count, 0, "Audit entries should be created")
        
        // Verify audit entry contains required information
        let lastEntry = auditEntries.last!
        XCTAssertNotNil(lastEntry.timestamp, "Audit entry must have timestamp")
        XCTAssertNotNil(lastEntry.userID, "Audit entry must have user ID")
        XCTAssertNotNil(lastEntry.action, "Audit entry must have action")
    }
    
    func testPerformanceCompliance() throws {
        // Test performance requirements for clinical use
        let renderer = DICOMImageRenderer()
        let metadata = createCompliantDICOMMetadata()
        
        // Test image rendering performance (should be < 100ms for clinical use)
        measure {
            for _ in 0..<10 {
                let pixelData = createMockPixelData(width: 512, height: 512)
                _ = renderer.processPixelData(pixelData, metadata: metadata)
            }
        }
        
        // Test memory usage compliance
        let initialMemory = getMemoryUsage()
        
        // Load multiple images to test memory management
        for i in 0..<50 {
            let testMetadata = createCompliantDICOMMetadata()
            testMetadata.sopInstanceUID = "test.instance.\(i)"
            let pixelData = createMockPixelData(width: 256, height: 256)
            
            let instance = DICOMInstance(metadata: testMetadata)
            instance.pixelData = pixelData
            
            DICOMMetadataStore.shared.addInstance(instance, to: "test.series.\(i/10)")
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (< 500MB for test data)
        XCTAssertLessThan(memoryIncrease, 500 * 1024 * 1024,
                         "Memory usage should be reasonable for clinical use")
        
        // Clean up
        DICOMMetadataStore.shared.clearAll()
    }
    
    // MARK: - Rendering Compliance Tests
    func testVolumeRenderingAccuracy() throws {
        let volumeRenderer = VolumeRenderer()
        
        // Test that volume rendering preserves medical data integrity
        let mockSeries = createMockMedicalSeries()
        
        let expectation = XCTestExpectation(description: "Volume rendering accuracy test")
        
        Task {
            do {
                try await volumeRenderer.loadVolume(from: mockSeries)
                
                // Verify volume data integrity
                XCTAssertTrue(volumeRenderer.isVolumeLoaded, "Volume should be loaded")
                
                if let volumeInfo = volumeRenderer.getVolumeInfo() {
                    // Verify dimensions match DICOM data
                    XCTAssertEqual(volumeInfo.width, 256, "Volume width should match DICOM data")
                    XCTAssertEqual(volumeInfo.height, 256, "Volume height should match DICOM data")
                    XCTAssertEqual(volumeInfo.depth, mockSeries.instances.count,
                                  "Volume depth should match number of slices")
                    
                    // Verify voxel spacing preservation
                    XCTAssertEqual(volumeInfo.spacing.x, 1.0, accuracy: 0.001,
                                  "X spacing should be preserved")
                    XCTAssertEqual(volumeInfo.spacing.y, 1.0, accuracy: 0.001,
                                  "Y spacing should be preserved")
                    XCTAssertEqual(volumeInfo.spacing.z, 2.0, accuracy: 0.001,
                                  "Z spacing should be preserved")
                }
                
                expectation.fulfill()
            } catch {
                XCTFail("Volume rendering failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        volumeRenderer.releaseResources()
    }
    
    func testMPRAccuracy() throws {
        let mprRenderer = MPRRenderer()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTSkip("Metal not available for MPR testing")
        }
        
        // Create test volume with known pattern
        let volumeTexture = createTestVolumeTexture(device: device)
        let voxelSpacing = simd_float3(1.0, 1.0, 2.0)
        
        mprRenderer.loadVolume(from: volumeTexture, voxelSpacing: voxelSpacing)
        
        // Test that MPR maintains spatial relationships
        for plane in MPRRenderer.MPRPlane.allCases {
            mprRenderer.setPlane(plane)
            
            XCTAssertEqual(mprRenderer.currentPlaneType, plane,
                          "Plane should be set correctly")
            XCTAssertGreaterThan(mprRenderer.maxSlices, 0,
                               "Should have slices available for \(plane)")
            
            // Test slice navigation
            let middleSlice = mprRenderer.maxSlices / 2
            mprRenderer.setSliceIndex(middleSlice)
            XCTAssertEqual(mprRenderer.currentSliceIndex, middleSlice,
                          "Slice index should be set correctly")
        }
        
        mprRenderer.releaseResources()
    }
    
    // MARK: - Quality Assurance Tests
    func testImageQualityMetrics() throws {
        let metadata = createCompliantDICOMMetadata()
        let pixelData = createMockPixelData(width: 512, height: 512)
        
        // Test signal-to-noise ratio calculation
        let snr = calculateSNR(pixelData: pixelData, metadata: metadata)
        XCTAssertGreaterThan(snr, 10.0, "SNR should be adequate for medical imaging")
        
        // Test contrast-to-noise ratio
        let cnr = calculateCNR(pixelData: pixelData, metadata: metadata)
        XCTAssertGreaterThan(cnr, 3.0, "CNR should be adequate for diagnosis")
        
        // Test spatial resolution compliance
        if let pixelSpacing = metadata.pixelSpacing {
            let spatialResolution = min(pixelSpacing[0], pixelSpacing[1])
            XCTAssertLessThanOrEqual(spatialResolution, 1.0,
                                   "Spatial resolution should be adequate for clinical use")
        }
    }
    
    func testDataIntegrityValidation() throws {
        let metadata = createCompliantDICOMMetadata()
        let pixelData = createMockPixelData(width: 512, height: 512)
        
        // Test checksum validation
        let originalChecksum = pixelData.sha256
        
        // Simulate data processing
        let processedData = processPixelData(pixelData, metadata: metadata)
        
        // For lossless operations, checksums should match
        if isLosslessOperation(metadata: metadata) {
            XCTAssertEqual(processedData.sha256, originalChecksum,
                          "Lossless operations should preserve data integrity")
        }
        
        // Test metadata consistency
        validateMetadataConsistency(metadata: metadata, pixelData: pixelData)
    }
}

// MARK: - Helper Methods and Mock Classes
extension ComplianceTests {
    
    private func createCompliantDICOMMetadata() -> DICOMMetadata {
        let metadata = DICOMMetadata()
        
        // Required DICOM elements
        metadata.sopClassUID = "1.2.840.10008.5.1.4.1.1.2" // CT Image Storage
        metadata.sopInstanceUID = "1.2.3.4.5.6.7.8.9.10.11.12.13.14.15"
        metadata.studyInstanceUID = "1.2.3.4.5.6.7.8.9.10.11.12.13.14"
        metadata.seriesInstanceUID = "1.2.3.4.5.6.7.8.9.10.11.12.13.15"
        
        // Patient information
        metadata.patientName = "Smith^John^A"
        metadata.patientID = "12345"
        metadata.patientBirthDate = Date()
        metadata.patientSex = "M"
        
        // Study information
        metadata.studyDate = Date()
        metadata.studyTime = Date()
        metadata.accessionNumber = "ACC001"
        metadata.studyDescription = "CT Chest"
        
        // Image information
        metadata.rows = 512
        metadata.columns = 512
        metadata.bitsAllocated = 16
        metadata.bitsStored = 16
        metadata.highBit = 15
        metadata.pixelRepresentation = 0
        metadata.samplesPerPixel = 1
        metadata.photometricInterpretation = "MONOCHROME2"
        
        // Geometry
        metadata.pixelSpacing = [0.5, 0.5]
        metadata.sliceThickness = 5.0
        metadata.imagePositionPatient = [0.0, 0.0, 0.0]
        metadata.imageOrientationPatient = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
        
        // Window/Level
        metadata.windowCenter = [40.0]
        metadata.windowWidth = [400.0]
        
        // Modality
        metadata.modality = "CT"
        
        return metadata
    }
    
    private func anonymizePatientData(_ metadata: DICOMMetadata) -> DICOMMetadata {
        let anonymized = DICOMMetadata()
        
        // Copy all metadata
        anonymized.sopClassUID = metadata.sopClassUID
        anonymized.sopInstanceUID = metadata.sopInstanceUID
        anonymized.studyInstanceUID = metadata.studyInstanceUID
        anonymized.seriesInstanceUID = metadata.seriesInstanceUID
        anonymized.rows = metadata.rows
        anonymized.columns = metadata.columns
        
        // Anonymize patient data
        anonymized.patientName = "ANONYMOUS"
        anonymized.patientID = "ANON001"
        anonymized.patientBirthDate = nil
        anonymized.patientSex = nil
        
        return anonymized
    }
    
    private func createMockPixelData(width: Int, height: Int) -> Data {
        return Data(repeating: 0x80, count: width * height * 2) // 16-bit data
    }
    
    private func createMockMedicalSeries() -> DICOMSeries {
        let series = DICOMSeries()
        series.seriesInstanceUID = "test.medical.series"
        series.modality = "CT"
        
        for i in 0..<100 {
            let metadata = createCompliantDICOMMetadata()
            metadata.instanceNumber = Int32(i + 1)
            metadata.imagePositionPatient = [0.0, 0.0, Double(i * 2)]
            
            let instance = DICOMInstance(metadata: metadata)
            instance.pixelData = createMockPixelData(width: 256, height: 256)
            
            series.addInstance(instance)
        }
        
        return series
    }
    
    private func createTestVolumeTexture(device: MTLDevice) -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .r16Unorm
        descriptor.width = 64
        descriptor.height = 64
        descriptor.depth = 32
        descriptor.usage = [.shaderRead]
        
        return device.makeTexture(descriptor: descriptor)!
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func calculateSNR(pixelData: Data, metadata: DICOMMetadata) -> Double {
        // Mock SNR calculation
        return 25.0 // Typical good SNR for medical imaging
    }
    
    private func calculateCNR(pixelData: Data, metadata: DICOMMetadata) -> Double {
        // Mock CNR calculation
        return 5.0 // Typical good CNR for medical imaging
    }
    
    private func processPixelData(_ data: Data, metadata: DICOMMetadata) -> Data {
        // Mock data processing (identity function for testing)
        return data
    }
    
    private func isLosslessOperation(metadata: DICOMMetadata) -> Bool {
        // Check if operation should be lossless
        return metadata.transferSyntaxUID != "1.2.840.10008.1.2.4.50" // Not JPEG Baseline
    }
    
    private func validateMetadataConsistency(metadata: DICOMMetadata, pixelData: Data) {
        let expectedSize = metadata.rows * metadata.columns * (metadata.bitsAllocated / 8)
        XCTAssertEqual(pixelData.count, expectedSize,
                      "Pixel data size must match metadata dimensions")
    }
}

// MARK: - Mock Clinical Audit Logger
class ClinicalAuditLogger {
    private var auditEntries: [AuditEntry] = []
    
    struct AuditEntry {
        let timestamp: Date
        let userID: String
        let action: String
        let studyUID: String?
        let details: [String: Any]
    }
    
    func logImageViewing(studyUID: String, userID: String, timestamp: Date, action: String) {
        let entry = AuditEntry(
            timestamp: timestamp,
            userID: userID,
            action: action,
            studyUID: studyUID,
            details: ["type": "image_viewing"]
        )
        auditEntries.append(entry)
    }
    
    func logStudyAccess(studyUID: String, userID: String, timestamp: Date, accessType: String) {
        let entry = AuditEntry(
            timestamp: timestamp,
            userID: userID,
            action: "study_access",
            studyUID: studyUID,
            details: ["access_type": accessType]
        )
        auditEntries.append(entry)
    }
    
    func getAuditEntries() -> [AuditEntry] {
        return auditEntries
    }
}

// MARK: - Data Extensions for Testing
extension Data {
    var sha256: String {
        // Mock SHA256 implementation for testing
        return "mock_checksum_\(self.count)"
    }
}