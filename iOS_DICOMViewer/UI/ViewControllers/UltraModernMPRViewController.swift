//
//  UltraModernMPRViewController.swift
//  iOS_DICOMViewer
//
//  Ultra-sophisticated MPR (Multi-Planar Reconstruction) viewer
//

import UIKit
import Metal
import MetalKit

class UltraModernMPRViewController: UIViewController {
    
    // MARK: - Properties
    var study: DICOMStudy?
    
    // MARK: - UI Components
    private let backgroundView = UIView()
    
    // Three plane views
    private let axialView = MPRPlaneView()
    private let coronalView = MPRPlaneView()
    private let sagittalView = MPRPlaneView()
    
    // 3D overview
    private let volume3DView = VolumetricDisplayView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    
    // Control panels
    private let topControlPanel = GlassMorphismView()
    private let crosshairControl = CrosshairControlView()
    private let sliceNavigator = SliceNavigatorView()
    
    // Layout selector
    private let layoutSelector = MPRLayoutSelector()
    
    // Advanced controls
    private let windowLevelControl = WindowLevelControlView()
    private let thicknessControl = SliceThicknessControl()
    private let orientationCube = OrientationCubeView()
    
    // Synchronization
    private var crosshairPosition = CGPoint(x: 0.5, y: 0.5) // Normalized coordinates
    private var currentSlices = (axial: 0, coronal: 0, sagittal: 0)
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupInteractions()
        loadVolumeData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        performEntranceAnimation()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = MedicalColorPalette.primaryDark
        
        // Background gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            MedicalColorPalette.primaryDark.cgColor,
            MedicalColorPalette.primaryMedium.cgColor
        ]
        gradientLayer.locations = [0, 1]
        backgroundView.layer.addSublayer(gradientLayer)
        backgroundView.frame = view.bounds
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundView)
        
        // Setup plane views
        setupPlaneViews()
        
        // Setup control panel
        setupTopControlPanel()
        
        // Setup advanced controls
        setupAdvancedControls()
        
        // Layout selector
        layoutSelector.translatesAutoresizingMaskIntoConstraints = false
        layoutSelector.onLayoutChanged = { [weak self] layout in
            self?.applyLayout(layout)
        }
        view.addSubview(layoutSelector)
        
        // Setup constraints
        setupConstraints()
    }
    
    private func setupPlaneViews() {
        // Configure each plane view
        axialView.planeType = .axial
        axialView.delegate = self
        axialView.translatesAutoresizingMaskIntoConstraints = false
        
        coronalView.planeType = .coronal
        coronalView.delegate = self
        coronalView.translatesAutoresizingMaskIntoConstraints = false
        
        sagittalView.planeType = .sagittal
        sagittalView.delegate = self
        sagittalView.translatesAutoresizingMaskIntoConstraints = false
        
        // 3D volume view
        volume3DView.translatesAutoresizingMaskIntoConstraints = false
        volume3DView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        // Add holographic effect to each view
        [axialView, coronalView, sagittalView].forEach { planeView in
            planeView.layer.cornerRadius = 16
            planeView.layer.cornerCurve = .continuous
            planeView.clipsToBounds = true
            
            // Add glow effect
            planeView.layer.shadowColor = MedicalColorPalette.accentPrimary.cgColor
            planeView.layer.shadowOffset = .zero
            planeView.layer.shadowRadius = 20
            planeView.layer.shadowOpacity = 0.3
        }
        
        volume3DView.layer.cornerRadius = 16
        volume3DView.layer.cornerCurve = .continuous
        volume3DView.clipsToBounds = true
        
        view.addSubview(axialView)
        view.addSubview(coronalView)
        view.addSubview(sagittalView)
        view.addSubview(volume3DView)
    }
    
    private func setupTopControlPanel() {
        topControlPanel.translatesAutoresizingMaskIntoConstraints = false
        topControlPanel.glassIntensity = 0.9
        view.addSubview(topControlPanel)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Multi-Planar Reconstruction"
        titleLabel.font = MedicalTypography.headlineLarge
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Patient info
        let patientLabel = UILabel()
        patientLabel.text = study?.patientName ?? "Unknown Patient"
        patientLabel.font = MedicalTypography.bodyMedium
        patientLabel.textColor = MedicalColorPalette.primaryLight
        patientLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Close button
        let closeButton = NeumorphicButton()
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        // Sync toggle
        let syncToggle = UISwitch()
        syncToggle.isOn = true
        syncToggle.onTintColor = MedicalColorPalette.accentPrimary
        syncToggle.addTarget(self, action: #selector(syncToggled(_:)), for: .valueChanged)
        syncToggle.translatesAutoresizingMaskIntoConstraints = false
        
        let syncLabel = UILabel()
        syncLabel.text = "Sync Views"
        syncLabel.font = MedicalTypography.bodySmall
        syncLabel.textColor = .white
        syncLabel.translatesAutoresizingMaskIntoConstraints = false
        
        topControlPanel.addSubview(titleLabel)
        topControlPanel.addSubview(patientLabel)
        topControlPanel.addSubview(closeButton)
        topControlPanel.addSubview(syncToggle)
        topControlPanel.addSubview(syncLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: topControlPanel.leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: topControlPanel.topAnchor, constant: 20),
            
            patientLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            patientLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            closeButton.trailingAnchor.constraint(equalTo: topControlPanel.trailingAnchor, constant: -20),
            closeButton.centerYAnchor.constraint(equalTo: topControlPanel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            syncToggle.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -20),
            syncToggle.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            
            syncLabel.trailingAnchor.constraint(equalTo: syncToggle.leadingAnchor, constant: -8),
            syncLabel.centerYAnchor.constraint(equalTo: syncToggle.centerYAnchor)
        ])
    }
    
    private func setupAdvancedControls() {
        // Crosshair control
        crosshairControl.translatesAutoresizingMaskIntoConstraints = false
        crosshairControl.onCrosshairMoved = { [weak self] position in
            self?.updateCrosshairPosition(position)
        }
        view.addSubview(crosshairControl)
        
        // Slice navigator
        sliceNavigator.translatesAutoresizingMaskIntoConstraints = false
        sliceNavigator.onSliceChanged = { [weak self] plane, slice in
            self?.updateSlice(plane: plane, slice: slice)
        }
        view.addSubview(sliceNavigator)
        
        // Window/Level control
        windowLevelControl.translatesAutoresizingMaskIntoConstraints = false
        windowLevelControl.onWindowLevelChanged = { [weak self] window, level in
            self?.applyWindowLevel(window: window, level: level)
        }
        view.addSubview(windowLevelControl)
        
        // Thickness control
        thicknessControl.translatesAutoresizingMaskIntoConstraints = false
        thicknessControl.onThicknessChanged = { [weak self] thickness in
            self?.applySliceThickness(thickness)
        }
        view.addSubview(thicknessControl)
        
        // Orientation cube
        orientationCube.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(orientationCube)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Top control panel
            topControlPanel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topControlPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topControlPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topControlPanel.heightAnchor.constraint(equalToConstant: 100),
            
            // Layout selector
            layoutSelector.topAnchor.constraint(equalTo: topControlPanel.bottomAnchor, constant: 20),
            layoutSelector.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            layoutSelector.widthAnchor.constraint(equalToConstant: 200),
            layoutSelector.heightAnchor.constraint(equalToConstant: 40),
            
            // Plane views (2x2 grid by default)
            axialView.topAnchor.constraint(equalTo: topControlPanel.bottomAnchor, constant: 80),
            axialView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            axialView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.45, constant: -30),
            axialView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.42, constant: -60),
            
            coronalView.topAnchor.constraint(equalTo: axialView.topAnchor),
            coronalView.leadingAnchor.constraint(equalTo: axialView.trailingAnchor, constant: 20),
            coronalView.widthAnchor.constraint(equalTo: axialView.widthAnchor),
            coronalView.heightAnchor.constraint(equalTo: axialView.heightAnchor),
            
            sagittalView.topAnchor.constraint(equalTo: axialView.bottomAnchor, constant: 20),
            sagittalView.leadingAnchor.constraint(equalTo: axialView.leadingAnchor),
            sagittalView.widthAnchor.constraint(equalTo: axialView.widthAnchor),
            sagittalView.heightAnchor.constraint(equalTo: axialView.heightAnchor),
            
            volume3DView.topAnchor.constraint(equalTo: sagittalView.topAnchor),
            volume3DView.leadingAnchor.constraint(equalTo: sagittalView.trailingAnchor, constant: 20),
            volume3DView.widthAnchor.constraint(equalTo: sagittalView.widthAnchor),
            volume3DView.heightAnchor.constraint(equalTo: sagittalView.heightAnchor),
            
            // Controls
            crosshairControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            crosshairControl.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            crosshairControl.widthAnchor.constraint(equalToConstant: 60),
            crosshairControl.heightAnchor.constraint(equalToConstant: 60),
            
            sliceNavigator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sliceNavigator.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            sliceNavigator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            sliceNavigator.heightAnchor.constraint(equalToConstant: 80),
            
            windowLevelControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            windowLevelControl.centerYAnchor.constraint(equalTo: axialView.centerYAnchor),
            windowLevelControl.widthAnchor.constraint(equalToConstant: 80),
            windowLevelControl.heightAnchor.constraint(equalToConstant: 200),
            
            thicknessControl.trailingAnchor.constraint(equalTo: windowLevelControl.trailingAnchor),
            thicknessControl.topAnchor.constraint(equalTo: windowLevelControl.bottomAnchor, constant: 20),
            thicknessControl.widthAnchor.constraint(equalToConstant: 80),
            thicknessControl.heightAnchor.constraint(equalToConstant: 100),
            
            orientationCube.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            orientationCube.topAnchor.constraint(equalTo: layoutSelector.topAnchor),
            orientationCube.widthAnchor.constraint(equalToConstant: 100),
            orientationCube.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadVolumeData() {
        guard let study = study else { return }
        
        // Simulate loading volume data
        showLoadingState()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.hideLoadingState()
            self?.displayVolumeData()
        }
    }
    
    private func displayVolumeData() {
        // Update plane views with data
        if let study = study {
            axialView.loadStudy(study)
            coronalView.loadStudy(study)
            sagittalView.loadStudy(study)
            
            // Start 3D volume rendering
            volume3DView.startRotation()
        }
        
        // Update slice counts
        sliceNavigator.updateSliceCounts(
            axial: 100,  // Placeholder
            coronal: 100,
            sagittal: 100
        )
    }
    
    // MARK: - Interactions
    
    private func setupInteractions() {
        // Implement synchronized scrolling and interactions
    }
    
    private func updateCrosshairPosition(_ position: CGPoint) {
        crosshairPosition = position
        
        // Update all plane views
        axialView.setCrosshairPosition(position)
        coronalView.setCrosshairPosition(position)
        sagittalView.setCrosshairPosition(position)
        
        // Calculate corresponding slices
        updateSlicesFromCrosshair()
    }
    
    private func updateSlice(plane: PlaneType, slice: Int) {
        switch plane {
        case .axial:
            currentSlices.axial = slice
            axialView.setSlice(slice)
        case .coronal:
            currentSlices.coronal = slice
            coronalView.setSlice(slice)
        case .sagittal:
            currentSlices.sagittal = slice
            sagittalView.setSlice(slice)
        }
        
        // Update crosshair based on new slice
        updateCrosshairFromSlices()
    }
    
    private func updateSlicesFromCrosshair() {
        // Convert crosshair position to slice indices
        // This is a simplified implementation
        let totalSlices = 100 // Placeholder
        
        currentSlices.axial = Int(crosshairPosition.y * CGFloat(totalSlices))
        currentSlices.coronal = Int(crosshairPosition.x * CGFloat(totalSlices))
        currentSlices.sagittal = Int((1 - crosshairPosition.x) * CGFloat(totalSlices))
        
        sliceNavigator.updateCurrentSlices(currentSlices)
    }
    
    private func updateCrosshairFromSlices() {
        // Convert slice indices to crosshair position
        // This is a simplified implementation
    }
    
    private func applyWindowLevel(window: Double, level: Double) {
        axialView.setWindowLevel(window: window, level: level)
        coronalView.setWindowLevel(window: window, level: level)
        sagittalView.setWindowLevel(window: window, level: level)
    }
    
    private func applySliceThickness(_ thickness: Int) {
        axialView.setSliceThickness(thickness)
        coronalView.setSliceThickness(thickness)
        sagittalView.setSliceThickness(thickness)
    }
    
    private func applyLayout(_ layout: MPRLayout) {
        // Animate layout change
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            // Update constraints based on layout
            // This would require updating constraint constants
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func syncToggled(_ sender: UISwitch) {
        // Toggle synchronized scrolling
    }
    
    // MARK: - Loading State
    
    private func showLoadingState() {
        let loadingView = QuantumLoadingIndicator()
        loadingView.tag = 999
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingView)
        
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 200),
            loadingView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        loadingView.startAnimating()
    }
    
    private func hideLoadingState() {
        if let loadingView = view.viewWithTag(999) as? QuantumLoadingIndicator {
            loadingView.stopAnimating()
            loadingView.removeFromSuperview()
        }
    }
    
    // MARK: - Animations
    
    private func performEntranceAnimation() {
        // Initial states
        [axialView, coronalView, sagittalView, volume3DView].forEach { view in
            view.alpha = 0
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }
        
        topControlPanel.transform = CGAffineTransform(translationX: 0, y: -100)
        crosshairControl.alpha = 0
        sliceNavigator.transform = CGAffineTransform(translationX: 0, y: 100)
        
        // Animate
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.topControlPanel.transform = .identity
            self.sliceNavigator.transform = .identity
        }
        
        // Stagger plane view animations
        let views = [axialView, coronalView, sagittalView, volume3DView]
        for (index, view) in views.enumerated() {
            UIView.animate(withDuration: 0.5, delay: Double(index) * 0.1 + 0.2) {
                view.alpha = 1
                view.transform = .identity
            }
        }
        
        UIView.animate(withDuration: 0.3, delay: 0.8) {
            self.crosshairControl.alpha = 1
        }
    }
}

// MARK: - MPRPlaneViewDelegate
extension UltraModernMPRViewController: MPRPlaneViewDelegate {
    func planeView(_ planeView: MPRPlaneView, didUpdateCrosshair position: CGPoint) {
        // Synchronize crosshair across all views
        if planeView != axialView {
            axialView.setCrosshairPosition(position)
        }
        if planeView != coronalView {
            coronalView.setCrosshairPosition(position)
        }
        if planeView != sagittalView {
            sagittalView.setCrosshairPosition(position)
        }
        
        updateSlicesFromCrosshair()
    }
    
    func planeView(_ planeView: MPRPlaneView, didScrollToSlice slice: Int) {
        // Update corresponding slice
        switch planeView.planeType {
        case .axial:
            updateSlice(plane: .axial, slice: slice)
        case .coronal:
            updateSlice(plane: .coronal, slice: slice)
        case .sagittal:
            updateSlice(plane: .sagittal, slice: slice)
        }
    }
}