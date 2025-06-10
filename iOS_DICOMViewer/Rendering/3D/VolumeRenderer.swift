import Metal
import MetalKit
import simd

final class VolumeRenderer: NSObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private let complianceManager = ClinicalComplianceManager.shared
    
    // Pipeline states
    private var volumeRenderPipeline: MTLComputePipelineState!
    private var rayCastPipeline: MTLComputePipelineState!
    
    // Volume data
    private var volumeTexture: MTLTexture?
    private var transferFunctionTexture: MTLTexture?
    
    // Rendering parameters
    private var renderParams = VolumeRenderParams()
    
    struct VolumeRenderParams {
        var modelMatrix = matrix_identity_float4x4
        var viewMatrix = matrix_identity_float4x4
        var projectionMatrix = matrix_identity_float4x4
        var cameraPosition = simd_float3(0, 0, -2)
        var volumeSize = simd_float3(1, 1, 1)
        var stepSize: Float = 0.01
        var transferFunction = TransferFunction.defaultCT
    }
    
    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            fatalError("Metal initialization failed")
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.library = library
        
        super.init()
        
        setupPipelines()
    }
    
    
    private func setupPipelines() {
        // Volume rendering pipeline
        guard let volumeFunction = library.makeFunction(name: "volumeRaycast"),
              let rayCastFunction = library.makeFunction(name: "generateRays") else {
            fatalError("Failed to load Metal functions")
        }
        
        do {
            volumeRenderPipeline = try device.makeComputePipelineState(function: volumeFunction)
            rayCastPipeline = try device.makeComputePipelineState(function: rayCastFunction)
        } catch {
            fatalError("Failed to create pipeline states: \(error)")
        }
    }
    
    func loadVolume(from series: DICOMSeries) async throws {
        // Sort instances by position
        let sortedInstances = series.sortedBySlicePosition
        
        guard !sortedInstances.isEmpty else {
            throw DICOMError.invalidFile(reason: .notDICOM)
        }
        
        // Get volume dimensions
        let firstInstance = sortedInstances[0]
        let width = firstInstance.metadata.columns
        let height = firstInstance.metadata.rows
        let depth = sortedInstances.count
        
        // Create 3D texture
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.pixelFormat = .r16Uint
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.depth = depth
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw DICOMError.memoryAllocationFailed(requiredBytes: Int64(width * height * depth * 2))
        }
        
        // Load slices into 3D texture
        for (index, instance) in sortedInstances.enumerated() {
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
                    bytesPerRow: width * 2,
                    bytesPerImage: width * height * 2
                )
            }
        }
        
        self.volumeTexture = texture
        
        // Update render parameters
        renderParams.volumeSize = simd_float3(
            Float(width),
            Float(height),
            Float(depth)
        )
    }
    
    
    func render(to drawable: CAMetalDrawable, viewportSize: CGSize) {
        complianceManager.measureRenderingPerformance(operation: "3D Volume Rendering") {
            performRender(to: drawable, viewportSize: viewportSize)
        }
    }
    
    private func performRender(to drawable: CAMetalDrawable, viewportSize: CGSize) {
        guard let volumeTexture = volumeTexture,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        // Create output texture
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: drawable.texture.pixelFormat,
            width: Int(viewportSize.width),
            height: Int(viewportSize.height),
            mipmapped: false
        )
        outputDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let outputTexture = device.makeTexture(descriptor: outputDescriptor) else {
            return
        }
        
        // Setup compute encoder
        computeEncoder.setComputePipelineState(volumeRenderPipeline)
        computeEncoder.setTexture(volumeTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        computeEncoder.setTexture(transferFunctionTexture, index: 2)
        
        var params = renderParams
        computeEncoder.setBytes(&params, length: MemoryLayout<VolumeRenderParams>.size, index: 0)
        
        // Dispatch threads
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        // Blit to drawable
        if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.copy(from: outputTexture, to: drawable.texture)
            blitEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func updateCamera(position: simd_float3, target: simd_float3, up: simd_float3) {
        renderParams.cameraPosition = position
        renderParams.viewMatrix = matrix_look_at(position, target, up)
    }
    
    func updateTransferFunction(_ transferFunction: TransferFunction) {
        renderParams.transferFunction = transferFunction
        transferFunctionTexture = createTransferFunctionTexture(transferFunction)
    }
    
    private func createTransferFunctionTexture(_ transferFunction: TransferFunction) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture1DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 256,
            mipmapped: false
        )
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        // Generate transfer function data
        var data = [UInt8](repeating: 0, count: 256 * 4)
        for i in 0..<256 {
            let value = Float(i) / 255.0
            let color = transferFunction.evaluate(at: value)
            data[i * 4 + 0] = UInt8(color.x * 255)
            data[i * 4 + 1] = UInt8(color.y * 255)
            data[i * 4 + 2] = UInt8(color.z * 255)
            data[i * 4 + 3] = UInt8(color.w * 255)
        }
        
        texture.replace(
            region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                            size: MTLSize(width: 256, height: 1, depth: 1)),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: 256 * 4
        )
        
        return texture
    }
}
// Transfer function for volume rendering
struct TransferFunction {
    struct ColorPoint {
        let value: Float
        let color: SIMD4<Float>
    }
    
    var points: [ColorPoint]
    
    func evaluate(at value: Float) -> SIMD4<Float> {
        // Linear interpolation between color points
        guard !points.isEmpty else {
            return SIMD4<Float>(0, 0, 0, 0)
        }
        
        if value <= points.first!.value {
            return points.first!.color
        }
        
        if value >= points.last!.value {
            return points.last!.color
        }
        
        for i in 1..<points.count {
            if value <= points[i].value {
                let t = (value - points[i-1].value) / (points[i].value - points[i-1].value)
                return mix(points[i-1].color, points[i].color, t: t)
            }
        }
        
        return points.last!.color
    }
    
    static let defaultCT = TransferFunction(points: [
        ColorPoint(value: 0.0, color: SIMD4<Float>(0, 0, 0, 0)),
        ColorPoint(value: 0.2, color: SIMD4<Float>(0.8, 0.2, 0.2, 0.1)),
        ColorPoint(value: 0.4, color: SIMD4<Float>(1.0, 0.8, 0.6, 0.4)),
        ColorPoint(value: 0.8, color: SIMD4<Float>(1.0, 1.0, 1.0, 0.8)),
        ColorPoint(value: 1.0, color: SIMD4<Float>(1.0, 1.0, 1.0, 1.0))
    ])
    
    static let defaultMR = TransferFunction(points: [
        ColorPoint(value: 0.0, color: SIMD4<Float>(0, 0, 0, 0)),
        ColorPoint(value: 0.3, color: SIMD4<Float>(0.3, 0.1, 0.1, 0.2)),
        ColorPoint(value: 0.5, color: SIMD4<Float>(0.8, 0.4, 0.4, 0.5)),
        ColorPoint(value: 0.7, color: SIMD4<Float>(1.0, 0.8, 0.8, 0.8)),
        ColorPoint(value: 1.0, color: SIMD4<Float>(1.0, 1.0, 1.0, 1.0))
    ])
}

// Helper functions
func matrix_look_at(_ eye: simd_float3, _ target: simd_float3, _ up: simd_float3) -> simd_float4x4 {
    let z = normalize(eye - target)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    
    return simd_float4x4(
        simd_float4(x.x, y.x, z.x, 0),
        simd_float4(x.y, y.y, z.y, 0),
        simd_float4(x.z, y.z, z.z, 0),
        simd_float4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
    )
}

func mix(_ a: SIMD4<Float>, _ b: SIMD4<Float>, t: Float) -> SIMD4<Float> {
    return a + (b - a) * t
}
