# iOS DICOM Viewer - Complete Architecture Documentation

## 📋 Table of Contents
- [System Overview](#system-overview)
- [Core Architecture](#core-architecture)
- [Data Models](#data-models)
- [Rendering Pipeline](#rendering-pipeline)
- [Parser Architecture](#parser-architecture)
- [Memory Management](#memory-management)
- [Performance Optimizations](#performance-optimizations)
- [Integration Points](#integration-points)
- [Testing Framework](#testing-framework)
- [Future Implementation Guidelines](#future-implementation-guidelines)

## 🏗️ System Overview

### High-Level Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    iOS DICOM Viewer                        │
├─────────────────────────────────────────────────────────────┤
│  Presentation Layer                                         │
│  ├── ViewControllers (MainVC, ViewerVC, StudyListVC)       │
│  ├── ROI Tools UI (ROIViewController)                      │
│  └── Gesture Handlers (DICOMGestureHandler)                │
├─────────────────────────────────────────────────────────────┤
│  Business Logic Layer                                       │
│  ├── Coordinators (AppCoordinator, StudyListCoordinator)   │
│  ├── Service Managers (DICOMServiceManager)                │
│  └── ROI Manager (ROIManager)                              │
├─────────────────────────────────────────────────────────────┤
│  Core Services Layer                                        │
│  ├── DICOM Parser (DICOMParser)                           │
│  ├── Image Renderer (DICOMImageRenderer)                   │
│  ├── Volume Renderer (VolumeRenderer)                      │
│  ├── MPR Renderer (MPRRenderer)                            │
│  ├── Segmentation Renderer (SegmentationRenderer)          │
│  └── RT Structure Renderer (RTStructureRenderer)           │
├─────────────────────────────────────────────────────────────┤
│  Data Layer                                                 │
│  ├── Models (DICOMStudy, DICOMSeries, DICOMInstance)      │
│  ├── Cache Manager (DICOMCacheManager)                     │
│  ├── Metadata Store (DICOMMetadataStore)                   │
│  └── File Importer (DICOMFileImporter)                     │
├─────────────────────────────────────────────────────────────┤
│  Native Bridge Layer                                        │
│  ├── DCMTK Bridge (DCMTKBridge.mm)                        │
│  └── Metal Shaders (*.metal)                              │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Core Architecture

### 1. MVVM-C Pattern Implementation
- **Model**: DICOM data models with Core Data integration
- **View**: UIKit views with Metal rendering surfaces
- **ViewModel**: Service managers handling business logic
- **Coordinator**: Navigation and flow control

### 2. Dependency Injection
```swift
// Service Manager Pattern
class DICOMServiceManager {
    static let shared = DICOMServiceManager()
    
    private let parser: DICOMParser
    private let renderer: DICOMImageRenderer
    private let cacheManager: DICOMCacheManager
    
    init(parser: DICOMParser = DICOMParser(),
         renderer: DICOMImageRenderer = DICOMImageRenderer(),
         cacheManager: DICOMCacheManager = DICOMCacheManager.shared) {
        self.parser = parser
        self.renderer = renderer
        self.cacheManager = cacheManager
    }
}
```

### 3. Protocol-Oriented Design
```swift
protocol ServiceProtocols {
    associatedtype DataType
    func load(_ data: DataType) throws
    func process() -> Result<DataType, Error>
}

protocol DICOMRenderable {
    func render(to drawable: CAMetalDrawable)
    func updateTransform(_ transform: simd_float4x4)
    func handleMemoryPressure()
}
```

## 📊 Data Models

### Core DICOM Hierarchy
```swift
// Study Level
class DICOMStudy {
    let studyInstanceUID: String
    let patientName: String
    let studyDate: Date?
    var series: [DICOMSeries]
    
    // Computed properties
    var totalImages: Int { series.reduce(0) { $0 + $1.instances.count } }
    var studyDescription: String { metadata.studyDescription ?? "Unknown Study" }
}

// Series Level
class DICOMSeries {
    let seriesInstanceUID: String
    let modality: String
    let seriesNumber: Int
    var instances: [DICOMInstance]
    
    // Series-specific properties
    var isMultiFrame: Bool { instances.first?.numberOfFrames ?? 1 > 1 }
    var pixelSpacing: [Double]? { instances.first?.metadata.pixelSpacing }
}

// Instance Level
class DICOMInstance {
    let sopInstanceUID: String
    let metadata: DICOMMetadata
    var pixelData: Data?
    
    // Image properties
    var windowCenter: Double { metadata.windowCenter ?? 40 }
    var windowWidth: Double { metadata.windowWidth ?? 400 }
}
```

### Extended Medical Models
```swift
// Segmentation Model
struct DICOMSegmentation {
    let sopInstanceUID: String
    let contentLabel: String
    let algorithmType: SegmentationAlgorithmType
    var segments: [SegmentationSegment]
    
    // iOS Memory Management
    mutating func loadSegmentDataLazy()
    mutating func handleMemoryPressure()
}

// RT Structure Set Model
struct RTStructureSet {
    let structureSetUID: String
    let frameOfReferenceUID: String
    var roiContours: [ROIContour]
    var structureSets: [StructureSetROI]
    
    // iOS Optimization Methods
    mutating func simplifyForRendering(tolerance: Float)
    func getContoursIntersectingPlane(normal: simd_float3, point: simd_float3) -> [ROIContour]
}
```

## 🎨 Rendering Pipeline

### Metal Rendering Architecture
```swift
class MetalRenderingPipeline {
    // Core Components
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Specialized Renderers
    private let volumeRenderer: VolumeRenderer
    private let mprRenderer: MPRRenderer
    private let segmentationRenderer: SegmentationRenderer
    private let rtStructureRenderer: RTStructureRenderer
    private let roiRenderer: ROIRenderer
    
    // Render Pipeline States
    private var dicomRenderPipeline: MTLRenderPipelineState?
    private var volumeRenderPipeline: MTLRenderPipelineState?
    private var overlayRenderPipeline: MTLRenderPipelineState?
}
```

### Shader Architecture
```metal
// DICOM Image Shaders
vertex DICOMVertexOut dicomVertex(DICOMVertex in [[stage_in]],
                                 constant DICOMUniforms& uniforms [[buffer(1)]]);

fragment float4 dicomFragment(DICOMVertexOut in [[stage_in]],
                             texture2d<float> dicomTexture [[texture(0)]],
                             texture2d<float> lutTexture [[texture(1)]]);

// Volume Rendering Shaders
vertex VolumeVertexOut volumeVertex(VolumeVertex in [[stage_in]],
                                   constant VolumeUniforms& uniforms [[buffer(1)]]);

fragment float4 volumeFragment(VolumeVertexOut in [[stage_in]],
                              texture3d<float> volumeTexture [[texture(0)]],
                              texture2d<float> transferFunction [[texture(1)]]);

// Compute Shaders for Processing
kernel void processVolumeData(texture3d<float, access::read> inputVolume [[texture(0)]],
                             texture3d<float, access::write> outputVolume [[texture(1)]],
                             constant VolumeProcessingParams& params [[buffer(0)]]);
```

### Multi-Planar Reconstruction (MPR)
```swift
class MPRRenderer {
    enum MPRPlane: CaseIterable {
        case axial, sagittal, coronal
        
        var normal: simd_float3 {
            switch self {
            case .axial: return simd_float3(0, 0, 1)
            case .sagittal: return simd_float3(1, 0, 0)
            case .coronal: return simd_float3(0, 1, 0)
            }
        }
    }
    
    func renderMPRPlane(_ plane: MPRPlane, 
                       sliceIndex: Int,
                       to drawable: CAMetalDrawable,
                       with crosshairs: Bool = true)
    
    func synchronizeCrosshairs(worldPosition: simd_float3)
}
```

## 🔍 Parser Architecture

### DCMTK Integration Strategy
```objective-c
// DCMTKBridge.mm - Objective-C++ Bridge
@interface DCMTKBridge : NSObject
- (BOOL)loadDICOMFile:(NSString *)filePath;
- (NSString *)getStringValue:(DCMTKTag)tag;
- (NSData *)getPixelData;
- (NSArray<NSNumber *> *)getDoubleArrayValue:(DCMTKTag)tag;
- (void)cleanup;
@end

// Implementation uses DCMTK C++ library
class DCMTKImplementation {
    DcmFileFormat fileFormat;
    DcmDataset* dataset;
    
    bool loadFile(const char* path);
    std::string getStringValue(uint16_t group, uint16_t element);
    std::vector<double> getDoubleArray(uint16_t group, uint16_t element);
};
```

### Specialized Parsers
```swift
// DICOM Segmentation Parser
class DICOMSegmentationParser {
    private let dcmtkBridge: DCMTKBridge
    private let maxSegmentSize: Int = 50 * 1024 * 1024 // 50MB
    
    func parseSegmentation(from filePath: String) throws -> DICOMSegmentation {
        // 1. Extract basic metadata
        let metadata = try extractBasicMetadata()
        
        // 2. Validate segmentation object
        try validateSegmentationObject(metadata)
        
        // 3. Parse segment sequence
        let segmentData = try parseSegmentSequence()
        
        // 4. Extract pixel data with iOS optimization
        let pixelData = try parsePixelData()
        
        // 5. Create segmentation object
        return createSegmentationObject(from: metadata, segments: segmentData, pixelData: pixelData)
    }
}

// RT Structure Set Parser
class RTStructureSetParser {
    private let contourSimplificationThreshold: Int = 1000 // Points
    
    func parseStructureSet(from filePath: String) throws -> RTStructureSet {
        // 1. Parse structure set metadata
        let metadata = try extractBasicMetadata()
        
        // 2. Parse ROI structures
        let roiStructures = try parseStructureSetROISequence()
        
        // 3. Parse contour data with simplification
        let contours = try parseROIContourSequence()
        
        // 4. Parse RT observations
        let observations = try parseRTROIObservationsSequence()
        
        // 5. Assemble complete structure set
        return assembleStructureSet(metadata: metadata, 
                                  structures: roiStructures,
                                  contours: contours, 
                                  observations: observations)
    }
}
```

## 💾 Memory Management

### iOS-Specific Optimizations
```swift
class DICOMMemoryManager {
    static let shared = DICOMMemoryManager()
    
    // Memory Pressure Monitoring
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
    }
    
    func handleMemoryPressure() {
        // 1. Clear texture caches
        volumeRenderer.handleMemoryPressure()
        segmentationRenderer.handleMemoryPressure()
        
        // 2. Compress inactive data
        cacheManager.compressInactiveData()
        
        // 3. Release non-visible segments
        for segmentation in activeSegmentations {
            segmentation.handleMemoryPressure()
        }
    }
}

// Lazy Loading Strategy
extension DICOMSegmentation {
    mutating func loadSegmentDataLazy() {
        for i in 0..<segments.count {
            if segments[i].pixelData.count > 1024 * 1024 { // > 1MB
                print("⚠️ Large segment data detected: \(segments[i].pixelData.count) bytes")
                // Implement compression or lazy loading
            }
        }
    }
}
```

### Cache Management
```swift
class DICOMCacheManager {
    private var imageCache: NSCache<NSString, UIImage>
    private var textureCache: NSCache<NSString, MTLTexture>
    private var volumeCache: NSCache<NSString, VolumeData>
    
    // Cache Policies
    private let maxMemoryUsage: Int = 200 * 1024 * 1024 // 200MB
    private let maxTextureCount: Int = 50
    
    func cacheImage(_ image: UIImage, for key: String) {
        let cost = calculateImageMemoryCost(image)
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func evictLeastRecentlyUsed() {
        // LRU eviction strategy
        imageCache.removeAllObjects()
        textureCache.removeAllObjects()
    }
}
```

## ⚡ Performance Optimizations

### GPU Acceleration Strategies
```swift
// Asynchronous Texture Loading
func loadTextureAsync(from data: Data) -> Future<MTLTexture, Error> {
    return Future { promise in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let texture = try self.createTexture(from: data)
                DispatchQueue.main.async {
                    promise(.success(texture))
                }
            } catch {
                DispatchQueue.main.async {
                    promise(.failure(error))
                }
            }
        }
    }
}

// Level of Detail (LOD) for Large Datasets
class LODManager {
    func selectLOD(for distance: Float, dataSize: Int) -> LODLevel {
        switch (distance, dataSize) {
        case (0..<10, _): return .high
        case (10..<50, _): return .medium
        case (_, let size) where size > 100_000_000: return .low
        default: return .medium
        }
    }
}
```

### Contour Simplification
```swift
// Douglas-Peucker Algorithm for iOS
extension ContourData {
    func decimateForPerformance(maxPoints: Int = 500) -> ContourData {
        guard numberOfContourPoints > maxPoints else { return self }
        
        let step = Int(numberOfContourPoints) / maxPoints
        var decimatedData: [Double] = []
        
        for i in stride(from: 0, to: contourData.count, by: step * 3) {
            if i + 2 < contourData.count {
                decimatedData.append(contourData[i])
                decimatedData.append(contourData[i + 1])
                decimatedData.append(contourData[i + 2])
            }
        }
        
        return ContourData(geometricType: contourGeometricType,
                          contourData: decimatedData)
    }
}
```

## 🎛️ ROI Tools Architecture

### Tool Management System
```swift
class ROIManager: ObservableObject {
    enum ROIToolType: CaseIterable {
        case linear, circular, rectangular, polygon, angle, elliptical
        
        var toolClass: ROITool.Type {
            switch self {
            case .linear: return LinearROITool.self
            case .circular: return CircularROITool.self
            case .rectangular: return RectangularROITool.self
            case .polygon: return PolygonROITool.self
            case .angle: return AngleROITool.self
            case .elliptical: return EllipticalROITool.self
            }
        }
    }
    
    // Tool State Management
    @Published var activeTools: [ROITool] = []
    @Published var selectedTool: ROITool?
    @Published var currentToolType: ROIToolType = .linear
    @Published var isCreating: Bool = false
    
    // Tool Creation and Management
    func startTool(at point: simd_float2, worldPoint: simd_float3)
    func selectTool(at point: simd_float2) -> ROITool?
    func deleteTool(_ tool: ROITool)
    func duplicateTool(_ tool: ROITool)
}
```

### Measurement Calculations
```swift
protocol ROITool {
    var id: UUID { get }
    var name: String { get }
    var color: UIColor { get set }
    var isComplete: Bool { get }
    var measurement: Measurement<UnitLength>? { get }
    var statistics: ROIStatistics? { get set }
    
    func addPoint(_ point: simd_float2, worldPoint: simd_float3)
    func contains(point: simd_float2) -> Bool
    func calculateMeasurement() -> Measurement<UnitLength>?
    func calculateStatistics(pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics?
}

// Statistical Analysis
struct ROIStatistics {
    let pixelCount: Int
    let area: Double
    let perimeter: Double
    let mean: Double
    let standardDeviation: Double
    let minimum: Double
    let maximum: Double
    let median: Double
    let sum: Double
    
    var displayText: String {
        """
        Pixels: \(pixelCount)
        Area: \(String(format: "%.2f", area)) mm²
        Mean: \(String(format: "%.1f", mean)) HU
        Std Dev: \(String(format: "%.1f", standardDeviation)) HU
        Range: \(String(format: "%.1f", minimum)) - \(String(format: "%.1f", maximum)) HU
        """
    }
}
```

## 🧪 Testing Framework

### Unit Test Architecture
```swift
class DICOMParserTests: XCTestCase {
    var parser: DICOMParser!
    var mockFileManager: MockFileManager!
    
    override func setUpWithError() throws {
        parser = DICOMParser()
        mockFileManager = MockFileManager()
    }
    
    func testDICOMFileLoading() throws {
        // Given
        let testDICOMFile = createMockDICOMFile()
        
        // When
        let result = try parser.parseDICOMFile(testDICOMFile)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result.metadata.sopInstanceUID, "expected_uid")
    }
}

// Performance Testing
class VolumeRenderingPerformanceTests: XCTestCase {
    func testVolumeRenderingPerformance() throws {
        let volumeRenderer = VolumeRenderer(device: MTLCreateSystemDefaultDevice()!)
        let testVolume = createTestVolumeData(size: (512, 512, 256))
        
        measure {
            volumeRenderer.renderVolume(testVolume, 
                                      renderMode: .mip,
                                      to: mockDrawable)
        }
    }
}
```

### Integration Tests
```swift
class DICOMWorkflowIntegrationTests: XCTestCase {
    func testCompleteWorkflow() throws {
        // Test complete DICOM loading and rendering workflow
        let fileImporter = DICOMFileImporter()
        let parser = DICOMParser()
        let renderer = DICOMImageRenderer()
        
        // Load DICOM file
        let dicomFile = try fileImporter.importFile(at: testFileURL)
        
        // Parse DICOM data
        let instance = try parser.parseDICOMFile(dicomFile)
        
        // Render image
        let image = try renderer.renderDICOMImage(instance)
        
        XCTAssertNotNil(image)
    }
}
```

## 🔌 Integration Points

### External Library Integration
```swift
// DCMTK Integration
class DCMTKIntegration {
    static func setupDCMTK() {
        // Initialize DCMTK logging
        OFLog.configureFromString("*=WARN")
        
        // Set up character encoding
        dcmEnableAutomaticInputDataCorrection.set(OFTrue)
    }
}

// Metal Performance Shaders
import MetalPerformanceShaders

extension VolumeRenderer {
    func applyMPSFilters(to texture: MTLTexture) -> MTLTexture {
        let gaussianBlur = MPSImageGaussianBlur(device: device, sigma: 1.0)
        let outputTexture = createOutputTexture(like: texture)
        
        gaussianBlur.encode(commandBuffer: commandBuffer,
                           sourceTexture: texture,
                           destinationTexture: outputTexture)
        
        return outputTexture
    }
}
```

### Core Data Integration
```swift
// Persistent Storage for Studies
@objc(DICOMStudyEntity)
class DICOMStudyEntity: NSManagedObject {
    @NSManaged var studyInstanceUID: String
    @NSManaged var patientName: String
    @NSManaged var studyDate: Date?
    @NSManaged var seriesEntities: Set<DICOMSeriesEntity>
}

class DICOMPersistenceManager {
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DICOMModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }
        return container
    }()
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            try? context.save()
        }
    }
}
```

## 🚀 Future Implementation Guidelines

### Extensibility Patterns
```swift
// Plugin Architecture for New Modalities
protocol DICOMModalityHandler {
    var supportedSOPClassUIDs: [String] { get }
    
    func canHandle(sopClassUID: String) -> Bool
    func parse(dicomFile: DICOMFile) throws -> DICOMInstance
    func render(instance: DICOMInstance, to drawable: CAMetalDrawable)
}

// Example: PET/CT Fusion Handler
class PETCTFusionHandler: DICOMModalityHandler {
    var supportedSOPClassUIDs: [String] = [
        "1.2.840.10008.5.1.4.1.1.128", // PET Image Storage
        "1.2.840.10008.5.1.4.1.1.2"    // CT Image Storage
    ]
    
    func canHandle(sopClassUID: String) -> Bool {
        return supportedSOPClassUIDs.contains(sopClassUID)
    }
}
```

### PACS Integration Framework
```swift
// DICOM Networking Protocol
protocol DICOMNetworkService {
    func query(parameters: DICOMQueryParameters) async throws -> [DICOMStudy]
    func retrieve(studyInstanceUID: String) async throws -> DICOMStudy
    func store(instance: DICOMInstance) async throws -> Bool
}

// PACS Connection Manager
class PACSConnectionManager {
    struct PACSConfiguration {
        let host: String
        let port: Int
        let callingAETitle: String
        let calledAETitle: String
    }
    
    func connect(to pacs: PACSConfiguration) async throws -> DICOMNetworkService
    func disconnect()
}
```

### AI/ML Integration Points
```swift
// AI Model Integration
protocol DICOMAIProcessor {
    associatedtype InputType
    associatedtype OutputType
    
    func process(_ input: InputType) async throws -> OutputType
}

// Example: Segmentation AI
class AISegmentationProcessor: DICOMAIProcessor {
    typealias InputType = DICOMInstance
    typealias OutputType = DICOMSegmentation
    
    private let coreMLModel: MLModel
    
    func process(_ instance: DICOMInstance) async throws -> DICOMSegmentation {
        // Run AI inference on DICOM image
        let prediction = try await runInference(on: instance.pixelData)
        return convertToSegmentation(prediction)
    }
}
```

### Regulatory Compliance Framework
```swift
// Audit Logging System
class DICOMAuditLogger {
    enum AuditEvent {
        case imageViewed(studyUID: String, userID: String)
        case measurementCreated(roiID: String, value: Double)
        case dataExported(studyUID: String, destination: String)
    }
    
    func logEvent(_ event: AuditEvent) {
        // Log to secure audit trail
        let auditEntry = AuditEntry(
            timestamp: Date(),
            event: event,
            userID: getCurrentUser(),
            sessionID: getCurrentSession()
        )
        
        secureAuditStore.append(auditEntry)
    }
}

// HIPAA Compliance Tools
class HIPAAComplianceManager {
    func validatePHIAccess(for user: User, resource: DICOMResource) -> Bool
    func anonymizeData(_ instance: DICOMInstance) -> DICOMInstance
    func generateComplianceReport() -> ComplianceReport
}
```

This comprehensive architecture documentation provides a complete blueprint for understanding and extending the iOS DICOM Viewer implementation. It covers all major components, design patterns, optimization strategies, and integration points for future development.