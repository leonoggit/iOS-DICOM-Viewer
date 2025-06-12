# iOS DICOM Viewer - Implementation Guide

## 📋 Quick Reference

This guide provides specific implementation details, methods, and logic for the iOS DICOM Viewer. Use this as a reference for future implementations and extensions.

## 🔧 Core Implementation Methods

### 1. DICOM File Loading and Parsing

#### DCMTKBridge Integration
```objective-c
// DCMTKBridge.mm - Core DCMTK Integration
@implementation DCMTKBridge {
    DcmFileFormat* fileformat;
    DcmDataset* dataset;
    OFCondition status;
}

- (BOOL)loadDICOMFile:(NSString *)filePath {
    const char* cPath = [filePath UTF8String];
    fileformat = new DcmFileFormat();
    status = fileformat->loadFile(cPath);
    
    if (status.good()) {
        dataset = fileformat->getDataset();
        return YES;
    }
    return NO;
}

- (NSString *)getStringValue:(DCMTKTag)tag {
    OFString stringValue;
    DcmTag dcmTag(tag.group, tag.element);
    
    if (dataset->findAndGetOFString(dcmTag, stringValue).good()) {
        return [NSString stringWithUTF8String:stringValue.c_str()];
    }
    return nil;
}

- (NSData *)getPixelData {
    const Uint8* pixelData = nullptr;
    unsigned long length = 0;
    
    if (dataset->findAndGetUint8Array(DCM_PixelData, pixelData, &length).good()) {
        return [NSData dataWithBytes:pixelData length:length];
    }
    return nil;
}
```

#### Swift Parser Implementation
```swift
class DICOMParser {
    private let dcmtkBridge = DCMTKBridge()
    
    func parseDICOMFile(_ filePath: String) throws -> DICOMInstance {
        // 1. Load file with DCMTK
        guard dcmtkBridge.loadDICOMFile(filePath) else {
            throw DICOMError.failedToLoadFile
        }
        
        // 2. Extract metadata
        let metadata = try extractMetadata()
        
        // 3. Extract pixel data
        let pixelData = try extractPixelData()
        
        // 4. Create instance
        let instance = DICOMInstance(metadata: metadata)
        instance.pixelData = pixelData
        
        return instance
    }
    
    private func extractMetadata() throws -> DICOMMetadata {
        let metadata = DICOMMetadata()
        
        // Essential DICOM tags
        metadata.sopInstanceUID = dcmtkBridge.getStringValue(for: DCMTKTag.sopInstanceUID)
        metadata.sopClassUID = dcmtkBridge.getStringValue(for: DCMTKTag.sopClassUID)
        metadata.studyInstanceUID = dcmtkBridge.getStringValue(for: DCMTKTag.studyInstanceUID)
        metadata.seriesInstanceUID = dcmtkBridge.getStringValue(for: DCMTKTag.seriesInstanceUID)
        
        // Image properties
        metadata.rows = Int(dcmtkBridge.getIntValue(for: DCMTKTag.rows))
        metadata.columns = Int(dcmtkBridge.getIntValue(for: DCMTKTag.columns))
        metadata.bitsStored = Int(dcmtkBridge.getIntValue(for: DCMTKTag.bitsStored))
        metadata.bitsAllocated = Int(dcmtkBridge.getIntValue(for: DCMTKTag.bitsAllocated))
        
        // Geometric information
        metadata.pixelSpacing = dcmtkBridge.getDoubleArrayValue(for: DCMTKTag.pixelSpacing)
        metadata.sliceThickness = dcmtkBridge.getDoubleValue(for: DCMTKTag.sliceThickness)
        metadata.imagePositionPatient = dcmtkBridge.getDoubleArrayValue(for: DCMTKTag.imagePositionPatient)
        metadata.imageOrientationPatient = dcmtkBridge.getDoubleArrayValue(for: DCMTKTag.imageOrientationPatient)
        
        // Display parameters
        metadata.windowCenter = dcmtkBridge.getDoubleValue(for: DCMTKTag.windowCenter)
        metadata.windowWidth = dcmtkBridge.getDoubleValue(for: DCMTKTag.windowWidth)
        
        return metadata
    }
}
```

### 2. Metal Rendering Pipeline

#### Core Renderer Setup
```swift
class DICOMImageRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private var renderPipelineState: MTLRenderPipelineState?
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError.noMetalDevice
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.failedToCreateCommandQueue
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            throw RendererError.failedToCreateLibrary
        }
        self.library = library
        
        try setupRenderPipeline()
    }
    
    private func setupRenderPipeline() throws {
        let vertexFunction = library.makeFunction(name: "dicomVertex")
        let fragmentFunction = library.makeFunction(name: "dicomFragment")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
}
```

#### Texture Creation
```swift
extension DICOMImageRenderer {
    func createTexture(from pixelData: Data, width: Int, height: Int, bitsPerPixel: Int) throws -> MTLTexture {
        let pixelFormat: MTLPixelFormat = bitsPerPixel == 8 ? .r8Unorm : .r16Unorm
        
        let descriptor = MTLTextureDescriptor.texture2D(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw RendererError.failedToCreateTexture
        }
        
        let bytesPerRow = width * (bitsPerPixel / 8)
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixelData.withUnsafeBytes { $0.baseAddress! },
            bytesPerRow: bytesPerRow
        )
        
        return texture
    }
}
```

### 3. Volume Rendering Implementation

#### 3D Volume Renderer
```swift
class VolumeRenderer {
    enum RenderMode {
        case mip, isosurface, dvr
    }
    
    private var volumeTexture: MTLTexture?
    private var transferFunctionTexture: MTLTexture?
    
    func renderVolume(_ volumeData: VolumeData, 
                     renderMode: RenderMode,
                     to drawable: CAMetalDrawable) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = createRenderPassDescriptor(for: drawable),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Set render pipeline based on mode
        let pipelineState = selectPipelineState(for: renderMode)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set textures and uniforms
        renderEncoder.setFragmentTexture(volumeTexture, index: 0)
        renderEncoder.setFragmentTexture(transferFunctionTexture, index: 1)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        
        // Draw full-screen quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func selectPipelineState(for mode: RenderMode) -> MTLRenderPipelineState {
        switch mode {
        case .mip: return mipRenderPipeline!
        case .isosurface: return isosurfaceRenderPipeline!
        case .dvr: return dvrRenderPipeline!
        }
    }
}
```

#### Volume Shaders
```metal
// Volume rendering fragment shader
fragment float4 volumeFragment(VolumeVertexOut in [[stage_in]],
                              texture3d<float> volumeTexture [[texture(0)]],
                              texture2d<float> transferFunction [[texture(1)]],
                              constant VolumeUniforms& uniforms [[buffer(0)]]) {
    
    constexpr sampler volumeSampler(mag_filter::linear, min_filter::linear);
    constexpr sampler tfSampler(mag_filter::linear, min_filter::linear);
    
    float3 rayDirection = normalize(in.worldPosition - uniforms.cameraPosition);
    float3 rayStart = in.worldPosition;
    
    float4 accumulatedColor = float4(0.0);
    float transmittance = 1.0;
    
    // Ray marching through volume
    for (int i = 0; i < uniforms.maxSteps; i++) {
        float3 samplePos = rayStart + rayDirection * (float(i) * uniforms.stepSize);
        
        // Sample volume
        float density = volumeTexture.sample(volumeSampler, samplePos).r;
        
        // Apply transfer function
        float4 sampleColor = transferFunction.sample(tfSampler, float2(density, 0.5));
        
        // Alpha compositing
        accumulatedColor.rgb += sampleColor.rgb * sampleColor.a * transmittance;
        transmittance *= (1.0 - sampleColor.a);
        
        if (transmittance < 0.01) break; // Early ray termination
    }
    
    accumulatedColor.a = 1.0 - transmittance;
    return accumulatedColor;
}
```

### 4. Multi-Planar Reconstruction (MPR)

#### MPR Implementation
```swift
class MPRRenderer {
    private var axialTexture: MTLTexture?
    private var sagittalTexture: MTLTexture?
    private var coronalTexture: MTLTexture?
    
    func renderMPRView(_ plane: MPRPlane,
                      sliceIndex: Int,
                      crosshairPosition: simd_float3,
                      to drawable: CAMetalDrawable) {
        
        let sliceTexture = extractSlice(plane: plane, index: sliceIndex)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = createRenderPassDescriptor(for: drawable),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Render slice
        renderEncoder.setRenderPipelineState(mprRenderPipeline!)
        renderEncoder.setFragmentTexture(sliceTexture, index: 0)
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        
        // Draw slice quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        // Render crosshairs if enabled
        if showCrosshairs {
            renderCrosshairs(at: crosshairPosition, renderEncoder: renderEncoder)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func extractSlice(plane: MPRPlane, index: Int) -> MTLTexture {
        // Extract 2D slice from 3D volume based on plane orientation
        switch plane {
        case .axial:
            return extractAxialSlice(at: index)
        case .sagittal:
            return extractSagittalSlice(at: index)
        case .coronal:
            return extractCoronalSlice(at: index)
        }
    }
}
```

### 5. ROI Tools Implementation

#### Base ROI Tool Protocol
```swift
protocol ROITool: AnyObject, Identifiable {
    var id: UUID { get }
    var name: String { get }
    var color: UIColor { get set }
    var pixelSpacing: simd_float2 { get set }
    var points: [simd_float2] { get }
    var worldPoints: [simd_float3] { get }
    var isComplete: Bool { get }
    var creationDate: Date { get }
    var measurement: Measurement<UnitLength>? { get }
    var statistics: ROIStatistics? { get set }
    
    func addPoint(_ point: simd_float2, worldPoint: simd_float3)
    func removeLastPoint()
    func contains(point: simd_float2) -> Bool
    func calculateMeasurement() -> Measurement<UnitLength>?
    func calculateStatistics(pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics?
}
```

#### Linear ROI Tool
```swift
class LinearROITool: ROITool {
    let id = UUID()
    let name = "Linear Measurement"
    var color = UIColor.systemBlue
    var pixelSpacing = simd_float2(1.0, 1.0)
    var points: [simd_float2] = []
    var worldPoints: [simd_float3] = []
    var statistics: ROIStatistics?
    let creationDate = Date()
    
    var isComplete: Bool {
        return points.count >= 2
    }
    
    var measurement: Measurement<UnitLength>? {
        return calculateMeasurement()
    }
    
    func addPoint(_ point: simd_float2, worldPoint: simd_float3) {
        if points.count < 2 {
            points.append(point)
            worldPoints.append(worldPoint)
        }
    }
    
    func calculateMeasurement() -> Measurement<UnitLength>? {
        guard points.count == 2 else { return nil }
        
        let distance = simd_distance(points[0], points[1])
        let realWorldDistance = distance * pixelSpacing.x // Assuming isotropic spacing
        
        return Measurement(value: Double(realWorldDistance), unit: UnitLength.millimeters)
    }
    
    func contains(point: simd_float2) -> Bool {
        guard points.count == 2 else { return false }
        
        // Calculate distance from point to line segment
        let distance = distanceFromPointToLineSegment(
            point: point,
            lineStart: points[0],
            lineEnd: points[1]
        )
        
        return distance < 5.0 // 5 pixel tolerance
    }
    
    private func distanceFromPointToLineSegment(point: simd_float2, 
                                              lineStart: simd_float2, 
                                              lineEnd: simd_float2) -> Float {
        let lineVec = lineEnd - lineStart
        let pointVec = point - lineStart
        
        let lineLength = simd_length(lineVec)
        guard lineLength > 0 else { return simd_distance(point, lineStart) }
        
        let t = max(0, min(1, simd_dot(pointVec, lineVec) / (lineLength * lineLength)))
        let projection = lineStart + t * lineVec
        
        return simd_distance(point, projection)
    }
}
```

#### Circular ROI Tool
```swift
class CircularROITool: ROITool {
    var center: simd_float2? {
        return points.first
    }
    
    var radius: Float {
        guard points.count == 2 else { return 0 }
        return simd_distance(points[0], points[1])
    }
    
    func calculateMeasurement() -> Measurement<UnitLength>? {
        guard isComplete else { return nil }
        
        let radiusInMM = radius * pixelSpacing.x
        let area = Float.pi * radiusInMM * radiusInMM
        
        return Measurement(value: Double(area), unit: UnitArea.squareMillimeters)
    }
    
    func calculateStatistics(pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics? {
        guard isComplete, let center = center else { return nil }
        
        let bytesPerPixel = metadata.bitsStored / 8
        var pixelValues: [Double] = []
        var pixelCount = 0
        
        // Iterate through circular region
        let radiusSquared = radius * radius
        for y in Int(center.y - radius)...Int(center.y + radius) {
            for x in Int(center.x - radius)...Int(center.x + radius) {
                let dx = Float(x) - center.x
                let dy = Float(y) - center.y
                
                if (dx * dx + dy * dy) <= radiusSquared {
                    if x >= 0 && x < metadata.columns && y >= 0 && y < metadata.rows {
                        let pixelIndex = y * metadata.columns + x
                        let dataIndex = pixelIndex * bytesPerPixel
                        
                        if dataIndex + bytesPerPixel <= pixelData.count {
                            let pixelValue = extractPixelValue(from: pixelData, 
                                                             at: dataIndex, 
                                                             bytesPerPixel: bytesPerPixel)
                            pixelValues.append(pixelValue)
                            pixelCount += 1
                        }
                    }
                }
            }
        }
        
        return calculateStatisticsFromValues(pixelValues, pixelCount: pixelCount)
    }
}
```

### 6. Segmentation Rendering

#### Segmentation Renderer
```swift
class SegmentationRenderer {
    private var segmentRenderPipeline: MTLRenderPipelineState?
    private var overlayRenderPipeline: MTLRenderPipelineState?
    private var colorLookupTexture: MTLTexture?
    
    func renderSegmentation(_ segmentation: DICOMSegmentation,
                           to drawable: CAMetalDrawable,
                           opacity: Float = 0.5) {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = createRenderPassDescriptor(for: drawable) else {
            return
        }
        
        // Render each visible segment
        for segment in segmentation.segments where segment.isVisible {
            renderSegment(segment, 
                         segmentation: segmentation,
                         commandBuffer: commandBuffer,
                         renderPassDescriptor: renderPassDescriptor,
                         opacity: opacity)
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func renderSegment(_ segment: SegmentationSegment,
                              segmentation: DICOMSegmentation,
                              commandBuffer: MTLCommandBuffer,
                              renderPassDescriptor: MTLRenderPassDescriptor,
                              opacity: Float) {
        
        let segmentTexture = createTextureFromSegment(segment, segmentation: segmentation)
        
        guard let texture = segmentTexture,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        let pipeline = segment.opacity < 1.0 ? overlayRenderPipeline : segmentRenderPipeline
        renderEncoder.setRenderPipelineState(pipeline!)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentTexture(colorLookupTexture, index: 1)
        
        // Draw full-screen quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
    }
}
```

### 7. RT Structure Set Rendering

#### RT Structure Renderer
```swift
class RTStructureRenderer {
    private var contourRenderPipeline: MTLRenderPipelineState?
    private var filledContourPipeline: MTLRenderPipelineState?
    
    func renderStructureSet(_ structureSet: RTStructureSet,
                           to drawable: CAMetalDrawable,
                           renderMode: RenderMode = .both) {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = createRenderPassDescriptor(for: drawable) else {
            return
        }
        
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
    
    private func generateMeshFromContour(_ roiContour: ROIContour) -> ContourMesh {
        var allVertices: [simd_float3] = []
        var allIndices: [UInt32] = []
        var indexOffset: UInt32 = 0
        
        // Process each contour in the sequence
        for contourData in roiContour.contourSequence {
            let points = contourData.points3D
            
            if contourData.contourGeometricType.isClosed && points.count >= 3 {
                // Triangulate closed contour using fan triangulation
                let (vertices, indices) = triangulateContour(points)
                allVertices.append(contentsOf: vertices)
                
                let adjustedIndices = indices.map { $0 + indexOffset }
                allIndices.append(contentsOf: adjustedIndices)
                indexOffset += UInt32(vertices.count)
            }
        }
        
        return ContourMesh(vertices: allVertices, indices: allIndices, color: roiContour.displayColor)
    }
}
```

### 8. Memory Management Strategies

#### iOS Memory Optimization
```swift
class DICOMMemoryManager {
    static let shared = DICOMMemoryManager()
    
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private let maxMemoryUsage: Int = 200 * 1024 * 1024 // 200MB
    
    func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        
        memoryPressureSource?.resume()
    }
    
    func handleMemoryPressure() {
        // 1. Clear texture caches
        TextureCache.shared.clearCache()
        
        // 2. Compress inactive segmentations
        for segmentation in activeSegmentations {
            segmentation.handleMemoryPressure()
        }
        
        // 3. Release non-visible contours
        for structureSet in activeStructureSets {
            structureSet.handleMemoryPressure()
        }
        
        // 4. Force garbage collection
        autoreleasepool {
            // Trigger autoreleasepool cleanup
        }
    }
    
    func checkMemoryPressure() {
        let memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsage = Int(memoryInfo.resident_size)
            if memoryUsage > maxMemoryUsage {
                handleMemoryPressure()
            }
        }
    }
}
```

#### Texture Cache Implementation
```swift
class TextureCache {
    static let shared = TextureCache()
    
    private var cache: NSCache<NSString, MTLTexture>
    private let maxCacheSize = 50
    
    init() {
        cache = NSCache<NSString, MTLTexture>()
        cache.countLimit = maxCacheSize
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    func texture(for key: String) -> MTLTexture? {
        return cache.object(forKey: key as NSString)
    }
    
    func setTexture(_ texture: MTLTexture, for key: String) {
        let cost = calculateTextureCost(texture)
        cache.setObject(texture, forKey: key as NSString, cost: cost)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    private func calculateTextureCost(_ texture: MTLTexture) -> Int {
        return texture.width * texture.height * 4 // Assuming 4 bytes per pixel
    }
}
```

### 9. Error Handling Patterns

#### DICOM Error Types
```swift
enum DICOMError: Error, LocalizedError {
    case failedToLoadFile
    case invalidFileFormat
    case missingRequiredTag(String)
    case invalidSOPClass(String)
    case missingPixelData
    case invalidImageDimensions
    case operationCancelled
    case memoryError
    case renderingError(String)
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadFile:
            return "Failed to load DICOM file"
        case .invalidFileFormat:
            return "Invalid DICOM file format"
        case .missingRequiredTag(let tag):
            return "Missing required DICOM tag: \(tag)"
        case .invalidSOPClass(let sopClass):
            return "Invalid SOP Class: \(sopClass)"
        case .missingPixelData:
            return "DICOM file missing pixel data"
        case .invalidImageDimensions:
            return "Invalid image dimensions"
        case .operationCancelled:
            return "Operation was cancelled"
        case .memoryError:
            return "Memory allocation error"
        case .renderingError(let message):
            return "Rendering error: \(message)"
        }
    }
}
```

#### Error Recovery Strategies
```swift
extension DICOMParser {
    func parseWithFallback(_ filePath: String) -> Result<DICOMInstance, DICOMError> {
        do {
            let instance = try parseDICOMFile(filePath)
            return .success(instance)
        } catch DICOMError.missingPixelData {
            // Try alternative pixel data extraction
            if let instance = tryAlternativePixelDataExtraction(filePath) {
                return .success(instance)
            }
            return .failure(.missingPixelData)
        } catch {
            return .failure(error as? DICOMError ?? .invalidFileFormat)
        }
    }
    
    private func tryAlternativePixelDataExtraction(_ filePath: String) -> DICOMInstance? {
        // Implement fallback pixel data extraction
        return nil
    }
}
```

This implementation guide provides concrete code examples and patterns used throughout the iOS DICOM Viewer. Use these as references for implementing similar functionality or extending the existing codebase.