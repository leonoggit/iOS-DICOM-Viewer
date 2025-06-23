//
//  AnomalyDetectionViewController.swift
//  iOS_DICOMViewer
//
//  Interactive UI for real-time anomaly detection with explanations
//

import UIKit
import Metal
import MetalKit
import CoreML

@available(iOS 26.0, *)
class AnomalyDetectionViewController: UIViewController {
    
    // MARK: - Properties
    private var study: DICOMStudy?
    private var currentInstance: DICOMInstance?
    private let anomalyEngine = AnomalyDetectionEngine()
    private var detectionResults: AnomalyDetectionResult?
    private var isRealTimeEnabled = true
    
    // MARK: - UI Components
    
    // Main image view with Metal-accelerated overlays
    private lazy var imageView: MTKView = {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.delegate = self
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 30
        return view
    }()
    
    // Explanation panel
    private lazy var explanationPanel: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 27/255, green: 36/255, blue: 39/255, alpha: 0.95)
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Anomaly list
    private lazy var anomalyTableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.register(AnomalyCell.self, forCellReuseIdentifier: "AnomalyCell")
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    // Confidence meter
    private lazy var confidenceMeter: ConfidenceMeterView = {
        let meter = ConfidenceMeterView()
        meter.translatesAutoresizingMaskIntoConstraints = false
        return meter
    }()
    
    // Real-time toggle
    private lazy var realTimeToggle: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = true
        toggle.onTintColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        toggle.addTarget(self, action: #selector(realTimeToggled), for: .valueChanged)
        return toggle
    }()
    
    // Processing indicator
    private lazy var processingIndicator: ProcessingIndicatorView = {
        let indicator = ProcessingIndicatorView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isHidden = true
        return indicator
    }()
    
    // Explanation detail view
    private lazy var explanationDetailView: ExplanationDetailView = {
        let view = ExplanationDetailView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    // Clinical actions panel
    private lazy var clinicalActionsPanel: ClinicalActionsPanel = {
        let panel = ClinicalActionsPanel()
        panel.delegate = self
        panel.translatesAutoresizingMaskIntoConstraints = false
        return panel
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupGestures()
        
        if #available(iOS 26.0, *) {
            setupFoundationModelsIntegration()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let instance = currentInstance {
            startAnomalyDetection(for: instance)
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 17/255, green: 22/255, blue: 24/255, alpha: 1.0)
        
        // Add subviews
        view.addSubview(imageView)
        view.addSubview(explanationPanel)
        view.addSubview(processingIndicator)
        view.addSubview(explanationDetailView)
        
        // Setup explanation panel content
        setupExplanationPanel()
        
        NSLayoutConstraint.activate([
            // Image view - takes up most of the screen
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
            
            // Explanation panel
            explanationPanel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            explanationPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            explanationPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            explanationPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            
            // Processing indicator (overlays image)
            processingIndicator.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            processingIndicator.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            processingIndicator.widthAnchor.constraint(equalToConstant: 100),
            processingIndicator.heightAnchor.constraint(equalToConstant: 100),
            
            // Explanation detail (full screen overlay)
            explanationDetailView.topAnchor.constraint(equalTo: view.topAnchor),
            explanationDetailView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            explanationDetailView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            explanationDetailView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupExplanationPanel() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Header with real-time toggle
        let headerView = createHeaderView()
        
        // Confidence meter
        let confidenceContainer = UIView()
        confidenceContainer.addSubview(confidenceMeter)
        NSLayoutConstraint.activate([
            confidenceMeter.leadingAnchor.constraint(equalTo: confidenceContainer.leadingAnchor),
            confidenceMeter.trailingAnchor.constraint(equalTo: confidenceContainer.trailingAnchor),
            confidenceMeter.topAnchor.constraint(equalTo: confidenceContainer.topAnchor),
            confidenceMeter.bottomAnchor.constraint(equalTo: confidenceContainer.bottomAnchor),
            confidenceMeter.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Anomaly list container
        let listContainer = UIView()
        listContainer.addSubview(anomalyTableView)
        NSLayoutConstraint.activate([
            anomalyTableView.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor),
            anomalyTableView.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor),
            anomalyTableView.topAnchor.constraint(equalTo: listContainer.topAnchor),
            anomalyTableView.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor)
        ])
        
        // Clinical actions
        stackView.addArrangedSubview(headerView)
        stackView.addArrangedSubview(confidenceContainer)
        stackView.addArrangedSubview(listContainer)
        stackView.addArrangedSubview(clinicalActionsPanel)
        
        explanationPanel.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: explanationPanel.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: explanationPanel.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: explanationPanel.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: explanationPanel.bottomAnchor, constant: -16)
        ])
    }
    
    private func createHeaderView() -> UIView {
        let headerView = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = "AI Anomaly Detection"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let realTimeLabel = UILabel()
        realTimeLabel.text = "Real-time"
        realTimeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        realTimeLabel.textColor = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        realTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        realTimeToggle.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(realTimeLabel)
        headerView.addSubview(realTimeToggle)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            realTimeToggle.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            realTimeToggle.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            realTimeLabel.trailingAnchor.constraint(equalTo: realTimeToggle.leadingAnchor, constant: -8),
            realTimeLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            headerView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return headerView
    }
    
    private func setupNavigationBar() {
        title = "Anomaly Detection"
        
        let infoButton = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(showInfo)
        )
        
        let exportButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(exportResults)
        )
        
        navigationItem.rightBarButtonItems = [exportButton, infoButton]
    }
    
    private func setupGestures() {
        // Tap gesture for showing detailed explanations
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        imageView.addGestureRecognizer(tapGesture)
        
        // Pinch gesture for zooming
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        imageView.addGestureRecognizer(pinchGesture)
    }
    
    @available(iOS 26.0, *)
    private func setupFoundationModelsIntegration() {
        // Setup iOS 26 Foundation Models Framework integration
        // This would enhance anomaly explanations with natural language
    }
    
    // MARK: - Anomaly Detection
    
    private func startAnomalyDetection(for instance: DICOMInstance) {
        guard isRealTimeEnabled else { return }
        
        processingIndicator.startAnimating()
        processingIndicator.isHidden = false
        
        Task {
            do {
                let previousStudies = loadPreviousStudies(for: instance)
                
                let result = try await anomalyEngine.detectAnomalies(
                    in: instance,
                    modality: instance.metadata.modality,
                    previousStudies: previousStudies
                )
                
                await MainActor.run {
                    self.processingIndicator.stopAnimating()
                    self.processingIndicator.isHidden = true
                    self.displayResults(result)
                }
                
            } catch {
                await MainActor.run {
                    self.processingIndicator.stopAnimating()
                    self.processingIndicator.isHidden = true
                    self.showError(error)
                }
            }
        }
    }
    
    private func displayResults(_ result: AnomalyDetectionResult) {
        self.detectionResults = result
        
        // Update confidence meter
        confidenceMeter.setConfidence(result.confidence)
        
        // Reload anomaly list
        anomalyTableView.reloadData()
        
        // Update clinical actions
        clinicalActionsPanel.updateWithContext(result.clinicalContext)
        
        // Trigger Metal view redraw for overlay
        imageView.setNeedsDisplay()
        
        // Show performance metrics
        showPerformanceMetrics(processingTime: result.processingTime)
    }
    
    private func loadPreviousStudies(for instance: DICOMInstance) -> [DICOMStudy]? {
        // Load previous studies for temporal analysis
        guard let store = DICOMServiceManager.shared.metadataStore else { return nil }
        
        let allStudies = store.getAllStudies()
        let patientStudies = allStudies.filter { 
            $0.patientID == instance.metadata.patientID 
        }
        
        return patientStudies.filter { study in
            study.studyDate ?? Date() < Date()
        }
    }
    
    // MARK: - Actions
    
    @objc private func realTimeToggled(_ sender: UISwitch) {
        isRealTimeEnabled = sender.isOn
        
        if isRealTimeEnabled, let instance = currentInstance {
            startAnomalyDetection(for: instance)
        }
    }
    
    @objc private func imageTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: imageView)
        
        // Check if tap is on an anomaly
        if let anomaly = getAnomalyAt(location: location) {
            showDetailedExplanation(for: anomaly)
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        // Handle pinch to zoom
    }
    
    @objc private func showInfo() {
        let infoVC = AnomalyDetectionInfoViewController()
        present(UINavigationController(rootViewController: infoVC), animated: true)
    }
    
    @objc private func exportResults() {
        guard let results = detectionResults else { return }
        
        let exporter = AnomalyResultsExporter()
        exporter.exportResults(results, from: self)
    }
    
    private func getAnomalyAt(location: CGPoint) -> DetectedAnomaly? {
        guard let results = detectionResults else { return nil }
        
        let normalizedLocation = CGPoint(
            x: location.x / imageView.bounds.width,
            y: location.y / imageView.bounds.height
        )
        
        for anomaly in results.anomalies {
            if anomaly.location.contains(normalizedLocation) {
                return anomaly
            }
        }
        
        return nil
    }
    
    private func showDetailedExplanation(for anomaly: DetectedAnomaly) {
        explanationDetailView.showAnomaly(anomaly)
        explanationDetailView.isHidden = false
        
        UIView.animate(withDuration: 0.3) {
            self.explanationDetailView.alpha = 1.0
        }
    }
    
    private func showPerformanceMetrics(processingTime: TimeInterval) {
        let fps = 1.0 / processingTime
        print("🎯 Anomaly detection completed in \(String(format: "%.3f", processingTime))s (\(String(format: "%.1f", fps)) FPS)")
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Detection Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Public Methods
    
    func loadInstance(_ instance: DICOMInstance, from study: DICOMStudy) {
        self.currentInstance = instance
        self.study = study
        
        if isViewLoaded && view.window != nil {
            startAnomalyDetection(for: instance)
        }
    }
}

// MARK: - MTKViewDelegate
@available(iOS 26.0, *)
extension AnomalyDetectionViewController: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = view.device?.makeCommandQueue()?.makeCommandBuffer() else {
            return
        }
        
        // Render DICOM image
        renderDICOMImage(to: drawable, commandBuffer: commandBuffer)
        
        // Overlay anomaly detection results
        if let results = detectionResults {
            renderAnomalyOverlay(results: results, to: drawable, commandBuffer: commandBuffer)
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func renderDICOMImage(to drawable: CAMetalDrawable, commandBuffer: MTLCommandBuffer) {
        // Render the base DICOM image
    }
    
    private func renderAnomalyOverlay(results: AnomalyDetectionResult, 
                                     to drawable: CAMetalDrawable, 
                                     commandBuffer: MTLCommandBuffer) {
        // Render GradCAM heatmap
        if let explanationMap = results.explanationMap {
            renderHeatmap(texture: explanationMap, to: drawable, commandBuffer: commandBuffer)
        }
        
        // Render bounding boxes for anomalies
        for anomaly in results.anomalies {
            renderBoundingBox(for: anomaly, to: drawable, commandBuffer: commandBuffer)
        }
    }
    
    private func renderHeatmap(texture: MTLTexture, to drawable: CAMetalDrawable, commandBuffer: MTLCommandBuffer) {
        // Implement heatmap rendering with Metal
    }
    
    private func renderBoundingBox(for anomaly: DetectedAnomaly, to drawable: CAMetalDrawable, commandBuffer: MTLCommandBuffer) {
        // Implement bounding box rendering with Metal
    }
}

// MARK: - UITableViewDataSource
@available(iOS 26.0, *)
extension AnomalyDetectionViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detectionResults?.anomalies.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AnomalyCell", for: indexPath) as! AnomalyCell
        
        if let anomaly = detectionResults?.anomalies[indexPath.row] {
            cell.configure(with: anomaly)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
@available(iOS 26.0, *)
extension AnomalyDetectionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let anomaly = detectionResults?.anomalies[indexPath.row] {
            showDetailedExplanation(for: anomaly)
        }
    }
}

// MARK: - ClinicalActionsPanelDelegate
@available(iOS 26.0, *)
extension AnomalyDetectionViewController: ClinicalActionsPanelDelegate {
    
    func clinicalActionsPanel(_ panel: ClinicalActionsPanel, didSelectAction action: ClinicalAction) {
        switch action {
        case .requestConsultation:
            requestRadiologistConsultation()
        case .exportToPACS:
            exportResultsToPACS()
        case .generateReport:
            generateStructuredReport()
        case .markForFollowUp:
            markStudyForFollowUp()
        }
    }
    
    private func requestRadiologistConsultation() {
        // Implement consultation request
    }
    
    private func exportResultsToPACS() {
        // Implement PACS export
    }
    
    private func generateStructuredReport() {
        // Generate DICOM SR
    }
    
    private func markStudyForFollowUp() {
        // Mark for follow-up
    }
}