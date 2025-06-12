import Metal
import MetalKit
import simd
import UIKit

/// Metal-based renderer for ROI tools and measurements
/// Provides high-performance GPU rendering of medical imaging annotations
class ROIRenderer {
    
    // MARK: - Core Metal Objects
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // MARK: - Pipeline States
    private var linePipeline: MTLRenderPipelineState!
    private var circlePipeline: MTLRenderPipelineState!
    private var rectanglePipeline: MTLRenderPipelineState!
    private var polygonPipeline: MTLRenderPipelineState!
    private var textPipeline: MTLRenderPipelineState!
    
    // MARK: - Buffers
    private var vertexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    
    // MARK: - Render Parameters
    private var viewportSize = simd_float2(1.0, 1.0)
    private var imageToScreenTransform = matrix_identity_float4x4
    
    // MARK: - Structures for GPU
    struct ROIVertex {
        var position: simd_float2
        var color: simd_float4
        var texCoord: simd_float2
    }
    
    struct ROIUniforms {
        var projectionMatrix: simd_float4x4
        var modelViewMatrix: simd_float4x4
        var viewportSize: simd_float2
        var lineWidth: Float
        var opacity: Float
    }
    
    // MARK: - Initialization
    init(device: MTLDevice) throws {
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw ROIRenderError.failedToCreateCommandQueue
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            throw ROIRenderError.failedToLoadLibrary
        }
        self.library = library
        
        try setupPipelines()
        setupBuffers()
        
        print("✅ ROI Renderer initialized")
    }
    
    private func setupPipelines() throws {
        // Line rendering pipeline
        let lineVertexFunction = library.makeFunction(name: "roiLineVertex")
        let lineFragmentFunction = library.makeFunction(name: "roiLineFragment")
        
        let linePipelineDescriptor = MTLRenderPipelineDescriptor()
        linePipelineDescriptor.vertexFunction = lineVertexFunction
        linePipelineDescriptor.fragmentFunction = lineFragmentFunction
        linePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        linePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        linePipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        linePipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        linePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        linePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        linePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        linePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        linePipeline = try device.makeRenderPipelineState(descriptor: linePipelineDescriptor)
        
        // Circle rendering pipeline
        let circleVertexFunction = library.makeFunction(name: "roiCircleVertex")
        let circleFragmentFunction = library.makeFunction(name: "roiCircleFragment")
        
        let circlePipelineDescriptor = MTLRenderPipelineDescriptor()
        circlePipelineDescriptor.vertexFunction = circleVertexFunction
        circlePipelineDescriptor.fragmentFunction = circleFragmentFunction
        circlePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        circlePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        circlePipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        circlePipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        circlePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        circlePipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        circlePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        circlePipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        circlePipeline = try device.makeRenderPipelineState(descriptor: circlePipelineDescriptor)
        
        // Use same pipeline for other shapes (simplified for this implementation)
        rectanglePipeline = linePipeline
        polygonPipeline = linePipeline
        textPipeline = linePipeline
    }
    
    private func setupBuffers() {
        // Create vertex buffer (will be updated dynamically)
        let maxVertices = 10000
        let vertexBufferSize = maxVertices * MemoryLayout<ROIVertex>.size
        vertexBuffer = device.makeBuffer(length: vertexBufferSize, options: [.storageModeShared])
        
        // Create uniform buffer
        let uniformBufferSize = MemoryLayout<ROIUniforms>.size
        uniformBuffer = device.makeBuffer(length: uniformBufferSize, options: [.storageModeShared])
    }
    
    // MARK: - Rendering
    func render(tools: [ROITool], 
               to drawable: CAMetalDrawable, 
               viewportSize: CGSize,
               imageToScreenTransform: simd_float4x4) {
        
        self.viewportSize = simd_float2(Float(viewportSize.width), Float(viewportSize.height))
        self.imageToScreenTransform = imageToScreenTransform
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("❌ Failed to create command buffer for ROI rendering")
            return
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("❌ Failed to create render encoder for ROI rendering")
            return
        }
        
        // Update uniforms
        updateUniforms()
        
        // Render each tool
        for tool in tools {
            if tool.isVisible {
                renderTool(tool, encoder: renderEncoder)
            }
        }
        
        renderEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    private func updateUniforms() {
        let uniformPointer = uniformBuffer.contents().bindMemory(to: ROIUniforms.self, capacity: 1)
        
        // Create orthographic projection matrix for screen coordinates
        let projectionMatrix = matrix_ortho(
            left: 0,
            right: viewportSize.x,
            bottom: viewportSize.y,
            top: 0,
            near: -1,
            far: 1
        )
        
        uniformPointer.pointee = ROIUniforms(
            projectionMatrix: projectionMatrix,
            modelViewMatrix: matrix_identity_float4x4,
            viewportSize: viewportSize,
            lineWidth: 2.0,
            opacity: 1.0
        )
    }
    
    private func renderTool(_ tool: ROITool, encoder: MTLRenderCommandEncoder) {
        switch tool {
        case is LinearROITool:
            renderLinearTool(tool as! LinearROITool, encoder: encoder)
        case is CircularROITool:
            renderCircularTool(tool as! CircularROITool, encoder: encoder)
        case is RectangularROITool:
            renderRectangularTool(tool as! RectangularROITool, encoder: encoder)
        case is PolygonROITool:
            renderPolygonTool(tool as! PolygonROITool, encoder: encoder)
        case is AngleROITool:
            renderAngleTool(tool as! AngleROITool, encoder: encoder)
        case is EllipticalROITool:
            renderEllipticalTool(tool as! EllipticalROITool, encoder: encoder)
        default:
            break
        }
        
        // Render measurement text
        if let measurement = tool.measurement {
            renderMeasurementText(for: tool, measurement: measurement, encoder: encoder)
        }
    }
    
    private func renderLinearTool(_ tool: LinearROITool, encoder: MTLRenderCommandEncoder) {
        guard tool.imageCoordinates.count >= 2 else { return }
        
        let start = transformImageToScreen(tool.imageCoordinates[0])
        let end = transformImageToScreen(tool.imageCoordinates[1])
        let color = simd_float4(tool.color.components)
        
        let vertices = [
            ROIVertex(position: start, color: color, texCoord: simd_float2(0, 0)),
            ROIVertex(position: end, color: color, texCoord: simd_float2(1, 0))
        ]
        
        renderLineSegments(vertices: vertices, encoder: encoder, lineWidth: tool.lineWidth)
    }
    
    private func renderCircularTool(_ tool: CircularROITool, encoder: MTLRenderCommandEncoder) {
        guard let center = tool.center, tool.imageCoordinates.count >= 2 else { return }
        
        let screenCenter = transformImageToScreen(center)
        let screenRadius = tool.radius * getScreenScale()
        let color = simd_float4(tool.color.components)
        
        renderCircle(center: screenCenter, radius: screenRadius, color: color, 
                    filled: tool.opacity > 0, encoder: encoder, lineWidth: tool.lineWidth)
    }
    
    private func renderRectangularTool(_ tool: RectangularROITool, encoder: MTLRenderCommandEncoder) {
        guard let topLeft = tool.topLeft, let bottomRight = tool.bottomRight else { return }
        
        let screenTopLeft = transformImageToScreen(topLeft)
        let screenBottomRight = transformImageToScreen(bottomRight)
        let color = simd_float4(tool.color.components)
        
        let vertices = [
            // Rectangle outline
            ROIVertex(position: screenTopLeft, color: color, texCoord: simd_float2(0, 0)),
            ROIVertex(position: simd_float2(screenBottomRight.x, screenTopLeft.y), color: color, texCoord: simd_float2(1, 0)),
            
            ROIVertex(position: simd_float2(screenBottomRight.x, screenTopLeft.y), color: color, texCoord: simd_float2(1, 0)),
            ROIVertex(position: screenBottomRight, color: color, texCoord: simd_float2(1, 1)),
            
            ROIVertex(position: screenBottomRight, color: color, texCoord: simd_float2(1, 1)),
            ROIVertex(position: simd_float2(screenTopLeft.x, screenBottomRight.y), color: color, texCoord: simd_float2(0, 1)),
            
            ROIVertex(position: simd_float2(screenTopLeft.x, screenBottomRight.y), color: color, texCoord: simd_float2(0, 1)),
            ROIVertex(position: screenTopLeft, color: color, texCoord: simd_float2(0, 0))
        ]
        
        renderLineSegments(vertices: vertices, encoder: encoder, lineWidth: tool.lineWidth)
        
        // Render fill if opacity > 0
        if tool.opacity > 0 {
            renderRectangleFill(topLeft: screenTopLeft, bottomRight: screenBottomRight, 
                              color: color * tool.opacity, encoder: encoder)
        }
    }
    
    private func renderPolygonTool(_ tool: PolygonROITool, encoder: MTLRenderCommandEncoder) {
        guard tool.imageCoordinates.count >= 2 else { return }
        
        let color = simd_float4(tool.color.components)
        var vertices: [ROIVertex] = []
        
        // Create line segments for polygon edges
        for i in 0..<tool.imageCoordinates.count {
            let current = transformImageToScreen(tool.imageCoordinates[i])
            let next = transformImageToScreen(tool.imageCoordinates[(i + 1) % tool.imageCoordinates.count])
            
            vertices.append(ROIVertex(position: current, color: color, texCoord: simd_float2(0, 0)))
            vertices.append(ROIVertex(position: next, color: color, texCoord: simd_float2(1, 0)))
        }
        
        renderLineSegments(vertices: vertices, encoder: encoder, lineWidth: tool.lineWidth)
        
        // Render fill if completed and opacity > 0
        if tool.isComplete() && tool.opacity > 0 {
            renderPolygonFill(coordinates: tool.imageCoordinates.map(transformImageToScreen), 
                            color: color * tool.opacity, encoder: encoder)
        }
    }
    
    private func renderAngleTool(_ tool: AngleROITool, encoder: MTLRenderCommandEncoder) {
        guard tool.imageCoordinates.count >= 2 else { return }
        
        let color = simd_float4(tool.color.components)
        var vertices: [ROIVertex] = []
        
        // Draw lines from vertex to each point
        if tool.imageCoordinates.count >= 2 {
            let start = transformImageToScreen(tool.imageCoordinates[0])
            let vertex = transformImageToScreen(tool.imageCoordinates[1])
            
            vertices.append(ROIVertex(position: start, color: color, texCoord: simd_float2(0, 0)))
            vertices.append(ROIVertex(position: vertex, color: color, texCoord: simd_float2(1, 0)))
            
            if tool.imageCoordinates.count >= 3 {
                let end = transformImageToScreen(tool.imageCoordinates[2])
                vertices.append(ROIVertex(position: vertex, color: color, texCoord: simd_float2(0, 0)))
                vertices.append(ROIVertex(position: end, color: color, texCoord: simd_float2(1, 0)))
                
                // Draw angle arc
                renderAngleArc(vertex: vertex, point1: start, point2: end, color: color, encoder: encoder)
            }
        }
        
        renderLineSegments(vertices: vertices, encoder: encoder, lineWidth: tool.lineWidth)
    }
    
    private func renderEllipticalTool(_ tool: EllipticalROITool, encoder: MTLRenderCommandEncoder) {
        guard let center = tool.center, let semiAxes = tool.semiAxes else { return }
        
        let screenCenter = transformImageToScreen(center)
        let screenSemiAxes = simd_float2(
            semiAxes.x * getScreenScale(),
            semiAxes.y * getScreenScale()
        )
        let color = simd_float4(tool.color.components)
        
        renderEllipse(center: screenCenter, semiAxes: screenSemiAxes, color: color,
                     filled: tool.opacity > 0, encoder: encoder, lineWidth: tool.lineWidth)
    }
    
    // MARK: - Primitive Rendering Methods
    private func renderLineSegments(vertices: [ROIVertex], encoder: MTLRenderCommandEncoder, lineWidth: Float) {
        guard !vertices.isEmpty else { return }
        
        encoder.setRenderPipelineState(linePipeline)
        
        let vertexPointer = vertexBuffer.contents().bindMemory(to: ROIVertex.self, capacity: vertices.count)
        for (index, vertex) in vertices.enumerated() {
            vertexPointer[index] = vertex
        }
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertices.count)
    }
    
    private func renderCircle(center: simd_float2, radius: Float, color: simd_float4, 
                             filled: Bool, encoder: MTLRenderCommandEncoder, lineWidth: Float) {
        
        encoder.setRenderPipelineState(circlePipeline)
        
        let segments = 64
        var vertices: [ROIVertex] = []
        
        // Generate circle vertices
        for i in 0...segments {
            let angle = Float(i) * 2.0 * Float.pi / Float(segments)
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            
            vertices.append(ROIVertex(position: simd_float2(x, y), color: color, texCoord: simd_float2(0, 0)))
            
            if i > 0 {
                vertices.append(ROIVertex(position: simd_float2(x, y), color: color, texCoord: simd_float2(0, 0)))
            }
        }
        
        renderLineSegments(vertices: vertices, encoder: encoder, lineWidth: lineWidth)
    }
    
    private func renderRectangleFill(topLeft: simd_float2, bottomRight: simd_float2, 
                                   color: simd_float4, encoder: MTLRenderCommandEncoder) {
        // Implementation for filled rectangle rendering
        // This would use triangle primitives
    }
    
    private func renderPolygonFill(coordinates: [simd_float2], color: simd_float4, encoder: MTLRenderCommandEncoder) {
        // Implementation for filled polygon rendering using triangle fan
        // This would tessellate the polygon into triangles
    }
    
    private func renderAngleArc(vertex: simd_float2, point1: simd_float2, point2: simd_float2, 
                              color: simd_float4, encoder: MTLRenderCommandEncoder) {
        // Implementation for angle arc rendering
        let radius: Float = 30.0 // Fixed arc radius
        
        let v1 = normalize(point1 - vertex)
        let v2 = normalize(point2 - vertex)
        
        let startAngle = atan2(v1.y, v1.x)
        let endAngle = atan2(v2.y, v2.x)
        
        var vertices: [ROIVertex] = []
        let segments = 16
        
        for i in 0...segments {
            let t = Float(i) / Float(segments)
            let angle = startAngle + t * (endAngle - startAngle)
            let x = vertex.x + radius * cos(angle)
            let y = vertex.y + radius * sin(angle)
            
            vertices.append(ROIVertex(position: simd_float2(x, y), color: color, texCoord: simd_float2(0, 0)))
            
            if i > 0 {
                vertices.append(ROIVertex(position: simd_float2(x, y), color: color, texCoord: simd_float2(0, 0)))
            }
        }
        
        renderLineSegments(vertices: vertices, encoder: encoder, lineWidth: 1.0)
    }
    
    private func renderEllipse(center: simd_float2, semiAxes: simd_float2, color: simd_float4,
                              filled: Bool, encoder: MTLRenderCommandEncoder, lineWidth: Float) {
        
        let segments = 64
        var vertices: [ROIVertex] = []
        
        for i in 0...segments {
            let angle = Float(i) * 2.0 * Float.pi / Float(segments)
            let x = center.x + semiAxes.x * cos(angle)
            let y = center.y + semiAxes.y * sin(angle)
            
            vertices.append(ROIVertex(position: simd_float2(x, y), color: color, texCoord: simd_float2(0, 0)))
            
            if i > 0 {
                vertices.append(ROIVertex(position: simd_float2(x, y), color: color, texCoord: simd_float2(0, 0)))
            }
        }
        
        renderLineSegments(vertices: vertices, encoder: encoder, lineWidth: lineWidth)
    }
    
    private func renderMeasurementText(for tool: ROITool, measurement: Measurement<Unit>, encoder: MTLRenderCommandEncoder) {
        // Text rendering would typically be handled by a separate text rendering system
        // For now, we'll just calculate the text position
        
        let textPosition = calculateTextPosition(for: tool)
        let measurementText = measurement.description
        
        // In a full implementation, this would render text using CoreText + Metal
        print("📏 \(tool.name): \(measurementText) at \(textPosition)")
    }
    
    // MARK: - Helper Methods
    private func transformImageToScreen(_ imagePoint: simd_float2) -> simd_float2 {
        let imagePoint4 = simd_float4(imagePoint.x, imagePoint.y, 0, 1)
        let screenPoint4 = imageToScreenTransform * imagePoint4
        return simd_float2(screenPoint4.x, screenPoint4.y)
    }
    
    private func getScreenScale() -> Float {
        // Extract scale from transformation matrix
        let scaleX = length(simd_float2(imageToScreenTransform.columns.0.x, imageToScreenTransform.columns.0.y))
        let scaleY = length(simd_float2(imageToScreenTransform.columns.1.x, imageToScreenTransform.columns.1.y))
        return (scaleX + scaleY) / 2.0
    }
    
    private func calculateTextPosition(for tool: ROITool) -> simd_float2 {
        guard !tool.imageCoordinates.isEmpty else { return simd_float2(0, 0) }
        
        // Calculate centroid of tool coordinates
        let sum = tool.imageCoordinates.reduce(simd_float2(0, 0)) { $0 + $1 }
        let centroid = sum / Float(tool.imageCoordinates.count)
        
        return transformImageToScreen(centroid)
    }
    
    private func matrix_ortho(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
        let ral = right + left
        let rsl = right - left
        let tab = top + bottom
        let tsb = top - bottom
        let fan = far + near
        let fsn = far - near
        
        return simd_float4x4(
            simd_float4(2.0 / rsl, 0.0, 0.0, 0.0),
            simd_float4(0.0, 2.0 / tsb, 0.0, 0.0),
            simd_float4(0.0, 0.0, -2.0 / fsn, 0.0),
            simd_float4(-ral / rsl, -tab / tsb, -fan / fsn, 1.0)
        )
    }
}

// MARK: - Extensions
extension UIColor {
    var components: (Float, Float, Float, Float) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (Float(red), Float(green), Float(blue), Float(alpha))
    }
}

extension simd_float4 {
    init(_ components: (Float, Float, Float, Float)) {
        self.init(components.0, components.1, components.2, components.3)
    }
}

// MARK: - Error Types
enum ROIRenderError: Error {
    case failedToCreateCommandQueue
    case failedToLoadLibrary
    case failedToCreatePipelineState
}