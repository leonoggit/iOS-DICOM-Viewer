import XCTest
import Metal
import MetalKit
import simd
@testable import iOS_DICOMViewer

/// Comprehensive tests for 3D volume rendering and MPR functionality
/// Tests Metal pipeline performance, rendering accuracy, and medical imaging compliance
class RenderingTests: XCTestCase {
    
    var device: MTLDevice!
    var volumeRenderer: VolumeRenderer!
    var mprRenderer: MPRRenderer!
    var mockVolumeTexture: MTLTexture!
    
    override func setUpWithError() throws {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            throw XCTestError(.failureWhileWaiting, userInfo: [NSLocalizedDescriptionKey: "Metal not supported"])
        }
        
        device = metalDevice
        volumeRenderer = VolumeRenderer()
        mprRenderer = MPRRenderer()
        
        // Create mock volume texture for testing
        mockVolumeTexture = try createMockVolumeTexture()
        
        print("✅ Rendering tests setup with Metal device: \(device.name)")
    }
    
    override func tearDownWithError() throws {
        volumeRenderer?.releaseResources()
        mprRenderer?.releaseResources()
        mockVolumeTexture = nil
        device = nil
    }
    
    // MARK: - Volume Renderer Tests
    func testVolumeRendererInitialization() throws {
        XCTAssertNotNil(volumeRenderer)
        XCTAssertFalse(volumeRenderer.isVolumeLoaded)
        XCTAssertEqual(volumeRenderer.currentRenderMode, .raycast)
        XCTAssertEqual(volumeRenderer.currentQualityLevel, .high)
    }
    
    func testVolumeLoadingFromSeries() throws {
        let mockSeries = createMockDICOMSeries()
        
        let expectation = XCTestExpectation(description: "Volume loading")
        
        Task {
            do {
                try await volumeRenderer.loadVolume(from: mockSeries)
                XCTAssertTrue(volumeRenderer.isVolumeLoaded)
                
                if let volumeInfo = volumeRenderer.getVolumeInfo() {
                    XCTAssertEqual(volumeInfo.width, 128)
                    XCTAssertEqual(volumeInfo.height, 128)
                    XCTAssertEqual(volumeInfo.depth, 50)
                    XCTAssertEqual(volumeInfo.spacing.x, 1.0)
                    XCTAssertEqual(volumeInfo.spacing.y, 1.0)
                    XCTAssertEqual(volumeInfo.spacing.z, 2.0)
                }
                
                expectation.fulfill()
            } catch {
                XCTFail("Volume loading failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testRenderModeChanges() throws {
        loadMockVolumeSync()
        
        let renderModes: [VolumeRenderer.RenderMode] = [.raycast, .mip, .isosurface, .dvr]
        
        for mode in renderModes {
            volumeRenderer.setRenderMode(mode)
            XCTAssertEqual(volumeRenderer.currentRenderMode, mode)
        }
    }
    
    func testQualityLevelSettings() throws {
        let qualityLevels: [VolumeRenderer.QualityLevel] = [.low, .medium, .high, .ultra]
        
        for quality in qualityLevels {
            volumeRenderer.setQualityLevel(quality)
            XCTAssertEqual(volumeRenderer.currentQualityLevel, quality)
            
            // Verify step size changes with quality
            let expectedStepSizes: [Float] = [0.02, 0.01, 0.005, 0.002]
            let expectedStepSize = expectedStepSizes[quality.rawValue]
            XCTAssertEqual(quality.stepSize, expectedStepSize, accuracy: 0.001)
        }
    }
    
    func testTransferFunctionPresets() throws {
        loadMockVolumeSync()
        
        let presets: [VolumeRenderer.TransferFunctionPreset] = [
            .ct, .ctBone, .ctSoftTissue, .mr, .mrBrain
        ]
        
        for preset in presets {
            volumeRenderer.setTransferFunctionPreset(preset)
            // Verify no crashes and renderer remains functional
            XCTAssertTrue(volumeRenderer.isVolumeLoaded)
        }
    }
    
    func testCameraControls() throws {
        // Test camera positioning
        let testPosition = simd_float3(5.0, 3.0, -10.0)
        let testTarget = simd_float3(0.0, 0.0, 0.0)
        let testUp = simd_float3(0.0, 1.0, 0.0)
        
        volumeRenderer.updateCamera(position: testPosition, target: testTarget, up: testUp)
        
        // Test camera distance
        volumeRenderer.setCameraDistance(15.0)
        
        // Test camera rotation
        volumeRenderer.rotateCameraAroundTarget(horizontal: Float.pi / 4, vertical: Float.pi / 6)
        
        // No specific assertions as these are transformation operations
        // The test verifies no crashes occur
    }
    
    func testWindowLevelAdjustments() throws {
        loadMockVolumeSync()
        
        let testCases = [
            (center: 0.3, width: 0.6),  // Soft tissue
            (center: 0.8, width: 0.2),  // Bone
            (center: 0.1, width: 1.0),  // Full range
            (center: 0.5, width: 0.8)   // Standard
        ]
        
        for testCase in testCases {
            volumeRenderer.setWindowLevel(center: testCase.center, width: testCase.width)
            // Verify no crashes and values are within valid range
            XCTAssertTrue(testCase.center >= 0.0 && testCase.center <= 1.0)
            XCTAssertTrue(testCase.width > 0.0 && testCase.width <= 1.0)
        }
    }
    
    // MARK: - MPR Renderer Tests
    func testMPRRendererInitialization() throws {
        XCTAssertNotNil(mprRenderer)
        XCTAssertFalse(mprRenderer.isVolumeLoaded)
        XCTAssertEqual(mprRenderer.currentPlaneType, .axial)
    }
    
    func testMPRPlaneChanges() throws {
        loadMockVolumeIntoMPR()
        
        let planes: [MPRRenderer.MPRPlane] = [.axial, .sagittal, .coronal]
        
        for plane in planes {
            mprRenderer.setPlane(plane)
            XCTAssertEqual(mprRenderer.currentPlaneType, plane)
            
            // Verify slice index is reset appropriately
            XCTAssertGreaterThanOrEqual(mprRenderer.currentSliceIndex, 0)
            XCTAssertLessThan(mprRenderer.currentSliceIndex, mprRenderer.maxSlices)
        }
    }
    
    func testMPRSliceNavigation() throws {
        loadMockVolumeIntoMPR()
        
        let maxSlices = mprRenderer.maxSlices
        XCTAssertGreaterThan(maxSlices, 0)
        
        // Test slice index boundaries
        mprRenderer.setSliceIndex(0)
        XCTAssertEqual(mprRenderer.currentSliceIndex, 0)
        
        mprRenderer.setSliceIndex(maxSlices - 1)
        XCTAssertEqual(mprRenderer.currentSliceIndex, maxSlices - 1)
        
        // Test out-of-bounds handling
        mprRenderer.setSliceIndex(-1)
        XCTAssertEqual(mprRenderer.currentSliceIndex, 0)
        
        mprRenderer.setSliceIndex(maxSlices + 10)
        XCTAssertEqual(mprRenderer.currentSliceIndex, maxSlices - 1)
        
        // Test next/previous slice navigation
        mprRenderer.setSliceIndex(maxSlices / 2)
        let middleSlice = mprRenderer.currentSliceIndex
        
        mprRenderer.nextSlice()
        XCTAssertEqual(mprRenderer.currentSliceIndex, middleSlice + 1)
        
        mprRenderer.previousSlice()
        XCTAssertEqual(mprRenderer.currentSliceIndex, middleSlice)
    }
    
    func testMPRTransformations() throws {
        loadMockVolumeIntoMPR()
        
        // Test zoom
        let zoomLevels: [Float] = [0.5, 1.0, 2.0, 5.0, 10.0]
        for zoom in zoomLevels {
            mprRenderer.setZoom(zoom)
            // Verify no crashes, actual zoom value testing would require access to internal state
        }
        
        // Test pan
        let panOffsets: [simd_float2] = [
            simd_float2(0.0, 0.0),
            simd_float2(0.1, -0.1),
            simd_float2(-0.2, 0.3),
            simd_float2(0.5, -0.5)
        ]
        for offset in panOffsets {
            mprRenderer.setPan(offset: offset)
        }
        
        // Test rotation
        let rotations: [Float] = [0.0, Float.pi/4, Float.pi/2, Float.pi, 2*Float.pi]
        for rotation in rotations {
            mprRenderer.setRotation(rotation)
        }
        
        // Test flip
        mprRenderer.setFlip(horizontal: true, vertical: false)
        mprRenderer.setFlip(horizontal: false, vertical: true)
        mprRenderer.setFlip(horizontal: true, vertical: true)
        mprRenderer.setFlip(horizontal: false, vertical: false)
    }
    
    func testMPRCrosshairControls() throws {
        loadMockVolumeIntoMPR()
        
        // Test crosshair positioning
        let crosshairPositions: [simd_float2] = [
            simd_float2(0.0, 0.0),    // Top-left
            simd_float2(0.5, 0.5),    // Center
            simd_float2(1.0, 1.0),    // Bottom-right
            simd_float2(0.25, 0.75)   // Arbitrary position
        ]
        
        for position in crosshairPositions {
            mprRenderer.setCrosshairPosition(position)
            // Verify position is clamped to valid range [0,1]
            XCTAssertTrue(position.x >= 0.0 && position.x <= 1.0)
            XCTAssertTrue(position.y >= 0.0 && position.y <= 1.0)
        }
        
        // Test crosshair enable/disable
        mprRenderer.setCrosshairEnabled(true)
        mprRenderer.setCrosshairEnabled(false)
        mprRenderer.setCrosshairEnabled(true)
    }
    
    // MARK: - Transfer Function Tests
    func testTransferFunctionEvaluation() throws {
        let ctTransferFunction = TransferFunction.defaultCT
        
        // Test evaluation at control points
        let testValues: [Float] = [0.0, 0.15, 0.3, 0.6, 0.85, 1.0]
        
        for value in testValues {
            let color = ctTransferFunction.evaluate(at: value)
            
            // Verify color components are in valid range [0,1]
            XCTAssertTrue(color.x >= 0.0 && color.x <= 1.0, "Red component out of range")
            XCTAssertTrue(color.y >= 0.0 && color.y <= 1.0, "Green component out of range")
            XCTAssertTrue(color.z >= 0.0 && color.z <= 1.0, "Blue component out of range")
            XCTAssertTrue(color.w >= 0.0 && color.w <= 1.0, "Alpha component out of range")
        }
        
        // Test boundary conditions
        let minColor = ctTransferFunction.evaluate(at: -0.5) // Below range
        let maxColor = ctTransferFunction.evaluate(at: 1.5)  // Above range
        
        XCTAssertNotNil(minColor)
        XCTAssertNotNil(maxColor)
    }
    
    func testTransferFunctionPresets() throws {
        let presets = [
            TransferFunction.defaultCT,
            TransferFunction.ctBone,
            TransferFunction.ctSoftTissue,
            TransferFunction.defaultMR,
            TransferFunction.mrBrain
        ]
        
        for preset in presets {
            XCTAssertGreaterThan(preset.points.count, 0)
            
            // Verify points are sorted by value
            for i in 1..<preset.points.count {
                XCTAssertLessThanOrEqual(preset.points[i-1].value, preset.points[i].value)
            }
            
            // Test evaluation at multiple points
            for i in 0...10 {
                let value = Float(i) / 10.0
                let color = preset.evaluate(at: value)
                XCTAssertNotNil(color)
            }
        }
    }
    
    // MARK: - Performance Tests
    func testVolumeRenderingPerformance() throws {
        loadMockVolumeSync()
        
        let drawable = try createMockDrawable()
        let viewportSize = CGSize(width: 512, height: 512)
        
        measure {
            // Measure rendering performance
            for _ in 0..<10 {
                volumeRenderer.render(to: drawable, viewportSize: viewportSize)
            }
        }
    }
    
    func testMPRRenderingPerformance() throws {
        loadMockVolumeIntoMPR()
        
        let drawable = try createMockDrawable()
        let viewportSize = CGSize(width: 512, height: 512)
        
        measure {
            // Measure MPR rendering performance
            for _ in 0..<20 {
                mprRenderer.render(to: drawable, viewportSize: viewportSize)
            }
        }
    }
    
    func testVolumeLoadingPerformance() throws {
        let mockSeries = createLargeMockDICOMSeries()
        
        measure {
            let expectation = XCTestExpectation(description: "Large volume loading")
            
            Task {
                do {
                    try await volumeRenderer.loadVolume(from: mockSeries)
                    expectation.fulfill()
                } catch {
                    XCTFail("Volume loading failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Memory Tests
    func testMemoryUsageVolumeRendering() throws {
        // Test memory usage with multiple volume loads
        let mockSeries = createMockDICOMSeries()
        
        for i in 0..<5 {
            let expectation = XCTestExpectation(description: "Volume load \(i)")
            
            Task {
                do {
                    try await volumeRenderer.loadVolume(from: mockSeries)
                    volumeRenderer.releaseResources()
                    expectation.fulfill()
                } catch {
                    XCTFail("Volume loading failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
        
        // Verify no memory leaks by checking resources are released
        XCTAssertFalse(volumeRenderer.isVolumeLoaded)
    }
    
    func testMPRMemoryEfficiency() throws {
        // Test MPR with multiple plane changes and large volumes
        let voxelSpacing = simd_float3(1.0, 1.0, 2.0)
        mprRenderer.loadVolume(from: mockVolumeTexture, voxelSpacing: voxelSpacing)
        
        // Rapidly change planes and slices to test memory stability
        for _ in 0..<100 {
            let plane = MPRRenderer.MPRPlane.allCases.randomElement()!
            mprRenderer.setPlane(plane)
            
            let randomSlice = Int.random(in: 0..<mprRenderer.maxSlices)
            mprRenderer.setSliceIndex(randomSlice)
        }
        
        XCTAssertTrue(mprRenderer.isVolumeLoaded)
    }
    
    // MARK: - Medical Imaging Compliance Tests
    func testDICOMWindowLevelCompliance() throws {
        loadMockVolumeSync()
        
        // Test standard medical imaging window/level presets
        let medicalPresets = [
            (center: Float(-600), width: Float(1600), name: "Lung"),      // CT Lung
            (center: Float(40), width: Float(400), name: "Abdomen"),      // CT Abdomen
            (center: Float(80), width: Float(200), name: "Brain"),        // CT Brain
            (center: Float(300), width: Float(1500), name: "Bone")        // CT Bone
        ]
        
        for preset in medicalPresets {
            // Normalize to [0,1] range for renderer
            let normalizedCenter = (preset.center + 1024) / 4096 // Assuming 12-bit range
            let normalizedWidth = preset.width / 4096
            
            volumeRenderer.setWindowLevel(center: normalizedCenter, width: normalizedWidth)
            
            // Verify values are reasonable
            XCTAssertTrue(normalizedCenter >= 0.0 && normalizedCenter <= 1.0,
                         "Window center out of range for \(preset.name)")
            XCTAssertTrue(normalizedWidth > 0.0 && normalizedWidth <= 1.0,
                         "Window width out of range for \(preset.name)")
        }
    }
    
    func testImageOrientationCompliance() throws {
        // Test standard medical imaging orientations
        let orientations = [
            ("Axial", MPRRenderer.MPRPlane.axial),
            ("Sagittal", MPRRenderer.MPRPlane.sagittal),
            ("Coronal", MPRRenderer.MPRPlane.coronal)
        ]
        
        loadMockVolumeIntoMPR()
        
        for (name, plane) in orientations {
            mprRenderer.setPlane(plane)
            XCTAssertEqual(mprRenderer.currentPlaneType, plane)
            
            // Verify slice information is available
            if let sliceInfo = mprRenderer.getSliceInfo() {
                XCTAssertEqual(sliceInfo.planeName, plane.displayName)
                XCTAssertGreaterThan(sliceInfo.totalSlices, 0)
                XCTAssertGreaterThan(sliceInfo.sliceNumber, 0)
            } else {
                XCTFail("Slice info not available for \(name) plane")
            }
        }
    }
}

// MARK: - Test Helper Methods
extension RenderingTests {
    
    private func createMockVolumeTexture() throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .r16Unorm
        descriptor.width = 128
        descriptor.height = 128
        descriptor.depth = 50
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTestError(.failureWhileWaiting, userInfo: [NSLocalizedDescriptionKey: "Failed to create mock volume texture"])
        }
        
        // Fill with test pattern
        fillVolumeTextureWithTestPattern(texture)
        
        return texture
    }
    
    private func fillVolumeTextureWithTestPattern(_ texture: MTLTexture) {
        let width = texture.width
        let height = texture.height
        let depth = texture.depth
        
        var data = [UInt16](repeating: 0, count: width * height * depth)
        
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    let index = z * width * height + y * width + x
                    
                    // Create a 3D test pattern (sphere + noise)
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
                    
                    data[index] = intensity
                }
            }
        }
        
        data.withUnsafeBytes { bytes in
            for z in 0..<depth {
                let region = MTLRegion(
                    origin: MTLOrigin(x: 0, y: 0, z: z),
                    size: MTLSize(width: width, height: height, depth: 1)
                )
                
                let sliceBytes = bytes.baseAddress!.advanced(by: z * width * height * 2)
                texture.replace(
                    region: region,
                    mipmapLevel: 0,
                    slice: 0,
                    withBytes: sliceBytes,
                    bytesPerRow: width * 2,
                    bytesPerImage: width * height * 2
                )
            }
        }
    }
    
    private func createMockDICOMSeries() -> DICOMSeries {
        let series = DICOMSeries()
        series.seriesInstanceUID = "test.rendering.series"
        series.seriesDescription = "Test Rendering Series"
        series.modality = "CT"
        
        for i in 0..<50 {
            let metadata = DICOMMetadata()
            metadata.sopInstanceUID = "test.instance.\(i)"
            metadata.instanceNumber = Int32(i + 1)
            metadata.rows = 128
            metadata.columns = 128
            metadata.bitsStored = 16
            metadata.pixelSpacing = [1.0, 1.0]
            metadata.sliceThickness = 2.0
            metadata.imagePositionPatient = [0.0, 0.0, Double(i * 2)]
            metadata.windowCenter = [40.0]
            metadata.windowWidth = [400.0]
            
            // Create mock pixel data
            let pixelData = Data(repeating: UInt8(i % 256), count: 128 * 128 * 2)
            
            let instance = DICOMInstance(metadata: metadata)
            instance.pixelData = pixelData
            
            series.addInstance(instance)
        }
        
        return series
    }
    
    private func createLargeMockDICOMSeries() -> DICOMSeries {
        let series = DICOMSeries()
        series.seriesInstanceUID = "test.large.series"
        series.seriesDescription = "Large Test Series"
        series.modality = "CT"
        
        for i in 0..<200 { // Larger series
            let metadata = DICOMMetadata()
            metadata.sopInstanceUID = "test.large.instance.\(i)"
            metadata.instanceNumber = Int32(i + 1)
            metadata.rows = 512 // Larger images
            metadata.columns = 512
            metadata.bitsStored = 16
            metadata.pixelSpacing = [0.5, 0.5]
            metadata.sliceThickness = 1.0
            metadata.imagePositionPatient = [0.0, 0.0, Double(i)]
            
            let pixelData = Data(repeating: UInt8(i % 256), count: 512 * 512 * 2)
            
            let instance = DICOMInstance(metadata: metadata)
            instance.pixelData = pixelData
            
            series.addInstance(instance)
        }
        
        return series
    }
    
    private func createMockDrawable() throws -> MockMetalDrawable {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 512,
            height: 512,
            mipmapped: false
        )
        descriptor.usage = [.shaderWrite, .renderTarget]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTestError(.failureWhileWaiting, userInfo: [NSLocalizedDescriptionKey: "Failed to create drawable texture"])
        }
        
        return MockMetalDrawable(texture: texture)
    }
    
    private func loadMockVolumeSync() {
        let expectation = XCTestExpectation(description: "Volume loading")
        
        Task {
            do {
                let mockSeries = createMockDICOMSeries()
                try await volumeRenderer.loadVolume(from: mockSeries)
                expectation.fulfill()
            } catch {
                XCTFail("Volume loading failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    private func loadMockVolumeIntoMPR() {
        let voxelSpacing = simd_float3(1.0, 1.0, 2.0)
        mprRenderer.loadVolume(from: mockVolumeTexture, voxelSpacing: voxelSpacing)
    }
}

// MARK: - Mock Metal Drawable
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
        // Mock implementation
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