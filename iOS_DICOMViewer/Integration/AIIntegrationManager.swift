//
//  AIIntegrationManager.swift
//  iOS_DICOMViewer
//
//  Central Integration Manager for AI-Powered Features
//  Connecting Report Generation and Anomaly Detection Systems
//

import UIKit
import SwiftUI
import Combine

// MARK: - AI Integration Manager

class AIIntegrationManager {
    
    // MARK: - Singleton
    
    static let shared = AIIntegrationManager()
    
    // MARK: - Properties
    
    private let reportEngine = MedicalReportEngine()
    private let anomalyDetector = AnomalyDetectionSystem()
    private var cancellables = Set<AnyCancellable>()
    
    // Published state
    @Published var isProcessing = false
    @Published var currentTask: AITask?
    @Published var lastReport: MedicalReport?
    @Published var lastAnomalyResult: AnomalyDetectionResult?
    
    // MARK: - Initialization
    
    private init() {
        setupBindings()
        preloadModels()
    }
    
    // MARK: - Public Methods
    
    /// Perform comprehensive AI analysis on a study
    func performComprehensiveAnalysis(
        study: DICOMStudy,
        images: [DICOMInstance],
        options: AnalysisOptions = .default
    ) async throws -> ComprehensiveAnalysisResult {
        
        isProcessing = true
        currentTask = .comprehensiveAnalysis
        
        defer {
            isProcessing = false
            currentTask = nil
        }
        
        // Run anomaly detection and report generation in parallel
        async let anomalyResult = anomalyDetector.detectAnomalies(
            in: images,
            studyContext: study,
            detectionMode: options.detectionMode,
            sensitivityLevel: options.sensitivityLevel
        )
        
        async let reportResult = reportEngine.generateReport(
            for: study,
            images: images,
            reportType: options.reportType
        )
        
        // Wait for both results
        let (anomalies, report) = try await (anomalyResult, reportResult)
        
        // Store results
        lastAnomalyResult = anomalies
        lastReport = report
        
        // Generate integrated insights
        let insights = generateIntegratedInsights(
            anomalies: anomalies,
            report: report
        )
        
        return ComprehensiveAnalysisResult(
            anomalyDetection: anomalies,
            generatedReport: report,
            integratedInsights: insights,
            recommendations: generateRecommendations(anomalies: anomalies, report: report),
            confidence: calculateOverallConfidence(anomalies: anomalies, report: report)
        )
    }
    
    /// Quick AI analysis for real-time feedback
    func performQuickAnalysis(
        image: DICOMInstance
    ) async throws -> QuickAnalysisResult {
        
        // Perform rapid anomaly detection
        let anomalies = try await detectQuickAnomalies(in: image)
        
        // Generate brief findings
        let findings = generateQuickFindings(from: anomalies)
        
        return QuickAnalysisResult(
            anomalies: anomalies,
            findings: findings,
            urgencyLevel: determineUrgency(anomalies),
            suggestedActions: suggestQuickActions(anomalies)
        )
    }
}

// MARK: - UI Integration Extensions

extension ModernViewerViewController {
    
    /// Add AI analysis buttons to the viewer
    func addAIAnalysisButtons() {
        let aiButtonsView = AIAnalysisButtonsView { [weak self] action in
            self?.handleAIAction(action)
        }
        
        let hostingController = UIHostingController(rootView: aiButtonsView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            hostingController.view.widthAnchor.constraint(equalToConstant: 60),
            hostingController.view.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    private func handleAIAction(_ action: AIAction) {
        switch action {
        case .detectAnomalies:
            showAnomalyDetection()
        case .generateReport:
            showReportGeneration()
        case .quickAnalysis:
            performQuickAnalysis()
        case .comprehensiveAnalysis:
            performComprehensiveAnalysis()
        }
    }
    
    private func showAnomalyDetection() {
        guard let study = study else { return }
        
        let anomalyView = AnomalyVisualizationView(
            study: study,
            images: study.allInstances
        )
        
        let hostingController = UIHostingController(rootView: anomalyView)
        hostingController.modalPresentationStyle = .fullScreen
        present(hostingController, animated: true)
    }
    
    private func performQuickAnalysis() {
        guard let currentInstance = currentInstance else { return }
        
        showLoadingOverlay(message: "Running AI Analysis...")
        
        Task {
            do {
                let result = try await AIIntegrationManager.shared.performQuickAnalysis(
                    image: currentInstance
                )
                
                await MainActor.run {
                    hideLoadingOverlay()
                    showQuickAnalysisResults(result)
                }
            } catch {
                await MainActor.run {
                    hideLoadingOverlay()
                    showError(error)
                }
            }
        }
    }
    
    private func showQuickAnalysisResults(_ result: QuickAnalysisResult) {
        let resultsView = QuickAnalysisResultsView(result: result)
        let hostingController = UIHostingController(rootView: resultsView)
        
        // Present as popover on iPad, sheet on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad {
            hostingController.modalPresentationStyle = .popover
            hostingController.popoverPresentationController?.sourceView = view
            hostingController.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }
        
        present(hostingController, animated: true)
    }
}

// MARK: - AI Analysis Buttons View

struct AIAnalysisButtonsView: View {
    let onAction: (AIAction) -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Main AI button
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 56, height: 56)
                        .shadow(color: .cyan.opacity(0.5), radius: 8)
                    
                    Image(systemName: "brain")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            
            // Expanded options
            if isExpanded {
                VStack(spacing: 8) {
                    AIActionButton(
                        icon: "eye.fill",
                        title: "Anomalies",
                        color: .red
                    ) {
                        onAction(.detectAnomalies)
                    }
                    
                    AIActionButton(
                        icon: "doc.text.fill",
                        title: "Report",
                        color: .green
                    ) {
                        onAction(.generateReport)
                    }
                    
                    AIActionButton(
                        icon: "bolt.fill",
                        title: "Quick",
                        color: .orange
                    ) {
                        onAction(.quickAnalysis)
                    }
                    
                    AIActionButton(
                        icon: "sparkles",
                        title: "Full",
                        color: .purple
                    ) {
                        onAction(.comprehensiveAnalysis)
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
}

struct AIActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(color)
                            .shadow(color: color.opacity(0.5), radius: 4)
                    )
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Quick Analysis Results View

struct QuickAnalysisResultsView: View {
    let result: QuickAnalysisResult
    @State private var showDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Urgency indicator
                UrgencyIndicator(level: result.urgencyLevel)
                    .padding(.top)
                
                // Summary
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.cyan)
                        Text("AI Quick Analysis")
                            .font(.headline)
                    }
                    
                    if result.anomalies.isEmpty {
                        Label("No anomalies detected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("\(result.anomalies.count) anomalies detected", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Findings
                if !result.findings.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Key Findings")
                            .font(.headline)
                        
                        ForEach(result.findings, id: \.self) { finding in
                            HStack {
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 6, height: 6)
                                Text(finding)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Suggested actions
                if !result.suggestedActions.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Suggested Actions")
                            .font(.headline)
                        
                        ForEach(result.suggestedActions, id: \.self) { action in
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(.blue)
                                    Text(action)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("View Details") {
                        showDetails = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Run Full Analysis") {
                        // Trigger comprehensive analysis
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Quick Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss
                    }
                }
            }
        }
    }
}

struct UrgencyIndicator: View {
    let level: UrgencyLevel
    
    var color: Color {
        switch level {
        case .routine: return .green
        case .urgent: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch level {
        case .routine: return "clock"
        case .urgent: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon"
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
            Text(level.displayName)
                .font(.headline)
        }
        .foregroundColor(color)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color, lineWidth: 2)
                )
        )
    }
}

// MARK: - Supporting Types

struct AnalysisOptions {
    let detectionMode: DetectionMode
    let sensitivityLevel: SensitivityLevel
    let reportType: ReportType
    let includeTemporalAnalysis: Bool
    let generateVisualizations: Bool
    
    static let `default` = AnalysisOptions(
        detectionMode: .comprehensive,
        sensitivityLevel: .balanced,
        reportType: .diagnostic,
        includeTemporalAnalysis: true,
        generateVisualizations: true
    )
}

struct ComprehensiveAnalysisResult {
    let anomalyDetection: AnomalyDetectionResult
    let generatedReport: MedicalReport
    let integratedInsights: [IntegratedInsight]
    let recommendations: [ClinicalRecommendation]
    let confidence: OverallConfidence
}

struct QuickAnalysisResult {
    let anomalies: [MedicalAnomaly]
    let findings: [String]
    let urgencyLevel: UrgencyLevel
    let suggestedActions: [String]
}

struct IntegratedInsight {
    let type: InsightType
    let description: String
    let confidence: Float
    let supportingEvidence: [String]
    
    enum InsightType {
        case correlatedFinding
        case progressiveChange
        case incidentalFinding
        case criticalAlert
    }
}

struct ClinicalRecommendation {
    let action: String
    let priority: Priority
    let rationale: String
    let evidence: [String]
    
    enum Priority {
        case immediate, urgent, routine, optional
    }
}

struct OverallConfidence {
    let score: Float
    let factors: [String: Float]
    let reliability: ReliabilityLevel
    
    enum ReliabilityLevel {
        case high, moderate, low
    }
}

enum AITask {
    case anomalyDetection
    case reportGeneration
    case quickAnalysis
    case comprehensiveAnalysis
}

enum AIAction {
    case detectAnomalies
    case generateReport
    case quickAnalysis
    case comprehensiveAnalysis
}

enum UrgencyLevel {
    case routine
    case urgent
    case critical
    
    var displayName: String {
        switch self {
        case .routine: return "Routine"
        case .urgent: return "Urgent Review Recommended"
        case .critical: return "Critical - Immediate Action Required"
        }
    }
}

// MARK: - Private Extensions

private extension AIIntegrationManager {
    
    func setupBindings() {
        // Monitor progress from both engines
        reportEngine.$generationProgress
            .sink { [weak self] progress in
                // Update UI with progress
            }
            .store(in: &cancellables)
        
        anomalyDetector.$detectionProgress
            .sink { [weak self] progress in
                // Update UI with progress
            }
            .store(in: &cancellables)
    }
    
    func preloadModels() {
        Task {
            // Preload ML models for better performance
            print("🤖 Preloading AI models...")
        }
    }
    
    func generateIntegratedInsights(
        anomalies: AnomalyDetectionResult,
        report: MedicalReport
    ) -> [IntegratedInsight] {
        var insights: [IntegratedInsight] = []
        
        // Correlate anomalies with report findings
        for anomaly in anomalies.anomalies {
            if let correlatedFinding = findCorrelatedFinding(anomaly, in: report) {
                insights.append(IntegratedInsight(
                    type: .correlatedFinding,
                    description: "AI-detected \(anomaly.type.displayName) correlates with reported \(correlatedFinding.type.displayName)",
                    confidence: (anomaly.confidence.overall + correlatedFinding.confidence) / 2,
                    supportingEvidence: [
                        "Anomaly detection confidence: \(Int(anomaly.confidence.overall * 100))%",
                        "Report finding confidence: \(Int(correlatedFinding.confidence * 100))%"
                    ]
                ))
            }
        }
        
        // Identify critical alerts
        let criticalAnomalies = anomalies.anomalies.filter { $0.severity == .critical }
        for critical in criticalAnomalies {
            insights.append(IntegratedInsight(
                type: .criticalAlert,
                description: "Critical \(critical.type.displayName) requires immediate attention",
                confidence: critical.confidence.overall,
                supportingEvidence: critical.characteristics
            ))
        }
        
        return insights
    }
    
    func findCorrelatedFinding(_ anomaly: MedicalAnomaly, in report: MedicalReport) -> MedicalFinding? {
        report.findings.first { finding in
            // Check if locations match
            let locationMatch = finding.location.displayName.contains(anomaly.anatomicalRegion) ||
                               anomaly.anatomicalRegion.contains(finding.location.displayName)
            
            // Check if types correlate
            let typeMatch = correlateTypes(anomalyType: anomaly.type, findingType: finding.type)
            
            return locationMatch && typeMatch
        }
    }
    
    func correlateTypes(anomalyType: MedicalAnomaly.AnomalyType, findingType: FindingType) -> Bool {
        switch (anomalyType, findingType) {
        case (.mass, .mass), (.nodule, .nodule), (.lesion, .mass):
            return true
        case (.hemorrhage, .hemorrhage), (.edema, .edema):
            return true
        case (.calcification, .calcification):
            return true
        default:
            return false
        }
    }
}