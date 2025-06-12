import Metal
import MetalKit
import simd
import Foundation

/// High-performance 3D volume renderer using Metal compute shaders
/// Supports multiple rendering techniques including ray casting, isosurface rendering, and MIP
final class VolumeRenderer: NSObject {
    
    // MARK: - Core Metal Objects
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private let complianceManager = ClinicalComplianceManager.shared
    
    // MARK: - Pipeline States
    private var volumeRaycastPipeline: MTLComputePipelineState!
    private var mipRenderPipeline: MTLComputePipelineState!
    private var isosurfacePipeline: MTLComputePipelineState!
    private var gradientPipeline: MTLComputePipelineState!
    
    // MARK: - Volume Data
    private var volumeTexture: MTLTexture?
    private var gradientTexture: MTLTexture?
    private var transferFunctionTexture: MTLTexture?
    private var volumeBuffer: MTLBuffer?
    
    // MARK: - Rendering State
    private var renderParams = VolumeRenderParams()
    private var renderSettings = VolumeRenderSettings()
    private var viewMatrix = matrix_identity_float4x4
    private var projectionMatrix = matrix_identity_float4x4
    private var modelMatrix = matrix_identity_float4x4
    
    // MARK: - Performance Monitoring
    private var frameCounter = 0
    private var lastPerformanceReport = Date()
    
    // MARK: - Structs for GPU
    struct VolumeRenderParams {
        var modelMatrix = matrix_identity_float4x4
        var viewMatrix = matrix_identity_float4x4
        var projectionMatrix = matrix_identity_float4x4
        var modelViewProjectionMatrix = matrix_identity_float4x4
        var inverseModelViewProjectionMatrix = matrix_identity_float4x4
        var cameraPosition = simd_float3(0, 0, -3)
        var volumeSize = simd_float3(1, 1, 1)
        var voxelSpacing = simd_float3(1, 1, 1)
        var stepSize: Float = 0.005
        var densityThreshold: Float = 0.1
        var opacityScale: Float = 1.0
        var brightnessScale: Float = 1.0
        var windowCenter: Float = 0.5
        var windowWidth: Float = 1.0
        var frameNumber: UInt32 = 0
    }
    
    struct VolumeRenderSettings {
        var renderMode: RenderMode = .raycast
        var qualityLevel: QualityLevel = .high
        var enableGradientShading = true
        var enableAmbientOcclusion = false
        var enableJittering = true
        var maxSamples: Int = 1000
        var earlyRayTermination = true
        var compositingMode: CompositingMode = .frontToBack
    }
    
    enum RenderMode: Int {
        case raycast = 0
        case mip = 1        // Maximum Intensity Projection
        case isosurface = 2
        case dvr = 3        // Direct Volume Rendering
    }
    
    enum QualityLevel: Int {
        case low = 0
        case medium = 1
        case high = 2
        case ultra = 3
        
        var stepSize: Float {
            switch self {
            case .low: return 0.02
            case .medium: return 0.01
            case .high: return 0.005
            case .ultra: return 0.002
            }
        }
        
        var maxSamples: Int {
            switch self {
            case .low: return 200
            case .medium: return 500
            case .high: return 1000
            case .ultra: return 2000
            }
        }
    }
    
    enum CompositingMode: Int {
        case frontToBack = 0
        case backToFront = 1
        case additive = 2
        case maximum = 3
    }
    
    // MARK: - Initialization
    override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load default Metal library")
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.library = library
        
        super.init()
        
        setupPipelines()
        initializeDefaultSettings()
        
        print("✅ VolumeRenderer initialized with device: \(device.name)")
    }
    
    private func initializeDefaultSettings() {
        renderSettings.qualityLevel = device.supportsFamily(.apple7) ? .ultra : .high
        renderParams.stepSize = renderSettings.qualityLevel.stepSize
        
        // Set up default projection matrix for perspective rendering
        let aspect: Float = 1.0
        let fov: Float = 45.0 * Float.pi / 180.0
        let near: Float = 0.1
        let far: Float = 100.0
        
        projectionMatrix = matrix_perspective(fov: fov, aspect: aspect, near: near, far: far)
        
        // Initialize view matrix for default camera position
        updateCamera(position: simd_float3(0, 0, -3), 
                    target: simd_float3(0, 0, 0), 
                    up: simd_float3(0, 1, 0))
    }
    
    private func setupPipelines() {
        do {
            // Volume raycast pipeline
            guard let volumeFunction = library.makeFunction(name: "volumeRaycast") else {
                fatalError("Failed to load volumeRaycast function")
            }
            volumeRaycastPipeline = try device.makeComputePipelineState(function: volumeFunction)
            
            // MIP rendering pipeline
            guard let mipFunction = library.makeFunction(name: "maximumIntensityProjection") else {
                fatalError("Failed to load maximumIntensityProjection function")
            }
            mipRenderPipeline = try device.makeComputePipelineState(function: mipFunction)
            
            // Isosurface rendering pipeline
            guard let isoFunction = library.makeFunction(name: "isosurfaceRender") else {
                fatalError("Failed to load isosurfaceRender function")
            }
            isosurfacePipeline = try device.makeComputePipelineState(function: isoFunction)
            
            // Gradient computation pipeline
            guard let gradientFunction = library.makeFunction(name: "computeGradients") else {
                fatalError("Failed to load computeGradients function")
            }
            gradientPipeline = try device.makeComputePipelineState(function: gradientFunction)
            
            print("✅ Metal pipelines created successfully")
            
        } catch {
            fatalError("Failed to create compute pipeline states: \(error)")
        }
    }
    
    // MARK: - Volume Loading
    func loadVolume(from series: DICOMSeries) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Sort instances by slice position for proper 3D reconstruction
        let sortedInstances = series.sortedBySlicePosition
        
        guard !sortedInstances.isEmpty else {
            throw DICOMError.invalidFile
        }
        
        // Extract volume metadata
        let firstInstance = sortedInstances[0]
        let metadata = firstInstance.metadata
        let width = metadata.columns
        let height = metadata.rows
        let depth = sortedInstances.count
        
        print("📦 Loading volume: \(width)x\(height)x\(depth)")
        
        // Determine optimal pixel format based on bit depth
        let pixelFormat: MTLPixelFormat
        let bytesPerPixel: Int
        
        switch metadata.bitsStored {
        case 8:
            pixelFormat = metadata.isSigned ? .r8Snorm : .r8Unorm
            bytesPerPixel = 1
        case 16:
            pixelFormat = metadata.isSigned ? .r16Snorm : .r16Unorm
            bytesPerPixel = 2
        default:
            // Convert to 16-bit for consistency
            pixelFormat = .r16Unorm
            bytesPerPixel = 2
        }
        
        // Create 3D volume texture
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.pixelFormat = pixelFormat
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.depth = depth
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw DICOMError.memoryAllocationFailed
        }
        
        // Extract spacing information for proper aspect ratio
        let pixelSpacing = metadata.pixelSpacing ?? [1.0, 1.0]
        let sliceThickness = metadata.sliceThickness ?? 1.0
        
        renderParams.voxelSpacing = simd_float3(
            Float(pixelSpacing[0]),
            Float(pixelSpacing[1]),
            Float(sliceThickness)
        )
        
        // Load slice data into 3D texture
        await loadSlicesIntoTexture(texture: texture, 
                                  instances: sortedInstances, 
                                  width: width, 
                                  height: height, 
                                  bytesPerPixel: bytesPerPixel)
        
        self.volumeTexture = texture
        
        // Update render parameters
        renderParams.volumeSize = simd_float3(Float(width), Float(height), Float(depth))
        
        // Apply windowing from DICOM metadata
        if let windowCenter = metadata.windowCenter?.first,
           let windowWidth = metadata.windowWidth?.first {
            renderParams.windowCenter = Float(windowCenter)
            renderParams.windowWidth = Float(windowWidth)
        }
        
        // Generate gradient texture for enhanced shading
        if renderSettings.enableGradientShading {
            try await generateGradientTexture()
        }
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        print("✅ Volume loaded in \(String(format: "%.2f", loadTime))s")
    }
    
    private func loadSlicesIntoTexture(texture: MTLTexture, instances: [DICOMInstance], 
                                     width: Int, height: Int, bytesPerPixel: Int) async {
        return await withTaskGroup(of: Void.self) { group in
            let batchSize = 10 // Process slices in batches for memory efficiency
            
            for batchStart in stride(from: 0, to: instances.count, by: batchSize) {
                group.addTask {
                    let batchEnd = min(batchStart + batchSize, instances.count)
                    
                    for index in batchStart..<batchEnd {
                        let instance = instances[index]
                        guard let pixelData = instance.pixelData else { continue }
                        
                        let region = MTLRegion(
                            origin: MTLOrigin(x: 0, y: 0, z: index),
                            size: MTLSize(width: width, height: height, depth: 1)
                        )
                        
                        pixelData.withUnsafeBytes { bytes in
                            texture.replace(
                                region: region,
                                mipmapLevel: 0,
                                slice: 0,
                                withBytes: bytes.baseAddress!,
                                bytesPerRow: width * bytesPerPixel,
                                bytesPerImage: width * height * bytesPerPixel
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func generateGradientTexture() async throws {
        guard let volumeTexture = volumeTexture else { return }
        
        // Create gradient texture (same dimensions as volume, but with 4 components for gradient vector + magnitude)
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rgba16Float
        descriptor.width = volumeTexture.width
        descriptor.height = volumeTexture.height
        descriptor.depth = volumeTexture.depth
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let gradientTex = device.makeTexture(descriptor: descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw DICOMError.failedToParse
        }
        
        computeEncoder.setComputePipelineState(gradientPipeline)
        computeEncoder.setTexture(volumeTexture, index: 0)
        computeEncoder.setTexture(gradientTex, index: 1)
        
        let threadgroupSize = MTLSize(width: 8, height: 8, depth: 8)
        let threadgroupCount = MTLSize(
            width: (volumeTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (volumeTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: (volumeTexture.depth + threadgroupSize.depth - 1) / threadgroupSize.depth
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        self.gradientTexture = gradientTex
        print("✅ Gradient texture generated")
    }
    
    // MARK: - Rendering
    func render(to drawable: CAMetalDrawable, viewportSize: CGSize) {
        complianceManager.measureRenderingPerformance(operation: "3D Volume Rendering") {
            performRender(to: drawable, viewportSize: viewportSize)
        }
    }
    
    private func performRender(to drawable: CAMetalDrawable, viewportSize: CGSize) {
        guard let volumeTexture = volumeTexture else {
            renderErrorFrame(to: drawable)
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("❌ Failed to create command buffer")
            return
        }
        
        // Update matrices and parameters
        updateRenderParameters(viewportSize: viewportSize)
        
        // Select pipeline based on render mode
        let pipeline: MTLComputePipelineState
        switch renderSettings.renderMode {
        case .raycast, .dvr:
            pipeline = volumeRaycastPipeline
        case .mip:
            pipeline = mipRenderPipeline
        case .isosurface:
            pipeline = isosurfacePipeline
        }
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("❌ Failed to create compute encoder")
            return
        }
        
        // Set up compute pipeline
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setTexture(volumeTexture, index: 0)
        computeEncoder.setTexture(drawable.texture, index: 1)
        computeEncoder.setTexture(transferFunctionTexture, index: 2)
        computeEncoder.setTexture(gradientTexture, index: 3)
        
        // Set parameters
        var params = renderParams
        params.frameNumber = UInt32(frameCounter)
        computeEncoder.setBytes(&params, length: MemoryLayout<VolumeRenderParams>.size, index: 0)
        
        var settings = renderSettings
        computeEncoder.setBytes(&settings, length: MemoryLayout<VolumeRenderSettings>.size, index: 1)
        
        // Dispatch compute threads
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (drawable.texture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (drawable.texture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        // Present the frame
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Performance monitoring
        frameCounter += 1
        if frameCounter % 60 == 0 {
            reportPerformance(renderTime: CFAbsoluteTimeGetCurrent() - startTime)
        }
    }
    
    private func renderErrorFrame(to drawable: CAMetalDrawable) {
        // Render a simple error state (gray background)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func updateRenderParameters(viewportSize: CGSize) {
        // Update projection matrix for current viewport
        let aspect = Float(viewportSize.width / viewportSize.height)
        let fov: Float = 45.0 * Float.pi / 180.0
        projectionMatrix = matrix_perspective(fov: fov, aspect: aspect, near: 0.1, far: 100.0)
        
        // Update matrices in render parameters
        renderParams.modelMatrix = modelMatrix
        renderParams.viewMatrix = viewMatrix
        renderParams.projectionMatrix = projectionMatrix
        renderParams.modelViewProjectionMatrix = projectionMatrix * viewMatrix * modelMatrix
        renderParams.inverseModelViewProjectionMatrix = renderParams.modelViewProjectionMatrix.inverse
        
        // Update quality-dependent parameters
        renderParams.stepSize = renderSettings.qualityLevel.stepSize
    }
    
    private func reportPerformance(renderTime: Double) {
        let now = Date()
        let timeSinceLastReport = now.timeIntervalSince(lastPerformanceReport)
        
        if timeSinceLastReport > 5.0 { // Report every 5 seconds
            let fps = 60.0 / timeSinceLastReport
            print("🎥 3D Rendering: \(String(format: "%.1f", fps)) FPS, Frame time: \(String(format: "%.2f", renderTime * 1000))ms")
            lastPerformanceReport = now
        }
    }
    
    // MARK: - Camera and View Controls
    func updateCamera(position: simd_float3, target: simd_float3, up: simd_float3) {
        renderParams.cameraPosition = position
        viewMatrix = matrix_look_at(position, target, up)
        print("📷 Camera updated: pos=\(position), target=\(target)")
    }
    
    func setCameraDistance(_ distance: Float) {
        let direction = normalize(renderParams.cameraPosition)
        updateCamera(position: direction * distance, 
                    target: simd_float3(0, 0, 0), 
                    up: simd_float3(0, 1, 0))
    }
    
    func rotateCameraAroundTarget(horizontal: Float, vertical: Float) {
        let target = simd_float3(0, 0, 0)
        let distance = length(renderParams.cameraPosition - target)
        
        // Convert to spherical coordinates
        let phi = atan2(renderParams.cameraPosition.z, renderParams.cameraPosition.x) + horizontal
        let theta = acos(renderParams.cameraPosition.y / distance) + vertical
        
        // Clamp theta to avoid gimbal lock
        let clampedTheta = max(0.1, min(Float.pi - 0.1, theta))
        
        // Convert back to Cartesian
        let newPosition = simd_float3(
            distance * sin(clampedTheta) * cos(phi),
            distance * cos(clampedTheta),
            distance * sin(clampedTheta) * sin(phi)
        )
        
        updateCamera(position: newPosition, target: target, up: simd_float3(0, 1, 0))
    }
    
    // MARK: - Transfer Function Management
    func updateTransferFunction(_ transferFunction: TransferFunction) {
        transferFunctionTexture = createTransferFunctionTexture(transferFunction)
        print("🎨 Transfer function updated with \(transferFunction.points.count) control points")
    }
    
    func setTransferFunctionPreset(_ preset: TransferFunctionPreset) {
        let transferFunction: TransferFunction
        switch preset {
        case .ct:
            transferFunction = TransferFunction.defaultCT
        case .ctBone:
            transferFunction = TransferFunction.ctBone
        case .ctSoftTissue:
            transferFunction = TransferFunction.ctSoftTissue
        case .mr:
            transferFunction = TransferFunction.defaultMR
        case .mrBrain:
            transferFunction = TransferFunction.mrBrain
        case .custom(let tf):
            transferFunction = tf
        }
        updateTransferFunction(transferFunction)
    }
    
    enum TransferFunctionPreset {
        case ct
        case ctBone
        case ctSoftTissue
        case mr
        case mrBrain
        case custom(TransferFunction)
    }
    
    // MARK: - Rendering Settings
    func setRenderMode(_ mode: RenderMode) {
        renderSettings.renderMode = mode
        print("🔄 Render mode changed to: \(mode)")
    }
    
    func setQualityLevel(_ quality: QualityLevel) {
        renderSettings.qualityLevel = quality
        renderParams.stepSize = quality.stepSize
        print("⚙️ Quality level changed to: \(quality)")
    }
    
    func setWindowLevel(center: Float, width: Float) {
        renderParams.windowCenter = center
        renderParams.windowWidth = width
    }
    
    func setOpacity(_ opacity: Float) {
        renderParams.opacityScale = max(0.0, min(1.0, opacity))
    }
    
    func setBrightness(_ brightness: Float) {
        renderParams.brightnessScale = max(0.1, min(3.0, brightness))
    }
    
    // MARK: - Transfer Function Texture Creation
    private func createTransferFunctionTexture(_ transferFunction: TransferFunction) -> MTLTexture? {
        let width = 1024 // Higher resolution for smoother gradients
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type1D
        descriptor.pixelFormat = .rgba16Float
        descriptor.width = width
        descriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            print("❌ Failed to create transfer function texture")
            return nil
        }
        
        // Generate high-precision transfer function data
        var data = [Float](repeating: 0, count: width * 4)
        for i in 0..<width {
            let value = Float(i) / Float(width - 1)
            let color = transferFunction.evaluate(at: value)
            data[i * 4 + 0] = color.x
            data[i * 4 + 1] = color.y
            data[i * 4 + 2] = color.z
            data[i * 4 + 3] = color.w
        }
        
        data.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                size: MTLSize(width: width, height: 1, depth: 1)),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: width * 4 * MemoryLayout<Float>.size
            )
        }
        
        return texture
    }
    
    // MARK: - Public Interface
    var isVolumeLoaded: Bool {
        return volumeTexture != nil
    }
    
    var currentRenderMode: RenderMode {
        return renderSettings.renderMode
    }
    
    var currentQualityLevel: QualityLevel {
        return renderSettings.qualityLevel
    }
    
    func getVolumeInfo() -> (width: Int, height: Int, depth: Int, spacing: simd_float3)? {
        guard let volume = volumeTexture else { return nil }
        return (volume.width, volume.height, volume.depth, renderParams.voxelSpacing)
    }
    
    // MARK: - Memory Management
    func releaseResources() {
        volumeTexture = nil
        gradientTexture = nil
        transferFunctionTexture = nil
        volumeBuffer = nil
        print("🗑️ Volume renderer resources released")
    }
}

// MARK: - Transfer Function
struct TransferFunction {
    struct ColorPoint {
        let value: Float
        let color: SIMD4<Float>
        
        init(value: Float, r: Float, g: Float, b: Float, a: Float) {
            self.value = value
            self.color = SIMD4<Float>(r, g, b, a)
        }
    }
    
    var points: [ColorPoint]
    
    init(points: [ColorPoint]) {
        self.points = points.sorted { $0.value < $1.value }
    }
    
    func evaluate(at value: Float) -> SIMD4<Float> {
        guard !points.isEmpty else {
            return SIMD4<Float>(0, 0, 0, 0)
        }
        
        let clampedValue = max(0.0, min(1.0, value))
        
        if clampedValue <= points.first!.value {
            return points.first!.color
        }
        
        if clampedValue >= points.last!.value {
            return points.last!.color
        }
        
        for i in 1..<points.count {
            if clampedValue <= points[i].value {
                let t = (clampedValue - points[i-1].value) / (points[i].value - points[i-1].value)
                return mix(points[i-1].color, points[i].color, t: t)
            }
        }
        
        return points.last!.color
    }
    
    // MARK: - Predefined Transfer Functions
    
    static let defaultCT = TransferFunction(points: [
        ColorPoint(value: 0.0, r: 0.0, g: 0.0, b: 0.0, a: 0.0),
        ColorPoint(value: 0.15, r: 0.4, g: 0.2, b: 0.2, a: 0.05),
        ColorPoint(value: 0.3, r: 0.8, g: 0.4, b: 0.3, a: 0.2),
        ColorPoint(value: 0.6, r: 1.0, g: 0.8, b: 0.6, a: 0.6),
        ColorPoint(value: 0.85, r: 1.0, g: 1.0, b: 1.0, a: 0.9),
        ColorPoint(value: 1.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0)
    ])
    
    static let ctBone = TransferFunction(points: [
        ColorPoint(value: 0.0, r: 0.0, g: 0.0, b: 0.0, a: 0.0),
        ColorPoint(value: 0.1, r: 0.0, g: 0.0, b: 0.0, a: 0.0),
        ColorPoint(value: 0.4, r: 0.6, g: 0.4, b: 0.2, a: 0.1),
        ColorPoint(value: 0.7, r: 1.0, g: 0.9, b: 0.8, a: 0.7),
        ColorPoint(value: 1.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0)
    ])
    
    static let ctSoftTissue = TransferFunction(points: [
        ColorPoint(value: 0.0, r: 0.0, g: 0.0, b: 0.0, a: 0.0),
        ColorPoint(value: 0.2, r: 0.8, g: 0.3, b: 0.3, a: 0.2),
        ColorPoint(value: 0.4, r: 0.9, g: 0.6, b: 0.6, a: 0.5),
        ColorPoint(value: 0.6, r: 0.9, g: 0.8, b: 0.8, a: 0.8),
        ColorPoint(value: 1.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0)
    ])
    
    static let defaultMR = TransferFunction(points: [
        ColorPoint(value: 0.0, r: 0.0, g: 0.0, b: 0.0, a: 0.0),
        ColorPoint(value: 0.2, r: 0.2, g: 0.1, b: 0.3, a: 0.1),
        ColorPoint(value: 0.4, r: 0.6, g: 0.3, b: 0.6, a: 0.4),
        ColorPoint(value: 0.7, r: 0.9, g: 0.7, b: 0.9, a: 0.8),
        ColorPoint(value: 1.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0)
    ])
    
    static let mrBrain = TransferFunction(points: [
        ColorPoint(value: 0.0, r: 0.0, g: 0.0, b: 0.0, a: 0.0),
        ColorPoint(value: 0.15, r: 0.3, g: 0.1, b: 0.1, a: 0.1),
        ColorPoint(value: 0.3, r: 0.7, g: 0.4, b: 0.4, a: 0.3),
        ColorPoint(value: 0.5, r: 0.9, g: 0.8, b: 0.6, a: 0.6),
        ColorPoint(value: 0.8, r: 1.0, g: 1.0, b: 0.9, a: 0.9),
        ColorPoint(value: 1.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0)
    ])
}

// MARK: - Matrix Helper Functions
func matrix_look_at(_ eye: simd_float3, _ target: simd_float3, _ up: simd_float3) -> simd_float4x4 {
    let forward = normalize(target - eye)
    let right = normalize(cross(forward, up))
    let newUp = cross(right, forward)
    
    return simd_float4x4(
        simd_float4(right.x, newUp.x, -forward.x, 0),
        simd_float4(right.y, newUp.y, -forward.y, 0),
        simd_float4(right.z, newUp.z, -forward.z, 0),
        simd_float4(-dot(right, eye), -dot(newUp, eye), dot(forward, eye), 1)
    )
}

func matrix_perspective(fov: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let f = 1.0 / tan(fov * 0.5)
    let rangeInv = 1.0 / (near - far)
    
    return simd_float4x4(
        simd_float4(f / aspect, 0, 0, 0),
        simd_float4(0, f, 0, 0),
        simd_float4(0, 0, (far + near) * rangeInv, -1),
        simd_float4(0, 0, 2.0 * far * near * rangeInv, 0)
    )
}

func mix(_ a: SIMD4<Float>, _ b: SIMD4<Float>, t: Float) -> SIMD4<Float> {
    return a + (b - a) * t
}

// MARK: - Matrix Extensions
extension simd_float4x4 {
    var inverse: simd_float4x4 {
        return simd_inverse(self)
    }
}

// MARK: - Volume Renderer Extensions
extension VolumeRenderer {
    
    /// Create a volume renderer optimized for the current device
    static func createOptimizedRenderer() -> VolumeRenderer {
        let renderer = VolumeRenderer()
        
        // Optimize settings based on device capabilities
        if let device = MTLCreateSystemDefaultDevice() {
            if device.supportsFamily(.apple7) {
                renderer.setQualityLevel(.ultra)
            } else if device.supportsFamily(.apple6) {
                renderer.setQualityLevel(.high)
            } else {
                renderer.setQualityLevel(.medium)
            }
        }
        
        return renderer
    }
    
    /// Load volume with automatic optimization
    func loadVolumeOptimized(from series: DICOMSeries, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await loadVolume(from: series)
                
                // Set appropriate transfer function based on modality
                if let modality = series.instances.first?.metadata.modality {
                    switch modality.uppercased() {
                    case "CT":
                        setTransferFunctionPreset(.ct)
                    case "MR", "MRI":
                        setTransferFunctionPreset(.mr)
                    default:
                        setTransferFunctionPreset(.ct)
                    }
                }
                
                // Auto-adjust camera for optimal viewing
                setCameraDistance(3.0)
                
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}