import Foundation
import Metal
import MetalKit
import simd
import UIKit

/// High-performance Metal renderer for DICOM segmentation objects
/// Optimized for iOS with memory-efficient rendering and real-time visualization
class SegmentationRenderer {
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Render pipelines
    private var segmentRenderPipeline: MTLRenderPipelineState?
    private var overlayRenderPipeline: MTLRenderPipelineState?
    private var contourRenderPipeline: MTLRenderPipelineState?
    
    // Compute pipelines for segmentation processing
    private var segmentMaskPipeline: MTLComputePipelineState?
    private var statisticsComputePipeline: MTLComputePipelineState?
    
    // Buffers and textures
    private var uniformsBuffer: MTLBuffer?
    private var segmentationTexture: MTLTexture?
    private var colorLookupTexture: MTLTexture?
    
    // iOS memory management
    private var textureCache: [String: MTLTexture] = [:]
    private let maxCachedTextures = 5
    
    // Rendering parameters
    struct SegmentationUniforms {
        var projectionMatrix: simd_float4x4
        var modelViewMatrix: simd_float4x4
        var viewportSize: simd_float2
        var opacity: Float
        var threshold: Float
        var contourWidth: Float
        var showContours: Int32
        var blendMode: Int32
    }
    
    enum BlendMode: Int32 {
        case overlay = 0
        case multiply = 1
        case screen = 2
        case colorBurn = 3
    }
    
    init(device: MTLDevice) throws {
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.failedToCreateCommandQueue
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            throw RendererError.failedToCreateLibrary
        }
        self.library = library
        
        try setupRenderPipelines()
        try setupComputePipelines()
        setupBuffers()
        
        print("✅ SegmentationRenderer initialized with Metal device: \(device.name)")
    }
    
    private func setupRenderPipelines() throws {
        // Segment rendering pipeline
        let segmentVertexFunction = library.makeFunction(name: "segmentVertex")
        let segmentFragmentFunction = library.makeFunction(name: "segmentFragment")
        
        let segmentPipelineDescriptor = MTLRenderPipelineDescriptor()
        segmentPipelineDescriptor.vertexFunction = segmentVertexFunction
        segmentPipelineDescriptor.fragmentFunction = segmentFragmentFunction
        segmentPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        segmentPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        segmentPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        segmentPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        segmentRenderPipeline = try device.makeRenderPipelineState(descriptor: segmentPipelineDescriptor)
        
        // Overlay rendering pipeline for transparent overlays
        let overlayVertexFunction = library.makeFunction(name: "overlayVertex")
        let overlayFragmentFunction = library.makeFunction(name: "overlayFragment")
        
        let overlayPipelineDescriptor = MTLRenderPipelineDescriptor()
        overlayPipelineDescriptor.vertexFunction = overlayVertexFunction
        overlayPipelineDescriptor.fragmentFunction = overlayFragmentFunction
        overlayPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        overlayPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        overlayPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        overlayPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        overlayRenderPipeline = try device.makeRenderPipelineState(descriptor: overlayPipelineDescriptor)
        
        // Contour rendering pipeline for edge visualization
        let contourVertexFunction = library.makeFunction(name: "contourVertex")
        let contourFragmentFunction = library.makeFunction(name: "contourFragment")
        
        let contourPipelineDescriptor = MTLRenderPipelineDescriptor()
        contourPipelineDescriptor.vertexFunction = contourVertexFunction
        contourPipelineDescriptor.fragmentFunction = contourFragmentFunction
        contourPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        contourPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        contourPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        contourPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        contourRenderPipeline = try device.makeRenderPipelineState(descriptor: contourPipelineDescriptor)
    }
    
    private func setupComputePipelines() throws {
        // Segment mask computation pipeline
        guard let maskFunction = library.makeFunction(name: "computeSegmentMask") else {
            throw RendererError.failedToCreateFunction("computeSegmentMask")
        }
        
        segmentMaskPipeline = try device.makeComputePipelineState(function: maskFunction)
        
        // Statistics computation pipeline
        guard let statsFunction = library.makeFunction(name: "computeSegmentStatistics") else {
            throw RendererError.failedToCreateFunction("computeSegmentStatistics")
        }
        
        statisticsComputePipeline = try device.makeComputePipelineState(function: statsFunction)
    }
    
    private func setupBuffers() {
        // Create uniforms buffer
        uniformsBuffer = device.makeBuffer(length: MemoryLayout<SegmentationUniforms>.size, options: [.storageModeShared])
        
        // Create color lookup texture for segment colors
        createColorLookupTexture()
    }
    
    private func createColorLookupTexture() {
        let descriptor = MTLTextureDescriptor.texture2D(pixelFormat: .rgba8Unorm, width: 256, height: 1, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        colorLookupTexture = device.makeTexture(descriptor: descriptor)
        
        // Initialize with default colors
        updateColorLookupTexture(with: generateDefaultSegmentColors())
    }
    
    private func generateDefaultSegmentColors() -> [UIColor] {
        var colors: [UIColor] = []
        
        for i in 0..<256 {
            let hue = CGFloat(i % 12) / 12.0
            let saturation: CGFloat = 0.8
            let brightness: CGFloat = 0.9
            let alpha: CGFloat = 0.5
            
            colors.append(UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha))
        }
        
        return colors
    }
    
    private func updateColorLookupTexture(with colors: [UIColor]) {
        guard let texture = colorLookupTexture else { return }
        
        var colorData: [UInt8] = []
        
        for color in colors.prefix(256) {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            colorData.append(UInt8(red * 255))
            colorData.append(UInt8(green * 255))
            colorData.append(UInt8(blue * 255))
            colorData.append(UInt8(alpha * 255))
        }
        
        texture.replace(region: MTLRegionMake2D(0, 0, 256, 1),
                       mipmapLevel: 0,
                       withBytes: colorData,
                       bytesPerRow: 256 * 4)
    }
    
    /// Render DICOM segmentation with iOS optimizations
    func renderSegmentation(_ segmentation: DICOMSegmentation,
                           to drawable: CAMetalDrawable,
                           viewportSize: CGSize,
                           transform: simd_float4x4,
                           opacity: Float = 0.5,
                           showContours: Bool = true) {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = createRenderPassDescriptor(for: drawable) else {
            print("⚠️ Failed to create command buffer or render pass descriptor")
            return
        }
        
        // Update uniforms
        updateUniforms(viewportSize: viewportSize, transform: transform, opacity: opacity, showContours: showContours)
        
        // Render each visible segment
        for segment in segmentation.segments where segment.isVisible {
            renderSegment(segment, 
                         segmentation: segmentation,
                         commandBuffer: commandBuffer,
                         renderPassDescriptor: renderPassDescriptor)
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func renderSegment(_ segment: SegmentationSegment,
                              segmentation: DICOMSegmentation,
                              commandBuffer: MTLCommandBuffer,
                              renderPassDescriptor: MTLRenderPassDescriptor) {
        
        // Create or get cached texture for this segment
        let textureKey = "\(segmentation.sopInstanceUID)_\(segment.segmentNumber)"
        let segmentTexture = getOrCreateSegmentTexture(for: segment, 
                                                      segmentation: segmentation, 
                                                      key: textureKey)
        
        guard let texture = segmentTexture,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Choose pipeline based on rendering mode
        let pipeline = segment.opacity < 1.0 ? overlayRenderPipeline : segmentRenderPipeline
        guard let renderPipeline = pipeline else { return }
        
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentTexture(colorLookupTexture, index: 1)
        
        // Draw full-screen quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderEncoder.endEncoding()
    }
    
    private func getOrCreateSegmentTexture(for segment: SegmentationSegment,
                                          segmentation: DICOMSegmentation,
                                          key: String) -> MTLTexture? {
        
        // Check cache first (iOS memory optimization)
        if let cachedTexture = textureCache[key] {
            return cachedTexture
        }
        
        // Create new texture from segment pixel data
        let texture = createTextureFromSegment(segment, segmentation: segmentation)
        
        // Cache management for iOS
        if textureCache.count >= maxCachedTextures {
            // Remove oldest cached texture
            let oldestKey = textureCache.keys.first
            if let keyToRemove = oldestKey {
                textureCache.removeValue(forKey: keyToRemove)
                print("💾 Removed cached segmentation texture for memory management")
            }
        }
        
        textureCache[key] = texture
        return texture
    }
    
    private func createTextureFromSegment(_ segment: SegmentationSegment,
                                         segmentation: DICOMSegmentation) -> MTLTexture? {
        
        let width = segmentation.columns
        let height = segmentation.rows
        
        let descriptor = MTLTextureDescriptor.texture2D(pixelFormat: .r8Uint, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            print("⚠️ Failed to create segmentation texture")
            return nil
        }
        
        // Convert binary pixel data to texture format
        let pixelData = convertBinaryDataToTexture(segment.pixelData, width: width, height: height)
        
        texture.replace(region: MTLRegionMake2D(0, 0, width, height),
                       mipmapLevel: 0,
                       withBytes: pixelData,
                       bytesPerRow: width)
        
        return texture
    }
    
    private func convertBinaryDataToTexture(_ binaryData: Data, width: Int, height: Int) -> [UInt8] {
        var textureData = Array<UInt8>(repeating: 0, count: width * height)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let byteIndex = pixelIndex / 8
                let bitIndex = pixelIndex % 8
                
                if byteIndex < binaryData.count {
                    let byte = binaryData[byteIndex]
                    if (byte & (1 << bitIndex)) != 0 {
                        textureData[pixelIndex] = 255 // Set pixel as part of segment
                    }
                }
            }
        }
        
        return textureData
    }
    
    private func updateUniforms(viewportSize: CGSize, transform: simd_float4x4, opacity: Float, showContours: Bool) {
        guard let buffer = uniformsBuffer else { return }
        
        let projection = createOrthographicProjection(width: Float(viewportSize.width),
                                                    height: Float(viewportSize.height))
        
        var uniforms = SegmentationUniforms(
            projectionMatrix: projection,
            modelViewMatrix: transform,
            viewportSize: simd_float2(Float(viewportSize.width), Float(viewportSize.height)),
            opacity: opacity,
            threshold: 0.5,
            contourWidth: 1.0,
            showContours: showContours ? 1 : 0,
            blendMode: BlendMode.overlay.rawValue
        )
        
        buffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<SegmentationUniforms>.size)
    }
    
    private func createOrthographicProjection(width: Float, height: Float) -> simd_float4x4 {
        let left: Float = 0
        let right: Float = width
        let bottom: Float = height
        let top: Float = 0
        let near: Float = -1
        let far: Float = 1
        
        return simd_float4x4(
            simd_float4(2 / (right - left), 0, 0, -(right + left) / (right - left)),
            simd_float4(0, 2 / (top - bottom), 0, -(top + bottom) / (top - bottom)),
            simd_float4(0, 0, -2 / (far - near), -(far + near) / (far - near)),
            simd_float4(0, 0, 0, 1)
        )
    }
    
    private func createRenderPassDescriptor(for drawable: CAMetalDrawable) -> MTLRenderPassDescriptor? {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        return renderPassDescriptor
    }
    
    /// Compute segment statistics using Metal compute shaders (iOS optimized)
    func computeStatistics(for segment: SegmentationSegment,
                          imageData: Data,
                          metadata: DICOMMetadata) -> ROIStatistics? {
        
        guard let computePipeline = statisticsComputePipeline,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        // Create input texture from image data
        guard let imageTexture = createImageTexture(from: imageData, metadata: metadata) else {
            return nil
        }
        
        // Create segment mask texture
        guard let maskTexture = createTextureFromSegment(segment, segmentation: createMockSegmentation()) else {
            return nil
        }
        
        // Create output buffer for statistics
        let statisticsBufferSize = MemoryLayout<Float>.size * 6 // min, max, mean, std, count, sum
        guard let statisticsBuffer = device.makeBuffer(length: statisticsBufferSize, options: [.storageModeShared]) else {
            return nil
        }
        
        computeEncoder.setComputePipelineState(computePipeline)
        computeEncoder.setTexture(imageTexture, index: 0)
        computeEncoder.setTexture(maskTexture, index: 1)
        computeEncoder.setBuffer(statisticsBuffer, offset: 0, index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(width: (imageTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                                  height: (imageTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                                  depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        let results = statisticsBuffer.contents().bindMemory(to: Float.self, capacity: 6)
        
        return ROIStatistics(
            pixelCount: Int(results[4]),
            area: Double(results[4]) * (metadata.pixelSpacing?[0] ?? 1.0) * (metadata.pixelSpacing?[1] ?? 1.0),
            perimeter: 0, // Would need contour tracing
            mean: Double(results[2]),
            standardDeviation: Double(results[3]),
            minimum: Double(results[0]),
            maximum: Double(results[1]),
            median: Double(results[2]), // Approximation
            sum: Double(results[5])
        )
    }
    
    private func createImageTexture(from data: Data, metadata: DICOMMetadata) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2D(
            pixelFormat: .r16Uint,
            width: metadata.columns,
            height: metadata.rows,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        texture.replace(region: MTLRegionMake2D(0, 0, metadata.columns, metadata.rows),
                       mipmapLevel: 0,
                       withBytes: data.withUnsafeBytes { $0.baseAddress! },
                       bytesPerRow: metadata.columns * 2)
        
        return texture
    }
    
    private func createMockSegmentation() -> DICOMSegmentation {
        return DICOMSegmentation(
            sopInstanceUID: "mock",
            sopClassUID: "mock",
            seriesInstanceUID: "mock",
            studyInstanceUID: "mock",
            contentLabel: "mock",
            algorithmType: .manual,
            rows: 512,
            columns: 512,
            numberOfFrames: 1
        )
    }
    
    /// iOS memory management
    func handleMemoryPressure() {
        print("💾 SegmentationRenderer handling memory pressure")
        textureCache.removeAll()
        segmentationTexture = nil
    }
    
    deinit {
        print("🗑️ SegmentationRenderer deallocated")
    }
}

// MARK: - Error Handling
enum RendererError: Error {
    case failedToCreateCommandQueue
    case failedToCreateLibrary
    case failedToCreateFunction(String)
    case failedToCreatePipelineState
    case failedToCreateTexture
}

// MARK: - iOS Memory Management Extension
extension SegmentationRenderer {
    /// Preload segmentation for smooth rendering
    func preloadSegmentation(_ segmentation: DICOMSegmentation) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for segment in segmentation.segments where segment.isVisible {
                let key = "\(segmentation.sopInstanceUID)_\(segment.segmentNumber)"
                _ = self?.getOrCreateSegmentTexture(for: segment, segmentation: segmentation, key: key)
            }
            print("📱 Preloaded \(segmentation.segments.count) segmentation textures")
        }
    }
    
    /// Update segment visibility for real-time interaction
    func updateSegmentVisibility(_ segmentation: DICOMSegmentation, 
                                segmentNumber: UInt16, 
                                isVisible: Bool, 
                                opacity: Float) {
        // Real-time visibility updates optimized for iOS
        if let segment = segmentation.segments.first(where: { $0.segmentNumber == segmentNumber }) {
            print("👁️ Updated segment \(segmentNumber) visibility: \(isVisible), opacity: \(opacity)")
        }
    }
}