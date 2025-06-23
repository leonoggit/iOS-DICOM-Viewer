//
//  UltraModern3DAIViewController.swift
//  iOS_DICOMViewer
//
//  Ultra-sophisticated 3D volume rendering and AI analysis viewer
//

import UIKit
import Metal
import MetalKit
import SceneKit

class UltraModern3DAIViewController: UIViewController {
    
    // MARK: - Properties
    var study: DICOMStudy?
    
    // MARK: - UI Components
    private let backgroundView = UIView()
    
    // Main 3D view
    private let volumeRenderView = VolumeRenderingView()
    private let sceneView = SCNView()
    
    // AI panels
    private let aiControlPanel = GlassMorphismView()
    private let segmentationPanel = SegmentationControlPanel()
    private let analysisResultsPanel = AIAnalysisResultsPanel()
    
    // Rendering controls
    private let renderingModeSelector = RenderingModeSelector()
    private let transferFunctionEditor = TransferFunctionEditor()
    private let lightingControl = LightingControlView()
    
    // AI controls
    private let modelSelector = AIModelSelector()
    private let segmentationToggle = SegmentationToggleView()
    private let confidenceThreshold = ConfidenceThresholdControl()
    
    // Animation controls
    private let rotationToggle = UISwitch()
    private let animationSpeed = UISlider()
    
    // Progress indicators
    private let progressRing = CircularProgressView()
    private let neuralNetworkViz = NeuralNetworkVisualization()
    
    // Interaction
    private var currentRenderingMode: RenderingMode = .volumeRendering
    private var isProcessingAI = false
    
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
        
        // Background with animated gradient
        setupAnimatedBackground()
        
        // Main 3D view
        setup3DView()
        
        // Control panels
        setupControlPanels()
        
        // AI components
        setupAIComponents()
        
        // Layout
        setupConstraints()
    }
    
    private func setupAnimatedBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            MedicalColorPalette.primaryDark.cgColor,
            MedicalColorPalette.primaryMedium.cgColor,
            MedicalColorPalette.accentPrimary.withAlphaComponent(0.1).cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        
        backgroundView.layer.addSublayer(gradientLayer)
        backgroundView.frame = view.bounds
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundView)
        
        // Animate gradient
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = gradientLayer.colors
        animation.toValue = [
            MedicalColorPalette.primaryMedium.cgColor,
            MedicalColorPalette.accentPrimary.withAlphaComponent(0.2).cgColor,
            MedicalColorPalette.primaryDark.cgColor
        ]
        animation.duration = 10.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "gradientAnimation")
    }
    
    private func setup3DView() {
        // Volume rendering view (Metal)
        volumeRenderView.translatesAutoresizingMaskIntoConstraints = false
        volumeRenderView.layer.cornerRadius = 20
        volumeRenderView.layer.cornerCurve = .continuous
        volumeRenderView.clipsToBounds = true
        view.addSubview(volumeRenderView)
        
        // SceneKit view (for 3D models)
        sceneView.backgroundColor = .clear
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.layer.cornerRadius = 20
        sceneView.layer.cornerCurve = .continuous
        sceneView.clipsToBounds = true
        sceneView.isHidden = true
        view.addSubview(sceneView)
        
        // Add holographic border effect
        let borderLayer = CAGradientLayer()
        borderLayer.frame = volumeRenderView.bounds
        borderLayer.colors = [
            MedicalColorPalette.accentPrimary.withAlphaComponent(0.5).cgColor,
            MedicalColorPalette.accentSecondary.withAlphaComponent(0.5).cgColor,
            MedicalColorPalette.accentTertiary.withAlphaComponent(0.5).cgColor
        ]
        borderLayer.locations = [0, 0.5, 1]
        borderLayer.startPoint = CGPoint(x: 0, y: 0)
        borderLayer.endPoint = CGPoint(x: 1, y: 1)
        borderLayer.type = .conic
        
        let maskLayer = CAShapeLayer()
        maskLayer.lineWidth = 2
        maskLayer.path = UIBezierPath(roundedRect: volumeRenderView.bounds.insetBy(dx: 1, dy: 1), cornerRadius: 19).cgPath
        maskLayer.fillColor = UIColor.clear.cgColor
        maskLayer.strokeColor = UIColor.black.cgColor
        borderLayer.mask = maskLayer
        
        volumeRenderView.layer.addSublayer(borderLayer)
    }
    
    private func setupControlPanels() {
        // AI Control Panel
        aiControlPanel.translatesAutoresizingMaskIntoConstraints = false
        aiControlPanel.glassIntensity = 0.9
        view.addSubview(aiControlPanel)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "AI-Powered 3D Analysis"
        titleLabel.font = MedicalTypography.displaySmall
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        aiControlPanel.addSubview(titleLabel)
        
        // Close button
        let closeButton = NeumorphicButton()
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        aiControlPanel.addSubview(closeButton)
        
        // Rendering mode selector
        renderingModeSelector.translatesAutoresizingMaskIntoConstraints = false
        renderingModeSelector.onModeChanged = { [weak self] mode in
            self?.switchRenderingMode(mode)
        }
        view.addSubview(renderingModeSelector)
        
        // Transfer function editor
        transferFunctionEditor.translatesAutoresizingMaskIntoConstraints = false
        transferFunctionEditor.onTransferFunctionChanged = { [weak self] function in
            self?.applyTransferFunction(function)
        }
        view.addSubview(transferFunctionEditor)
        
        // Segmentation panel
        segmentationPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentationPanel)
        
        // Analysis results panel
        analysisResultsPanel.translatesAutoresizingMaskIntoConstraints = false
        analysisResultsPanel.alpha = 0
        view.addSubview(analysisResultsPanel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: aiControlPanel.leadingAnchor, constant: 20),
            titleLabel.centerYAnchor.constraint(equalTo: aiControlPanel.centerYAnchor),
            
            closeButton.trailingAnchor.constraint(equalTo: aiControlPanel.trailingAnchor, constant: -20),
            closeButton.centerYAnchor.constraint(equalTo: aiControlPanel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupAIComponents() {
        // Model selector
        modelSelector.translatesAutoresizingMaskIntoConstraints = false
        modelSelector.onModelSelected = { [weak self] model in
            self?.loadAIModel(model)
        }
        
        // Segmentation toggle
        segmentationToggle.translatesAutoresizingMaskIntoConstraints = false
        segmentationToggle.onSegmentationToggled = { [weak self] organs in
            self?.toggleSegmentation(organs: organs)
        }
        
        // Confidence threshold
        confidenceThreshold.translatesAutoresizingMaskIntoConstraints = false
        confidenceThreshold.onThresholdChanged = { [weak self] threshold in
            self?.updateConfidenceThreshold(threshold)
        }
        
        // Neural network visualization
        neuralNetworkViz.translatesAutoresizingMaskIntoConstraints = false
        neuralNetworkViz.alpha = 0
        view.addSubview(neuralNetworkViz)
        
        // Progress ring
        progressRing.translatesAutoresizingMaskIntoConstraints = false
        progressRing.isHidden = true
        view.addSubview(progressRing)
        
        // Animation controls
        setupAnimationControls()
    }
    
    private func setupAnimationControls() {
        let animationPanel = GlassMorphismView()
        animationPanel.translatesAutoresizingMaskIntoConstraints = false
        animationPanel.glassIntensity = 0.7
        
        // Rotation toggle
        rotationToggle.isOn = false
        rotationToggle.onTintColor = MedicalColorPalette.accentPrimary
        rotationToggle.addTarget(self, action: #selector(rotationToggled), for: .valueChanged)
        
        let rotationLabel = UILabel()
        rotationLabel.text = "Auto Rotate"
        rotationLabel.font = MedicalTypography.bodySmall
        rotationLabel.textColor = .white
        
        // Animation speed
        animationSpeed.minimumValue = 0.1
        animationSpeed.maximumValue = 2.0
        animationSpeed.value = 1.0
        animationSpeed.tintColor = MedicalColorPalette.accentSecondary
        animationSpeed.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        
        let speedLabel = UILabel()
        speedLabel.text = "Speed"
        speedLabel.font = MedicalTypography.bodySmall
        speedLabel.textColor = .white
        
        // Layout animation controls
        rotationToggle.translatesAutoresizingMaskIntoConstraints = false
        rotationLabel.translatesAutoresizingMaskIntoConstraints = false
        animationSpeed.translatesAutoresizingMaskIntoConstraints = false
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        
        animationPanel.addSubview(rotationToggle)
        animationPanel.addSubview(rotationLabel)
        animationPanel.addSubview(animationSpeed)
        animationPanel.addSubview(speedLabel)
        
        view.addSubview(animationPanel)
        
        NSLayoutConstraint.activate([
            animationPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            animationPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            animationPanel.widthAnchor.constraint(equalToConstant: 200),
            animationPanel.heightAnchor.constraint(equalToConstant: 100),
            
            rotationLabel.leadingAnchor.constraint(equalTo: animationPanel.leadingAnchor, constant: 16),
            rotationLabel.topAnchor.constraint(equalTo: animationPanel.topAnchor, constant: 16),
            
            rotationToggle.trailingAnchor.constraint(equalTo: animationPanel.trailingAnchor, constant: -16),
            rotationToggle.centerYAnchor.constraint(equalTo: rotationLabel.centerYAnchor),
            
            speedLabel.leadingAnchor.constraint(equalTo: rotationLabel.leadingAnchor),
            speedLabel.topAnchor.constraint(equalTo: rotationLabel.bottomAnchor, constant: 16),
            
            animationSpeed.leadingAnchor.constraint(equalTo: speedLabel.trailingAnchor, constant: 12),
            animationSpeed.trailingAnchor.constraint(equalTo: animationPanel.trailingAnchor, constant: -16),
            animationSpeed.centerYAnchor.constraint(equalTo: speedLabel.centerYAnchor)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // AI Control Panel
            aiControlPanel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            aiControlPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            aiControlPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            aiControlPanel.heightAnchor.constraint(equalToConstant: 80),
            
            // 3D Views
            volumeRenderView.topAnchor.constraint(equalTo: aiControlPanel.bottomAnchor, constant: 20),
            volumeRenderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            volumeRenderView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.65, constant: -30),
            volumeRenderView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -120),
            
            sceneView.topAnchor.constraint(equalTo: volumeRenderView.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: volumeRenderView.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: volumeRenderView.trailingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: volumeRenderView.bottomAnchor),
            
            // Rendering controls
            renderingModeSelector.topAnchor.constraint(equalTo: aiControlPanel.bottomAnchor, constant: 20),
            renderingModeSelector.leadingAnchor.constraint(equalTo: volumeRenderView.trailingAnchor, constant: 20),
            renderingModeSelector.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            renderingModeSelector.heightAnchor.constraint(equalToConstant: 60),
            
            transferFunctionEditor.topAnchor.constraint(equalTo: renderingModeSelector.bottomAnchor, constant: 20),
            transferFunctionEditor.leadingAnchor.constraint(equalTo: renderingModeSelector.leadingAnchor),
            transferFunctionEditor.trailingAnchor.constraint(equalTo: renderingModeSelector.trailingAnchor),
            transferFunctionEditor.heightAnchor.constraint(equalToConstant: 200),
            
            // Segmentation panel
            segmentationPanel.topAnchor.constraint(equalTo: transferFunctionEditor.bottomAnchor, constant: 20),
            segmentationPanel.leadingAnchor.constraint(equalTo: transferFunctionEditor.leadingAnchor),
            segmentationPanel.trailingAnchor.constraint(equalTo: transferFunctionEditor.trailingAnchor),
            segmentationPanel.heightAnchor.constraint(equalToConstant: 250),
            
            // Analysis results
            analysisResultsPanel.leadingAnchor.constraint(equalTo: volumeRenderView.leadingAnchor),
            analysisResultsPanel.trailingAnchor.constraint(equalTo: volumeRenderView.trailingAnchor),
            analysisResultsPanel.bottomAnchor.constraint(equalTo: volumeRenderView.bottomAnchor),
            analysisResultsPanel.heightAnchor.constraint(equalToConstant: 150),
            
            // Neural network viz
            neuralNetworkViz.centerXAnchor.constraint(equalTo: volumeRenderView.centerXAnchor),
            neuralNetworkViz.centerYAnchor.constraint(equalTo: volumeRenderView.centerYAnchor),
            neuralNetworkViz.widthAnchor.constraint(equalToConstant: 300),
            neuralNetworkViz.heightAnchor.constraint(equalToConstant: 200),
            
            // Progress ring
            progressRing.centerXAnchor.constraint(equalTo: volumeRenderView.centerXAnchor),
            progressRing.centerYAnchor.constraint(equalTo: volumeRenderView.centerYAnchor),
            progressRing.widthAnchor.constraint(equalToConstant: 100),
            progressRing.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadVolumeData() {
        guard let study = study else { return }
        
        showLoadingState()
        
        // Simulate loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.hideLoadingState()
            self?.displayVolume()
            self?.startAIAnalysis()
        }
    }
    
    private func displayVolume() {
        // Load and display 3D volume
        volumeRenderView.loadVolume(from: study)
        
        // Setup initial rendering
        applyDefaultTransferFunction()
    }
    
    // MARK: - AI Analysis
    
    private func startAIAnalysis() {
        isProcessingAI = true
        
        // Show neural network visualization
        UIView.animate(withDuration: 0.5) {
            self.neuralNetworkViz.alpha = 1
        }
        neuralNetworkViz.startActivation()
        
        // Simulate AI processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.completeAIAnalysis()
        }
    }
    
    private func completeAIAnalysis() {
        isProcessingAI = false
        
        // Hide neural network
        neuralNetworkViz.stopActivation()
        UIView.animate(withDuration: 0.5) {
            self.neuralNetworkViz.alpha = 0
        }
        
        // Show results
        let results = [
            AIAnalysisResult(organ: "Liver", volume: 1523.4, confidence: 0.92, anomalies: 0),
            AIAnalysisResult(organ: "Kidneys", volume: 287.3, confidence: 0.88, anomalies: 1),
            AIAnalysisResult(organ: "Spleen", volume: 182.7, confidence: 0.85, anomalies: 0),
            AIAnalysisResult(organ: "Pancreas", volume: 98.2, confidence: 0.79, anomalies: 0)
        ]
        
        analysisResultsPanel.displayResults(results)
        
        UIView.animate(withDuration: 0.5) {
            self.analysisResultsPanel.alpha = 1
        }
        
        // Enable segmentation
        segmentationPanel.enableOrgans(results.map { $0.organ })
    }
    
    // MARK: - Rendering Modes
    
    private func switchRenderingMode(_ mode: RenderingMode) {
        currentRenderingMode = mode
        
        switch mode {
        case .volumeRendering:
            volumeRenderView.isHidden = false
            sceneView.isHidden = true
            volumeRenderView.setRenderingMode(.volumeRendering)
            
        case .maximumIntensityProjection:
            volumeRenderView.isHidden = false
            sceneView.isHidden = true
            volumeRenderView.setRenderingMode(.mip)
            
        case .isosurface:
            volumeRenderView.isHidden = false
            sceneView.isHidden = true
            volumeRenderView.setRenderingMode(.isosurface)
            
        case .mesh3D:
            // Switch to SceneKit for mesh rendering
            volumeRenderView.isHidden = true
            sceneView.isHidden = false
            displayMesh3D()
        }
        
        // Animate transition
        let transitionView = currentRenderingMode == .mesh3D ? sceneView : volumeRenderView
        transitionView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            transitionView.alpha = 1
        }
    }
    
    private func displayMesh3D() {
        // Create 3D mesh from segmentation
        let scene = SCNScene()
        
        // Add organs as 3D meshes
        let liverNode = createOrganNode(name: "liver", color: .systemRed)
        let kidneyNode = createOrganNode(name: "kidney", color: .systemOrange)
        
        scene.rootNode.addChildNode(liverNode)
        scene.rootNode.addChildNode(kidneyNode)
        
        // Add lighting
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        sceneView.scene = scene
    }
    
    private func createOrganNode(name: String, color: UIColor) -> SCNNode {
        // Placeholder geometry
        let geometry = SCNSphere(radius: 2.0)
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.transparency = 0.8
        
        let node = SCNNode(geometry: geometry)
        node.name = name
        
        // Add pulsing animation
        let pulseAnimation = CABasicAnimation(keyPath: "scale")
        pulseAnimation.fromValue = SCNVector3(1, 1, 1)
        pulseAnimation.toValue = SCNVector3(1.1, 1.1, 1.1)
        pulseAnimation.duration = 2.0
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        node.addAnimation(pulseAnimation, forKey: "pulse")
        
        return node
    }
    
    // MARK: - Transfer Functions
    
    private func applyDefaultTransferFunction() {
        let defaultFunction = TransferFunction.bone()
        applyTransferFunction(defaultFunction)
    }
    
    private func applyTransferFunction(_ function: TransferFunction) {
        volumeRenderView.applyTransferFunction(function)
    }
    
    // MARK: - Segmentation
    
    private func toggleSegmentation(organs: Set<String>) {
        volumeRenderView.showSegmentation(for: organs)
        
        // Update 3D mesh if in mesh mode
        if currentRenderingMode == .mesh3D {
            updateMeshVisibility(organs: organs)
        }
    }
    
    private func updateMeshVisibility(organs: Set<String>) {
        sceneView.scene?.rootNode.enumerateChildNodes { node, _ in
            if let name = node.name {
                node.isHidden = !organs.contains(name)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func rotationToggled() {
        if rotationToggle.isOn {
            volumeRenderView.startAutoRotation(speed: animationSpeed.value)
            sceneView.allowsCameraControl = false
            
            // Add rotation to SceneKit
            let rotation = CABasicAnimation(keyPath: "rotation")
            rotation.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, Double.pi * 2))
            rotation.duration = 10.0 / Double(animationSpeed.value)
            rotation.repeatCount = .infinity
            sceneView.scene?.rootNode.addAnimation(rotation, forKey: "rotation")
        } else {
            volumeRenderView.stopAutoRotation()
            sceneView.allowsCameraControl = true
            sceneView.scene?.rootNode.removeAllAnimations()
        }
    }
    
    @objc private func speedChanged() {
        if rotationToggle.isOn {
            volumeRenderView.updateRotationSpeed(animationSpeed.value)
            
            // Update SceneKit rotation
            sceneView.scene?.rootNode.removeAnimation(forKey: "rotation")
            rotationToggled() // Re-apply with new speed
        }
    }
    
    private func loadAIModel(_ model: AIModel) {
        // Load selected AI model
        showLoadingState()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.hideLoadingState()
            self?.startAIAnalysis()
        }
    }
    
    private func updateConfidenceThreshold(_ threshold: Float) {
        // Update AI confidence threshold
        volumeRenderView.setConfidenceThreshold(threshold)
    }
    
    // MARK: - Loading State
    
    private func showLoadingState() {
        progressRing.isHidden = false
        progressRing.startAnimating()
        
        // Blur 3D view
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.tag = 999
        blurView.frame = volumeRenderView.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        volumeRenderView.addSubview(blurView)
    }
    
    private func hideLoadingState() {
        progressRing.stopAnimating()
        progressRing.isHidden = true
        
        // Remove blur
        volumeRenderView.viewWithTag(999)?.removeFromSuperview()
    }
    
    // MARK: - Animations
    
    private func performEntranceAnimation() {
        // Initial states
        aiControlPanel.transform = CGAffineTransform(translationX: 0, y: -100)
        volumeRenderView.alpha = 0
        volumeRenderView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        [renderingModeSelector, transferFunctionEditor, segmentationPanel].forEach { view in
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 100, y: 0)
        }
        
        // Animate
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.aiControlPanel.transform = .identity
        }
        
        UIView.animate(withDuration: 0.8, delay: 0.2) {
            self.volumeRenderView.alpha = 1
            self.volumeRenderView.transform = .identity
        }
        
        // Stagger side panel animations
        let sidePanels = [renderingModeSelector, transferFunctionEditor, segmentationPanel]
        for (index, panel) in sidePanels.enumerated() {
            UIView.animate(withDuration: 0.5, delay: 0.3 + Double(index) * 0.1) {
                panel.alpha = 1
                panel.transform = .identity
            }
        }
        
        // Particle effect
        let particleView = ParticleEffectView(frame: view.bounds)
        view.insertSubview(particleView, aboveSubview: backgroundView)
        particleView.startParticleEffect(type: .medical)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            particleView.stopParticleEffect()
            UIView.animate(withDuration: 1.0) {
                particleView.alpha = 0
            } completion: { _ in
                particleView.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Interactions
    
    private func setupInteractions() {
        // Setup gesture recognizers and interactions
    }
}

// MARK: - Supporting Types

enum RenderingMode {
    case volumeRendering
    case maximumIntensityProjection
    case isosurface
    case mesh3D
}

struct AIModel {
    let name: String
    let type: String
    let accuracy: Float
}

struct AIAnalysisResult {
    let organ: String
    let volume: Double
    let confidence: Double
    let anomalies: Int
}

struct TransferFunction {
    let name: String
    let colorMap: [UIColor]
    let opacityMap: [Float]
    
    static func bone() -> TransferFunction {
        return TransferFunction(
            name: "Bone",
            colorMap: [.black, .gray, .white],
            opacityMap: [0, 0.5, 1.0]
        )
    }
    
    static func softTissue() -> TransferFunction {
        return TransferFunction(
            name: "Soft Tissue",
            colorMap: [.black, .red, .yellow],
            opacityMap: [0, 0.3, 0.8]
        )
    }
}