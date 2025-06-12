import XCTest
import Metal
import MetalKit
import simd
@testable import iOS_DICOMViewer

/// Performance and benchmarking tests for iOS DICOM Viewer
/// Tests rendering performance, memory usage, and scalability
class PerformanceTests: XCTestCase {
    
    var device: MTLDevice!
    var volumeRenderer: VolumeRenderer!
    var mprRenderer: MPRRenderer!
    
    override func setUpWithError() throws {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            throw XCTestError(.failureWhileWaiting, userInfo: [NSLocalizedDescriptionKey: "Metal not supported"])
        }
        
        device = metalDevice
        volumeRenderer = VolumeRenderer()
        mprRenderer = MPRRenderer()
        
        print("🚀 Performance tests setup with Metal device: \(device.name)")
    }
    
    override func tearDownWithError() throws {
        volumeRenderer?.releaseResources()
        mprRenderer?.releaseResources()
        device = nil
    }
    
    // MARK: - DICOM Parsing Performance Tests
    func testDICOMParsingPerformance() throws {
        let parser = DICOMParser()
        
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            // Test parsing performance with multiple instances
            for i in 0..<100 {
                let metadata = createLargeDICOMMetadata(instanceNumber: i)
                let pixelData = createLargePixelData()
                
                let instance = DICOMInstance(metadata: metadata)
                instance.pixelData = pixelData
                
                // Simulate metadata processing
                _ = instance.metadata.sopInstanceUID
                _ = instance.metadata.studyInstanceUID
                _ = instance.pixelData?.count
            }
        }
    }
    
    func testMetadataStorePerformance() throws {
        let store = DICOMMetadataStore.shared
        
        measure(metrics: [XCTCPUMetric(), XCTStorageMetric()]) {
            // Test large-scale metadata operations
            for studyIndex in 0..<10 {
                let study = DICOMStudy()
                study.studyInstanceUID = "performance.test.study.\(studyIndex)"
                
                for seriesIndex in 0..<5 {
                    let series = DICOMSeries()
                    series.seriesInstanceUID = "performance.test.series.\(studyIndex).\(seriesIndex)"
                    
                    for instanceIndex in 0..<50 {
                        let metadata = createLargeDICOMMetadata(instanceNumber: instanceIndex)
                        metadata.studyInstanceUID = study.studyInstanceUID
                        metadata.seriesInstanceUID = series.seriesInstanceUID
                        
                        let instance = DICOMInstance(metadata: metadata)
                        series.addInstance(instance)
                    }
                    
                    study.addSeries(series)
                }
                
                store.addStudy(study)
            }
            
            // Test retrieval performance
            for studyIndex in 0..<10 {
                let studyUID = "performance.test.study.\(studyIndex)"
                _ = store.getStudy(withUID: studyUID)
            }
            
            // Cleanup
            store.clearAll()
        }
    }
    
    // MARK: - Volume Rendering Performance Tests
    func testVolumeLoadingPerformance() throws {
        let qualityLevels: [VolumeRenderer.QualityLevel] = [.low, .medium, .high, .ultra]
        
        for quality in qualityLevels {
            volumeRenderer.setQualityLevel(quality)
            
            measure(metrics: [XCTCPUMetric(), XCTMemoryMetric(), XCTClockMetric()]) {
                let expectation = XCTestExpectation(description: "Volume loading \(quality)")
                
                Task {
                    do {
                        let largeSeries = createLargeDICOMSeries(size: .large) // 512x512x200
                        try await volumeRenderer.loadVolume(from: largeSeries)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Volume loading failed: \(error)")
                        expectation.fulfill()
                    }
                }
                
                wait(for: [expectation], timeout: 30.0)
                volumeRenderer.releaseResources()
            }
        }
    }
    
    func testVolumeRenderingFPS() throws {
        // Load a test volume
        let expectation = XCTestExpectation(description: "Volume loading for FPS test")
        
        Task {
            do {
                let testSeries = createLargeDICOMSeries(size: .medium) // 256x256x100
                try await volumeRenderer.loadVolume(from: testSeries)
                expectation.fulfill()
            } catch {
                XCTFail("Volume loading failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        let drawable = try createMockDrawable(size: CGSize(width: 1024, height: 1024))
        let viewportSize = CGSize(width: 1024, height: 1024)
        
        // Test rendering performance at different quality levels
        let qualityLevels: [VolumeRenderer.QualityLevel] = [.low, .medium, .high, .ultra]
        
        for quality in qualityLevels {
            volumeRenderer.setQualityLevel(quality)
            
            // Measure rendering FPS
            measure(metrics: [XCTClockMetric()]) {
                for _ in 0..<60 { // Simulate 60 frames
                    volumeRenderer.render(to: drawable, viewportSize: viewportSize)
                }
            }
        }
    }
    
    func testVolumeRenderingModePerformance() throws {
        // Load test volume
        let expectation = XCTestExpectation(description: "Volume loading for mode test")
        
        Task {
            do {
                let testSeries = createLargeDICOMSeries(size: .medium)
                try await volumeRenderer.loadVolume(from: testSeries)
                expectation.fulfill()
            } catch {
                XCTFail("Volume loading failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        let drawable = try createMockDrawable(size: CGSize(width: 512, height: 512))
        let viewportSize = CGSize(width: 512, height: 512)
        
        let renderModes: [VolumeRenderer.RenderMode] = [.raycast, .mip, .isosurface, .dvr]
        
        for mode in renderModes {
            volumeRenderer.setRenderMode(mode)
            
            measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
                for _ in 0..<30 {
                    volumeRenderer.render(to: drawable, viewportSize: viewportSize)
                }
            }
        }
    }
    
    // MARK: - MPR Performance Tests
    func testMPRRenderingPerformance() throws {
        let volumeTexture = try createLargeVolumeTexture(size: (512, 512, 200))
        let voxelSpacing = simd_float3(0.5, 0.5, 1.0)
        
        mprRenderer.loadVolume(from: volumeTexture, voxelSpacing: voxelSpacing)
        
        let drawable = try createMockDrawable(size: CGSize(width: 512, height: 512))
        let viewportSize = CGSize(width: 512, height: 512)
        
        let planes: [MPRRenderer.MPRPlane] = [.axial, .sagittal, .coronal]
        
        for plane in planes {
            mprRenderer.setPlane(plane)
            
            measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
                // Test rapid slice navigation
                let maxSlices = mprRenderer.maxSlices
                let step = max(1, maxSlices / 20)
                
                for i in stride(from: 0, to: maxSlices, by: step) {
                    mprRenderer.setSliceIndex(i)
                    mprRenderer.render(to: drawable, viewportSize: viewportSize)
                }
            }
        }
    }
    
    func testMPRTransformationPerformance() throws {
        let volumeTexture = try createLargeVolumeTexture(size: (256, 256, 100))
        let voxelSpacing = simd_float3(1.0, 1.0, 2.0)
        
        mprRenderer.loadVolume(from: volumeTexture, voxelSpacing: voxelSpacing)
        
        let drawable = try createMockDrawable(size: CGSize(width: 512, height: 512))
        let viewportSize = CGSize(width: 512, height: 512)
        
        measure(metrics: [XCTClockMetric()]) {
            // Test rapid transformations
            for i in 0..<100 {
                let zoom = 0.5 + Float(i % 10) * 0.2
                let rotation = Float(i) * 0.1
                let pan = simd_float2(Float(i % 5) * 0.1, Float(i % 3) * 0.1)
                
                mprRenderer.setZoom(zoom)
                mprRenderer.setRotation(rotation)
                mprRenderer.setPan(offset: pan)
                mprRenderer.render(to: drawable, viewportSize: viewportSize)
            }
        }
    }
    
    // MARK: - Memory Performance Tests
    func testMemoryUsageVolumeLoading() throws {
        let initialMemory = getMemoryUsage()
        
        // Load progressively larger volumes
        let volumeSizes: [(String, SeriesSize)] = [
            ("Small", .small),
            ("Medium", .medium),
            ("Large", .large),
            ("XLarge", .extraLarge)
        ]
        
        for (sizeName, size) in volumeSizes {
            let memoryBefore = getMemoryUsage()
            
            let expectation = XCTestExpectation(description: "Loading \(sizeName) volume")
            
            Task {
                do {
                    let series = createLargeDICOMSeries(size: size)
                    try await volumeRenderer.loadVolume(from: series)
                    
                    let memoryAfter = getMemoryUsage()
                    let memoryIncrease = memoryAfter - memoryBefore
                    
                    print("📊 \(sizeName) volume memory usage: \(memoryIncrease / (1024*1024)) MB")
                    
                    // Memory increase should be reasonable
                    let maxExpectedMemory = getExpectedMemoryUsage(for: size)
                    XCTAssertLessThan(memoryIncrease, maxExpectedMemory,
                                    "Memory usage for \(sizeName) volume exceeds expected limit")
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to load \(sizeName) volume: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 60.0)
            
            // Clean up after each test
            volumeRenderer.releaseResources()
            
            // Force memory cleanup
            autoreleasepool { }
        }
        
        let finalMemory = getMemoryUsage()
        let totalIncrease = finalMemory - initialMemory
        
        // Total memory increase should be minimal after cleanup
        XCTAssertLessThan(totalIncrease, 50 * 1024 * 1024, // 50MB tolerance
                         "Memory should be properly released after volume cleanup")
    }
    
    func testMemoryLeaksDetection() throws {
        let iterations = 20
        var memoryMeasurements: [Int64] = []
        
        for i in 0..<iterations {
            autoreleasepool {
                let series = createLargeDICOMSeries(size: .medium)
                
                let expectation = XCTestExpectation(description: "Memory leak test \(i)")
                
                Task {
                    do {
                        try await volumeRenderer.loadVolume(from: series)
                        volumeRenderer.releaseResources()
                        
                        let memoryUsage = getMemoryUsage()
                        memoryMeasurements.append(memoryUsage)
                        
                        expectation.fulfill()
                    } catch {
                        XCTFail("Volume loading failed in iteration \(i): \(error)")
                        expectation.fulfill()
                    }
                }
                
                wait(for: [expectation], timeout: 30.0)
            }
        }
        
        // Analyze memory trend
        if memoryMeasurements.count >= iterations {
            let firstHalf = Array(memoryMeasurements[0..<iterations/2])
            let secondHalf = Array(memoryMeasurements[iterations/2..<iterations])
            
            let firstHalfAverage = firstHalf.reduce(0, +) / Int64(firstHalf.count)
            let secondHalfAverage = secondHalf.reduce(0, +) / Int64(secondHalf.count)
            
            let memoryGrowth = secondHalfAverage - firstHalfAverage
            let growthPercentage = Double(memoryGrowth) / Double(firstHalfAverage) * 100
            
            print("📈 Memory growth over \(iterations) iterations: \(growthPercentage)%")
            
            // Memory growth should be minimal (< 10%)
            XCTAssertLessThan(growthPercentage, 10.0,
                            "Memory growth suggests potential memory leaks")
        }
    }
    
    // MARK: - Cache Performance Tests
    func testCachePerformance() throws {
        let cacheManager = DICOMCacheManager.shared
        
        // Test cache write performance
        measure(metrics: [XCTCPUMetric(), XCTStorageMetric()]) {
            for i in 0..<1000 {
                let pixelData = createPixelData(size: 512 * 512 * 2) // 512KB per item
                let instanceUID = "cache.test.instance.\(i)"
                cacheManager.cachePixelData(pixelData, forInstance: instanceUID)
            }
        }
        
        // Test cache read performance
        measure(metrics: [XCTCPUMetric()]) {
            for i in 0..<1000 {
                let instanceUID = "cache.test.instance.\(i)"
                _ = cacheManager.getCachedPixelData(forInstance: instanceUID)
            }
        }
        
        // Test cache eviction performance
        measure(metrics: [XCTCPUMetric()]) {
            cacheManager.clearCache()
        }
    }
    
    // MARK: - Concurrent Access Performance Tests
    func testConcurrentVolumeLoading() throws {
        let concurrentCount = 5
        let expectation = XCTestExpectation(description: "Concurrent volume loading")
        expectation.expectedFulfillmentCount = concurrentCount
        
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            // Test concurrent volume loading
            for i in 0..<concurrentCount {
                Task {
                    do {
                        let renderer = VolumeRenderer()
                        let series = createLargeDICOMSeries(size: .small)
                        try await renderer.loadVolume(from: series)
                        renderer.releaseResources()
                        expectation.fulfill()
                    } catch {
                        XCTFail("Concurrent volume loading failed for task \(i): \(error)")
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 60.0)
        }
    }
    
    func testConcurrentMPRRendering() throws {
        let volumeTexture = try createLargeVolumeTexture(size: (256, 256, 100))
        let voxelSpacing = simd_float3(1.0, 1.0, 2.0)
        
        let concurrentCount = 3
        let renderers = (0..<concurrentCount).map { _ in MPRRenderer() }
        
        // Load volume into all renderers
        for renderer in renderers {
            renderer.loadVolume(from: volumeTexture, voxelSpacing: voxelSpacing)
        }
        
        measure(metrics: [XCTCPUMetric(), XCTClockMetric()]) {
            let group = DispatchGroup()
            
            for (index, renderer) in renderers.enumerated() {
                group.enter()
                
                DispatchQueue.global().async {
                    let drawable = try! self.createMockDrawable(size: CGSize(width: 256, height: 256))
                    let viewportSize = CGSize(width: 256, height: 256)
                    
                    let plane = MPRRenderer.MPRPlane.allCases[index % 3]
                    renderer.setPlane(plane)
                    
                    for i in 0..<50 {
                        renderer.setSliceIndex(i % renderer.maxSlices)
                        renderer.render(to: drawable, viewportSize: viewportSize)
                    }
                    
                    group.leave()
                }
            }
            
            group.wait()
        }
        
        // Cleanup
        for renderer in renderers {
            renderer.releaseResources()
        }
    }
    
    // MARK: - Scalability Tests
    func testLargeDatasetHandling() throws {
        // Test handling of very large datasets
        let largeStudy = createLargeStudy(
            seriesCount: 10,
            instancesPerSeries: 500 // 5000 total instances
        )
        
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric(), XCTStorageMetric()]) {
            let store = DICOMMetadataStore.shared
            store.addStudy(largeStudy)
            
            // Test retrieval operations
            _ = store.getStudy(withUID: largeStudy.studyInstanceUID)
            
            for series in largeStudy.series {
                let retrievedSeries = store.getSeries(withUID: series.seriesInstanceUID)
                XCTAssertNotNil(retrievedSeries)
            }
            
            store.clearAll()
        }
    }
}

// MARK: - Performance Test Helpers
extension PerformanceTests {
    
    enum SeriesSize {
        case small      // 128x128x50
        case medium     // 256x256x100
        case large      // 512x512x200
        case extraLarge // 1024x1024x300
        
        var dimensions: (width: Int, height: Int, depth: Int) {
            switch self {
            case .small: return (128, 128, 50)
            case .medium: return (256, 256, 100)
            case .large: return (512, 512, 200)
            case .extraLarge: return (1024, 1024, 300)
            }
        }
        
        var pixelSpacing: (x: Double, y: Double, z: Double) {
            switch self {
            case .small: return (2.0, 2.0, 5.0)
            case .medium: return (1.0, 1.0, 2.5)
            case .large: return (0.5, 0.5, 1.0)
            case .extraLarge: return (0.25, 0.25, 0.5)
            }
        }
    }
    
    private func createLargeDICOMMetadata(instanceNumber: Int) -> DICOMMetadata {
        let metadata = DICOMMetadata()
        
        metadata.sopInstanceUID = "performance.test.instance.\(instanceNumber).\(UUID().uuidString)"
        metadata.studyInstanceUID = "performance.test.study"
        metadata.seriesInstanceUID = "performance.test.series"
        metadata.instanceNumber = Int32(instanceNumber)
        
        metadata.rows = 512
        metadata.columns = 512
        metadata.bitsStored = 16
        metadata.bitsAllocated = 16
        metadata.pixelSpacing = [0.5, 0.5]
        metadata.sliceThickness = 1.0
        metadata.imagePositionPatient = [0.0, 0.0, Double(instanceNumber)]
        
        metadata.patientName = "Performance^Test^Patient"
        metadata.studyDescription = "Performance Test Study"
        metadata.modality = "CT"
        
        return metadata
    }
    
    private func createLargePixelData() -> Data {
        let size = 512 * 512 * 2 // 16-bit pixels
        return Data(repeating: 0x80, count: size)
    }
    
    private func createLargeDICOMSeries(size: SeriesSize) -> DICOMSeries {
        let series = DICOMSeries()
        series.seriesInstanceUID = "performance.test.series.\(UUID().uuidString)"
        series.modality = "CT"
        
        let dimensions = size.dimensions
        let spacing = size.pixelSpacing
        
        for i in 0..<dimensions.depth {
            let metadata = DICOMMetadata()
            metadata.sopInstanceUID = "performance.instance.\(i)"
            metadata.instanceNumber = Int32(i + 1)
            metadata.rows = dimensions.height
            metadata.columns = dimensions.width
            metadata.bitsStored = 16
            metadata.bitsAllocated = 16
            metadata.pixelSpacing = [spacing.x, spacing.y]
            metadata.sliceThickness = spacing.z
            metadata.imagePositionPatient = [0.0, 0.0, Double(i) * spacing.z]
            
            let pixelDataSize = dimensions.width * dimensions.height * 2
            let pixelData = createPixelData(size: pixelDataSize)
            
            let instance = DICOMInstance(metadata: metadata)
            instance.pixelData = pixelData
            
            series.addInstance(instance)
        }
        
        return series
    }
    
    private func createLargeVolumeTexture(size: (width: Int, height: Int, depth: Int)) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .r16Unorm
        descriptor.width = size.width
        descriptor.height = size.height
        descriptor.depth = size.depth
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTestError(.failureWhileWaiting, 
                            userInfo: [NSLocalizedDescriptionKey: "Failed to create large volume texture"])
        }
        
        // Fill with test pattern for realistic performance testing
        fillVolumeTextureWithPattern(texture)
        
        return texture
    }
    
    private func fillVolumeTextureWithPattern(_ texture: MTLTexture) {
        let width = texture.width
        let height = texture.height
        let depth = texture.depth
        
        // Create realistic test pattern (sphere + noise)
        for z in 0..<depth {
            var sliceData = [UInt16](repeating: 0, count: width * height)
            
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    
                    let centerX = Double(width) / 2.0
                    let centerY = Double(height) / 2.0
                    let centerZ = Double(depth) / 2.0
                    
                    let distance = sqrt(pow(Double(x) - centerX, 2) + 
                                      pow(Double(y) - centerY, 2) + 
                                      pow(Double(z) - centerZ, 2))
                    let radius = Double(min(width, height, depth)) / 3.0
                    
                    let intensity: UInt16
                    if distance < radius {
                        intensity = UInt16(32768 + Int(sin(distance / radius * Double.pi) * 16384))
                    } else {
                        intensity = UInt16(8192 + Int.random(in: 0..<4096))
                    }
                    
                    sliceData[index] = intensity
                }
            }
            
            sliceData.withUnsafeBytes { bytes in
                let region = MTLRegion(
                    origin: MTLOrigin(x: 0, y: 0, z: z),
                    size: MTLSize(width: width, height: height, depth: 1)
                )
                
                texture.replace(
                    region: region,
                    mipmapLevel: 0,
                    slice: 0,
                    withBytes: bytes.baseAddress!,
                    bytesPerRow: width * 2,
                    bytesPerImage: width * height * 2
                )
            }
        }
    }
    
    private func createMockDrawable(size: CGSize) throws -> MockMetalDrawable {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderWrite, .renderTarget]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTestError(.failureWhileWaiting, 
                            userInfo: [NSLocalizedDescriptionKey: "Failed to create drawable texture"])
        }
        
        return MockMetalDrawable(texture: texture)
    }
    
    private func createPixelData(size: Int) -> Data {
        return Data(repeating: UInt8.random(in: 0...255), count: size)
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
    
    private func getExpectedMemoryUsage(for size: SeriesSize) -> Int64 {
        let dimensions = size.dimensions
        let pixelDataSize = dimensions.width * dimensions.height * dimensions.depth * 2 // 16-bit
        
        // Account for texture storage overhead (typically 2-3x for GPU textures)
        return Int64(pixelDataSize * 3)
    }
    
    private func createLargeStudy(seriesCount: Int, instancesPerSeries: Int) -> DICOMStudy {
        let study = DICOMStudy()
        study.studyInstanceUID = "performance.large.study.\(UUID().uuidString)"
        study.patientName = "Large^Dataset^Test"
        study.studyDescription = "Large Dataset Performance Test"
        
        for seriesIndex in 0..<seriesCount {
            let series = DICOMSeries()
            series.seriesInstanceUID = "performance.large.series.\(seriesIndex)"
            series.modality = seriesIndex % 2 == 0 ? "CT" : "MR"
            
            for instanceIndex in 0..<instancesPerSeries {
                let metadata = createLargeDICOMMetadata(instanceNumber: instanceIndex)
                metadata.studyInstanceUID = study.studyInstanceUID
                metadata.seriesInstanceUID = series.seriesInstanceUID
                
                let instance = DICOMInstance(metadata: metadata)
                // Don't add pixel data for this test to focus on metadata performance
                
                series.addInstance(instance)
            }
            
            study.addSeries(series)
        }
        
        return study
    }
}

// MARK: - Mock Drawable for Performance Testing
class MockMetalDrawable: CAMetalDrawable {
    private let _texture: MTLTexture
    
    init(texture: MTLTexture) {
        _texture = texture
    }
    
    var texture: MTLTexture {
        return _texture
    }
    
    var layer: CAMetalLayer {
        return CAMetalLayer()
    }
    
    var drawableID: UInt {
        return 0
    }
    
    var presentedTime: CFTimeInterval {
        return 0
    }
    
    func present() {
        // Mock implementation - no actual presentation
    }
    
    func present(at presentationTime: CFTimeInterval) {
        // Mock implementation
    }
    
    func present(afterMinimumDuration duration: CFTimeInterval) {
        // Mock implementation
    }
    
    func addPresentedHandler(_ block: @escaping (CAMetalDrawable) -> Void) {
        // Mock implementation
    }
}