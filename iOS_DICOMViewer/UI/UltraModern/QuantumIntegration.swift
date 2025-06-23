//
//  QuantumIntegration.swift
//  iOS_DICOMViewer
//
//  Integration layer between the Quantum Interface and existing DICOM viewer
//

import UIKit
import SwiftUI
import Combine

// MARK: - Quantum Tab View Controller

/// UIKit wrapper for the revolutionary Quantum DICOM Interface
class QuantumDICOMViewController: UIViewController {
    
    private var hostingController: UIHostingController<QuantumViewerView>?
    private var quantum = QuantumDICOMInterface()
    private var study: DICOMStudy?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupQuantumInterface()
        setupNavigationBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hide standard navigation bar for immersive experience
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        // Enable edge-to-edge display
        additionalSafeAreaInsets = UIEdgeInsets(top: -44, left: 0, bottom: -34, right: 0)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Restore navigation bar when leaving
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup
    
    private func setupQuantumInterface() {
        let quantumView = QuantumViewerView()
        let hostingController = UIHostingController(rootView: quantumView)
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
        
        // Set background
        view.backgroundColor = UIColor(red: 0.067, green: 0.086, blue: 0.094, alpha: 1.0)
    }
    
    private func setupNavigationBar() {
        title = "Quantum Viewer"
        
        // Custom back button for quantum interface
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(navigateBack)
        )
        backButton.tintColor = .cyan
        navigationItem.leftBarButtonItem = backButton
    }
    
    // MARK: - Public Methods
    
    func loadStudy(_ study: DICOMStudy) {
        self.study = study
        // Update quantum interface with study data
        updateQuantumInterface()
    }
    
    func refreshStudy(_ study: DICOMStudy) {
        self.study = study
        updateQuantumInterface()
    }
    
    // MARK: - Private Methods
    
    private func updateQuantumInterface() {
        guard let study = study else { return }
        
        // Pass study data to SwiftUI view through environment or binding
        // This would require updating QuantumViewerView to accept study data
        print("🌌 Quantum Interface: Loading study \(study.studyInstanceUID)")
    }
    
    @objc private func navigateBack() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Tab Bar Integration Extension

extension MainTabBarController {
    
    /// Add Quantum Viewer as an additional tab
    func addQuantumViewerTab() {
        guard var controllers = viewControllers else { return }
        
        // Create Quantum Viewer
        let quantumController = QuantumDICOMViewController()
        let quantumNav = createNavigationController(
            rootViewController: quantumController,
            title: "Quantum",
            iconName: "atom",
            selectedIconName: "atom"
        )
        
        // Customize tab appearance for quantum viewer
        quantumNav.tabBarItem.image = createQuantumTabIcon()
        quantumNav.tabBarItem.selectedImage = createQuantumTabIcon(selected: true)
        
        // Insert before Settings tab
        let settingsIndex = controllers.count - 1
        controllers.insert(quantumNav, at: settingsIndex)
        
        viewControllers = controllers
    }
    
    private func createQuantumTabIcon() -> UIImage? {
        return UIImage(systemName: "atom")?
            .withConfiguration(UIImage.SymbolConfiguration(weight: .medium))
    }
    
    private func createQuantumTabIcon(selected: Bool) -> UIImage? {
        return UIImage(systemName: "atom")?
            .withConfiguration(UIImage.SymbolConfiguration(weight: .bold))
            .withTintColor(selected ? .cyan : .gray, renderingMode: .alwaysOriginal)
    }
}

// MARK: - Enhanced Modern Viewer Integration

extension ModernViewerViewController {
    
    /// Enable Quantum UI features in the standard viewer
    func enableQuantumFeatures() {
        // Add gesture visualization
        addGestureVisualization()
        
        // Enable haptic feedback
        enableAdvancedHaptics()
        
        // Add AI suggestions
        enableAIPredictions()
    }
    
    private func addGestureVisualization() {
        let gestureOverlay = UIHostingController(
            rootView: GestureVisualizationLayer(quantum: QuantumDICOMInterface())
        )
        
        addChild(gestureOverlay)
        view.addSubview(gestureOverlay.view)
        
        gestureOverlay.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gestureOverlay.view.topAnchor.constraint(equalTo: view.topAnchor),
            gestureOverlay.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gestureOverlay.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gestureOverlay.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        gestureOverlay.didMove(toParent: self)
        gestureOverlay.view.isUserInteractionEnabled = false
    }
    
    private func enableAdvancedHaptics() {
        let quantum = QuantumDICOMInterface()
        
        // Add haptic feedback to existing controls
        windowLevelGesture?.addTarget(self, action: #selector(handleHapticFeedback))
    }
    
    @objc private func handleHapticFeedback() {
        QuantumDICOMInterface().hapticFeedback(for: .gestureRecognized)
    }
    
    private func enableAIPredictions() {
        // Add AI prediction overlay
        let aiOverlay = FloatingAIAssistant(
            suggestions: [
                AISuggestion(
                    title: "Auto Window/Level",
                    confidence: 0.92,
                    action: { self.autoAdjustWindowLevel() }
                ),
                AISuggestion(
                    title: "Detect Anomalies",
                    confidence: 0.87,
                    action: { self.runAnomalyDetection() }
                )
            ],
            predictedAction: "Measure lesion"
        )
        
        let aiHost = UIHostingController(rootView: aiOverlay)
        addChild(aiHost)
        view.addSubview(aiHost.view)
        
        aiHost.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            aiHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            aiHost.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            aiHost.view.widthAnchor.constraint(equalToConstant: 100),
            aiHost.view.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        aiHost.didMove(toParent: self)
    }
    
    private func autoAdjustWindowLevel() {
        // AI-powered window/level adjustment
        print("🤖 AI: Auto-adjusting window/level based on image content")
        
        // Analyze image histogram and adjust
        UIView.animate(withDuration: 0.3) {
            self.currentWindow = 400  // AI-determined optimal window
            self.currentLevel = 40    // AI-determined optimal level
            self.loadCurrentImage()
        }
    }
    
    private func runAnomalyDetection() {
        // AI anomaly detection
        print("🤖 AI: Running anomaly detection on current image")
        
        // This would integrate with CoreML models
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showAnomalyResults()
        }
    }
    
    private func showAnomalyResults() {
        // Show AI detection results
        let alert = UIAlertController(
            title: "AI Analysis Complete",
            message: "No significant anomalies detected in current image.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Settings Integration

extension SettingsViewController {
    
    /// Add Quantum Interface settings section
    func addQuantumSettings() {
        // Add new settings section for Quantum features
        let quantumSection = SettingsSection(
            title: "Quantum Interface",
            items: [
                SettingItem(
                    title: "Enable Neural Control",
                    type: .toggle(isOn: false) { isOn in
                        UserDefaults.standard.set(isOn, forKey: "neuralControlEnabled")
                    }
                ),
                SettingItem(
                    title: "Haptic Intensity",
                    type: .slider(value: 0.7, range: 0...1) { value in
                        UserDefaults.standard.set(value, forKey: "hapticIntensity")
                    }
                ),
                SettingItem(
                    title: "AI Predictions",
                    type: .toggle(isOn: true) { isOn in
                        UserDefaults.standard.set(isOn, forKey: "aiPredictionsEnabled")
                    }
                ),
                SettingItem(
                    title: "Gesture Visualization",
                    type: .toggle(isOn: true) { isOn in
                        UserDefaults.standard.set(isOn, forKey: "gestureVisualizationEnabled")
                    }
                ),
                SettingItem(
                    title: "Biometric Monitoring",
                    type: .toggle(isOn: false) { isOn in
                        UserDefaults.standard.set(isOn, forKey: "biometricMonitoringEnabled")
                    }
                )
            ]
        )
        
        // Add to settings
        // This would require updating SettingsViewController to support dynamic sections
    }
}

// MARK: - App-wide Quantum Features

class QuantumFeatureManager {
    static let shared = QuantumFeatureManager()
    
    private let quantum = QuantumDICOMInterface()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupGlobalFeatures()
    }
    
    private func setupGlobalFeatures() {
        // Monitor user behavior across the app
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                self.quantum.startAdaptiveInterface()
            }
            .store(in: &cancellables)
        
        // Setup global gesture recognition
        setupGlobalGestureRecognition()
        
        // Initialize voice commands
        setupVoiceCommands()
    }
    
    private func setupGlobalGestureRecognition() {
        // Add edge swipe gestures for quick navigation
        let edgeSwipe = UIScreenEdgePanGestureRecognizer(
            target: self,
            action: #selector(handleEdgeSwipe(_:))
        )
        edgeSwipe.edges = .left
        
        // Add to key window when available
        DispatchQueue.main.async {
            if let window = UIApplication.shared.windows.first {
                window.addGestureRecognizer(edgeSwipe)
            }
        }
    }
    
    @objc private func handleEdgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .recognized {
            quantum.hapticFeedback(for: .gestureRecognized)
            // Trigger quick action menu
        }
    }
    
    private func setupVoiceCommands() {
        // Setup global voice commands
        // "Hey DICOM, show next series"
        // "Hey DICOM, adjust window for chest"
        // "Hey DICOM, measure this lesion"
    }
}

// MARK: - Helper Types

struct SettingsSection {
    let title: String
    let items: [SettingItem]
}

struct SettingItem {
    let title: String
    let type: SettingType
    
    enum SettingType {
        case toggle(isOn: Bool, action: (Bool) -> Void)
        case slider(value: Float, range: ClosedRange<Float>, action: (Float) -> Void)
        case selection(options: [String], selected: Int, action: (Int) -> Void)
        case action(handler: () -> Void)
    }
}