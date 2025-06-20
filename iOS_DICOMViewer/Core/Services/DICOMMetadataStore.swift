import Foundation

/// Metadata store service that manages DICOM studies, series, and instances
/// Follows OHIF's metadata management patterns
class DICOMMetadataStore: DICOMServiceProtocol {
    static let shared = DICOMMetadataStore()
    
    let identifier = "DICOMMetadataStore"
    private var studies: [String: DICOMStudy] = [:]
    private var series: [String: DICOMSeries] = [:]
    private var instances: [String: DICOMInstance] = [:]
    
    // Notification center for broadcasting changes
    private let notificationCenter = NotificationCenter.default
    
    // MARK: - Notification Names
    static let studyAddedNotification = Notification.Name("DICOMStudyAdded")
    static let seriesAddedNotification = Notification.Name("DICOMSeriesAdded")
    static let instanceAddedNotification = Notification.Name("DICOMInstanceAdded")
    static let metadataUpdatedNotification = Notification.Name("DICOMMetadataUpdated")
    
    private init() {}
    
    func initialize() async throws {
        print("📊 DICOM Metadata Store initialized")
    }
    
    func shutdown() async {
        reset()
        print("🗑️ DICOM Metadata Store shutdown")
    }
    
    func reset() {
        studies.removeAll()
        series.removeAll()
        instances.removeAll()
        
        notificationCenter.post(name: Self.metadataUpdatedNotification, object: nil)
        print("🗑️ DICOM Metadata Store reset")
    }
    
    // MARK: - Study Management
    
    /// Add a study to the store
    func addStudy(_ study: DICOMStudy) {
        studies[study.studyInstanceUID] = study
        
        // Add all series and instances from the study
        for seriesItem in study.series {
            addSeries(seriesItem)
        }
        
        notificationCenter.post(
            name: Self.studyAddedNotification,
            object: study,
            userInfo: ["studyUID": study.studyInstanceUID]
        )
        
        print("📚 Added study: \(study.studyInstanceUID)")
    }
    
    /// Get study by UID
    func getStudy(byUID studyUID: String) -> DICOMStudy? {
        return studies[studyUID]
    }
    
    /// Get all studies
    func getAllStudies() -> [DICOMStudy] {
        return Array(studies.values).sorted { first, second in
            // Sort by study date, most recent first
            let firstDate = first.studyDate ?? ""
            let secondDate = second.studyDate ?? ""
            return firstDate > secondDate
        }
    }
    
    /// Remove study
    func removeStudy(byUID studyUID: String) {
        guard let study = studies[studyUID] else { return }
        
        // Remove all series and instances
        for seriesItem in study.series {
            removeSeries(byUID: seriesItem.seriesInstanceUID)
        }
        
        studies.removeValue(forKey: studyUID)
        notificationCenter.post(name: Self.metadataUpdatedNotification, object: nil)
        
        print("🗑️ Removed study: \(studyUID)")
    }
    
    // MARK: - Series Management
    
    /// Add a series to the store
    func addSeries(_ seriesItem: DICOMSeries) {
        series[seriesItem.seriesInstanceUID] = seriesItem
        
        // Add to corresponding study if it exists
        if let study = studies[seriesItem.studyInstanceUID] {
            study.addSeries(seriesItem)
        }
        
        // Add all instances from the series
        for instance in seriesItem.instances {
            addInstance(instance)
        }
        
        notificationCenter.post(
            name: Self.seriesAddedNotification,
            object: seriesItem,
            userInfo: ["seriesUID": seriesItem.seriesInstanceUID]
        )
        
        print("📷 Added series: \(seriesItem.seriesInstanceUID)")
    }
    
    /// Get series by UID
    func getSeries(byUID seriesUID: String) -> DICOMSeries? {
        return series[seriesUID]
    }
    
    /// Get series by study UID
    func getSeries(byStudyUID studyUID: String) -> [DICOMSeries] {
        return series.values.filter { $0.studyInstanceUID == studyUID }
    }
    
    /// Remove series
    func removeSeries(byUID seriesUID: String) {
        guard let seriesItem = series[seriesUID] else { return }
        
        // Remove all instances
        for instance in seriesItem.instances {
            removeInstance(byUID: instance.metadata.sopInstanceUID)
        }
        
        // Remove from study
        if let study = studies[seriesItem.studyInstanceUID] {
            study.removeSeries(seriesItem)
        }
        
        series.removeValue(forKey: seriesUID)
        notificationCenter.post(name: Self.metadataUpdatedNotification, object: nil)
        
        print("🗑️ Removed series: \(seriesUID)")
    }
    
    // MARK: - Instance Management
    
    /// Add an instance to the store
    func addInstance(_ instance: DICOMInstance) {
        instances[instance.metadata.sopInstanceUID] = instance
        
        // Add to corresponding series if it exists
        if let seriesItem = series[instance.metadata.seriesInstanceUID] {
            seriesItem.addInstance(instance)
        }
        
        notificationCenter.post(
            name: Self.instanceAddedNotification,
            object: instance,
            userInfo: ["instanceUID": instance.metadata.sopInstanceUID]
        )
        
        print("🖼️ Added instance: \(instance.metadata.sopInstanceUID)")
    }
    
    /// Get instance by UID
    func getInstance(byUID instanceUID: String) -> DICOMInstance? {
        return instances[instanceUID]
    }
    
    /// Get instances by series UID
    func getInstances(bySeriesUID seriesUID: String) -> [DICOMInstance] {
        return instances.values.filter { $0.metadata.seriesInstanceUID == seriesUID }
    }
    
    /// Remove instance
    func removeInstance(byUID instanceUID: String) {
        guard let instance = instances[instanceUID] else { return }
        
        // Remove from series
        if let seriesItem = series[instance.metadata.seriesInstanceUID] {
            seriesItem.removeInstance(instance)
        }
        
        instances.removeValue(forKey: instanceUID)
        notificationCenter.post(name: Self.metadataUpdatedNotification, object: nil)
        
        print("🗑️ Removed instance: \(instanceUID)")
    }
    
    // MARK: - Query Methods
    
    /// Find studies by patient name
    func findStudies(byPatientName name: String) -> [DICOMStudy] {
        return studies.values.filter { study in
            guard let patientName = study.patientName else { return false }
            return patientName.localizedCaseInsensitiveContains(name)
        }
    }
    
    /// Find studies by patient ID
    func findStudies(byPatientID patientID: String) -> [DICOMStudy] {
        return studies.values.filter { $0.patientID == patientID }
    }
    
    /// Find series by modality
    func findSeries(byModality modality: String) -> [DICOMSeries] {
        return series.values.filter { $0.modality == modality }
    }
    
    /// Get statistics
    func getStatistics() -> (studies: Int, series: Int, instances: Int) {
        return (studies.count, series.count, instances.count)
    }
    
    /// Check if store is empty
    var isEmpty: Bool {
        return studies.isEmpty
    }
}

// MARK: - DICOMFileImporterDelegate
extension DICOMMetadataStore: DICOMFileImporterDelegate {
    func didImportDICOMFile(_ metadata: DICOMMetadata, from url: URL) {
        // Create instance
        let instance = DICOMInstance(metadata: metadata, fileURL: url)
        
        // Get or create series
        let seriesUID = metadata.seriesInstanceUID
        let studyUID = metadata.studyInstanceUID
        
        var seriesItem: DICOMSeries
        if let existingSeries = getSeries(byUID: seriesUID) {
            seriesItem = existingSeries
        } else {
            seriesItem = DICOMSeries(
                seriesInstanceUID: seriesUID,
                seriesNumber: metadata.seriesNumber,
                seriesDescription: metadata.seriesDescription,
                modality: metadata.modality,
                studyInstanceUID: studyUID,
                frameOfReferenceUID: metadata.frameOfReferenceUID
            )
        }
        
        // Get or create study
        var study: DICOMStudy
        if let existingStudy = getStudy(byUID: studyUID) {
            study = existingStudy
        } else {
            study = DICOMStudy(
                studyInstanceUID: studyUID,
                studyDate: metadata.studyDate,
                studyTime: metadata.studyTime,
                studyDescription: metadata.studyDescription,
                patientName: metadata.patientName,
                patientID: metadata.patientID,
                patientBirthDate: metadata.patientBirthDate,
                patientSex: metadata.patientSex
            )
        }
        
        // Add in correct order
        addInstance(instance)
        if getSeries(byUID: seriesUID) == nil {
            addSeries(seriesItem)
        }
        if getStudy(byUID: studyUID) == nil {
            addStudy(study)
        }
        
        // Always post metadata updated notification after import on main thread
        print("📡 DICOMMetadataStore: Posting metadataUpdatedNotification on main thread")
        DispatchQueue.main.async {
            self.notificationCenter.post(name: Self.metadataUpdatedNotification, object: nil)
            print("📡 DICOMMetadataStore: Posted notification on main thread")
        }
    }
}
