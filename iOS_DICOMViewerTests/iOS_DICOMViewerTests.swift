import XCTest
import Metal
import simd
@testable import iOS_DICOMViewer

/// Core unit tests for iOS DICOM Viewer components
class iOS_DICOMViewerTests: XCTestCase {
    
    // MARK: - Test Setup
    override func setUpWithError() throws {
        // Initialize core services for testing
        DICOMServiceManager.shared.initialize()
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        DICOMMetadataStore.shared.clearAll()
    }
    
    // MARK: - DICOM Model Tests
    func testDICOMMetadataInitialization() throws {
        let metadata = DICOMMetadata()
        
        XCTAssertNotNil(metadata.studyInstanceUID)
        XCTAssertNotNil(metadata.seriesInstanceUID) 
        XCTAssertNotNil(metadata.sopInstanceUID)
        XCTAssertEqual(metadata.rows, 512)
        XCTAssertEqual(metadata.columns, 512)
        XCTAssertEqual(metadata.bitsStored, 16)
    }
    
    func testDICOMStudyHierarchy() throws {
        let study = DICOMStudy()
        let series = DICOMSeries()
        let instance = DICOMInstance(metadata: DICOMMetadata())
        
        series.addInstance(instance)
        study.addSeries(series)
        
        XCTAssertEqual(study.series.count, 1)
        XCTAssertEqual(series.instances.count, 1)
        XCTAssertEqual(study.series.first?.instances.first?.metadata.sopInstanceUID, 
                      instance.metadata.sopInstanceUID)
    }
    
    func testDICOMSeriesSorting() throws {
        let series = DICOMSeries()
        
        // Create instances with different slice positions
        for i in 0..<10 {
            let metadata = DICOMMetadata()
            metadata.imagePositionPatient = [0.0, 0.0, Double(i * 5)] // 5mm spacing
            metadata.instanceNumber = Int32(i + 1)
            
            let instance = DICOMInstance(metadata: metadata)
            series.addInstance(instance)
        }
        
        let sortedInstances = series.sortedBySlicePosition
        
        XCTAssertEqual(sortedInstances.count, 10)
        
        // Verify ascending order by Z position
        for i in 1..<sortedInstances.count {
            let prevZ = sortedInstances[i-1].metadata.imagePositionPatient?[2] ?? 0
            let currentZ = sortedInstances[i].metadata.imagePositionPatient?[2] ?? 0
            XCTAssertLessThanOrEqual(prevZ, currentZ)
        }
    }
    
    // MARK: - DICOM Metadata Store Tests
    func testMetadataStoreOperations() throws {
        let store = DICOMMetadataStore.shared
        let study = DICOMStudy()
        study.studyInstanceUID = "test.study.uid"
        
        // Test adding study
        store.addStudy(study)
        XCTAssertEqual(store.studies.count, 1)
        
        // Test retrieving study
        let retrievedStudy = store.getStudy(withUID: "test.study.uid")
        XCTAssertNotNil(retrievedStudy)
        XCTAssertEqual(retrievedStudy?.studyInstanceUID, study.studyInstanceUID)
        
        // Test clearing
        store.clearAll()
        XCTAssertEqual(store.studies.count, 0)
    }
    
    // MARK: - DICOM Error Handling Tests
    func testDICOMErrorTypes() throws {
        let fileNotFoundError = DICOMError.fileNotFound(path: "/invalid/path")
        let invalidFormatError = DICOMError.invalidFile(reason: .notDICOM)
        let memoryError = DICOMError.memoryAllocationFailed(requiredBytes: 1000000)
        
        XCTAssertEqual(fileNotFoundError.localizedDescription, "DICOM file not found at path: /invalid/path")
        XCTAssertTrue(invalidFormatError.localizedDescription.contains("Invalid DICOM file"))
        XCTAssertTrue(memoryError.localizedDescription.contains("Memory allocation failed"))
    }
    
    // MARK: - Cache Manager Tests
    func testDICOMCacheOperations() throws {
        let cacheManager = DICOMCacheManager.shared
        let testKey = "test.instance.uid"
        let testData = Data(repeating: 0xFF, count: 1000)
        
        // Test caching
        cacheManager.cachePixelData(testData, forInstance: testKey)
        
        // Test retrieval
        let cachedData = cacheManager.getCachedPixelData(forInstance: testKey)
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData?.count, testData.count)
        
        // Test memory pressure handling
        cacheManager.clearCache()
        let clearedData = cacheManager.getCachedPixelData(forInstance: testKey)
        XCTAssertNil(clearedData)
    }
    
    // MARK: - Image Renderer Tests
    func testWindowLevelCalculations() throws {
        let renderer = DICOMImageRenderer()
        
        // Test standard CT window/level
        let ctCenter: Float = 40
        let ctWidth: Float = 400
        
        let testValues: [Float] = [-160, 40, 240] // HU values
        let expectedNormalized: [Float] = [0.0, 0.5, 1.0]
        
        for (index, value) in testValues.enumerated() {
            let normalized = renderer.applyWindowLevel(value: value, center: ctCenter, width: ctWidth)
            XCTAssertEqual(normalized, expectedNormalized[index], accuracy: 0.01)
        }
    }
    
    func testImageTransformations() throws {
        let renderer = DICOMImageRenderer()
        let transform = CGAffineTransform.identity
            .scaledBy(x: 2.0, y: 2.0)
            .rotated(by: .pi / 4)
        
        // Test that transformations maintain image bounds
        let originalSize = CGSize(width: 512, height: 512)
        let transformedBounds = renderer.calculateTransformedBounds(size: originalSize, transform: transform)
        
        XCTAssertGreaterThan(transformedBounds.width, originalSize.width)
        XCTAssertGreaterThan(transformedBounds.height, originalSize.height)
    }
    
    // MARK: - Clinical Compliance Tests
    func testClinicalComplianceLogging() throws {
        let complianceManager = ClinicalComplianceManager.shared
        
        let testOperation = "DICOM Image Viewing"
        let startTime = CFAbsoluteTimeGetCurrent()
        
        complianceManager.measureRenderingPerformance(operation: testOperation) {
            // Simulate some work
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Verify performance was measured (should be at least 10ms)
        XCTAssertGreaterThan(duration, 0.01)
    }
    
    // MARK: - Memory Management Tests
    func testMemoryPressureHandling() throws {
        let cacheManager = DICOMCacheManager.shared
        
        // Fill cache with test data
        for i in 0..<100 {
            let testData = Data(repeating: UInt8(i), count: 10000) // 10KB per item
            cacheManager.cachePixelData(testData, forInstance: "test.instance.\(i)")
        }
        
        // Simulate memory pressure
        cacheManager.handleMemoryPressure()
        
        // Verify cache was cleared
        let cachedData = cacheManager.getCachedPixelData(forInstance: "test.instance.0")
        XCTAssertNil(cachedData)
    }
    
    // MARK: - Performance Tests
    func testPerformanceMetadataParsing() throws {
        let parser = DICOMParser()
        
        measure {
            // Simulate parsing multiple metadata objects
            for _ in 0..<1000 {
                let metadata = DICOMMetadata()
                metadata.studyInstanceUID = UUID().uuidString
                metadata.seriesInstanceUID = UUID().uuidString
                metadata.sopInstanceUID = UUID().uuidString
            }
        }
    }
    
    func testPerformanceCacheOperations() throws {
        let cacheManager = DICOMCacheManager.shared
        let testData = Data(repeating: 0xFF, count: 1000)
        
        measure {
            for i in 0..<100 {
                cacheManager.cachePixelData(testData, forInstance: "perf.test.\(i)")
                _ = cacheManager.getCachedPixelData(forInstance: "perf.test.\(i)")
            }
        }
    }
}

// MARK: - Mock Data Generation
extension iOS_DICOMViewerTests {
    
    func createMockDICOMStudy(seriesCount: Int = 3, instancesPerSeries: Int = 20) -> DICOMStudy {
        let study = DICOMStudy()
        study.studyInstanceUID = "test.study.\(UUID().uuidString)"
        study.patientName = "Test Patient"
        study.studyDate = Date()
        study.studyDescription = "Test Study"
        
        for seriesIndex in 0..<seriesCount {
            let series = DICOMSeries()
            series.seriesInstanceUID = "test.series.\(seriesIndex)"
            series.seriesDescription = "Test Series \(seriesIndex + 1)"
            series.modality = seriesIndex == 0 ? "CT" : "MR"
            
            for instanceIndex in 0..<instancesPerSeries {
                let metadata = DICOMMetadata()
                metadata.sopInstanceUID = "test.instance.\(seriesIndex).\(instanceIndex)"
                metadata.instanceNumber = Int32(instanceIndex + 1)
                metadata.imagePositionPatient = [0.0, 0.0, Double(instanceIndex * 5)]
                metadata.pixelSpacing = [0.5, 0.5]
                metadata.sliceThickness = 5.0
                metadata.modality = series.modality
                
                let instance = DICOMInstance(metadata: metadata)
                instance.pixelData = Data(repeating: UInt8(instanceIndex % 256), count: 512 * 512 * 2)
                
                series.addInstance(instance)
            }
            
            study.addSeries(series)
        }
        
        return study
    }
    
    func createMockPixelData(width: Int = 512, height: Int = 512, bitsPerPixel: Int = 16) -> Data {
        let bytesPerPixel = bitsPerPixel / 8
        let totalBytes = width * height * bytesPerPixel
        
        var data = Data(capacity: totalBytes)
        
        for y in 0..<height {
            for x in 0..<width {
                // Create a simple gradient pattern
                let value = UInt16((x + y) % (1 << bitsPerPixel))
                
                if bitsPerPixel == 16 {
                    withUnsafeBytes(of: value.littleEndian) { bytes in
                        data.append(contentsOf: bytes)
                    }
                } else {
                    data.append(UInt8(value & 0xFF))
                }
            }
        }
        
        return data
    }
}