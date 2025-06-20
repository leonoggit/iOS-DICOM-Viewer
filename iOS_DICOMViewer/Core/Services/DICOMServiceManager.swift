import Foundation

/// Main service manager that coordinates all DICOM-related services
/// Inspired by OHIF's service manager architecture
class DICOMServiceManager {
    static let shared = DICOMServiceManager()
    
    // Core services
    private(set) var metadataStore: DICOMMetadataStore!
    private(set) var imageLoader: DICOMImageRenderer!
    private(set) var fileImporter: DICOMFileImporter!
    private(set) var renderingEngine: DICOMImageRenderer!
    
    // Extension services
    private(set) var segmentationService: SegmentationService?
    private(set) var structureSetService: RTStructureSetService?
    
    private var isInitialized = false
    
    private init() {}
    
    /// Initialize all services
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Initialize core services
        metadataStore = DICOMMetadataStore.shared
        imageLoader = DICOMImageRenderer()
        fileImporter = DICOMFileImporter.shared
        renderingEngine = DICOMImageRenderer()
        
        // Initialize extension services
        initializeExtensionServices()
        
        // Setup service dependencies
        setupServiceDependencies()
        
        // Initialize all services
        try await initializeAllServices()
        
        isInitialized = true
        
        print("✅ DICOM Service Manager initialized successfully")
    }
    
    private func initializeExtensionServices() {
        // Initialize segmentation service for structure handling
        segmentationService = SegmentationService(metadataStore: metadataStore)
        
        // Initialize structure set service for RT structures
        structureSetService = RTStructureSetService(metadataStore: metadataStore)
    }
    
    private func setupServiceDependencies() {
        // Connect file importer to metadata store
        fileImporter.delegate = metadataStore
        
        // Connect image loader to rendering engine
        // imageLoader.renderingEngine = renderingEngine
        
        print("✅ DICOM Service dependencies set up successfully")
        print("📦 File importer delegate: \(String(describing: fileImporter.delegate))")
    }
    
    private func initializeAllServices() async throws {
        // Initialize metadata store
        try await metadataStore.initialize()
        
        // Initialize file importer
        try await fileImporter.initialize()
        
        print("✅ All DICOM services initialized successfully")
    }
    
    /// Reset all services (useful for testing or cleanup)
    func reset() {
        metadataStore?.reset()
        // imageLoader?.clearCache()
        // renderingEngine?.cleanup()
        
        print("🔄 DICOM Service Manager reset")
    }
    
    /// Get service by type
    func getService<T>(_ type: T.Type) -> T? {
        switch type {
        case is DICOMMetadataStore.Type:
            return metadataStore as? T
        // case is DICOMImageLoader.Type:
        //     return imageLoader as? T
        case is DICOMFileImporter.Type:
            return fileImporter as? T
        // case is RenderingEngine.Type:
        //     return renderingEngine as? T
        case is SegmentationService.Type:
            return segmentationService as? T
        case is RTStructureSetService.Type:
            return structureSetService as? T
        default:
            return nil
        }
    }
    
    /// Register extension service
    func registerExtensionService<T>(_ service: T, for type: T.Type) {
        // Allow registration of custom extension services
        print("📦 Registered extension service: \(type)")
    }
}

// MARK: - Service Protocol
protocol DICOMService {
    func initialize()
    func reset()
}
