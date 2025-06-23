//
//  UltraModernViewerViewController.swift
//  iOS_DICOMViewer
//
//  Ultra-sophisticated 2D DICOM viewer with advanced medical imaging controls
//

import UIKit
import Metal
import MetalKit

class UltraModernViewerViewController: UIViewController, NightModeObserver {
    
    // MARK: - Properties
    var study: DICOMStudy?
    private var currentSeriesIndex = 0
    private var currentInstanceIndex = 0
    
    // MARK: - UI Components
    private let backgroundView = UIView()
    private let viewerContainer = UIView()
    private let dicomImageView = UIImageView()
    
    // Control panels
    private let topControlPanel = GlassMorphismView()
    private let bottomControlPanel = GlassMorphismView()
    private let sideToolPanel = GlassMorphismView()
    
    // Window/Level controls
    private let windowLevelControl = WindowLevelControlView()
    private let presetSelector = PresetSelectorView()
    
    // Measurement tools
    private let measurementToolbar = MeasurementToolbarView()
    private var activeMeasurementTool: MeasurementTool?
    
    // Advanced controls
    private let zoomControl = CircularZoomControl()
    private let rotationControl = RotationControlView()
    private let flipControl = FlipControlView()
    
    // Metadata display
    private let metadataOverlay = MetadataOverlayView()
    private let thumbnailStrip = ThumbnailStripView()
    
    // AI assistance
    private let aiAssistantButton = NeumorphicButton()
    private let aiAnalysisOverlay = AIAnalysisOverlayView()
    
    // Navigation
    private let seriesNavigator = SeriesNavigatorView()
    private let instanceSlider = InstanceSliderView()
    
    // Gesture recognizers
    private var panGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!
    private var doubleTapGesture: UITapGestureRecognizer!
    
    // State
    private var currentWindowLevel = (window: 400.0, level: 40.0)
    private var currentZoom: CGFloat = 1.0
    private var currentRotation: CGFloat = 0.0
    private var imageOffset = CGPoint.zero
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        loadInitialImage()
        setupNotifications()
        
        // Setup night mode
        NightModeManager.shared.addObserver(self)
        nightModeDidChange(NightModeManager.shared.isNightMode)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        performEntranceAnimation()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = MedicalColorPalette.primaryDark
        
        // Background with gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = MedicalColorPalette.primaryGradient
        gradientLayer.frame = view.bounds
        backgroundView.layer.addSublayer(gradientLayer)
        backgroundView.frame = view.bounds
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundView)
        
        // Viewer container
        viewerContainer.backgroundColor = .black
        viewerContainer.layer.cornerRadius = 20
        viewerContainer.layer.cornerCurve = .continuous
        viewerContainer.clipsToBounds = true
        viewerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(viewerContainer)
        
        // DICOM image view
        dicomImageView.contentMode = .scaleAspectFit
        dicomImageView.backgroundColor = .black
        dicomImageView.translatesAutoresizingMaskIntoConstraints = false
        viewerContainer.addSubview(dicomImageView)
        
        // Setup control panels
        setupTopControlPanel()
        setupBottomControlPanel()
        setupSideToolPanel()
        
        // Window/Level control
        windowLevelControl.translatesAutoresizingMaskIntoConstraints = false
        windowLevelControl.onWindowLevelChanged = { [weak self] window, level in
            self?.applyWindowLevel(window: window, level: level)
        }
        view.addSubview(windowLevelControl)
        
        // Preset selector
        presetSelector.translatesAutoresizingMaskIntoConstraints = false
        presetSelector.onPresetSelected = { [weak self] preset in
            self?.applyPreset(preset)
        }
        
        // Zoom control
        zoomControl.translatesAutoresizingMaskIntoConstraints = false
        zoomControl.onZoomChanged = { [weak self] zoom in
            self?.applyZoom(zoom)
        }
        view.addSubview(zoomControl)
        
        // Metadata overlay
        metadataOverlay.translatesAutoresizingMaskIntoConstraints = false
        metadataOverlay.alpha = 0.9
        view.addSubview(metadataOverlay)
        
        // Thumbnail strip
        thumbnailStrip.translatesAutoresizingMaskIntoConstraints = false
        thumbnailStrip.onThumbnailSelected = { [weak self] index in
            self?.navigateToInstance(index)
        }
        view.addSubview(thumbnailStrip)
        
        // AI assistant button
        aiAssistantButton.setImage(UIImage(systemName: "brain"), for: .normal)
        aiAssistantButton.tintColor = MedicalColorPalette.accentSecondary
        aiAssistantButton.translatesAutoresizingMaskIntoConstraints = false
        aiAssistantButton.addTarget(self, action: #selector(toggleAIAssistant), for: .touchUpInside)
        
        // AI analysis overlay
        aiAnalysisOverlay.translatesAutoresizingMaskIntoConstraints = false
        aiAnalysisOverlay.alpha = 0
        view.addSubview(aiAnalysisOverlay)
        
        // Setup constraints
        setupConstraints()
    }
    
    private func setupTopControlPanel() {
        topControlPanel.translatesAutoresizingMaskIntoConstraints = false
        topControlPanel.glassIntensity = 0.9
        view.addSubview(topControlPanel)
        
        // Patient info
        let patientLabel = UILabel()
        patientLabel.text = study?.patientName ?? "Unknown Patient"
        patientLabel.font = MedicalTypography.headlineSmall
        patientLabel.textColor = .white
        patientLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Study info
        let studyLabel = UILabel()
        studyLabel.text = study?.studyDescription ?? "Medical Study"
        studyLabel.font = MedicalTypography.bodyMedium
        studyLabel.textColor = MedicalColorPalette.primaryLight
        studyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Close button
        let closeButton = NeumorphicButton()
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        topControlPanel.addSubview(patientLabel)
        topControlPanel.addSubview(studyLabel)
        topControlPanel.addSubview(closeButton)
        topControlPanel.addSubview(aiAssistantButton)
        
        NSLayoutConstraint.activate([
            patientLabel.leadingAnchor.constraint(equalTo: topControlPanel.leadingAnchor, constant: 20),
            patientLabel.topAnchor.constraint(equalTo: topControlPanel.topAnchor, constant: 20),
            
            studyLabel.leadingAnchor.constraint(equalTo: patientLabel.leadingAnchor),
            studyLabel.topAnchor.constraint(equalTo: patientLabel.bottomAnchor, constant: 4),
            
            closeButton.trailingAnchor.constraint(equalTo: topControlPanel.trailingAnchor, constant: -20),
            closeButton.centerYAnchor.constraint(equalTo: topControlPanel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            aiAssistantButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12),
            aiAssistantButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            aiAssistantButton.widthAnchor.constraint(equalToConstant: 44),
            aiAssistantButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupBottomControlPanel() {
        bottomControlPanel.translatesAutoresizingMaskIntoConstraints = false
        bottomControlPanel.glassIntensity = 0.9
        view.addSubview(bottomControlPanel)
        
        // Series navigator
        seriesNavigator.translatesAutoresizingMaskIntoConstraints = false
        seriesNavigator.onSeriesChanged = { [weak self] index in
            self?.navigateToSeries(index)
        }
        bottomControlPanel.addSubview(seriesNavigator)
        
        // Instance slider
        instanceSlider.translatesAutoresizingMaskIntoConstraints = false
        instanceSlider.onInstanceChanged = { [weak self] index in
            self?.navigateToInstance(index)
        }
        bottomControlPanel.addSubview(instanceSlider)
        
        NSLayoutConstraint.activate([
            seriesNavigator.leadingAnchor.constraint(equalTo: bottomControlPanel.leadingAnchor, constant: 20),
            seriesNavigator.centerYAnchor.constraint(equalTo: bottomControlPanel.centerYAnchor),
            seriesNavigator.widthAnchor.constraint(equalToConstant: 200),
            seriesNavigator.heightAnchor.constraint(equalToConstant: 40),
            
            instanceSlider.leadingAnchor.constraint(equalTo: seriesNavigator.trailingAnchor, constant: 20),
            instanceSlider.trailingAnchor.constraint(equalTo: bottomControlPanel.trailingAnchor, constant: -20),
            instanceSlider.centerYAnchor.constraint(equalTo: bottomControlPanel.centerYAnchor),
            instanceSlider.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupSideToolPanel() {
        sideToolPanel.translatesAutoresizingMaskIntoConstraints = false
        sideToolPanel.glassIntensity = 0.9
        view.addSubview(sideToolPanel)
        
        // Measurement toolbar
        measurementToolbar.translatesAutoresizingMaskIntoConstraints = false
        measurementToolbar.onToolSelected = { [weak self] tool in
            self?.selectMeasurementTool(tool)
        }
        sideToolPanel.addSubview(measurementToolbar)
        
        // Rotation control
        rotationControl.translatesAutoresizingMaskIntoConstraints = false
        rotationControl.onRotationChanged = { [weak self] rotation in
            self?.applyRotation(rotation)
        }
        sideToolPanel.addSubview(rotationControl)
        
        // Flip control
        flipControl.translatesAutoresizingMaskIntoConstraints = false
        flipControl.onFlipChanged = { [weak self] horizontal, vertical in
            self?.applyFlip(horizontal: horizontal, vertical: vertical)
        }
        sideToolPanel.addSubview(flipControl)
        
        NSLayoutConstraint.activate([
            measurementToolbar.topAnchor.constraint(equalTo: sideToolPanel.topAnchor, constant: 20),
            measurementToolbar.centerXAnchor.constraint(equalTo: sideToolPanel.centerXAnchor),
            measurementToolbar.widthAnchor.constraint(equalToConstant: 60),
            measurementToolbar.heightAnchor.constraint(equalToConstant: 300),
            
            rotationControl.topAnchor.constraint(equalTo: measurementToolbar.bottomAnchor, constant: 20),
            rotationControl.centerXAnchor.constraint(equalTo: sideToolPanel.centerXAnchor),
            rotationControl.widthAnchor.constraint(equalToConstant: 60),
            rotationControl.heightAnchor.constraint(equalToConstant: 60),
            
            flipControl.topAnchor.constraint(equalTo: rotationControl.bottomAnchor, constant: 20),
            flipControl.centerXAnchor.constraint(equalTo: sideToolPanel.centerXAnchor),
            flipControl.widthAnchor.constraint(equalToConstant: 60),
            flipControl.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Viewer container
            viewerContainer.topAnchor.constraint(equalTo: topControlPanel.bottomAnchor, constant: 20),
            viewerContainer.leadingAnchor.constraint(equalTo: sideToolPanel.trailingAnchor, constant: 20),
            viewerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            viewerContainer.bottomAnchor.constraint(equalTo: bottomControlPanel.topAnchor, constant: -20),
            
            // DICOM image view
            dicomImageView.topAnchor.constraint(equalTo: viewerContainer.topAnchor),
            dicomImageView.leadingAnchor.constraint(equalTo: viewerContainer.leadingAnchor),
            dicomImageView.trailingAnchor.constraint(equalTo: viewerContainer.trailingAnchor),
            dicomImageView.bottomAnchor.constraint(equalTo: viewerContainer.bottomAnchor),
            
            // Top control panel
            topControlPanel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topControlPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topControlPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topControlPanel.heightAnchor.constraint(equalToConstant: 100),
            
            // Bottom control panel
            bottomControlPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomControlPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomControlPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomControlPanel.heightAnchor.constraint(equalToConstant: 100),
            
            // Side tool panel
            sideToolPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sideToolPanel.topAnchor.constraint(equalTo: topControlPanel.bottomAnchor, constant: 20),
            sideToolPanel.bottomAnchor.constraint(equalTo: bottomControlPanel.topAnchor, constant: -20),
            sideToolPanel.widthAnchor.constraint(equalToConstant: 100),
            
            // Window/Level control
            windowLevelControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            windowLevelControl.centerYAnchor.constraint(equalTo: viewerContainer.centerYAnchor),
            windowLevelControl.widthAnchor.constraint(equalToConstant: 80),
            windowLevelControl.heightAnchor.constraint(equalToConstant: 200),
            
            // Zoom control
            zoomControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            zoomControl.bottomAnchor.constraint(equalTo: windowLevelControl.topAnchor, constant: -20),
            zoomControl.widthAnchor.constraint(equalToConstant: 80),
            zoomControl.heightAnchor.constraint(equalToConstant: 80),
            
            // Metadata overlay
            metadataOverlay.topAnchor.constraint(equalTo: viewerContainer.topAnchor, constant: 20),
            metadataOverlay.leadingAnchor.constraint(equalTo: viewerContainer.leadingAnchor, constant: 20),
            metadataOverlay.widthAnchor.constraint(equalToConstant: 300),
            metadataOverlay.heightAnchor.constraint(equalToConstant: 200),
            
            // Thumbnail strip
            thumbnailStrip.leadingAnchor.constraint(equalTo: viewerContainer.leadingAnchor),
            thumbnailStrip.trailingAnchor.constraint(equalTo: viewerContainer.trailingAnchor),
            thumbnailStrip.bottomAnchor.constraint(equalTo: viewerContainer.bottomAnchor),
            thumbnailStrip.heightAnchor.constraint(equalToConstant: 80),
            
            // AI analysis overlay
            aiAnalysisOverlay.topAnchor.constraint(equalTo: viewerContainer.topAnchor),
            aiAnalysisOverlay.leadingAnchor.constraint(equalTo: viewerContainer.leadingAnchor),
            aiAnalysisOverlay.trailingAnchor.constraint(equalTo: viewerContainer.trailingAnchor),
            aiAnalysisOverlay.bottomAnchor.constraint(equalTo: viewerContainer.bottomAnchor)
        ])
    }
    
    private func setupGestures() {
        // Pan gesture
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        dicomImageView.addGestureRecognizer(panGesture)
        
        // Pinch gesture
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        dicomImageView.addGestureRecognizer(pinchGesture)
        
        // Rotation gesture
        rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        dicomImageView.addGestureRecognizer(rotationGesture)
        
        // Double tap gesture
        doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        dicomImageView.addGestureRecognizer(doubleTapGesture)
        
        dicomImageView.isUserInteractionEnabled = true
    }
    
    // MARK: - Data Loading
    
    private func loadInitialImage() {
        guard let study = study,
              let series = study.series.first,
              let instance = series.instances.first else { return }
        
        loadDICOMImage(instance: instance)
        updateMetadataDisplay()
        loadThumbnails()
    }
    
    private func loadDICOMImage(instance: DICOMInstance) {
        Task {
            do {
                if let image = try await DICOMImageRenderer.shared.renderImage(
                    from: instance,
                    windowWidth: currentWindowLevel.window,
                    windowCenter: currentWindowLevel.level
                ) {
                    await MainActor.run {
                        self.dicomImageView.image = image
                        self.applyCurrentTransforms()
                    }
                }
            } catch {
                print("Error loading DICOM image: \(error)")
            }
        }
    }
    
    private func loadThumbnails() {
        guard let series = study?.series[safe: currentSeriesIndex] else { return }
        thumbnailStrip.loadThumbnails(for: series.instances)
    }
    
    // MARK: - Navigation
    
    private func navigateToSeries(_ index: Int) {
        guard let study = study, index < study.series.count else { return }
        currentSeriesIndex = index
        currentInstanceIndex = 0
        
        if let instance = study.series[index].instances.first {
            loadDICOMImage(instance: instance)
            loadThumbnails()
        }
    }
    
    private func navigateToInstance(_ index: Int) {
        guard let series = study?.series[safe: currentSeriesIndex],
              let instance = series.instances[safe: index] else { return }
        
        currentInstanceIndex = index
        loadDICOMImage(instance: instance)
        updateMetadataDisplay()
    }
    
    // MARK: - Image Manipulation
    
    private func applyWindowLevel(window: Double, level: Double) {
        currentWindowLevel = (window, level)
        
        guard let series = study?.series[safe: currentSeriesIndex],
              let instance = series.instances[safe: currentInstanceIndex] else { return }
        
        loadDICOMImage(instance: instance)
    }
    
    private func applyPreset(_ preset: WindowLevelPreset) {
        applyWindowLevel(window: preset.window, level: preset.level)
        
        // Show preset name
        showToast(preset.name)
    }
    
    private func applyZoom(_ zoom: CGFloat) {
        currentZoom = zoom
        applyCurrentTransforms()
    }
    
    private func applyRotation(_ rotation: CGFloat) {
        currentRotation = rotation
        applyCurrentTransforms()
    }
    
    private func applyFlip(horizontal: Bool, vertical: Bool) {
        var transform = CGAffineTransform.identity
        
        if horizontal {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        
        if vertical {
            transform = transform.scaledBy(x: 1, y: -1)
        }
        
        UIView.animate(withDuration: 0.3) {
            self.dicomImageView.transform = transform
                .rotated(by: self.currentRotation)
                .scaledBy(x: self.currentZoom, y: self.currentZoom)
                .translatedBy(x: self.imageOffset.x, y: self.imageOffset.y)
        }
    }
    
    private func applyCurrentTransforms() {
        dicomImageView.transform = CGAffineTransform.identity
            .rotated(by: currentRotation)
            .scaledBy(x: currentZoom, y: currentZoom)
            .translatedBy(x: imageOffset.x, y: imageOffset.y)
    }
    
    // MARK: - Gestures
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: viewerContainer)
        
        if gesture.state == .changed {
            imageOffset.x += translation.x
            imageOffset.y += translation.y
            applyCurrentTransforms()
            gesture.setTranslation(.zero, in: viewerContainer)
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            currentZoom *= gesture.scale
            currentZoom = max(0.5, min(currentZoom, 5.0))
            applyCurrentTransforms()
            gesture.scale = 1.0
        }
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        if gesture.state == .changed {
            currentRotation += gesture.rotation
            applyCurrentTransforms()
            gesture.rotation = 0
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        // Reset transforms
        UIView.animate(withDuration: 0.3) {
            self.currentZoom = 1.0
            self.currentRotation = 0
            self.imageOffset = .zero
            self.applyCurrentTransforms()
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func toggleAIAssistant() {
        let showAI = aiAnalysisOverlay.alpha == 0
        
        if showAI {
            // Perform AI analysis
            performAIAnalysis()
        }
        
        UIView.animate(withDuration: 0.3) {
            self.aiAnalysisOverlay.alpha = showAI ? 1.0 : 0.0
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func selectMeasurementTool(_ tool: MeasurementTool) {
        activeMeasurementTool = tool
        // Implementation for measurement tools
    }
    
    // MARK: - AI Analysis
    
    private func performAIAnalysis() {
        // Simulate AI analysis
        aiAnalysisOverlay.showLoadingState()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            let findings = [
                AIFinding(type: .anomaly, confidence: 0.87, location: CGRect(x: 100, y: 150, width: 80, height: 80), description: "Possible nodule detected"),
                AIFinding(type: .measurement, confidence: 0.95, location: CGRect(x: 250, y: 200, width: 120, height: 40), description: "Cardiac measurement: 12.3cm")
            ]
            
            self?.aiAnalysisOverlay.displayFindings(findings)
        }
    }
    
    // MARK: - Utility
    
    private func updateMetadataDisplay() {
        guard let series = study?.series[safe: currentSeriesIndex],
              let instance = series.instances[safe: currentInstanceIndex] else { return }
        
        let metadata = [
            "Patient": study?.patientName ?? "Unknown",
            "Study Date": formatDate(study?.studyDate),
            "Series": "\(currentSeriesIndex + 1)/\(study?.series.count ?? 0)",
            "Instance": "\(currentInstanceIndex + 1)/\(series.instances.count)",
            "Modality": series.modality ?? "Unknown",
            "Window/Level": String(format: "W:%.0f L:%.0f", currentWindowLevel.window, currentWindowLevel.level)
        ]
        
        metadataOverlay.updateMetadata(metadata)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func showToast(_ message: String) {
        let toast = ToastView(message: message)
        toast.show(in: view)
    }
    
    // MARK: - Animations
    
    private func performEntranceAnimation() {
        // Initial states
        topControlPanel.transform = CGAffineTransform(translationX: 0, y: -100)
        bottomControlPanel.transform = CGAffineTransform(translationX: 0, y: 100)
        sideToolPanel.transform = CGAffineTransform(translationX: -100, y: 0)
        windowLevelControl.transform = CGAffineTransform(translationX: 100, y: 0)
        viewerContainer.alpha = 0
        viewerContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        // Animate
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.topControlPanel.transform = .identity
            self.bottomControlPanel.transform = .identity
            self.sideToolPanel.transform = .identity
            self.windowLevelControl.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.2) {
            self.viewerContainer.alpha = 1
            self.viewerContainer.transform = .identity
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        // Listen for any relevant notifications
    }
    
    deinit {
        NightModeManager.shared.removeObserver(self)
    }
}

// MARK: - Night Mode
extension UltraModernViewerViewController {
    func nightModeDidChange(_ isNightMode: Bool) {
        UIView.animate(withDuration: 0.3) {
            if isNightMode {
                self.view.backgroundColor = MedicalColorPalette.primaryDarkNight
                self.viewerContainer.backgroundColor = .black
                self.topControlPanel.glassColor = UIColor.white.withAlphaComponent(0.05)
                self.bottomControlPanel.glassColor = UIColor.white.withAlphaComponent(0.05)
                self.sideToolPanel.glassColor = UIColor.white.withAlphaComponent(0.05)
                self.metadataOverlay.glassColor = UIColor.white.withAlphaComponent(0.05)
            } else {
                self.view.backgroundColor = MedicalColorPalette.primaryDark
                self.viewerContainer.backgroundColor = .black
                self.topControlPanel.glassColor = UIColor.white.withAlphaComponent(0.1)
                self.bottomControlPanel.glassColor = UIColor.white.withAlphaComponent(0.1)
                self.sideToolPanel.glassColor = UIColor.white.withAlphaComponent(0.1)
                self.metadataOverlay.glassColor = UIColor.white.withAlphaComponent(0.1)
            }
        }
    }
}

// MARK: - Helper Extensions

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}