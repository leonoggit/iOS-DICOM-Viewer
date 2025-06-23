//
//  ViewerControls.swift
//  iOS_DICOMViewer
//
//  Advanced medical imaging controls for the ultra-modern viewer
//

import UIKit

// MARK: - Window/Level Control
class WindowLevelControlView: UIView {
    
    var onWindowLevelChanged: ((Double, Double) -> Void)?
    
    private let windowSlider = UISlider()
    private let levelSlider = UISlider()
    private let windowLabel = UILabel()
    private let levelLabel = UILabel()
    
    private var currentWindow: Double = 400.0
    private var currentLevel: Double = 40.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupControl()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupControl()
    }
    
    private func setupControl() {
        backgroundColor = MedicalColorPalette.primaryMedium.withAlphaComponent(0.3)
        layer.cornerRadius = 16
        
        // Window control
        windowLabel.text = "W"
        windowLabel.font = MedicalTypography.bodySmall
        windowLabel.textColor = .white
        windowLabel.textAlignment = .center
        
        windowSlider.minimumValue = 1
        windowSlider.maximumValue = 4000
        windowSlider.value = Float(currentWindow)
        windowSlider.isContinuous = true
        windowSlider.tintColor = MedicalColorPalette.accentPrimary
        windowSlider.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        windowSlider.addTarget(self, action: #selector(windowChanged), for: .valueChanged)
        
        // Level control
        levelLabel.text = "L"
        levelLabel.font = MedicalTypography.bodySmall
        levelLabel.textColor = .white
        levelLabel.textAlignment = .center
        
        levelSlider.minimumValue = -1000
        levelSlider.maximumValue = 1000
        levelSlider.value = Float(currentLevel)
        levelSlider.isContinuous = true
        levelSlider.tintColor = MedicalColorPalette.accentSecondary
        levelSlider.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        levelSlider.addTarget(self, action: #selector(levelChanged), for: .valueChanged)
        
        // Layout
        windowLabel.translatesAutoresizingMaskIntoConstraints = false
        windowSlider.translatesAutoresizingMaskIntoConstraints = false
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        levelSlider.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(windowLabel)
        addSubview(windowSlider)
        addSubview(levelLabel)
        addSubview(levelSlider)
        
        NSLayoutConstraint.activate([
            windowLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            windowLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            windowLabel.widthAnchor.constraint(equalToConstant: 20),
            
            windowSlider.centerXAnchor.constraint(equalTo: windowLabel.centerXAnchor),
            windowSlider.topAnchor.constraint(equalTo: windowLabel.bottomAnchor, constant: 30),
            windowSlider.widthAnchor.constraint(equalToConstant: 120),
            
            levelLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            levelLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            levelLabel.widthAnchor.constraint(equalToConstant: 20),
            
            levelSlider.centerXAnchor.constraint(equalTo: levelLabel.centerXAnchor),
            levelSlider.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 30),
            levelSlider.widthAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    @objc private func windowChanged() {
        currentWindow = Double(windowSlider.value)
        onWindowLevelChanged?(currentWindow, currentLevel)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    @objc private func levelChanged() {
        currentLevel = Double(levelSlider.value)
        onWindowLevelChanged?(currentWindow, currentLevel)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Preset Selector
struct WindowLevelPreset {
    let name: String
    let window: Double
    let level: Double
}

class PresetSelectorView: UIView {
    
    var onPresetSelected: ((WindowLevelPreset) -> Void)?
    
    private let presets = [
        WindowLevelPreset(name: "Lung", window: 1500, level: -600),
        WindowLevelPreset(name: "Bone", window: 2000, level: 300),
        WindowLevelPreset(name: "Brain", window: 80, level: 40),
        WindowLevelPreset(name: "Soft Tissue", window: 350, level: 50),
        WindowLevelPreset(name: "Liver", window: 150, level: 30)
    ]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPresets()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPresets()
    }
    
    private func setupPresets() {
        backgroundColor = .clear
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for preset in presets {
            let button = createPresetButton(preset: preset)
            stackView.addArrangedSubview(button)
        }
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func createPresetButton(preset: WindowLevelPreset) -> UIButton {
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
        onPresetSelected?(preset)
    }
}

// MARK: - Circular Zoom Control
class CircularZoomControl: UIView {
    
    var onZoomChanged: ((CGFloat) -> Void)?
    
    private let circleLayer = CAShapeLayer()
    private let indicatorLayer = CAShapeLayer()
    private var currentAngle: CGFloat = 0
    private var currentZoom: CGFloat = 1.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupControl()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupControl()
    }
    
    private func setupControl() {
        backgroundColor = MedicalColorPalette.primaryMedium.withAlphaComponent(0.3)
        layer.cornerRadius = 40
        
        // Circle track
        let circlePath = UIBezierPath(
            arcCenter: CGPoint(x: 40, y: 40),
            radius: 30,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = MedicalColorPalette.primaryLight.cgColor
        circleLayer.lineWidth = 4
        layer.addSublayer(circleLayer)
        
        // Indicator
        indicatorLayer.bounds = CGRect(x: 0, y: 0, width: 12, height: 12)
        indicatorLayer.position = CGPoint(x: 40 + 30, y: 40)
        indicatorLayer.cornerRadius = 6
        indicatorLayer.backgroundColor = MedicalColorPalette.accentPrimary.cgColor
        layer.addSublayer(indicatorLayer)
        
        // Center label
        let zoomLabel = UILabel()
        zoomLabel.text = "1.0x"
        zoomLabel.font = MedicalTypography.monoSmall
        zoomLabel.textColor = .white
        zoomLabel.textAlignment = .center
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(zoomLabel)
        
        NSLayoutConstraint.activate([
            zoomLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            zoomLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        let angle = atan2(location.y - center.y, location.x - center.x)
        currentAngle = angle
        
        // Update indicator position
        let x = center.x + cos(angle) * 30
        let y = center.y + sin(angle) * 30
        indicatorLayer.position = CGPoint(x: x, y: y)
        
        // Calculate zoom (1x to 5x)
        let normalizedAngle = (angle + .pi) / (2 * .pi)
        currentZoom = 1 + normalizedAngle * 4
        
        // Update label
        if let label = subviews.first(where: { $0 is UILabel }) as? UILabel {
            label.text = String(format: "%.1fx", currentZoom)
        }
        
        onZoomChanged?(currentZoom)
    }
}

// MARK: - Measurement Toolbar
enum MeasurementTool {
    case ruler
    case angle
    case area
    case roi
    case annotation
}

class MeasurementToolbarView: UIView {
    
    var onToolSelected: ((MeasurementTool) -> Void)?
    
    private let tools: [(MeasurementTool, String)] = [
        (.ruler, "ruler"),
        (.angle, "angle"),
        (.area, "square.dashed"),
        (.roi, "circle.dashed"),
        (.annotation, "pencil.tip")
    ]
    
    private var selectedTool: MeasurementTool?
    private var toolButtons: [UIButton] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupToolbar()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupToolbar()
    }
    
    private func setupToolbar() {
        backgroundColor = MedicalColorPalette.primaryMedium.withAlphaComponent(0.3)
        layer.cornerRadius = 16
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for (tool, icon) in tools {
            let button = createToolButton(tool: tool, icon: icon)
            toolButtons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    private func createToolButton(tool: MeasurementTool, icon: String) -> UIButton {
        let button = NeumorphicButton()
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(toolTapped(_:)), for: .touchUpInside)
        button.tag = tools.firstIndex(where: { $0.0 == tool }) ?? 0
        return button
    }
    
    @objc private func toolTapped(_ sender: UIButton) {
        let tool = tools[sender.tag].0
        selectedTool = tool
        
        // Update button states
        for (index, button) in toolButtons.enumerated() {
            button.tintColor = index == sender.tag ? MedicalColorPalette.accentPrimary : .white
        }
        
        onToolSelected?(tool)
    }
}

// MARK: - Metadata Overlay
class MetadataOverlayView: GlassMorphismView {
    
    private let stackView = UIStackView()
    private var metadataLabels: [UILabel] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }
    
    private func setupOverlay() {
        glassIntensity = 0.7
        
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    func updateMetadata(_ metadata: [String: String]) {
        // Clear existing labels
        metadataLabels.forEach { $0.removeFromSuperview() }
        metadataLabels.removeAll()
        
        // Add new labels
        for (key, value) in metadata {
            let label = UILabel()
            label.text = "\(key): \(value)"
            label.font = MedicalTypography.monoSmall
            label.textColor = .white
            
            stackView.addArrangedSubview(label)
            metadataLabels.append(label)
        }
    }
}

// MARK: - AI Analysis Overlay
struct AIFinding {
    enum FindingType {
        case anomaly, measurement, annotation
    }
    
    let type: FindingType
    let confidence: Double
    let location: CGRect
    let description: String
}

class AIAnalysisOverlayView: UIView {
    
    private var findingLayers: [CALayer] = []
    private let loadingView = QuantumLoadingIndicator()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }
    
    private func setupOverlay() {
        backgroundColor = .clear
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loadingView)
        
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 100),
            loadingView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    func showLoadingState() {
        loadingView.isHidden = false
        loadingView.startAnimating()
        findingLayers.forEach { $0.removeFromSuperlayer() }
        findingLayers.removeAll()
    }
    
    func displayFindings(_ findings: [AIFinding]) {
        loadingView.stopAnimating()
        loadingView.isHidden = true
        
        for finding in findings {
            let layer = createFindingLayer(for: finding)
            self.layer.addSublayer(layer)
            findingLayers.append(layer)
            
            // Animate appearance
            layer.opacity = 0
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0
            animation.toValue = 1
            animation.duration = 0.5
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: "appear")
        }
    }
    
    private func createFindingLayer(for finding: AIFinding) -> CALayer {
        let container = CALayer()
        container.frame = finding.location
        
        // Border
        let borderLayer = CAShapeLayer()
        borderLayer.path = UIBezierPath(roundedRect: container.bounds, cornerRadius: 8).cgPath
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = colorForFinding(finding).cgColor
        borderLayer.lineWidth = 2
        borderLayer.lineDashPattern = [4, 4]
        
        // Pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "strokeColor")
        pulseAnimation.fromValue = colorForFinding(finding).cgColor
        pulseAnimation.toValue = colorForFinding(finding).withAlphaComponent(0.3).cgColor
        pulseAnimation.duration = 1.0
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        borderLayer.add(pulseAnimation, forKey: "pulse")
        
        container.addSublayer(borderLayer)
        
        // Confidence badge
        let badgeLayer = createConfidenceBadge(confidence: finding.confidence)
        badgeLayer.position = CGPoint(x: container.bounds.maxX - 20, y: 20)
        container.addSublayer(badgeLayer)
        
        return container
    }
    
    private func colorForFinding(_ finding: AIFinding) -> UIColor {
        switch finding.type {
        case .anomaly:
            return MedicalColorPalette.accentCritical
        case .measurement:
            return MedicalColorPalette.accentPrimary
        case .annotation:
            return MedicalColorPalette.accentSecondary
        }
    }
    
    private func createConfidenceBadge(confidence: Double) -> CALayer {
        let badge = CATextLayer()
        badge.string = String(format: "%.0f%%", confidence * 100)
        badge.fontSize = 12
        badge.font = MedicalTypography.monoSmall
        badge.foregroundColor = UIColor.white.cgColor
        badge.backgroundColor = MedicalColorPalette.primaryMedium.cgColor
        badge.cornerRadius = 10
        badge.bounds = CGRect(x: 0, y: 0, width: 40, height: 20)
        badge.alignmentMode = .center
        badge.contentsScale = UIScreen.main.scale
        
        return badge
    }
}

// MARK: - Other Controls
class RotationControlView: UIView {
    var onRotationChanged: ((CGFloat) -> Void)?
    
    // Implementation similar to CircularZoomControl but for rotation
}

class FlipControlView: UIView {
    var onFlipChanged: ((Bool, Bool) -> Void)?
    
    // Implementation for horizontal/vertical flip controls
}

class SeriesNavigatorView: UIView {
    var onSeriesChanged: ((Int) -> Void)?
    
    // Implementation for series navigation
}

class InstanceSliderView: UIView {
    var onInstanceChanged: ((Int) -> Void)?
    
    // Implementation for instance slider
}

class ThumbnailStripView: UIView {
    var onThumbnailSelected: ((Int) -> Void)?
    
    func loadThumbnails(for instances: [DICOMInstance]) {
        // Implementation for thumbnail strip
    }
}

class ToastView: UIView {
    init(message: String) {
        super.init(frame: .zero)
        // Implementation for toast notifications
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(in view: UIView) {
        // Implementation for showing toast
    }
}