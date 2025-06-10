import Foundation

/// DICOM Series model - represents a collection of related instances
/// Follows OHIF's series organization pattern
class DICOMSeries {
    let seriesInstanceUID: String
    let seriesNumber: Int?
    let seriesDescription: String?
    let modality: String
    let studyInstanceUID: String
    
    private(set) var instances: [DICOMInstance] = []
    private(set) var isLoaded: Bool = false
    
    // Series-level metadata
    let frameOfReferenceUID: String?
    let acquisitionDate: String?
    let acquisitionTime: String?
    
    init(seriesInstanceUID: String, 
         seriesNumber: Int? = nil,
         seriesDescription: String? = nil,
         modality: String,
         studyInstanceUID: String,
         frameOfReferenceUID: String? = nil) {
        self.seriesInstanceUID = seriesInstanceUID
        self.seriesNumber = seriesNumber
        self.seriesDescription = seriesDescription
        self.modality = modality
        self.studyInstanceUID = studyInstanceUID
        self.frameOfReferenceUID = frameOfReferenceUID
        self.acquisitionDate = nil
        self.acquisitionTime = nil
    }
    
    /// Add an instance to this series
    func addInstance(_ instance: DICOMInstance) {
        guard instance.metadata.seriesInstanceUID == seriesInstanceUID else {
            return
        }
        
        instances.append(instance)
        sortInstances()
    }
    
    /// Remove an instance from this series
    func removeInstance(_ instance: DICOMInstance) {
        instances.removeAll { $0.id == instance.id }
    }
    
    /// Sort instances by instance number for proper ordering
    private func sortInstances() {
        instances.sort { first, second in
            let firstInstanceNumber = first.metadata.instanceNumber ?? 0
            let secondInstanceNumber = second.metadata.instanceNumber ?? 0
            return firstInstanceNumber < secondInstanceNumber
        }
    }
    
    /// Load all instances in this series
    func loadAllInstances() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for instance in instances {
                group.addTask {
                    try await instance.loadPixelData()
                }
            }
            
            try await group.waitForAll()
        }
        
        isLoaded = true
    }
    
    /// Get instances sorted by slice position for 3D reconstruction
    var sortedBySlicePosition: [DICOMInstance] {
        return instances.sorted { first, second in
            guard let firstPosition = first.metadata.imagePositionPatient,
                  let secondPosition = second.metadata.imagePositionPatient,
                  firstPosition.count >= 3,
                  secondPosition.count >= 3 else {
                return (first.metadata.instanceNumber ?? 0) < (second.metadata.instanceNumber ?? 0)
            }
            
            // Sort by Z position (assuming axial slices)
            return firstPosition[2] < secondPosition[2]
        }
    }
    
    /// Check if this series supports 3D reconstruction
    var supports3DReconstruction: Bool {
        guard instances.count > 1 else { return false }
        
        // Check if we have consistent image orientation and position data
        let orientationConsistent = instances.allSatisfy { instance in
            return instance.metadata.imageOrientationPatient != nil &&
                   instance.metadata.imagePositionPatient != nil
        }
        
        return orientationConsistent && (modality == "CT" || modality == "MR" || modality == "PT")
    }
    
    /// Get slice thickness for 3D reconstruction
    var sliceThickness: Double? {
        // Try to get from metadata first
        if let thickness = instances.first?.metadata.sliceThickness {
            return thickness
        }
        
        // Calculate from slice positions
        let sortedInstances = sortedBySlicePosition
        guard sortedInstances.count > 1,
              let firstPosition = sortedInstances[0].metadata.imagePositionPatient,
              let secondPosition = sortedInstances[1].metadata.imagePositionPatient,
              firstPosition.count >= 3,
              secondPosition.count >= 3 else {
            return nil
        }
        
        return abs(secondPosition[2] - firstPosition[2])
    }
    
    /// Get pixel spacing from first instance
    var pixelSpacing: (x: Double, y: Double)? {
        return instances.first?.pixelSpacing
    }
    
    /// Check if all instances are loaded
    var allInstancesLoaded: Bool {
        return instances.allSatisfy { $0.isLoaded }
    }
    
    /// Get total number of frames across all instances
    var totalFrameCount: Int {
        return instances.reduce(0) { $0 + $1.frameCount }
    }
}

// MARK: - Identifiable
extension DICOMSeries: Identifiable {
    var id: String {
        return seriesInstanceUID
    }
}

// MARK: - CustomStringConvertible
extension DICOMSeries: CustomStringConvertible {
    var description: String {
        return "DICOMSeries(UID: \(seriesInstanceUID), Modality: \(modality), Instances: \(instances.count))"
    }
}
