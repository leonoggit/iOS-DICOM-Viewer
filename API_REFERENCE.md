# iOS DICOM Viewer - API Reference

## 📚 Complete API Documentation

This reference documents all public APIs, methods, and interfaces in the iOS DICOM Viewer for future implementations.

## 🔧 Core APIs

### DICOMServiceManager
```swift
public class DICOMServiceManager {
    public static let shared: DICOMServiceManager
    
    // MARK: - File Management
    public func importDICOMFile(at url: URL) async throws -> DICOMInstance
    public func importDICOMFiles(at urls: [URL]) async throws -> [DICOMInstance]
    public func loadStudy(studyInstanceUID: String) async throws -> DICOMStudy
    public func loadSeries(seriesInstanceUID: String) async throws -> DICOMSeries
    
    // MARK: - Rendering
    public func renderInstance(_ instance: DICOMInstance, 
                              to view: MTKView,
                              with parameters: RenderingParameters) throws
    
    // MARK: - Cache Management
    public func clearCache()
    public func getCacheSize() -> Int
    public func setCacheLimit(_ limit: Int)
    
    // MARK: - Memory Management
    public func handleMemoryPressure()
    public func getMemoryUsage() -> MemoryUsageInfo
}
```

### DICOMParser
```swift
public class DICOMParser {
    // MARK: - Initialization
    public init()
    
    // MARK: - Parsing Methods
    public func parseDICOMFile(_ filePath: String) throws -> DICOMInstance
    public func parseDICOMData(_ data: Data) throws -> DICOMInstance
    public func parseMetadataOnly(_ filePath: String) throws -> DICOMMetadata
    
    // MARK: - Validation
    public func validateDICOMFile(_ filePath: String) -> Bool
    public func getSupportedSOPClasses() -> [String]
    
    // MARK: - Progress Tracking
    public func parseWithProgress(_ filePath: String, 
                                 progressHandler: @escaping (Float) -> Void) async throws -> DICOMInstance
    
    // MARK: - Error Recovery
    public func parseWithFallback(_ filePath: String) -> Result<DICOMInstance, DICOMError>
}
```

### DICOMSegmentationParser
```swift
public class DICOMSegmentationParser {
    // MARK: - Initialization
    public init()
    
    // MARK: - Parsing Methods
    public func parseSegmentation(from filePath: String) throws -> DICOMSegmentation
    public func parseSegmentation(from data: Data) throws -> DICOMSegmentation
    
    // MARK: - Control
    public func cancelParsing()
    
    // MARK: - Validation
    public func validateSegmentationFile(_ filePath: String) -> Bool
    
    // MARK: - Memory Optimization
    public func setMemoryOptimizationLevel(_ level: MemoryOptimizationLevel)
}
```

### RTStructureSetParser
```swift
public class RTStructureSetParser {
    // MARK: - Initialization
    public init()
    
    // MARK: - Parsing Methods
    public func parseStructureSet(from filePath: String) throws -> RTStructureSet
    public func parseStructureSet(from data: Data) throws -> RTStructureSet
    
    // MARK: - Control
    public func cancelParsing()
    
    // MARK: - Optimization
    public func setContourSimplificationThreshold(_ threshold: Int)
    public func enableContourSimplification(_ enabled: Bool)
}
```

## 🎨 Rendering APIs

### DICOMImageRenderer
```swift
public class DICOMImageRenderer {
    // MARK: - Initialization
    public init(device: MTLDevice) throws
    
    // MARK: - Rendering
    public func renderDICOMImage(_ instance: DICOMInstance,
                                to drawable: CAMetalDrawable,
                                with parameters: ImageRenderingParameters) throws
    
    public func renderDICOMImageToTexture(_ instance: DICOMInstance,
                                         size: CGSize) throws -> MTLTexture
    
    // MARK: - Window/Level
    public func applyWindowLevel(center: Double, width: Double, to instance: DICOMInstance)
    public func resetWindowLevel(for instance: DICOMInstance)
    
    // MARK: - Transforms
    public func setImageTransform(_ transform: CGAffineTransform)
    public func resetImageTransform()
    
    // MARK: - LUT
    public func applyLUT(_ lut: LookupTable, to instance: DICOMInstance)
    public func resetLUT(for instance: DICOMInstance)
}
```

### VolumeRenderer
```swift
public class VolumeRenderer {
    // MARK: - Initialization
    public init(device: MTLDevice) throws
    
    // MARK: - Volume Rendering
    public func renderVolume(_ volumeData: VolumeData,
                           renderMode: VolumeRenderMode,
                           to drawable: CAMetalDrawable,
                           with parameters: VolumeRenderingParameters) throws
    
    // MARK: - Render Modes
    public enum VolumeRenderMode {
        case mip, isosurface, dvr, composite
    }
    
    // MARK: - Transfer Function
    public func setTransferFunction(_ transferFunction: TransferFunction)
    public func getTransferFunction() -> TransferFunction
    
    // MARK: - Camera Control
    public func setCameraPosition(_ position: simd_float3)
    public func setCameraTarget(_ target: simd_float3)
    public func setCameraUp(_ up: simd_float3)
    
    // MARK: - Quality Control
    public func setRenderQuality(_ quality: RenderQuality)
    public func setStepSize(_ stepSize: Float)
    public func setMaxSteps(_ maxSteps: Int)
}
```

### MPRRenderer
```swift
public class MPRRenderer {
    // MARK: - Initialization
    public init(device: MTLDevice) throws
    
    // MARK: - MPR Planes
    public enum MPRPlane: CaseIterable {
        case axial, sagittal, coronal
        
        public var normal: simd_float3 { get }
        public var displayName: String { get }
    }
    
    // MARK: - Rendering
    public func renderMPRPlane(_ plane: MPRPlane,
                              sliceIndex: Int,
                              volumeData: VolumeData,
                              to drawable: CAMetalDrawable,
                              with parameters: MPRRenderingParameters) throws
    
    // MARK: - Crosshairs
    public func enableCrosshairs(_ enabled: Bool)
    public func setCrosshairPosition(_ position: simd_float3)
    public func synchronizeCrosshairs(worldPosition: simd_float3)
    
    // MARK: - Slice Navigation
    public func getSliceCount(for plane: MPRPlane, volumeData: VolumeData) -> Int
    public func getSliceThickness(for plane: MPRPlane, volumeData: VolumeData) -> Float
    
    // MARK: - Oblique MPR
    public func renderObliquePlane(normal: simd_float3,
                                  point: simd_float3,
                                  volumeData: VolumeData,
                                  to drawable: CAMetalDrawable) throws
}
```

### SegmentationRenderer
```swift
public class SegmentationRenderer {
    // MARK: - Initialization
    public init(device: MTLDevice) throws
    
    // MARK: - Rendering
    public func renderSegmentation(_ segmentation: DICOMSegmentation,
                                  to drawable: CAMetalDrawable,
                                  viewportSize: CGSize,
                                  transform: simd_float4x4,
                                  opacity: Float = 0.5,
                                  showContours: Bool = true) throws
    
    // MARK: - Blend Modes
    public enum BlendMode: Int32 {
        case overlay = 0
        case multiply = 1
        case screen = 2
        case colorBurn = 3
    }
    
    public func setBlendMode(_ mode: BlendMode)
    
    // MARK: - Statistics
    public func computeStatistics(for segment: SegmentationSegment,
                                 imageData: Data,
                                 metadata: DICOMMetadata) -> ROIStatistics?
    
    // MARK: - Memory Management
    public func preloadSegmentation(_ segmentation: DICOMSegmentation)
    public func updateSegmentVisibility(_ segmentation: DICOMSegmentation,
                                       segmentNumber: UInt16,
                                       isVisible: Bool,
                                       opacity: Float)
    public func handleMemoryPressure()
}
```

### RTStructureRenderer
```swift
public class RTStructureRenderer {
    // MARK: - Initialization
    public init(device: MTLDevice) throws
    
    // MARK: - Render Modes
    public enum RenderMode: Int32 {
        case wireframe = 0
        case filled = 1
        case both = 2
        case volume = 3
    }
    
    // MARK: - Rendering
    public func renderStructureSet(_ structureSet: RTStructureSet,
                                  to drawable: CAMetalDrawable,
                                  viewportSize: CGSize,
                                  projectionMatrix: simd_float4x4,
                                  viewMatrix: simd_float4x4,
                                  renderMode: RenderMode = .both,
                                  opacity: Float = 0.7) throws
    
    // MARK: - MPR Integration
    public func renderInMPRPlane(_ structureSet: RTStructureSet,
                                planeNormal: simd_float3,
                                planePoint: simd_float3,
                                to drawable: CAMetalDrawable,
                                viewportSize: CGSize,
                                transform: simd_float4x4) throws
    
    // MARK: - Interaction
    public func distanceToNearestContour(_ structureSet: RTStructureSet,
                                        point: simd_float3) -> Float
    
    // MARK: - Memory Management
    public func preloadStructureSet(_ structureSet: RTStructureSet)
    public func handleMemoryPressure()
}
```

## 🎯 ROI Tools APIs

### ROIManager
```swift
public class ROIManager: ObservableObject {
    public static let shared: ROIManager
    
    // MARK: - Tool Types
    public enum ROIToolType: CaseIterable {
        case linear, circular, rectangular, polygon, angle, elliptical
        
        public var displayName: String { get }
        public var icon: String { get }
    }
    
    // MARK: - State Properties
    @Published public var activeTools: [ROITool]
    @Published public var selectedTool: ROITool?
    @Published public var currentToolType: ROIToolType
    @Published public var isCreating: Bool
    
    // MARK: - Configuration
    public func setCurrentInstance(instanceUID: String,
                                  seriesUID: String,
                                  pixelSpacing: simd_float2,
                                  sliceThickness: Float)
    
    // MARK: - Tool Management
    public func selectToolType(_ type: ROIToolType)
    public func startTool(at point: simd_float2, worldPoint: simd_float3)
    public func selectTool(at point: simd_float2) -> ROITool?
    public func deleteTool(_ tool: ROITool)
    public func deleteAllTools()
    public func duplicateTool(_ tool: ROITool)
    
    // MARK: - Tool State
    public func deleteLastPoint()
    public func finishCurrentTool()
    public func closePolygon()
    
    // MARK: - Measurements
    public func calculateStatistics(for tool: ROITool,
                                   pixelData: Data,
                                   metadata: DICOMMetadata) -> ROIStatistics?
    
    // MARK: - Persistence
    public func saveToolsForInstance(_ instanceUID: String)
    public func loadToolsForInstance(_ instanceUID: String)
    public func exportTools() -> Data?
    public func importTools(from data: Data) throws
    
    // MARK: - Reporting
    public func generateReport() -> ROIReport
    
    // MARK: - Computed Properties
    public var hasActiveTools: Bool { get }
    public func getToolsForCurrentInstance() -> [ROITool]
    
    // MARK: - Color Management
    public func setToolColor(_ color: UIColor, for tool: ROITool)
}
```

### ROITool Protocol
```swift
public protocol ROITool: AnyObject, Identifiable {
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

### Specific ROI Tools
```swift
// Linear ROI Tool
public class LinearROITool: ROITool {
    public var length: Float { get }
    public var angle: Float { get }
}

// Circular ROI Tool
public class CircularROITool: ROITool {
    public var center: simd_float2? { get }
    public var radius: Float { get }
    public var area: Float { get }
    public var circumference: Float { get }
}

// Rectangular ROI Tool
public class RectangularROITool: ROITool {
    public var topLeft: simd_float2? { get }
    public var bottomRight: simd_float2? { get }
    public var width: Float { get }
    public var height: Float { get }
    public var area: Float { get }
}

// Polygon ROI Tool
public class PolygonROITool: ROITool {
    public var isClosed: Bool { get }
    public var area: Float { get }
    public var perimeter: Float { get }
    
    public func closePolygon()
    public func addIntermediatePoint(_ point: simd_float2, worldPoint: simd_float3)
}

// Angle ROI Tool
public class AngleROITool: ROITool {
    public var vertex: simd_float2? { get }
    public var angle: Float { get } // in degrees
    public var angleInRadians: Float { get }
}

// Elliptical ROI Tool
public class EllipticalROITool: ROITool {
    public var center: simd_float2? { get }
    public var semiMajorAxis: Float { get }
    public var semiMinorAxis: Float { get }
    public var area: Float { get }
    public var eccentricity: Float { get }
}
```

### ROIRenderer
```swift
public class ROIRenderer {
    // MARK: - Initialization
    public init(device: MTLDevice) throws
    
    // MARK: - Rendering
    public func render(tools: [ROITool],
                      to drawable: CAMetalDrawable,
                      viewportSize: CGSize,
                      imageToScreenTransform: simd_float4x4) throws
    
    // MARK: - Style Configuration
    public func setLineWidth(_ width: Float)
    public func setPointSize(_ size: Float)
    public func enableAntialiasing(_ enabled: Bool)
    
    // MARK: - Selection Highlighting
    public func highlightTool(_ tool: ROITool, highlighted: Bool)
}
```

## 📊 Data Model APIs

### DICOMStudy
```swift
public class DICOMStudy {
    // MARK: - Properties
    public let studyInstanceUID: String
    public let studyID: String
    public let studyDate: Date?
    public let studyTime: Date?
    public let studyDescription: String?
    public let patientName: String
    public let patientID: String
    public let patientBirthDate: Date?
    public let patientSex: String?
    public var series: [DICOMSeries]
    
    // MARK: - Computed Properties
    public var totalImages: Int { get }
    public var modalities: Set<String> { get }
    public var studySize: Int { get }
    
    // MARK: - Methods
    public func addSeries(_ series: DICOMSeries)
    public func removeSeries(_ series: DICOMSeries)
    public func getSeries(instanceUID: String) -> DICOMSeries?
    public func getSeriesByModality(_ modality: String) -> [DICOMSeries]
}
```

### DICOMSeries
```swift
public class DICOMSeries {
    // MARK: - Properties
    public let seriesInstanceUID: String
    public let seriesNumber: Int
    public let seriesDate: Date?
    public let seriesTime: Date?
    public let seriesDescription: String?
    public let modality: String
    public let bodyPartExamined: String?
    public let protocolName: String?
    public var instances: [DICOMInstance]
    
    // MARK: - Computed Properties
    public var isMultiFrame: Bool { get }
    public var frameCount: Int { get }
    public var pixelSpacing: [Double]? { get }
    public var sliceThickness: Double? { get }
    public var imagePositions: [simd_float3] { get }
    public var imageOrientations: [simd_float3] { get }
    
    // MARK: - Methods
    public func addInstance(_ instance: DICOMInstance)
    public func removeInstance(_ instance: DICOMInstance)
    public func getInstance(sopInstanceUID: String) -> DICOMInstance?
    public func sortInstancesByPosition()
    public func getSliceSpacing() -> Float
}
```

### DICOMInstance
```swift
public class DICOMInstance {
    // MARK: - Properties
    public let sopInstanceUID: String
    public let sopClassUID: String
    public let instanceNumber: Int
    public let metadata: DICOMMetadata
    public var pixelData: Data?
    public var windowCenter: Double
    public var windowWidth: Double
    
    // MARK: - Computed Properties
    public var imageSize: CGSize { get }
    public var pixelSpacing: simd_float2? { get }
    public var sliceThickness: Float? { get }
    public var imagePosition: simd_float3? { get }
    public var imageOrientation: [Float]? { get }
    public var isColor: Bool { get }
    public var bitsPerPixel: Int { get }
    
    // MARK: - Methods
    public func getPixelValue(at point: CGPoint) -> Double?
    public func getWorldCoordinate(from imagePoint: CGPoint) -> simd_float3?
    public func getImageCoordinate(from worldPoint: simd_float3) -> CGPoint?
    public func applyWindowLevel(center: Double, width: Double)
    public func resetWindowLevel()
}
```

### DICOMMetadata
```swift
public class DICOMMetadata {
    // MARK: - Patient Information
    public var patientName: String?
    public var patientID: String?
    public var patientBirthDate: Date?
    public var patientSex: String?
    public var patientAge: String?
    
    // MARK: - Study Information
    public var studyInstanceUID: String?
    public var studyID: String?
    public var studyDate: Date?
    public var studyTime: Date?
    public var studyDescription: String?
    public var referringPhysicianName: String?
    
    // MARK: - Series Information
    public var seriesInstanceUID: String?
    public var seriesNumber: Int = 0
    public var seriesDate: Date?
    public var seriesTime: Date?
    public var seriesDescription: String?
    public var modality: String?
    public var bodyPartExamined: String?
    
    // MARK: - Instance Information
    public var sopInstanceUID: String?
    public var sopClassUID: String?
    public var instanceNumber: Int = 0
    public var instanceCreationDate: Date?
    public var instanceCreationTime: Date?
    
    // MARK: - Image Information
    public var rows: Int = 0
    public var columns: Int = 0
    public var bitsAllocated: Int = 16
    public var bitsStored: Int = 16
    public var highBit: Int = 15
    public var pixelRepresentation: Int = 0
    public var samplesPerPixel: Int = 1
    public var photometricInterpretation: String?
    
    // MARK: - Geometric Information
    public var pixelSpacing: [Double]?
    public var sliceThickness: Double?
    public var sliceLocation: Double?
    public var imagePositionPatient: [Double]?
    public var imageOrientationPatient: [Double]?
    
    // MARK: - Display Information
    public var windowCenter: Double?
    public var windowWidth: Double?
    public var rescaleSlope: Double = 1.0
    public var rescaleIntercept: Double = 0.0
    public var units: String?
    
    // MARK: - Multi-frame Information
    public var numberOfFrames: Int = 1
    public var frameTime: Double?
    public var frameIncrementPointer: String?
    
    // MARK: - Methods
    public func getValue(for tag: DCMTKTag) -> Any?
    public func setValue(_ value: Any, for tag: DCMTKTag)
    public func hasTag(_ tag: DCMTKTag) -> Bool
    public func getAllTags() -> [DCMTKTag: Any]
}
```

### DICOMSegmentation
```swift
public struct DICOMSegmentation {
    // MARK: - Properties
    public let sopInstanceUID: String
    public let sopClassUID: String
    public let seriesInstanceUID: String
    public let studyInstanceUID: String
    public let segmentationUID: String
    public let contentLabel: String
    public let contentDescription: String?
    public let segmentationAlgorithmType: SegmentationAlgorithmType
    public let instanceNumber: Int32
    public let contentDate: Date?
    public let contentTime: Date?
    public let referencedSeriesUID: String
    public let referencedFrameOfReferenceUID: String
    public var segments: [SegmentationSegment]
    public let rows: Int
    public let columns: Int
    public let numberOfFrames: Int
    
    // MARK: - Computed Properties
    public var totalVoxelCount: Int { get }
    public var isEmpty: Bool { get }
    
    // MARK: - Methods
    public mutating func addSegment(_ segment: SegmentationSegment)
    public mutating func removeSegment(withNumber segmentNumber: UInt16)
    public func getSegment(number: UInt16) -> SegmentationSegment?
    
    // MARK: - iOS Memory Management
    public mutating func loadSegmentDataLazy()
    public mutating func handleMemoryPressure()
    
    // MARK: - Factory Methods
    public static func createTestSegmentation() -> DICOMSegmentation
}
```

### RTStructureSet
```swift
public struct RTStructureSet {
    // MARK: - Properties
    public let sopInstanceUID: String
    public let sopClassUID: String
    public let seriesInstanceUID: String
    public let studyInstanceUID: String
    public let structureSetUID: String
    public let structureSetLabel: String
    public let structureSetName: String?
    public let structureSetDescription: String?
    public let frameOfReferenceUID: String
    public let referencedStudyUID: String
    public let referencedSeriesUID: String
    public var roiContours: [ROIContour]
    public var rtROIObservations: [RTROIObservation]
    public var structureSets: [StructureSetROI]
    
    // MARK: - Computed Properties
    public var totalContourCount: Int { get }
    public var isEmpty: Bool { get }
    
    // MARK: - Methods
    public mutating func addROIContour(_ contour: ROIContour)
    public mutating func addRTROIObservation(_ observation: RTROIObservation)
    public mutating func addStructureSetROI(_ roi: StructureSetROI)
    public func getROIContour(number: Int32) -> ROIContour?
    public func getStructureSetROI(number: Int32) -> StructureSetROI?
    public func getRTROIObservation(number: Int32) -> RTROIObservation?
    
    // MARK: - iOS Memory Management
    public mutating func loadContourDataLazy()
    public mutating func handleMemoryPressure()
    
    // MARK: - Factory Methods
    public static func createTestStructureSet() -> RTStructureSet
}
```

## 🎛️ Configuration APIs

### RenderingParameters
```swift
public struct RenderingParameters {
    public var windowCenter: Double = 40
    public var windowWidth: Double = 400
    public var zoom: Float = 1.0
    public var pan: simd_float2 = simd_float2(0, 0)
    public var rotation: Float = 0.0
    public var flipHorizontal: Bool = false
    public var flipVertical: Bool = false
    public var interpolation: InterpolationMode = .linear
    public var lutType: LUTType = .linear
    
    public init()
}

public enum InterpolationMode {
    case nearest, linear, cubic
}

public enum LUTType {
    case linear, sigmoid, log, hotMetal, rainbow
}
```

### VolumeRenderingParameters
```swift
public struct VolumeRenderingParameters {
    public var renderMode: VolumeRenderer.VolumeRenderMode = .dvr
    public var stepSize: Float = 0.5
    public var maxSteps: Int = 1000
    public var opacity: Float = 1.0
    public var transferFunction: TransferFunction = TransferFunction.default
    public var cameraPosition: simd_float3 = simd_float3(0, 0, -500)
    public var cameraTarget: simd_float3 = simd_float3(0, 0, 0)
    public var cameraUp: simd_float3 = simd_float3(0, 1, 0)
    public var fieldOfView: Float = 45.0
    public var nearPlane: Float = 0.1
    public var farPlane: Float = 1000.0
    
    public init()
}
```

### MPRRenderingParameters
```swift
public struct MPRRenderingParameters {
    public var windowCenter: Double = 40
    public var windowWidth: Double = 400
    public var sliceThickness: Float = 1.0
    public var showCrosshairs: Bool = true
    public var crosshairColor: simd_float4 = simd_float4(1, 1, 0, 1)
    public var crosshairThickness: Float = 1.0
    public var interpolation: InterpolationMode = .linear
    
    public init()
}
```

## 📋 Utility APIs

### DICOMMemoryManager
```swift
public class DICOMMemoryManager {
    public static let shared: DICOMMemoryManager
    
    // MARK: - Memory Monitoring
    public func setupMemoryPressureMonitoring()
    public func handleMemoryPressure()
    public func checkMemoryPressure()
    
    // MARK: - Memory Info
    public func getMemoryUsage() -> MemoryUsageInfo
    public func getAvailableMemory() -> Int
    
    // MARK: - Cache Control
    public func clearAllCaches()
    public func setMaxMemoryUsage(_ bytes: Int)
    public func requestMemoryOptimization()
}

public struct MemoryUsageInfo {
    public let totalMemory: Int
    public let usedMemory: Int
    public let availableMemory: Int
    public let cacheMemory: Int
    public let textureMemory: Int
    
    public var memoryPressureLevel: MemoryPressureLevel { get }
}

public enum MemoryPressureLevel {
    case normal, warning, critical
}
```

### DICOMCacheManager
```swift
public class DICOMCacheManager {
    public static let shared: DICOMCacheManager
    
    // MARK: - Cache Management
    public func cacheImage(_ image: UIImage, for key: String)
    public func getCachedImage(for key: String) -> UIImage?
    public func cacheTexture(_ texture: MTLTexture, for key: String)
    public func getCachedTexture(for key: String) -> MTLTexture?
    
    // MARK: - Cache Control
    public func clearImageCache()
    public func clearTextureCache()
    public func clearAllCaches()
    public func setCacheLimit(_ limit: Int)
    public func getCacheSize() -> Int
    
    // MARK: - LRU Management
    public func evictLeastRecentlyUsed()
    public func touchCacheEntry(for key: String)
}
```

### ROIStatistics
```swift
public struct ROIStatistics {
    public let pixelCount: Int
    public let area: Double
    public let perimeter: Double
    public let mean: Double
    public let standardDeviation: Double
    public let minimum: Double
    public let maximum: Double
    public let median: Double
    public let sum: Double
    
    // MARK: - Computed Properties
    public var coefficient: Double { get }
    public var variance: Double { get }
    public var skewness: Double { get }
    public var kurtosis: Double { get }
    
    // MARK: - Display
    public var displayText: String { get }
    public var detailedText: String { get }
    
    // MARK: - Export
    public func toDictionary() -> [String: Any]
    public func toCSVRow() -> String
}
```

This comprehensive API reference provides all the public interfaces and methods available in the iOS DICOM Viewer for future implementations and integrations.