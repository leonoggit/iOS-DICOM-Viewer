import Metal
import MetalKit
import simd

final class MetalDICOMRenderer: NSObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let windowLevelPipelineState: MTLComputePipelineState

    private var pixelBuffer: MTLBuffer?
    private var outputTexture: MTLTexture?

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device")
        }

        self.device = device
        self.commandQueue = commandQueue

        // Load shaders
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertexShader")!
        let fragmentFunction = library.makeFunction(name: "fragmentShader")!
        let windowLevelKernel = library.makeFunction(name: "windowLevelKernel")!

        // Create pipeline states
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        self.windowLevelPipelineState = try! device.makeComputePipelineState(function: windowLevelKernel)

        super.init()
    }

    func renderDICOMImage(_ pixelData: Data,
                         width: Int,
                         height: Int,
                         windowLevel: DICOMImageRenderer.WindowLevel,
                         to drawable: CAMetalDrawable) {

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Create or update pixel buffer
        if pixelBuffer == nil || pixelBuffer!.length != pixelData.count {
            pixelBuffer = device.makeBuffer(bytes: pixelData.withUnsafeBytes { $0.baseAddress! },
                                          length: pixelData.count,
                                          options: .storageModeShared)
        }

        // Create output texture if needed
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r16Uint,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        outputTexture = device.makeTexture(descriptor: textureDescriptor)

        // Apply window/level transformation
        applyWindowLevel(commandBuffer: commandBuffer,
                        inputBuffer: pixelBuffer!,
                        outputTexture: outputTexture!,
                        windowLevel: windowLevel)

        // Render to drawable
        renderToDrawable(commandBuffer: commandBuffer,
                        texture: outputTexture!,
                        drawable: drawable)

        commandBuffer.commit()
    }

    private func applyWindowLevel(commandBuffer: MTLCommandBuffer,
                                 inputBuffer: MTLBuffer,
                                 outputTexture: MTLTexture,
                                 windowLevel: DICOMImageRenderer.WindowLevel) {

        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }

        computeEncoder.setComputePipelineState(windowLevelPipelineState)
        computeEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        computeEncoder.setTexture(outputTexture, index: 0)

        var params = WindowLevelParams(
            window: windowLevel.window,
            level: windowLevel.level,
            rescaleSlope: 1.0,
            rescaleIntercept: 0.0
        )
        computeEncoder.setBytes(&params, length: MemoryLayout<WindowLevelParams>.size, index: 1)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )

        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
    }

    private func renderToDrawable(commandBuffer: MTLCommandBuffer,
                                 texture: MTLTexture,
                                 drawable: CAMetalDrawable) {

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(texture, index: 0)

        // Draw a full-screen quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
    }
}

// Metal shader structures
struct WindowLevelParams {
    let window: Float
    let level: Float
    let rescaleSlope: Float
    let rescaleIntercept: Float
}

struct WindowLevel {
    let window: Float
    let level: Float
    let rescaleSlope: Float
    let rescaleIntercept: Float

    static let `default` = WindowLevel(window: 400, level: 40, rescaleSlope: 1, rescaleIntercept: 0)
    static let lung = WindowLevel(window: 1500, level: -600, rescaleSlope: 1, rescaleIntercept: -1024)
    static let bone = WindowLevel(window: 2000, level: 300, rescaleSlope: 1, rescaleIntercept: -1024)
    static let brain = WindowLevel(window: 100, level: 50, rescaleSlope: 1, rescaleIntercept: -1024)
    static let abdomen = WindowLevel(window: 350, level: 40, rescaleSlope: 1, rescaleIntercept: -1024)
}

// MARK: - MTKViewDelegate
extension MetalDICOMRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes
    }

    func draw(in view: MTKView) {
        // This would be called if using MTKView
        // For now, we're using direct rendering to CAMetalDrawable
    }
}

// Extension to integrate with existing renderer
extension DICOMImageRenderer {
    private static let metalRenderer = MetalDICOMRenderer()

    func renderWithMetal(from pixelData: PixelData,
                        windowLevel: DICOMImageRenderer.WindowLevel,
                        to layer: CAMetalLayer) -> Bool {

        guard let drawable = layer.nextDrawable() else {
            return false
        }

        DICOMImageRenderer.metalRenderer.renderDICOMImage(
            Data(pixelData.data.flatMap {
                withUnsafeBytes(of: $0) { Array($0) }
            }),
            width: pixelData.width,
            height: pixelData.height,
            windowLevel: windowLevel,
            to: drawable
        )

        return true
    }
}
