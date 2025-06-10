import Foundation

/// DICOM Study model - represents a complete imaging study
/// Mirrors OHIF's study organization and management
class DICOMStudy {
    let studyInstanceUID: String
    let studyDate: String?
    let studyTime: String?
    let studyDescription: String?
    let patientName: String?
    let patientID: String?
    let patientBirthDate: String?
    let patientSex: String?
    let accessionNumber: String?
    
    private(set) var series: [DICOMSeries] = []
    private(set) var isLoaded: Bool = false
    private(set) var loadingProgress: Double = 0.0
    private let complianceManager = ClinicalComplianceManager.shared
    
    init(studyInstanceUID: String,
         studyDate: String? = nil,
         studyTime: String? = nil,
         studyDescription: String? = nil,
         patientName: String? = nil,
         patientID: String? = nil,
         patientBirthDate: String? = nil,
         patientSex: String? = nil,
         accessionNumber: String? = nil) {
        self.studyInstanceUID = studyInstanceUID
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.studyDescription = studyDescription
        self.patientName = patientName
        self.patientID = patientID
        self.patientBirthDate = patientBirthDate
        self.patientSex = patientSex
        self.accessionNumber = accessionNumber
    }
    
    /// Add a series to this study
    func addSeries(_ seriesData: DICOMSeries) {
        guard seriesData.studyInstanceUID == studyInstanceUID else {
            return
        }
        
        // Check if series already exists
        if let existingIndex = series.firstIndex(where: { $0.id == seriesData.id }) {
            // Merge instances if series already exists
            for instance in seriesData.instances {
                series[existingIndex].addInstance(instance)
            }
        } else {
            series.append(seriesData)
            sortSeries()
        }
    }
    
    /// Remove a series from this study
    func removeSeries(_ seriesData: DICOMSeries) {
        series.removeAll { $0.id == seriesData.id }
    }
    
    /// Sort series by series number
    private func sortSeries() {
        series.sort { first, second in
            let firstSeriesNumber = first.seriesNumber ?? 0
            let secondSeriesNumber = second.seriesNumber ?? 0
            return firstSeriesNumber < secondSeriesNumber
        }
    }
    
    /// Load entire study with progress tracking
    func loadStudy() async throws {
        loadingProgress = 0.0
        
        let totalSeries = series.count
        guard totalSeries > 0 else {
            isLoaded = true
            loadingProgress = 1.0
            return
        }
        
        for (index, seriesItem) in series.enumerated() {
            try await seriesItem.loadAllInstances()
            loadingProgress = Double(index + 1) / Double(totalSeries)
        }
        
        // Perform clinical validation after loading
        let validationResult = complianceManager.validateClinicalIntegrity(of: self)
        if !validationResult.isValid {
            print("Clinical validation warnings for study \(studyInstanceUID):")
            for issue in validationResult.issues {
                print("- \(issue.severity): \(issue.message)")
            }
        }
        
        isLoaded = true
        loadingProgress = 1.0
    }
    
    /// Get series by modality
    func getSeries(byModality modality: String) -> [DICOMSeries] {
        return series.filter { $0.modality == modality }
    }
    
    /// Get all available modalities in this study
    var availableModalities: Set<String> {
        return Set(series.map { $0.modality })
    }
    
    /// Get total number of instances across all series
    var totalInstanceCount: Int {
        return series.reduce(0) { $0 + $1.instances.count }
    }
    
    /// Get total number of frames across all series
    var totalFrameCount: Int {
        return series.reduce(0) { $0 + $1.totalFrameCount }
    }
    
    /// Check if study has any 3D reconstructable series
    var supports3DReconstruction: Bool {
        return series.contains { $0.supports3DReconstruction }
    }
    
    /// Get series that support 3D reconstruction
    var reconstructableSeries: [DICOMSeries] {
        return series.filter { $0.supports3DReconstruction }
    }
    
    /// Get primary display series (usually the first CT or MR series)
    var primarySeries: DICOMSeries? {
        // Prefer CT, then MR, then others
        if let ctSeries = getSeries(byModality: "CT").first {
            return ctSeries
        }
        
        if let mrSeries = getSeries(byModality: "MR").first {
            return mrSeries
        }
        
        return series.first
    }
    
    /// Check if all series are loaded
    var allSeriesLoaded: Bool {
        return series.allSatisfy { $0.allInstancesLoaded }
    }
    
    /// Get study summary for display
    var studySummary: String {
        let modalityList = availableModalities.sorted().joined(separator: ", ")
        let instanceCount = totalInstanceCount
        
        var summary = ""
        if let description = studyDescription, !description.isEmpty {
            summary += description
        } else {
            summary += "Study"
        }
        
        summary += " (\(modalityList), \(instanceCount) images)"
        
        if let date = studyDate {
            summary += " - \(formatStudyDate(date))"
        }
        
        return summary
    }
    
    private func formatStudyDate(_ date: String) -> String {
        // Convert DICOM date format (YYYYMMDD) to readable format
        guard date.count == 8 else { return date }
        
        let year = String(date.prefix(4))
        let month = String(date.dropFirst(4).prefix(2))
        let day = String(date.dropFirst(6))
        
        return "\(month)/\(day)/\(year)"
    }
}

// MARK: - Identifiable
extension DICOMStudy: Identifiable {
    var id: String {
        return studyInstanceUID
    }
}

// MARK: - CustomStringConvertible
extension DICOMStudy: CustomStringConvertible {
    var description: String {
        return "DICOMStudy(UID: \(studyInstanceUID), Series: \(series.count), Patient: \(patientName ?? "Unknown"))"
    }
}
