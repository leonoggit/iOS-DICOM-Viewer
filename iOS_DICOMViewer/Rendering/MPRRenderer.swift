import Metal
import MetalKit
import simd
import Foundation

/// Multi-Planar Reconstruction (MPR) renderer for 2D slice visualization
/// Provides axial, sagittal, and coronal views from 3D volume data
final class MPRRenderer: NSObject {
    
    // MARK: - Core Metal Objects
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private let complianceManager = ClinicalComplianceManager.shared
    
    // MARK: - Pipeline States
    private var mprSlicePipeline: MTLComputePipelineState!
    private var mprAnnotationPipeline: MTLRenderPipelineState!
    
    // MARK: - Volume Data
    private var volumeTexture: MTLTexture?
    private var transferFunctionTexture: MTLTexture?
    
    // MARK: - MPR Configuration
    private var mprParams = MPRRenderParams()
    private var currentPlane: MPRPlane = .axial
    private var sliceIndex: Int = 0
    private var maxSliceIndex: Int = 0
    
    // MARK: - Crosshair and Annotations
    private var crosshairEnabled = true
    private var annotationsEnabled = true
    private var rulerEnabled = false
    
    // MARK: - Window/Level
    private var windowCenter: Float = 0.5
    private var windowWidth: Float = 1.0
    
    // MARK: - Structs for GPU
    struct MPRRenderParams {
        var volumeSize = simd_float3(1, 1, 1)
        var voxelSpacing = simd_float3(1, 1, 1)
        var sliceIndex: UInt32 = 0
        var plane: UInt32 = 0  // 0=axial, 1=sagittal, 2=coronal
        var windowCenter: Float = 0.5
        var windowWidth: Float = 1.0
        var zoom: Float = 1.0
        var panOffset = simd_float2(0, 0)
        var rotation: Float = 0.0
        var flipHorizontal: Bool = false
        var flipVertical: Bool = false
        var crosshairPosition = simd_float2(0.5, 0.5)
        var crosshairEnabled: Bool = true
    }
    
    enum MPRPlane: Int, CaseIterable {
        case axial = 0
        case sagittal = 1
        case coronal = 2
        
        var displayName: String {
            switch self {
            case .axial: return "Axial"
            case .sagittal: return "Sagittal"
            case .coronal: return "Coronal"
            }
        }
        
        var anatomicalView: String {
            switch self {
            case .axial: return "Top-Down (Z-axis)"
            case .sagittal: return "Left-Right (X-axis)"
            case .coronal: return "Front-Back (Y-axis)"
            }
        }
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
        
        print("✅ MPRRenderer initialized")
    }
    
    private func initializeDefaultSettings() {
        mprParams.zoom = 1.0
        mprParams.crosshairPosition = simd_float2(0.5, 0.5)
        mprParams.crosshairEnabled = true
    }
    
    private func setupPipelines() {
        do {
            // MPR slice rendering pipeline
            guard let sliceFunction = library.makeFunction(name: "mprSliceRender") else {
                fatalError("Failed to load mprSliceRender function")
            }
            mprSlicePipeline = try device.makeComputePipelineState(function: sliceFunction)
            
            // Annotation rendering pipeline (for crosshairs, measurements)
            let vertexFunction = library.makeFunction(name: "mprAnnotationVertex")
            let fragmentFunction = library.makeFunction(name: "mprAnnotationFragment")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            mprAnnotationPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            print("✅ MPR pipelines created successfully")
            
        } catch {
            fatalError("Failed to create MPR pipeline states: \(error)")
        }
    }
    
    // MARK: - Volume Loading
    func loadVolume(from volumeTexture: MTLTexture, voxelSpacing: simd_float3) {
        self.volumeTexture = volumeTexture
        
        mprParams.volumeSize = simd_float3(
            Float(volumeTexture.width),
            Float(volumeTexture.height),
            Float(volumeTexture.depth)
        )
        mprParams.voxelSpacing = voxelSpacing
        
        // Calculate max slice indices for each plane
        switch currentPlane {
        case .axial:
            maxSliceIndex = volumeTexture.depth - 1
            sliceIndex = volumeTexture.depth / 2
        case .sagittal:
            maxSliceIndex = volumeTexture.width - 1
            sliceIndex = volumeTexture.width / 2
        case .coronal:
            maxSliceIndex = volumeTexture.height - 1
            sliceIndex = volumeTexture.height / 2
        }
        
        mprParams.sliceIndex = UInt32(sliceIndex)
        mprParams.plane = UInt32(currentPlane.rawValue)
        
        print("📦 MPR volume loaded: \(volumeTexture.width)x\(volumeTexture.height)x\(volumeTexture.depth)")
    }
    
    // MARK: - Rendering
    func render(to drawable: CAMetalDrawable, viewportSize: CGSize) {
        complianceManager.measureRenderingPerformance(operation: "MPR Slice Rendering") {
            performRender(to: drawable, viewportSize: viewportSize)
        }
    }
    
    private func performRender(to drawable: CAMetalDrawable, viewportSize: CGSize) {
        guard let volumeTexture = volumeTexture else {
            renderErrorFrame(to: drawable)
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("❌ Failed to create command buffer")
            return
        }
        
        // Render MPR slice
        renderSlice(commandBuffer: commandBuffer, 
                   outputTexture: drawable.texture,
                   volumeTexture: volumeTexture,
                   viewportSize: viewportSize)
        
        // Render annotations if enabled
        if crosshairEnabled || annotationsEnabled {
            renderAnnotations(commandBuffer: commandBuffer,
                            outputTexture: drawable.texture,
                            viewportSize: viewportSize)
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func renderSlice(commandBuffer: MTLCommandBuffer,
                           outputTexture: MTLTexture,
                           volumeTexture: MTLTexture,
                           viewportSize: CGSize) {
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("❌ Failed to create compute encoder")
            return
        }
        
        computeEncoder.setComputePipelineState(mprSlicePipeline)
        computeEncoder.setTexture(volumeTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        computeEncoder.setTexture(transferFunctionTexture, index: 2)
        
        // Update parameters
        var params = mprParams
        params.sliceIndex = UInt32(sliceIndex)
        params.plane = UInt32(currentPlane.rawValue)
        params.windowCenter = windowCenter
        params.windowWidth = windowWidth
        
        computeEncoder.setBytes(&params, length: MemoryLayout<MPRRenderParams>.size, index: 0)
        
        // Dispatch compute threads
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }
    
    private func renderAnnotations(commandBuffer: MTLCommandBuffer,
                                 outputTexture: MTLTexture,
                                 viewportSize: CGSize) {
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(mprAnnotationPipeline)
        
        // Render crosshair
        if crosshairEnabled {
            renderCrosshair(renderEncoder: renderEncoder, viewportSize: viewportSize)
        }
        
        // Render slice information text
        if annotationsEnabled {
            renderSliceInfo(renderEncoder: renderEncoder, viewportSize: viewportSize)
        }
        
        renderEncoder.endEncoding()
    }
    
    private func renderCrosshair(renderEncoder: MTLRenderCommandEncoder, viewportSize: CGSize) {
        // Create crosshair vertices (two lines intersecting at crosshair position)
        let crosshairX = mprParams.crosshairPosition.x * Float(viewportSize.width)
        let crosshairY = mprParams.crosshairPosition.y * Float(viewportSize.height)
        
        // Normalize to [-1, 1] coordinate system
        let normX = (crosshairX / Float(viewportSize.width)) * 2.0 - 1.0
        let normY = 1.0 - (crosshairY / Float(viewportSize.height)) * 2.0
        
        let crosshairSize: Float = 20.0 // pixels
        let normSizeX = (crosshairSize / Float(viewportSize.width)) * 2.0
        let normSizeY = (crosshairSize / Float(viewportSize.height)) * 2.0
        
        let vertices: [simd_float2] = [
            // Horizontal line
            simd_float2(normX - normSizeX, normY),
            simd_float2(normX + normSizeX, normY),
            // Vertical line
            simd_float2(normX, normY - normSizeY),
            simd_float2(normX, normY + normSizeY)
        ]
        
        // Create vertex buffer
        guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                                 length: vertices.count * MemoryLayout<simd_float2>.size,
                                                 options: []) else { return }
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 4)
    }
    
    private func renderSliceInfo(renderEncoder: MTLRenderCommandEncoder, viewportSize: CGSize) {
        // Render slice information (plane name, slice number, position info)
        // This would typically use a text rendering system
        // For now, we'll prepare the data structure for text rendering
        
        let sliceInfo = SliceInfoData(
            planeName: currentPlane.displayName,
            sliceNumber: sliceIndex + 1,
            totalSlices: maxSliceIndex + 1,
            position: getSliceWorldPosition(),
            spacing: mprParams.voxelSpacing,
            windowCenter: windowCenter,
            windowWidth: windowWidth
        )
        
        // In a full implementation, this would render text overlays
        // For now, we just prepare the data
        _ = sliceInfo
    }
    
    private func renderErrorFrame(to drawable: CAMetalDrawable) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - MPR Controls
    func setPlane(_ plane: MPRPlane) {
        currentPlane = plane
        mprParams.plane = UInt32(plane.rawValue)
        
        // Update max slice index and reset to middle slice
        guard let volumeTexture = volumeTexture else { return }
        
        switch plane {
        case .axial:
            maxSliceIndex = volumeTexture.depth - 1
            sliceIndex = volumeTexture.depth / 2
        case .sagittal:
            maxSliceIndex = volumeTexture.width - 1
            sliceIndex = volumeTexture.width / 2
        case .coronal:
            maxSliceIndex = volumeTexture.height - 1
            sliceIndex = volumeTexture.height / 2
        }
        
        mprParams.sliceIndex = UInt32(sliceIndex)
        print("🔄 MPR plane changed to: \(plane.displayName)")
    }
    
    func setSliceIndex(_ index: Int) {
        sliceIndex = max(0, min(index, maxSliceIndex))
        mprParams.sliceIndex = UInt32(sliceIndex)
    }
    
    func nextSlice() {
        setSliceIndex(sliceIndex + 1)
    }
    
    func previousSlice() {
        setSliceIndex(sliceIndex - 1)
    }
    
    func setWindowLevel(center: Float, width: Float) {
        windowCenter = center
        windowWidth = width
        mprParams.windowCenter = center
        mprParams.windowWidth = width
    }
    
    func setZoom(_ zoom: Float) {
        mprParams.zoom = max(0.1, min(10.0, zoom))
    }
    
    func setPan(offset: simd_float2) {
        mprParams.panOffset = offset
    }
    
    func setRotation(_ rotation: Float) {
        mprParams.rotation = rotation
    }
    
    func setFlip(horizontal: Bool, vertical: Bool) {
        mprParams.flipHorizontal = horizontal
        mprParams.flipVertical = vertical
    }
    
    func setCrosshairPosition(_ position: simd_float2) {
        mprParams.crosshairPosition = simd_float2(
            max(0.0, min(1.0, position.x)),
            max(0.0, min(1.0, position.y))
        )
    }
    
    func setCrosshairEnabled(_ enabled: Bool) {
        crosshairEnabled = enabled
        mprParams.crosshairEnabled = enabled
    }
    
    func setAnnotationsEnabled(_ enabled: Bool) {
        annotationsEnabled = enabled
    }
    
    // MARK: - Transfer Function
    func updateTransferFunction(_ transferFunction: TransferFunction) {
        transferFunctionTexture = createTransferFunctionTexture(transferFunction)
    }
    
    private func createTransferFunctionTexture(_ transferFunction: TransferFunction) -> MTLTexture? {
        let width = 1024
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type1D
        descriptor.pixelFormat = .rgba16Float
        descriptor.width = width
        descriptor.height = 1
        descriptor.mipmapLevelCount = 1
        descriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
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
    
    // MARK: - Utility Functions
    private func getSliceWorldPosition() -> simd_float3 {
        guard let volumeTexture = volumeTexture else {
            return simd_float3(0, 0, 0)
        }
        
        let voxelPos: simd_float3
        
        switch currentPlane {
        case .axial:
            voxelPos = simd_float3(
                Float(volumeTexture.width) / 2.0,
                Float(volumeTexture.height) / 2.0,
                Float(sliceIndex)
            )
        case .sagittal:
            voxelPos = simd_float3(
                Float(sliceIndex),
                Float(volumeTexture.height) / 2.0,
                Float(volumeTexture.depth) / 2.0
            )
        case .coronal:
            voxelPos = simd_float3(
                Float(volumeTexture.width) / 2.0,
                Float(sliceIndex),
                Float(volumeTexture.depth) / 2.0
            )
        }
        
        return voxelPos * mprParams.voxelSpacing
    }
    
    // MARK: - Public Interface
    var currentPlaneType: MPRPlane {
        return currentPlane
    }
    
    var currentSliceIndex: Int {
        return sliceIndex
    }
    
    var maxSlices: Int {
        return maxSliceIndex + 1
    }
    
    var isVolumeLoaded: Bool {
        return volumeTexture != nil
    }
    
    var slicePosition: simd_float3 {
        return getSliceWorldPosition()
    }
    
    func getSliceInfo() -> SliceInfoData? {
        guard isVolumeLoaded else { return nil }
        
        return SliceInfoData(
            planeName: currentPlane.displayName,
            sliceNumber: sliceIndex + 1,
            totalSlices: maxSliceIndex + 1,
            position: getSliceWorldPosition(),
            spacing: mprParams.voxelSpacing,
            windowCenter: windowCenter,
            windowWidth: windowWidth
        )
    }
    
    // MARK: - Memory Management
    func releaseResources() {
        volumeTexture = nil
        transferFunctionTexture = nil
        print("🗑️ MPR renderer resources released")
    }
}

// MARK: - Supporting Structures
struct SliceInfoData {
    let planeName: String
    let sliceNumber: Int
    let totalSlices: Int
    let position: simd_float3
    let spacing: simd_float3
    let windowCenter: Float
    let windowWidth: Float
    
    var displayText: String {
        return """
        \(planeName) \(sliceNumber)/\(totalSlices)
        Position: (\(String(format: "%.1f", position.x)), \(String(format: "%.1f", position.y)), \(String(format: "%.1f", position.z)))mm
        W/L: \(Int(windowWidth))/\(Int(windowCenter))
        """
    }
}

// MARK: - MPR Extensions
extension MPRRenderer {
    
    /// Create synchronized MPR renderers for tri-planar view
    static func createTriPlanarRenderers() -> (axial: MPRRenderer, sagittal: MPRRenderer, coronal: MPRRenderer) {
        let axialRenderer = MPRRenderer()
        let sagittalRenderer = MPRRenderer()
        let coronalRenderer = MPRRenderer()
        
        axialRenderer.setPlane(.axial)
        sagittalRenderer.setPlane(.sagittal)
        coronalRenderer.setPlane(.coronal)
        
        return (axialRenderer, sagittalRenderer, coronalRenderer)
    }
    
    /// Load volume into all three MPR renderers with synchronization
    func loadVolumeForTriPlanar(axial: MPRRenderer, sagittal: MPRRenderer, coronal: MPRRenderer,
                               volumeTexture: MTLTexture, voxelSpacing: simd_float3) {
        axial.loadVolume(from: volumeTexture, voxelSpacing: voxelSpacing)
        sagittal.loadVolume(from: volumeTexture, voxelSpacing: voxelSpacing)
        coronal.loadVolume(from: volumeTexture, voxelSpacing: voxelSpacing)
        
        // Synchronize crosshair positions
        let centerPosition = simd_float2(0.5, 0.5)
        axial.setCrosshairPosition(centerPosition)
        sagittal.setCrosshairPosition(centerPosition)
        coronal.setCrosshairPosition(centerPosition)
    }
    
    /// Synchronize crosshair across all three planes
    func synchronizeCrosshair(with otherRenderers: [MPRRenderer], position: simd_float3) {
        // Convert 3D world position to 2D slice coordinates for each plane
        for renderer in otherRenderers {
            let normalizedPos: simd_float2
            
            switch renderer.currentPlane {
            case .axial:
                normalizedPos = simd_float2(
                    position.x / mprParams.volumeSize.x,
                    position.y / mprParams.volumeSize.y
                )
            case .sagittal:
                normalizedPos = simd_float2(
                    position.y / mprParams.volumeSize.y,
                    position.z / mprParams.volumeSize.z
                )
            case .coronal:
                normalizedPos = simd_float2(
                    position.x / mprParams.volumeSize.x,
                    position.z / mprParams.volumeSize.z
                )
            }
            
            renderer.setCrosshairPosition(normalizedPos)
        }
    }
}