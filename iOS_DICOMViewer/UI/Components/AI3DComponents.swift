//
//  AI3DComponents.swift
//  iOS_DICOMViewer
//
//  Advanced components for 3D rendering and AI analysis
//

import UIKit
import Metal
import MetalKit
import CoreML

// MARK: - Volume Rendering View
class VolumeRenderingView: MTKView {
    
    enum RenderMode {
        case volumeRendering
        case mip // Maximum Intensity Projection
        case isosurface
    }
    
    private var commandQueue: MTLCommandQueue?
    private var volumeTexture: MTLTexture?
    private var renderPipeline: MTLRenderPipelineState?
    private var computePipeline: MTLComputePipelineState?
    
    private var currentMode: RenderMode = .volumeRendering
    private var rotationAngle: Float = 0
    private var autoRotating = false
    private var rotationSpeed: Float = 1.0
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        setupMetal()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupMetal()
    }
    
    private func setupMetal() {
        guard let device = device else { return }
        
        commandQueue = device.makeCommandQueue()
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        delegate = self
        
        // Setup render pipeline
        setupRenderPipeline()
    }
    
    private func setupRenderPipeline() {
        // This would load custom Metal shaders for volume rendering
        // For now, using placeholder implementation
    }
    
    func loadVolume(from study: DICOMStudy?) {
        // Load DICOM volume data into 3D texture
        guard let device = device else { return }
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.pixelFormat = .r16Float
        textureDescriptor.width = 256
        textureDescriptor.height = 256
        textureDescriptor.depth = 128
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        volumeTexture = device.makeTexture(descriptor: textureDescriptor)
        
        // Load volume data from DICOM series
        // This is a placeholder - actual implementation would process DICOM data
    }
    
    func setRenderingMode(_ mode: RenderMode) {
        currentMode = mode
        setNeedsDisplay()
    }
    
    func applyTransferFunction(_ function: TransferFunction) {
        // Apply transfer function to volume rendering
        setNeedsDisplay()
    }
    
    func showSegmentation(for organs: Set<String>) {
        // Overlay segmentation masks
        setNeedsDisplay()
    }
    
    func setConfidenceThreshold(_ threshold: Float) {
        // Update AI confidence threshold for display
        setNeedsDisplay()
    }
    
    func startAutoRotation(speed: Float) {
        autoRotating = true
        rotationSpeed = speed
        isPaused = false
    }
    
    func stopAutoRotation() {
        autoRotating = false
    }
    
    func updateRotationSpeed(_ speed: Float) {
        rotationSpeed = speed
    }
}

// MARK: - MTKViewDelegate
extension VolumeRenderingView: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue?.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else { return }
        
        // Update rotation if auto-rotating
        if autoRotating {
            rotationAngle += 0.01 * rotationSpeed
        }
        
        // Render volume based on current mode
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Rendering Mode Selector
class RenderingModeSelector: UIView {
    
    var onModeChanged: ((RenderingMode) -> Void)?
    
    private let modes: [(RenderingMode, String, String)] = [
        (.volumeRendering, "Volume", "cube.fill"),
        (.maximumIntensityProjection, "MIP", "rays"),
        (.isosurface, "Surface", "circle.grid.3x3.fill"),
        (.mesh3D, "Mesh", "cube.transparent")
    ]
    
    private var modeButtons: [UIButton] = []
    private var selectedMode: RenderingMode = .volumeRendering
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSelector()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSelector()
    }
    
    private func setupSelector() {
        backgroundColor = MedicalColorPalette.primaryMedium.withAlphaComponent(0.3)
        layer.cornerRadius = 16
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for (mode, title, icon) in modes {
            let button = createModeButton(mode: mode, title: title, icon: icon)
            modeButtons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        
        selectMode(.volumeRendering)
    }
    
    private func createModeButton(mode: RenderingMode, title: String, icon: String) -> UIButton {
        let button = NeumorphicButton()
        
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = MedicalTypography.bodySmall
        
        // Stack image and label vertically
        button.contentHorizontalAlignment = .center
        button.titleEdgeInsets = UIEdgeInsets(top: 30, left: -30, bottom: 0, right: 0)
        button.imageEdgeInsets = UIEdgeInsets(top: -10, left: 0, bottom: 0, right: 0)
        
        button.addTarget(self, action: #selector(modeTapped(_:)), for: .touchUpInside)
        button.tag = modes.firstIndex(where: { $0.0 == mode }) ?? 0
        
        return button
    }
    
    @objc private func modeTapped(_ sender: UIButton) {
        let mode = modes[sender.tag].0
        selectMode(mode)
        onModeChanged?(mode)
    }
    
    private func selectMode(_ mode: RenderingMode) {
        selectedMode = mode
        
        for (index, button) in modeButtons.enumerated() {
            let isSelected = modes[index].0 == mode
            button.tintColor = isSelected ? MedicalColorPalette.accentPrimary : .white
            button.titleLabel?.textColor = isSelected ? MedicalColorPalette.accentPrimary : .white
        }
    }
}

// MARK: - Transfer Function Editor
class TransferFunctionEditor: UIView {
    
    var onTransferFunctionChanged: ((TransferFunction) -> Void)?
    
    private let gradientView = UIView()
    private let opacityEditor = OpacityEditorView()
    private let presetButtons: [UIButton] = []
    
    private let presets = [
        TransferFunction.bone(),
        TransferFunction.softTissue(),
        TransferFunction(name: "Lung", colorMap: [.black, .blue, .cyan], opacityMap: [0, 0.2, 0.8]),
        TransferFunction(name: "Custom", colorMap: [], opacityMap: [])
    ]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupEditor()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupEditor()
    }
    
    private func setupEditor() {
        backgroundColor = MedicalColorPalette.primaryMedium.withAlphaComponent(0.3)
        layer.cornerRadius = 16
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Transfer Function"
        titleLabel.font = MedicalTypography.headlineSmall
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Gradient display
        gradientView.layer.cornerRadius = 8
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        updateGradientDisplay(TransferFunction.bone())
        
        // Opacity editor
        opacityEditor.translatesAutoresizingMaskIntoConstraints = false
        opacityEditor.onOpacityChanged = { [weak self] opacityMap in
            self?.updateCustomTransferFunction(opacityMap: opacityMap)
        }
        
        // Preset buttons
        let presetStack = UIStackView()
        presetStack.axis = .horizontal
        presetStack.distribution = .fillEqually
        presetStack.spacing = 8
        presetStack.translatesAutoresizingMaskIntoConstraints = false
        
        for preset in presets {
            let button = createPresetButton(preset: preset)
            presetStack.addArrangedSubview(button)
        }
        
        addSubview(titleLabel)
        addSubview(gradientView)
        addSubview(opacityEditor)
        addSubview(presetStack)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            gradientView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            gradientView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            gradientView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            gradientView.heightAnchor.constraint(equalToConstant: 30),
            
            opacityEditor.topAnchor.constraint(equalTo: gradientView.bottomAnchor, constant: 12),
            opacityEditor.leadingAnchor.constraint(equalTo: gradientView.leadingAnchor),
            opacityEditor.trailingAnchor.constraint(equalTo: gradientView.trailingAnchor),
            opacityEditor.heightAnchor.constraint(equalToConstant: 60),
            
            presetStack.topAnchor.constraint(equalTo: opacityEditor.bottomAnchor, constant: 12),
            presetStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            presetStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            presetStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    private func createPresetButton(preset: TransferFunction) -> UIButton {
        let button = NeumorphicButton()
        button.setTitle(preset.name, for: .normal)
        button.titleLabel?.font = MedicalTypography.bodySmall
        button.setTitleColor(.white, for: .normal)
        button.addTarget(self, action: #selector(presetTapped(_:)), for: .touchUpInside)
        button.tag = presets.firstIndex(where: { $0.name == preset.name }) ?? 0
        return button
    }
    
    @objc private func presetTapped(_ sender: UIButton) {
        let preset = presets[sender.tag]
        updateGradientDisplay(preset)
        opacityEditor.setOpacityMap(preset.opacityMap)
        onTransferFunctionChanged?(preset)
    }
    
    private func updateGradientDisplay(_ function: TransferFunction) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = gradientView.bounds
        gradientLayer.colors = function.colorMap.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        
        gradientView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        gradientView.layer.addSublayer(gradientLayer)
    }
    
    private func updateCustomTransferFunction(opacityMap: [Float]) {
        // Create custom transfer function
        let customFunction = TransferFunction(
            name: "Custom",
            colorMap: [.black, .white], // Simplified
            opacityMap: opacityMap
        )
        onTransferFunctionChanged?(customFunction)
    }
}

// MARK: - Opacity Editor View
class OpacityEditorView: UIView {
    
    var onOpacityChanged: (([Float]) -> Void)?
    
    private var controlPoints: [CGPoint] = []
    private let curveLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupEditor()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupEditor()
    }
    
    private func setupEditor() {
        backgroundColor = MedicalColorPalette.primaryDark.withAlphaComponent(0.5)
        layer.cornerRadius = 8
        
        // Curve layer
        curveLayer.strokeColor = MedicalColorPalette.accentPrimary.cgColor
        curveLayer.fillColor = UIColor.clear.cgColor
        curveLayer.lineWidth = 2
        layer.addSublayer(curveLayer)
        
        // Default linear opacity
        controlPoints = [
            CGPoint(x: 0, y: bounds.height),
            CGPoint(x: bounds.width, y: 0)
        ]
        
        // Gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCurve()
    }
    
    func setOpacityMap(_ map: [Float]) {
        // Convert opacity values to control points
        controlPoints = map.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(map.count - 1) * bounds.width
            let y = (1 - CGFloat(value)) * bounds.height
            return CGPoint(x: x, y: y)
        }
        updateCurve()
    }
    
    private func updateCurve() {
        let path = UIBezierPath()
        
        if controlPoints.isEmpty { return }
        
        path.move(to: controlPoints[0])
        for point in controlPoints.dropFirst() {
            path.addLine(to: point)
        }
        
        curveLayer.path = path.cgPath
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        
        // Find nearest control point
        // Update opacity curve
        // Notify delegate
    }
}

// MARK: - Segmentation Control Panel
class SegmentationControlPanel: GlassMorphismView {
    
    private let titleLabel = UILabel()
    private let organToggles: [OrganToggleView] = []
    private let confidenceSlider = UISlider()
    private let volumeLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPanel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPanel()
    }
    
    private func setupPanel() {
        glassIntensity = 0.8
        
        // Title
        titleLabel.text = "AI Segmentation"
        titleLabel.font = MedicalTypography.headlineMedium
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Organ list (placeholder)
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Confidence threshold
        let confidenceLabel = UILabel()
        confidenceLabel.text = "Confidence: 80%"
        confidenceLabel.font = MedicalTypography.bodySmall
        confidenceLabel.textColor = .white
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        confidenceSlider.minimumValue = 0
        confidenceSlider.maximumValue = 100
        confidenceSlider.value = 80
        confidenceSlider.tintColor = MedicalColorPalette.accentPrimary
        confidenceSlider.translatesAutoresizingMaskIntoConstraints = false
        
        // Total volume
        volumeLabel.text = "Total Volume: -- mL"
        volumeLabel.font = MedicalTypography.monoMedium
        volumeLabel.textColor = MedicalColorPalette.accentSecondary
        volumeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        addSubview(stackView)
        addSubview(confidenceLabel)
        addSubview(confidenceSlider)
        addSubview(volumeLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            confidenceLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 20),
            confidenceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            confidenceSlider.topAnchor.constraint(equalTo: confidenceLabel.bottomAnchor, constant: 8),
            confidenceSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            confidenceSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            volumeLabel.topAnchor.constraint(equalTo: confidenceSlider.bottomAnchor, constant: 20),
            volumeLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
    
    func enableOrgans(_ organs: [String]) {
        // Create organ toggles
    }
}

// MARK: - AI Model Selector
class AIModelSelector: UIView {
    
    var onModelSelected: ((AIModel) -> Void)?
    
    private let models = [
        AIModel(name: "TotalSegmentator", type: "CT", accuracy: 0.92),
        AIModel(name: "nnU-Net", type: "MRI", accuracy: 0.89),
        AIModel(name: "Custom Model", type: "Multi", accuracy: 0.85)
    ]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSelector()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSelector()
    }
    
    private func setupSelector() {
        // Implementation
    }
}

// MARK: - Other Components
class SegmentationToggleView: UIView {
    var onSegmentationToggled: ((Set<String>) -> Void)?
}

class ConfidenceThresholdControl: UIView {
    var onThresholdChanged: ((Float) -> Void)?
}

class AIAnalysisResultsPanel: GlassMorphismView {
    func displayResults(_ results: [AIAnalysisResult]) {
        // Display AI analysis results
    }
}

class LightingControlView: UIView {
    // 3D lighting controls
}

class CircularProgressView: UIView {
    func startAnimating() {
        // Circular progress animation
    }
    
    func stopAnimating() {
        // Stop animation
    }
}

class OrganToggleView: UIView {
    // Individual organ toggle
}