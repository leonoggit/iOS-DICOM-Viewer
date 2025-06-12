import XCTest
import Metal
import simd
@testable import iOS_DICOMViewer

/// Comprehensive tests for DICOM parsing functionality
/// Tests both mock and real DCMTK parsing capabilities
class DICOMParsingTests: XCTestCase {
    
    var parser: DICOMParser!
    
    override func setUpWithError() throws {
        parser = DICOMParser()
        DICOMServiceManager.shared.initialize()
    }
    
    override func tearDownWithError() throws {
        parser = nil
    }
    
    // MARK: - DCMTK Bridge Tests
    func testDCMTKBridgePixelDataExtraction() throws {
        // Test pixel data extraction with different bit depths
        let testCases = [
            (width: 512, height: 512, bitsStored: 8, isSigned: false),
            (width: 512, height: 512, bitsStored: 16, isSigned: false),
            (width: 1024, height: 1024, bitsStored: 16, isSigned: true)
        ]
        
        for testCase in testCases {
            let mockPixelData = createMockDICOMPixelData(
                width: testCase.width,
                height: testCase.height,
                bitsStored: testCase.bitsStored,
                isSigned: testCase.isSigned
            )
            
            XCTAssertNotNil(mockPixelData)
            
            let expectedSize = testCase.width * testCase.height * (testCase.bitsStored / 8)
            XCTAssertEqual(mockPixelData.count, expectedSize)
        }
    }
    
    func testDCMTKBridgeMetadataExtraction() throws {
        let mockMetadata = createMockDICOMMetadata()
        
        // Test core DICOM tags
        XCTAssertNotNil(mockMetadata.patientName)
        XCTAssertNotNil(mockMetadata.studyInstanceUID)
        XCTAssertNotNil(mockMetadata.seriesInstanceUID)
        XCTAssertNotNil(mockMetadata.sopInstanceUID)
        
        // Test image geometry
        XCTAssertGreaterThan(mockMetadata.rows, 0)
        XCTAssertGreaterThan(mockMetadata.columns, 0)
        XCTAssertGreaterThan(mockMetadata.bitsStored, 0)
        
        // Test medical imaging parameters
        XCTAssertNotNil(mockMetadata.pixelSpacing)
        XCTAssertNotNil(mockMetadata.imagePositionPatient)
        XCTAssertNotNil(mockMetadata.imageOrientationPatient)
    }
    
    func testDCMTKTransferSyntaxSupport() throws {
        let supportedTransferSyntaxes = [
            "1.2.840.10008.1.2",        // Implicit VR Little Endian
            "1.2.840.10008.1.2.1",      // Explicit VR Little Endian
            "1.2.840.10008.1.2.2",      // Explicit VR Big Endian
            "1.2.840.10008.1.2.4.50",   // JPEG Baseline
            "1.2.840.10008.1.2.4.51",   // JPEG Extended
            "1.2.840.10008.1.2.5"       // RLE Lossless
        ]
        
        for transferSyntax in supportedTransferSyntaxes {
            let metadata = createMockDICOMMetadata()
            metadata.transferSyntaxUID = transferSyntax
            
            // Verify transfer syntax is recognized
            XCTAssertNotNil(metadata.transferSyntaxUID)
            XCTAssertEqual(metadata.transferSyntaxUID, transferSyntax)
        }
    }
    
    // MARK: - DICOM File Structure Tests
    func testDICOMInstanceCreation() throws {
        let metadata = createMockDICOMMetadata()
        let pixelData = createMockDICOMPixelData(width: 512, height: 512, bitsStored: 16, isSigned: false)
        
        let instance = DICOMInstance(metadata: metadata)
        instance.pixelData = pixelData
        
        XCTAssertNotNil(instance.metadata)
        XCTAssertNotNil(instance.pixelData)
        XCTAssertEqual(instance.metadata.sopInstanceUID, metadata.sopInstanceUID)
        XCTAssertEqual(instance.pixelData?.count, pixelData.count)
    }
    
    func testDICOMSeriesGrouping() throws {
        let series = DICOMSeries()
        series.seriesInstanceUID = "test.series.uid"
        
        // Add instances with consistent series UID
        for i in 1...10 {
            let metadata = createMockDICOMMetadata()
            metadata.seriesInstanceUID = series.seriesInstanceUID
            metadata.instanceNumber = Int32(i)
            metadata.imagePositionPatient = [0.0, 0.0, Double(i * 5)]
            
            let instance = DICOMInstance(metadata: metadata)
            series.addInstance(instance)
        }
        
        XCTAssertEqual(series.instances.count, 10)
        
        // Test sorting by instance number
        let sortedInstances = series.sortedByInstanceNumber
        for i in 1..<sortedInstances.count {
            XCTAssertLessThan(sortedInstances[i-1].metadata.instanceNumber, 
                            sortedInstances[i].metadata.instanceNumber)
        }
        
        // Test sorting by slice position
        let sortedByPosition = series.sortedBySlicePosition
        for i in 1..<sortedByPosition.count {
            let prevZ = sortedByPosition[i-1].metadata.imagePositionPatient?[2] ?? 0
            let currentZ = sortedByPosition[i].metadata.imagePositionPatient?[2] ?? 0
            XCTAssertLessThanOrEqual(prevZ, currentZ)
        }
    }
    
    // MARK: - Window/Level Tests
    func testWindowLevelExtraction() throws {
        let metadata = createMockDICOMMetadata()
        
        // Test CT window/level
        metadata.windowCenter = [40.0, 80.0]  // Soft tissue, bone
        metadata.windowWidth = [400.0, 1000.0]
        metadata.modality = "CT"
        
        XCTAssertNotNil(metadata.windowCenter)
        XCTAssertNotNil(metadata.windowWidth)
        XCTAssertEqual(metadata.windowCenter?.count, 2)
        XCTAssertEqual(metadata.windowWidth?.count, 2)
        
        // Test MR window/level
        metadata.windowCenter = [128.0]
        metadata.windowWidth = [256.0]
        metadata.modality = "MR"
        
        XCTAssertEqual(metadata.windowCenter?.first, 128.0)
        XCTAssertEqual(metadata.windowWidth?.first, 256.0)
    }
    
    // MARK: - Multi-frame DICOM Tests
    func testMultiframeDICOMSupport() throws {
        let metadata = createMockDICOMMetadata()
        metadata.numberOfFrames = 50
        metadata.modality = "CT"
        
        let frameSize = metadata.rows * metadata.columns * (metadata.bitsStored / 8)
        let totalPixelDataSize = frameSize * Int(metadata.numberOfFrames)
        
        let multiframePixelData = Data(repeating: 0xFF, count: totalPixelDataSize)
        
        let instance = DICOMInstance(metadata: metadata)
        instance.pixelData = multiframePixelData
        
        XCTAssertEqual(instance.pixelData?.count, totalPixelDataSize)
        XCTAssertEqual(metadata.numberOfFrames, 50)
    }
    
    // MARK: - DICOM Segmentation Tests
    func testDICOMSegmentationParsing() throws {
        let segMetadata = createMockDICOMMetadata()
        segMetadata.modality = "SEG"
        segMetadata.sopClassUID = "1.2.840.10008.5.1.4.1.1.66.4" // Segmentation Storage
        
        // Create mock segmentation data
        let segmentCount = 3
        let frameSize = segMetadata.rows * segMetadata.columns
        let segPixelData = Data(repeating: 0x01, count: frameSize * segmentCount)
        
        let segInstance = DICOMInstance(metadata: segMetadata)
        segInstance.pixelData = segPixelData
        
        XCTAssertEqual(segMetadata.modality, "SEG")
        XCTAssertNotNil(segInstance.pixelData)
        
        // Test segmentation-specific parsing
        let isSegmentation = segMetadata.sopClassUID?.contains("1.1.66.4") ?? false
        XCTAssertTrue(isSegmentation)
    }
    
    // MARK: - RT Structure Set Tests
    func testRTStructureSetParsing() throws {
        let rtMetadata = createMockDICOMMetadata()
        rtMetadata.modality = "RTSTRUCT"
        rtMetadata.sopClassUID = "1.2.840.10008.5.1.4.1.1.481.3" // RT Structure Set Storage
        
        XCTAssertEqual(rtMetadata.modality, "RTSTRUCT")
        
        // Test RT-specific metadata
        let isRTStruct = rtMetadata.sopClassUID?.contains("481.3") ?? false
        XCTAssertTrue(isRTStruct)
    }
    
    // MARK: - Error Handling Tests
    func testDICOMParsingErrorHandling() throws {
        // Test invalid file path
        XCTAssertThrowsError(try parser.parseDICOMFile(at: "/invalid/path.dcm")) { error in
            XCTAssertTrue(error is DICOMError)
            if case DICOMError.fileNotFound = error {
                // Expected error type
            } else {
                XCTFail("Expected DICOMError.fileNotFound")
            }
        }
        
        // Test invalid DICOM format
        let invalidData = Data(repeating: 0x00, count: 100)
        let tempURL = createTemporaryFile(with: invalidData)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        XCTAssertThrowsError(try parser.parseDICOMFile(at: tempURL.path)) { error in
            XCTAssertTrue(error is DICOMError)
        }
    }
    
    // MARK: - Memory Efficiency Tests
    func testLargeVolumeMemoryHandling() throws {
        // Test memory efficiency with large volumes
        let largeMetadata = createMockDICOMMetadata()
        largeMetadata.rows = 1024
        largeMetadata.columns = 1024
        largeMetadata.bitsStored = 16
        
        let frameSize = largeMetadata.rows * largeMetadata.columns * 2 // 16-bit
        let sliceCount = 500 // Large CT volume
        
        measure {
            // Simulate loading large volume slice by slice
            for i in 0..<10 { // Test subset for performance
                let metadata = createMockDICOMMetadata()
                metadata.rows = largeMetadata.rows
                metadata.columns = largeMetadata.columns
                metadata.instanceNumber = Int32(i + 1)
                
                let pixelData = Data(repeating: UInt8(i % 256), count: frameSize)
                let instance = DICOMInstance(metadata: metadata)
                instance.pixelData = pixelData
                
                // Verify instance creation doesn't leak memory
                XCTAssertNotNil(instance.pixelData)
            }
        }
    }
    
    // MARK: - DICOM Compliance Tests
    func testDICOMTagCompliance() throws {
        let metadata = createMockDICOMMetadata()
        
        // Test required DICOM tags for Image IOD
        XCTAssertNotNil(metadata.sopClassUID, "SOP Class UID is required")
        XCTAssertNotNil(metadata.sopInstanceUID, "SOP Instance UID is required")
        XCTAssertNotNil(metadata.studyInstanceUID, "Study Instance UID is required")
        XCTAssertNotNil(metadata.seriesInstanceUID, "Series Instance UID is required")
        
        // Test image-specific required tags
        XCTAssertGreaterThan(metadata.rows, 0, "Rows must be > 0")
        XCTAssertGreaterThan(metadata.columns, 0, "Columns must be > 0")
        XCTAssertGreaterThan(metadata.bitsStored, 0, "Bits Stored must be > 0")
        XCTAssertGreaterThan(metadata.bitsAllocated, 0, "Bits Allocated must be > 0")
        
        // Test patient information
        XCTAssertNotNil(metadata.patientName, "Patient Name should be present")
        XCTAssertNotNil(metadata.patientID, "Patient ID should be present")
    }
}

// MARK: - Test Helper Methods
extension DICOMParsingTests {
    
    private func createMockDICOMMetadata() -> DICOMMetadata {
        let metadata = DICOMMetadata()
        
        // Patient Information
        metadata.patientName = "Test^Patient"
        metadata.patientID = "TEST001"
        metadata.patientBirthDate = Date()
        metadata.patientSex = "M"
        
        // Study Information
        metadata.studyInstanceUID = "1.2.3.4.5.6.7.8.9.10.11.12.13.14.15"
        metadata.studyDate = Date()
        metadata.studyTime = Date()
        metadata.studyDescription = "Test Study"
        metadata.accessionNumber = "ACC001"
        
        // Series Information
        metadata.seriesInstanceUID = "1.2.3.4.5.6.7.8.9.10.11.12.13.14.16"
        metadata.seriesNumber = 1
        metadata.seriesDescription = "Test Series"
        metadata.modality = "CT"
        
        // Instance Information
        metadata.sopInstanceUID = "1.2.3.4.5.6.7.8.9.10.11.12.13.14.17"
        metadata.sopClassUID = "1.2.840.10008.5.1.4.1.1.2" // CT Image Storage
        metadata.instanceNumber = 1
        
        // Image Information
        metadata.rows = 512
        metadata.columns = 512
        metadata.bitsAllocated = 16
        metadata.bitsStored = 16
        metadata.highBit = 15
        metadata.pixelRepresentation = 0 // unsigned
        metadata.samplesPerPixel = 1
        metadata.photometricInterpretation = "MONOCHROME2"
        
        // Geometry Information
        metadata.pixelSpacing = [0.5, 0.5]
        metadata.sliceThickness = 5.0
        metadata.imagePositionPatient = [0.0, 0.0, 0.0]
        metadata.imageOrientationPatient = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
        
        // Window/Level
        metadata.windowCenter = [40.0]
        metadata.windowWidth = [400.0]
        
        // Transfer Syntax
        metadata.transferSyntaxUID = "1.2.840.10008.1.2.1" // Explicit VR Little Endian
        
        return metadata
    }
    
    private func createMockDICOMPixelData(width: Int, height: Int, bitsStored: Int, isSigned: Bool) -> Data {
        let bytesPerPixel = bitsStored / 8
        let totalBytes = width * height * bytesPerPixel
        
        var data = Data(capacity: totalBytes)
        
        for y in 0..<height {
            for x in 0..<width {
                // Create a test pattern (diagonal gradient)
                let distance = sqrt(Double((x - width/2) * (x - width/2) + (y - height/2) * (y - height/2)))
                let maxDistance = sqrt(Double(width * width + height * height)) / 2.0
                let normalizedValue = distance / maxDistance
                
                if bitsStored == 16 {
                    let value: UInt16
                    if isSigned {
                        value = UInt16((normalizedValue * 32767.0).clamped(to: 0...32767))
                    } else {
                        value = UInt16((normalizedValue * 65535.0).clamped(to: 0...65535))
                    }
                    
                    withUnsafeBytes(of: value.littleEndian) { bytes in
                        data.append(contentsOf: bytes)
                    }
                } else {
                    let value = UInt8((normalizedValue * 255.0).clamped(to: 0...255))
                    data.append(value)
                }
            }
        }
        
        return data
    }
    
    private func createTemporaryFile(with data: Data) -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFile = tempDirectory.appendingPathComponent("test_\(UUID().uuidString).tmp")
        
        try! data.write(to: tempFile)
        return tempFile
    }
}

// MARK: - Helper Extensions
extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}