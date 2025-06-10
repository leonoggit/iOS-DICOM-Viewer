//
//  ClinicalComplianceManager.swift
//  iOS_DICOMViewer
//
//  Clinical compliance framework for HIPAA, audit logging, and clinical validation
//  Ensures medical device software compliance and patient data protection
//

import Foundation
import os.log

final class ClinicalComplianceManager {
    static let shared = ClinicalComplianceManager()
    
    private let auditLogger: OSLog
    private let performanceLogger: OSLog
    
    private init() {
        auditLogger = OSLog(subsystem: "com.dicomviewer.audit", category: "HIPAA")
        performanceLogger = OSLog(subsystem: "com.dicomviewer.performance", category: "Clinical")
    }
    
    // MARK: - Audit Logging
    
    func logPatientDataAccess(patientID: String, studyUID: String, action: AuditAction) {
        os_log(.info, log: auditLogger, 
               "Patient data access - ID: %{private}@, Study: %{public}@, Action: %{public}@",
               patientID, studyUID, action.rawValue)
        
        // Store in secure audit database
        storeAuditRecord(AuditRecord(
            timestamp: Date(),
            userID: getCurrentUserID(),
            patientID: patientID,
            studyUID: studyUID,
            action: action
        ))
    }
    
    func logDICOMExport(studyUID: String, destination: ExportDestination) {
        os_log(.info, log: auditLogger,
               "DICOM export - Study: %{public}@, Destination: %{public}@",
               studyUID, destination.description)
    }
    
    // MARK: - Performance Monitoring
    
    func measureRenderingPerformance<T>(operation: String, 
                                       block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            os_log(.info, log: performanceLogger,
                   "Rendering operation '%{public}@' completed in %{public}.3f seconds",
                   operation, duration)
            
            if duration > 1.0 {
                os_log(.warning, log: performanceLogger,
                       "Slow rendering detected for '%{public}@': %{public}.3f seconds",
                       operation, duration)
            }
        }
        
        return try block()
    }
    
    // MARK: - Data Anonymization
    
    func anonymizeMetadata(_ metadata: DICOMMetadata) -> DICOMMetadata {
        var dict = metadata.toDictionary()
        
        // Remove patient identifiable information
        let tagsToRemove = [
            "PatientName",
            "PatientID",
            "PatientBirthDate",
            "PatientAddress",
            "PatientTelephoneNumbers",
            "ReferringPhysicianName"
        ]
        
        for tag in tagsToRemove {
            dict.removeValue(forKey: tag)
        }
        
        // Replace with anonymized values
        dict["PatientName"] = "ANONYMIZED"
        dict["PatientID"] = UUID().uuidString
        
        return DICOMMetadata(dictionary: dict)
    }
    
    // MARK: - Clinical Validation
    
    func validateClinicalIntegrity(of study: DICOMStudy) -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Check for required metadata
        if study.studyInstanceUID.isEmpty {
            issues.append(ValidationIssue(
                severity: .critical,
                message: "Missing Study Instance UID"
            ))
        }
        
        // Check series consistency
        for series in study.series {
            if series.instances.isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "Empty series: \(series.seriesInstanceUID)"
                ))
            }
            
            // Check slice spacing consistency for 3D series
            if series.supports3DReconstruction {
                if let spacing = validateSliceSpacing(series) {
                    issues.append(spacing)
                }
            }
        }
        
        return ValidationResult(
            isValid: !issues.contains(where: { $0.severity == .critical }),
            issues: issues
        )
    }
    
    private func validateSliceSpacing(_ series: DICOMSeries) -> ValidationIssue? {
        let positions = series.instances.compactMap { 
            $0.metadata.imagePositionPatient?.last 
        }
        
        guard positions.count > 2 else { return nil }
        
        let spacings = zip(positions, positions.dropFirst()).map { abs($1 - $0) }
        let averageSpacing = spacings.reduce(0, +) / Double(spacings.count)
        
        for spacing in spacings {
            let deviation = abs(spacing - averageSpacing) / averageSpacing
            if deviation > 0.1 { // 10% tolerance
                return ValidationIssue(
                    severity: .warning,
                    message: "Inconsistent slice spacing detected"
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func storeAuditRecord(_ record: AuditRecord) {
        // Implementation would store audit records in a secure database
        // For now, just log to system for demonstration
        print("Audit Record: \(record)")
    }
    
    private func getCurrentUserID() -> String {
        // Implementation would return current authenticated user ID
        // For now, return placeholder
        return "current_user"
    }
}

// MARK: - Supporting Types

enum AuditAction: String {
    case view = "VIEW"
    case export = "EXPORT"
    case modify = "MODIFY"
    case delete = "DELETE"
    case print = "PRINT"
}

struct AuditRecord {
    let timestamp: Date
    let userID: String
    let patientID: String
    let studyUID: String
    let action: AuditAction
}

enum ExportDestination {
    case localFile(URL)
    case network(String)
    case print
    
    var description: String {
        switch self {
        case .localFile(let url):
            return "Local file: \(url.lastPathComponent)"
        case .network(let destination):
            return "Network: \(destination)"
        case .print:
            return "Print"
        }
    }
}

struct ValidationResult {
    let isValid: Bool
    let issues: [ValidationIssue]
}

struct ValidationIssue {
    enum Severity {
        case info
        case warning
        case critical
    }
    
    let severity: Severity
    let message: String
}

// MARK: - Extensions for Clinical Compliance

extension DICOMMetadata {
    func toDictionary() -> [String: Any] {
        // Implementation would convert metadata to dictionary format
        // For now, return placeholder
        return [:]
    }
    
    init(dictionary: [String: Any]) {
        // Implementation would create metadata from dictionary
        // For now, use existing init
        self.init(
            sopInstanceUID: dictionary["SOPInstanceUID"] as? String ?? "",
            sopClassUID: dictionary["SOPClassUID"] as? String ?? "",
            studyInstanceUID: dictionary["StudyInstanceUID"] as? String ?? "",
            seriesInstanceUID: dictionary["SeriesInstanceUID"] as? String ?? "",
            instanceNumber: dictionary["InstanceNumber"] as? Int ?? 0,
            rows: dictionary["Rows"] as? Int ?? 0,
            columns: dictionary["Columns"] as? Int ?? 0,
            bitsAllocated: dictionary["BitsAllocated"] as? Int ?? 0,
            bitsStored: dictionary["BitsStored"] as? Int ?? 0,
            pixelRepresentation: dictionary["PixelRepresentation"] as? Int ?? 0,
            photometricInterpretation: dictionary["PhotometricInterpretation"] as? String ?? "",
            imagePositionPatient: dictionary["ImagePositionPatient"] as? [Double],
            imageOrientationPatient: dictionary["ImageOrientationPatient"] as? [Double],
            pixelSpacing: dictionary["PixelSpacing"] as? [Double],
            sliceThickness: dictionary["SliceThickness"] as? Double,
            windowCenter: dictionary["WindowCenter"] as? [Double],
            windowWidth: dictionary["WindowWidth"] as? [Double],
            rescaleIntercept: dictionary["RescaleIntercept"] as? Double ?? 0,
            rescaleSlope: dictionary["RescaleSlope"] as? Double ?? 1,
            modality: dictionary["Modality"] as? String ?? "",
            patientName: dictionary["PatientName"] as? String,
            patientID: dictionary["PatientID"] as? String,
            studyDate: dictionary["StudyDate"] as? String,
            studyTime: dictionary["StudyTime"] as? String,
            studyDescription: dictionary["StudyDescription"] as? String,
            seriesDescription: dictionary["SeriesDescription"] as? String,
            protocolName: dictionary["ProtocolName"] as? String,
            bodyPartExamined: dictionary["BodyPartExamined"] as? String,
            transferSyntaxUID: dictionary["TransferSyntaxUID"] as? String
        )
    }
}
