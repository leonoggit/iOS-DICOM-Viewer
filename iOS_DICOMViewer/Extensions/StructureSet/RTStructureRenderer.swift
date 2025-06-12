import Foundation
import Metal
import MetalKit
import simd
import UIKit

/// High-performance Metal renderer for RT Structure Sets
/// Optimized for iOS with real-time 3D contour visualization and MPR support
class RTStructureRenderer {
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Render pipelines
    private var contourRenderPipeline: MTLRenderPipelineState?
    private var filledContourPipeline: MTLRenderPipelineState?
    private var wireframeRenderPipeline: MTLRenderPipelineState?
    private var volumeRenderPipeline: MTLRenderPipelineState?
    
    // Compute pipelines for RT processing
    private var contourMeshPipeline: MTLComputePipelineState?
    private var contourSimplificationPipeline: MTLComputePipelineState?
    
    // Buffers and resources
    private var uniformsBuffer: MTLBuffer?
    private var contourVertexBuffers: [String: MTLBuffer] = [:]
    private var contourIndexBuffers: [String: MTLBuffer] = [:]
    
    // iOS optimization caches
    private var meshCache: [String: ContourMesh] = [:]
    private let maxCachedMeshes = 10
    
    // Rendering parameters
    struct RTStructureUniforms {
        var projectionMatrix: simd_float4x4
        var modelViewMatrix: simd_float4x4
        var viewMatrix: simd_float4x4
        var viewportSize: simd_float2
        var contourWidth: Float
        var opacity: Float
        var showFilled: Int32
        var showWireframe: Int32
        var cullBackFaces: Int32
        var renderMode: Int32
    }
    
    enum RenderMode: Int32 {
        case wireframe = 0
        case filled = 1
        case both = 2
        case volume = 3
    }
    
    struct ContourMesh {
        let vertices: [simd_float3]
        let indices: [UInt32]
        let color: simd_float4
        let creationDate: Date
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
        
        print("✅ RTStructureRenderer initialized with Metal device: \(device.name)")
    }
    
    private func setupRenderPipelines() throws {
        // Contour line rendering pipeline
        let contourVertexFunction = library.makeFunction(name: "rtContourVertex")
        let contourFragmentFunction = library.makeFunction(name: "rtContourFragment")
        
        let contourPipelineDescriptor = MTLRenderPipelineDescriptor()
        contourPipelineDescriptor.vertexFunction = contourVertexFunction
        contourPipelineDescriptor.fragmentFunction = contourFragmentFunction
        contourPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        contourPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        contourPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        contourPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        contourPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        // Vertex descriptor for RT contours
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.size
        contourPipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        contourRenderPipeline = try device.makeRenderPipelineState(descriptor: contourPipelineDescriptor)
        
        // Filled contour rendering pipeline
        let filledVertexFunction = library.makeFunction(name: "rtFilledVertex")
        let filledFragmentFunction = library.makeFunction(name: "rtFilledFragment")
        
        let filledPipelineDescriptor = MTLRenderPipelineDescriptor()
        filledPipelineDescriptor.vertexFunction = filledVertexFunction
        filledPipelineDescriptor.fragmentFunction = filledFragmentFunction
        filledPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        filledPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        filledPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        filledPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        filledPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        filledPipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        filledContourPipeline = try device.makeRenderPipelineState(descriptor: filledPipelineDescriptor)
        
        // Wireframe rendering pipeline
        let wireframeVertexFunction = library.makeFunction(name: "rtWireframeVertex")
        let wireframeFragmentFunction = library.makeFunction(name: "rtWireframeFragment")
        
        let wireframePipelineDescriptor = MTLRenderPipelineDescriptor()
        wireframePipelineDescriptor.vertexFunction = wireframeVertexFunction
        wireframePipelineDescriptor.fragmentFunction = wireframeFragmentFunction
        wireframePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        wireframePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        wireframePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        wireframePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        wireframePipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        wireframePipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        wireframeRenderPipeline = try device.makeRenderPipelineState(descriptor: wireframePipelineDescriptor)
    }
    
    private func setupComputePipelines() throws {
        // Contour mesh generation pipeline
        guard let meshFunction = library.makeFunction(name: "generateContourMesh") else {
            throw RendererError.failedToCreateFunction("generateContourMesh")
        }
        
        contourMeshPipeline = try device.makeComputePipelineState(function: meshFunction)
        
        // Contour simplification pipeline for iOS performance
        guard let simplifyFunction = library.makeFunction(name: "simplifyContour") else {
            throw RendererError.failedToCreateFunction("simplifyContour")
        }
        
        contourSimplificationPipeline = try device.makeComputePipelineState(function: simplifyFunction)
    }
    
    private func setupBuffers() {
        // Create uniforms buffer
        uniformsBuffer = device.makeBuffer(length: MemoryLayout<RTStructureUniforms>.size, options: [.storageModeShared])
    }
    
    /// Render RT Structure Set with iOS optimizations
    func renderStructureSet(_ structureSet: RTStructureSet,
                           to drawable: CAMetalDrawable,
                           viewportSize: CGSize,
                           projectionMatrix: simd_float4x4,
                           viewMatrix: simd_float4x4,
                           renderMode: RenderMode = .both,
                           opacity: Float = 0.7) {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = createRenderPassDescriptor(for: drawable) else {
            print("⚠️ Failed to create command buffer or render pass descriptor")
            return
        }
        
        // Update uniforms
        updateUniforms(projectionMatrix: projectionMatrix,
                      viewMatrix: viewMatrix,
                      viewportSize: viewportSize,
                      renderMode: renderMode,
                      opacity: opacity)
        
        // Render each visible ROI contour
        for roiContour in structureSet.roiContours where roiContour.isVisible {
            renderROIContour(roiContour,
                           structureSet: structureSet,
                           commandBuffer: commandBuffer,
                           renderPassDescriptor: renderPassDescriptor,
                           renderMode: renderMode)
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func renderROIContour(_ roiContour: ROIContour,
                                 structureSet: RTStructureSet,
                                 commandBuffer: MTLCommandBuffer,
                                 renderPassDescriptor: MTLRenderPassDescriptor,
                                 renderMode: RenderMode) {
        
        let contourKey = "\(structureSet.structureSetUID)_\(roiContour.referencedROINumber)"
        
        // Get or create mesh for this contour
        let mesh = getOrCreateContourMesh(for: roiContour, key: contourKey)
        
        guard let vertexBuffer = createVertexBuffer(from: mesh),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        
        // Render based on mode
        switch renderMode {
        case .wireframe:
            renderWireframe(mesh, renderEncoder: renderEncoder, vertexBuffer: vertexBuffer)
            
        case .filled:
            renderFilled(mesh, renderEncoder: renderEncoder, vertexBuffer: vertexBuffer)
            
        case .both:
            renderFilled(mesh, renderEncoder: renderEncoder, vertexBuffer: vertexBuffer)
            renderWireframe(mesh, renderEncoder: renderEncoder, vertexBuffer: vertexBuffer)
            
        case .volume:
            // Future: 3D volume rendering of structure sets
            renderFilled(mesh, renderEncoder: renderEncoder, vertexBuffer: vertexBuffer)
        }
        
        renderEncoder.endEncoding()
    }
    
    private func renderWireframe(_ mesh: ContourMesh, renderEncoder: MTLRenderCommandEncoder, vertexBuffer: MTLBuffer) {
        guard let pipeline = wireframeRenderPipeline else { return }
        
        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Create wireframe indices from triangulated mesh
        let wireframeIndices = createWireframeIndices(from: mesh.indices)
        
        if let indexBuffer = createIndexBuffer(from: wireframeIndices) {
            renderEncoder.drawIndexedPrimitives(type: .line,
                                              indexCount: wireframeIndices.count,
                                              indexType: .uint32,
                                              indexBuffer: indexBuffer,
                                              indexBufferOffset: 0)
        }
    }
    
    private func renderFilled(_ mesh: ContourMesh, renderEncoder: MTLRenderCommandEncoder, vertexBuffer: MTLBuffer) {
        guard let pipeline = filledContourPipeline else { return }
        
        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        if let indexBuffer = createIndexBuffer(from: mesh.indices) {
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                              indexCount: mesh.indices.count,
                                              indexType: .uint32,
                                              indexBuffer: indexBuffer,
                                              indexBufferOffset: 0)
        }
    }
    
    private func getOrCreateContourMesh(for roiContour: ROIContour, key: String) -> ContourMesh {
        // Check cache first (iOS memory optimization)
        if let cachedMesh = meshCache[key] {
            return cachedMesh
        }
        
        // Generate new mesh from contour data
        let mesh = generateMeshFromContour(roiContour)
        
        // Cache management for iOS
        if meshCache.count >= maxCachedMeshes {
            // Remove oldest cached mesh
            let oldestKey = meshCache.min(by: { $0.value.creationDate < $1.value.creationDate })?.key
            if let keyToRemove = oldestKey {
                meshCache.removeValue(forKey: keyToRemove)
                print("💾 Removed cached RT structure mesh for memory management")
            }
        }
        
        meshCache[key] = mesh
        return mesh
    }
    
    private func generateMeshFromContour(_ roiContour: ROIContour) -> ContourMesh {
        var allVertices: [simd_float3] = []
        var allIndices: [UInt32] = []
        var indexOffset: UInt32 = 0
        
        // Process each contour in the sequence
        for contourData in roiContour.contourSequence {
            let points = contourData.points3D
            
            if contourData.contourGeometricType.isClosed && points.count >= 3 {
                // Triangulate closed contour
                let (vertices, indices) = triangulateContour(points)
                allVertices.append(contentsOf: vertices)
                
                // Adjust indices for vertex offset
                let adjustedIndices = indices.map { $0 + indexOffset }
                allIndices.append(contentsOf: adjustedIndices)
                indexOffset += UInt32(vertices.count)
            } else {
                // For open contours, create line segments
                allVertices.append(contentsOf: points)
                
                // Create line indices
                for i in 0..<(points.count - 1) {
                    allIndices.append(indexOffset + UInt32(i))
                    allIndices.append(indexOffset + UInt32(i + 1))
                }
                indexOffset += UInt32(points.count)
            }
        }
        
        // Get color from ROI display color
        let uiColor = roiContour.displayColor
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let color = simd_float4(Float(red), Float(green), Float(blue), Float(alpha))
        
        return ContourMesh(
            vertices: allVertices,
            indices: allIndices,
            color: color,
            creationDate: Date()
        )
    }
    
    private func triangulateContour(_ points: [simd_float3]) -> ([simd_float3], [UInt32]) {
        // Simple fan triangulation for planar contours
        // For more complex contours, could use ear clipping or Delaunay triangulation
        
        guard points.count >= 3 else { return ([], []) }
        
        var indices: [UInt32] = []
        
        // Fan triangulation from first vertex
        for i in 1..<(points.count - 1) {
            indices.append(0)
            indices.append(UInt32(i))
            indices.append(UInt32(i + 1))
        }
        
        return (points, indices)
    }
    
    private func createWireframeIndices(from triangleIndices: [UInt32]) -> [UInt32] {
        var wireframeIndices: [UInt32] = []
        
        // Convert triangle indices to line indices
        for i in stride(from: 0, to: triangleIndices.count, by: 3) {
            if i + 2 < triangleIndices.count {
                let v0 = triangleIndices[i]
                let v1 = triangleIndices[i + 1]
                let v2 = triangleIndices[i + 2]
                
                // Add three edges of the triangle
                wireframeIndices.append(contentsOf: [v0, v1, v1, v2, v2, v0])
            }
        }
        
        return wireframeIndices
    }
    
    private func createVertexBuffer(from mesh: ContourMesh) -> MTLBuffer? {
        let bufferKey = "\(mesh.vertices.count)_\(mesh.creationDate.timeIntervalSince1970)"
        
        if let cachedBuffer = contourVertexBuffers[bufferKey] {
            return cachedBuffer
        }
        
        let buffer = device.makeBuffer(bytes: mesh.vertices,
                                     length: mesh.vertices.count * MemoryLayout<simd_float3>.size,
                                     options: [.storageModeShared])
        
        contourVertexBuffers[bufferKey] = buffer
        return buffer
    }
    
    private func createIndexBuffer(from indices: [UInt32]) -> MTLBuffer? {
        return device.makeBuffer(bytes: indices,
                               length: indices.count * MemoryLayout<UInt32>.size,
                               options: [.storageModeShared])
    }
    
    private func updateUniforms(projectionMatrix: simd_float4x4,
                               viewMatrix: simd_float4x4,
                               viewportSize: CGSize,
                               renderMode: RenderMode,
                               opacity: Float) {
        
        guard let buffer = uniformsBuffer else { return }
        
        var uniforms = RTStructureUniforms(
            projectionMatrix: projectionMatrix,
            modelViewMatrix: matrix_identity_float4x4,
            viewMatrix: viewMatrix,
            viewportSize: simd_float2(Float(viewportSize.width), Float(viewportSize.height)),
            contourWidth: 2.0,
            opacity: opacity,
            showFilled: (renderMode == .filled || renderMode == .both) ? 1 : 0,
            showWireframe: (renderMode == .wireframe || renderMode == .both) ? 1 : 0,
            cullBackFaces: 1,
            renderMode: renderMode.rawValue
        )
        
        buffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<RTStructureUniforms>.size)
    }
    
    private func createRenderPassDescriptor(for drawable: CAMetalDrawable) -> MTLRenderPassDescriptor? {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        // Create depth texture for 3D rendering
        let depthDescriptor = MTLTextureDescriptor()
        depthDescriptor.textureType = .type2D
        depthDescriptor.pixelFormat = .depth32Float
        depthDescriptor.width = drawable.texture.width
        depthDescriptor.height = drawable.texture.height
        depthDescriptor.usage = .renderTarget
        
        if let depthTexture = device.makeTexture(descriptor: depthDescriptor) {
            renderPassDescriptor.depthAttachment.texture = depthTexture
            renderPassDescriptor.depthAttachment.loadAction = .clear
            renderPassDescriptor.depthAttachment.storeAction = .dontCare
            renderPassDescriptor.depthAttachment.clearDepth = 1.0
        }
        
        return renderPassDescriptor
    }
    
    /// Render structure set in specific MPR plane (iOS optimized for medical imaging)
    func renderInMPRPlane(_ structureSet: RTStructureSet,
                         planeNormal: simd_float3,
                         planePoint: simd_float3,
                         to drawable: CAMetalDrawable,
                         viewportSize: CGSize,
                         transform: simd_float4x4) {
        
        // Filter contours that intersect with the MPR plane
        let intersectingContours = getContoursIntersectingPlane(structureSet, 
                                                              planeNormal: planeNormal, 
                                                              planePoint: planePoint)
        
        guard !intersectingContours.isEmpty else { return }
        
        let projection = createOrthographicProjection(width: Float(viewportSize.width),
                                                    height: Float(viewportSize.height))
        
        // Render intersecting contours
        renderStructureSet(structureSet,
                          to: drawable,
                          viewportSize: viewportSize,
                          projectionMatrix: projection,
                          viewMatrix: transform,
                          renderMode: .wireframe,
                          opacity: 0.8)
    }
    
    private func getContoursIntersectingPlane(_ structureSet: RTStructureSet,
                                            planeNormal: simd_float3,
                                            planePoint: simd_float3) -> [ROIContour] {
        
        return structureSet.roiContours.filter { roiContour in
            guard let boundingBox = roiContour.boundingBox else { return false }
            
            // Quick bounding box test against plane
            let center = boundingBox.center
            let distance = abs(simd_dot(center - planePoint, planeNormal))
            let maxExtent = max(boundingBox.width, max(boundingBox.height, boundingBox.depth)) / 2.0
            
            return distance <= Float(maxExtent)
        }
    }
    
    private func createOrthographicProjection(width: Float, height: Float) -> simd_float4x4 {
        let left: Float = 0
        let right: Float = width
        let bottom: Float = height
        let top: Float = 0
        let near: Float = -1000
        let far: Float = 1000
        
        return simd_float4x4(
            simd_float4(2 / (right - left), 0, 0, -(right + left) / (right - left)),
            simd_float4(0, 2 / (top - bottom), 0, -(top + bottom) / (top - bottom)),
            simd_float4(0, 0, -2 / (far - near), -(far + near) / (far - near)),
            simd_float4(0, 0, 0, 1)
        )
    }
    
    /// Compute distance from point to nearest contour (iOS optimized for touch interaction)
    func distanceToNearestContour(_ structureSet: RTStructureSet, point: simd_float3) -> Float {
        var minDistance = Float.infinity
        
        for roiContour in structureSet.roiContours where roiContour.isVisible {
            for contourData in roiContour.contourSequence {
                let distance = contourData.distanceToPoint(point)
                minDistance = min(minDistance, distance)
            }
        }
        
        return minDistance
    }
    
    /// iOS memory management
    func handleMemoryPressure() {
        print("💾 RTStructureRenderer handling memory pressure")
        meshCache.removeAll()
        contourVertexBuffers.removeAll()
        contourIndexBuffers.removeAll()
    }
    
    /// Preload structure set for smooth rendering
    func preloadStructureSet(_ structureSet: RTStructureSet) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for roiContour in structureSet.roiContours where roiContour.isVisible {
                let key = "\(structureSet.structureSetUID)_\(roiContour.referencedROINumber)"
                _ = self?.getOrCreateContourMesh(for: roiContour, key: key)
            }
            print("📱 Preloaded \(structureSet.roiContours.count) RT structure meshes")
        }
    }
    
    deinit {
        print("🗑️ RTStructureRenderer deallocated")
    }
}