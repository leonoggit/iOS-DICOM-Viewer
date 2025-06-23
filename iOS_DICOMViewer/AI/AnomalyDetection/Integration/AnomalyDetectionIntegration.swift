//
//  AnomalyDetectionIntegration.swift
//  iOS_DICOMViewer
//
//  Integration layer for Real-Time Anomaly Detection with main DICOM viewer
//

import UIKit
import CoreML
import Metal

// MARK: - Integration with Main Tab Controller
extension MainTabBarController {
    
    func setupAnomalyDetectionTab() {
        // Add AI Detection tab if iOS 26+
        if #available(iOS 26.0, *) {
            let anomalyVC = AnomalyDetectionViewController()
            anomalyVC.tabBarItem = UITabBarItem(
                title: "AI Detection",
                image: UIImage(systemName: "brain"),
                selectedImage: UIImage(systemName: "brain.fill")
            )
            
            // Insert before settings tab
            var viewControllers = self.viewControllers ?? []
            viewControllers.insert(UINavigationController(rootViewController: anomalyVC), at: viewControllers.count - 1)
            self.viewControllers = viewControllers
        }
    }
}

// MARK: - Integration with ViewerViewController
extension ViewerViewController {
    
    @objc func enableAnomalyDetection() {
        guard #available(iOS 26.0, *) else {
            showAlert(title: "Not Available", 
                     message: "Anomaly Detection requires iOS 26 or later")
            return
        }
        
        // Add anomaly detection button to toolbar
        let aiButton = UIBarButtonItem(
            image: UIImage(systemName: "brain.head.profile"),
            style: .plain,
            target: self,
            action: #selector(showAnomalyDetection)
        )
        aiButton.tintColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        
        var items = navigationItem.rightBarButtonItems ?? []
        items.append(aiButton)
        navigationItem.rightBarButtonItems = items
    }
    
    @objc private func showAnomalyDetection() {
        guard #available(iOS 26.0, *),
              let currentInstance = getCurrentInstance() else { return }
        
        let anomalyVC = AnomalyDetectionViewController()
        anomalyVC.loadInstance(currentInstance, from: study)
        
        let navController = UINavigationController(rootViewController: anomalyVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
}

// MARK: - Integration with StudyListViewController
extension StudyListViewController {
    
    func showAnomalyDetectionForStudy(_ study: DICOMStudy) {
        guard #available(iOS 26.0, *) else { return }
        
        let anomalyVC = AnomalyDetectionViewController()
        if let firstInstance = study.series.first?.instances.first {
            anomalyVC.loadInstance(firstInstance, from: study)
        }
        
        navigationController?.pushViewController(anomalyVC, animated: true)
    }
    
    // Add batch processing option
    func processStudiesForAnomalies(_ studies: [DICOMStudy]) {
        guard #available(iOS 26.0, *) else { return }
        
        let batchProcessor = AnomalyBatchProcessor()
        batchProcessor.processStudies(studies) { results in
            self.displayBatchResults(results)
        }
    }
}

// MARK: - Service Manager Integration
extension DICOMServiceManager {
    
    private struct AssociatedKeys {
        static var anomalyEngine = "anomalyEngine"
    }
    
    @available(iOS 26.0, *)
    var anomalyDetectionEngine: AnomalyDetectionEngine? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.anomalyEngine) as? AnomalyDetectionEngine
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.anomalyEngine, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    @available(iOS 26.0, *)
    func initializeAnomalyDetection() {
        anomalyDetectionEngine = AnomalyDetectionEngine()
        print("✅ Anomaly Detection Engine initialized")
    }
}

// MARK: - Batch Processing
@available(iOS 26.0, *)
class AnomalyBatchProcessor {
    
    private let engine = AnomalyDetectionEngine()
    private let processingQueue = DispatchQueue(label: "anomaly.batch", qos: .userInitiated)
    
    func processStudies(_ studies: [DICOMStudy], 
                       progressHandler: ((Float) -> Void)? = nil,
                       completion: @escaping ([BatchProcessingResult]) -> Void) {
        
        var results: [BatchProcessingResult] = []
        let totalInstances = studies.flatMap { $0.series }.flatMap { $0.instances }.count
        var processedCount = 0
        
        processingQueue.async {
            for study in studies {
                for series in study.series {
                    for instance in series.instances {
                        Task {
                            do {
                                let result = try await self.engine.detectAnomalies(
                                    in: instance,
                                    modality: series.modality
                                )
                                
                                let batchResult = BatchProcessingResult(
                                    studyUID: study.studyInstanceUID,
                                    seriesUID: series.seriesInstanceUID,
                                    instanceUID: instance.metadata.sopInstanceUID,
                                    anomalyResult: result
                                )
                                
                                results.append(batchResult)
                                
                                processedCount += 1
                                let progress = Float(processedCount) / Float(totalInstances)
                                
                                await MainActor.run {
                                    progressHandler?(progress)
                                }
                                
                            } catch {
                                print("❌ Failed to process instance: \(error)")
                            }
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
    }
}

struct BatchProcessingResult {
    let studyUID: String
    let seriesUID: String
    let instanceUID: String
    let anomalyResult: AnomalyDetectionResult
}

// MARK: - Settings Integration
extension SettingsViewController {
    
    func addAnomalyDetectionSettings() {
        guard #available(iOS 26.0, *) else { return }
        
        let aiSection = SettingsSection(
            title: "AI Anomaly Detection",
            items: [
                SettingsItem(
                    title: "Enable Real-Time Detection",
                    type: .toggle(isOn: UserDefaults.standard.bool(forKey: "enableRealTimeAnomalyDetection")),
                    action: { isOn in
                        UserDefaults.standard.set(isOn, forKey: "enableRealTimeAnomalyDetection")
                    }
                ),
                SettingsItem(
                    title: "Confidence Threshold",
                    type: .slider(value: UserDefaults.standard.float(forKey: "anomalyConfidenceThreshold"), min: 0.5, max: 0.95),
                    action: { value in
                        UserDefaults.standard.set(value, forKey: "anomalyConfidenceThreshold")
                    }
                ),
                SettingsItem(
                    title: "Download Models",
                    type: .button,
                    action: { _ in
                        self.downloadAnomalyDetectionModels()
                    }
                ),
                SettingsItem(
                    title: "Model Info",
                    type: .disclosure,
                    action: { _ in
                        self.showModelInfo()
                    }
                )
            ]
        )
        
        // Add to settings sections
        addSection(aiSection)
    }
    
    @available(iOS 26.0, *)
    private func downloadAnomalyDetectionModels() {
        let downloader = ModelDownloader()
        
        let progressVC = ProgressViewController()
        present(progressVC, animated: true)
        
        Task {
            do {
                // Download chest X-ray model
                try await downloader.downloadModel(
                    name: "ChestXRayAnomalyDetection",
                    url: URL(string: "https://models.example.com/chest-xray-v2.mlmodel")!,
                    progressHandler: { progress in
                        await MainActor.run {
                            progressVC.updateProgress(progress, status: "Downloading Chest X-Ray Model...")
                        }
                    }
                )
                
                // Download brain MRI model
                try await downloader.downloadModel(
                    name: "BrainMRIAnomalyDetection",
                    url: URL(string: "https://models.example.com/brain-mri-v2.mlmodel")!,
                    progressHandler: { progress in
                        await MainActor.run {
                            progressVC.updateProgress(progress, status: "Downloading Brain MRI Model...")
                        }
                    }
                )
                
                await MainActor.run {
                    progressVC.dismiss(animated: true) {
                        self.showAlert(title: "Success", message: "Models downloaded successfully")
                    }
                }
                
            } catch {
                await MainActor.run {
                    progressVC.dismiss(animated: true) {
                        self.showAlert(title: "Error", message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func showModelInfo() {
        let infoVC = ModelInfoViewController()
        navigationController?.pushViewController(infoVC, animated: true)
    }
}

// MARK: - Model Management
@available(iOS 26.0, *)
class ModelDownloader {
    
    func downloadModel(name: String, url: URL, progressHandler: ((Float) async -> Void)?) async throws {
        let session = URLSession.shared
        
        let (localURL, response) = try await session.download(from: url) { bytesWritten, totalBytes in
            let progress = Float(bytesWritten) / Float(totalBytes)
            Task {
                await progressHandler?(progress)
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ModelDownloadError.invalidResponse
        }
        
        // Move to models directory
        let modelURL = getModelsDirectory().appendingPathComponent("\(name).mlmodelc")
        try FileManager.default.moveItem(at: localURL, to: modelURL)
        
        // Compile model if needed
        let compiledURL = try await MLModel.compileModel(at: modelURL)
        try FileManager.default.moveItem(at: compiledURL, to: modelURL)
    }
    
    private func getModelsDirectory() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDirectory = documentsDirectory.appendingPathComponent("MLModels")
        
        if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
            try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        }
        
        return modelsDirectory
    }
}

enum ModelDownloadError: Error {
    case invalidResponse
    case compilationFailed
}

// MARK: - Clinical Integration
@available(iOS 26.0, *)
extension ClinicalComplianceManager {
    
    func logAnomalyDetection(_ result: AnomalyDetectionResult, 
                           for instanceUID: String,
                           action: AuditAction = .aiAnalysis) {
        
        let event = AuditEvent(
            timestamp: Date(),
            userID: getCurrentUserID(),
            action: action,
            resourceType: .anomalyDetection,
            resourceID: instanceUID,
            details: [
                "anomalyCount": result.anomalies.count,
                "confidence": result.confidence,
                "processingTime": result.processingTime,
                "urgencyLevel": result.clinicalContext.urgencyLevel
            ]
        )
        
        auditLogger.log(event)
    }
}

// MARK: - Export Integration
extension AnomalyDetectionResult {
    
    func exportAsDICOMSR() throws -> Data {
        // Create DICOM Structured Report
        let srBuilder = DICOMStructuredReportBuilder()
        
        srBuilder.setTitle("AI Anomaly Detection Report")
        srBuilder.setReportType(.diagnosticImaging)
        
        // Add findings
        for anomaly in anomalies {
            srBuilder.addFinding(
                code: anomaly.type.rawValue,
                value: anomaly.explanation,
                confidence: anomaly.confidence,
                location: anomaly.location
            )
        }
        
        // Add clinical context
        srBuilder.addClinicalContext(clinicalContext)
        
        return try srBuilder.build()
    }
    
    func exportAsJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        return try? encoder.encode(self)
    }
}

// MARK: - Notification Integration
@available(iOS 26.0, *)
extension AnomalyDetectionEngine {
    
    func sendCriticalFindingNotification(_ anomaly: DetectedAnomaly, study: DICOMStudy) {
        guard anomaly.severity == .critical else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Critical Finding Detected"
        content.body = "\(anomaly.type.rawValue) detected in \(study.patientName ?? "Patient")"
        content.sound = .defaultCritical
        content.categoryIdentifier = "CRITICAL_FINDING"
        
        // Add actions
        content.userInfo = [
            "studyUID": study.studyInstanceUID,
            "anomalyType": anomaly.type.rawValue
        ]
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Performance Monitoring
@available(iOS 26.0, *)
extension PerformanceMetrics {
    
    func exportMetrics() -> [String: Any] {
        return [
            "averageInferenceTime": averageInferenceTime,
            "totalInferences": inferenceTimes.count,
            "minTime": inferenceTimes.min() ?? 0,
            "maxTime": inferenceTimes.max() ?? 0,
            "deviceModel": UIDevice.current.model,
            "osVersion": UIDevice.current.systemVersion
        ]
    }
}