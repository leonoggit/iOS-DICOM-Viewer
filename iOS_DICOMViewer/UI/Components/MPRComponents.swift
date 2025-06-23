//
//  MPRComponents.swift
//  iOS_DICOMViewer
//
//  Specialized components for Multi-Planar Reconstruction
//

import UIKit
import Metal
import MetalKit

// MARK: - Plane Types
enum PlaneType {
    case axial, coronal, sagittal
    
    var color: UIColor {
        switch self {
        case .axial: return MedicalColorPalette.accentPrimary
        case .coronal: return MedicalColorPalette.accentSecondary
        case .sagittal: return MedicalColorPalette.accentTertiary
        }
    }
    
    var label: String {
        switch self {
        case .axial: return "Axial"
        case .coronal: return "Coronal"
        case .sagittal: return "Sagittal"
        }
    }
}

// MARK: - MPR Plane View
protocol MPRPlaneViewDelegate: AnyObject {
    func planeView(_ planeView: MPRPlaneView, didUpdateCrosshair position: CGPoint)
    func planeView(_ planeView: MPRPlaneView, didScrollToSlice slice: Int)
}

class MPRPlaneView: UIView {
    
    // Properties
    var planeType: PlaneType = .axial {
        didSet { updatePlaneAppearance() }
    }
    
    weak var delegate: MPRPlaneViewDelegate?
    
    // UI Components
    private let imageView = UIImageView()
    private let crosshairLayer = CAShapeLayer()
    private let planeLabel = UILabel()
    private let sliceLabel = UILabel()
    private let overlayView = UIView()
    
    // State
    private var currentSlice = 0
    private var crosshairPosition = CGPoint(x: 0.5, y: 0.5)
    private var isDraggingCrosshair = false
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .black
        
        // Image view
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        // Overlay for interactions
        overlayView.backgroundColor = .clear
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlayView)
        
        // Crosshair
        crosshairLayer.strokeColor = UIColor.white.withAlphaComponent(0.8).cgColor
        crosshairLayer.lineWidth = 1
        crosshairLayer.lineDashPattern = [4, 4]
        overlayView.layer.addSublayer(crosshairLayer)
        
        // Plane label
        planeLabel.font = MedicalTypography.headlineSmall
        planeLabel.textColor = .white
        planeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(planeLabel)
        
        // Slice label
        sliceLabel.font = MedicalTypography.monoSmall
        sliceLabel.textColor = MedicalColorPalette.primaryLight
        sliceLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sliceLabel)
        
        // Add glass morphism border
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            planeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            planeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            
            sliceLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            sliceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
        
        setupGestures()
    }
    
    private func setupGestures() {
        // Pan for crosshair
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        overlayView.addGestureRecognizer(panGesture)
        
        // Scroll for slices
        let scrollGesture = UIPanGestureRecognizer(target: self, action: #selector(handleScroll(_:)))
        scrollGesture.minimumNumberOfTouches = 2
        overlayView.addGestureRecognizer(scrollGesture)
        
        // Tap to center crosshair
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        overlayView.addGestureRecognizer(tapGesture)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCrosshair()
    }
    
    // MARK: - Public Methods
    
    func loadStudy(_ study: DICOMStudy) {
        // Load appropriate plane data
        updateSliceLabel()
    }
    
    func setSlice(_ slice: Int) {
        currentSlice = slice
        updateSliceLabel()
        // Load and display the slice image
    }
    
    func setCrosshairPosition(_ position: CGPoint) {
        crosshairPosition = position
        updateCrosshair()
    }
    
    func setWindowLevel(window: Double, level: Double) {
        // Apply window/level to current image
    }
    
    func setSliceThickness(_ thickness: Int) {
        // Apply slice thickness (MIP/MinIP)
    }
    
    // MARK: - Private Methods
    
    private func updatePlaneAppearance() {
        planeLabel.text = planeType.label
        layer.shadowColor = planeType.color.cgColor
        
        // Update crosshair color
        crosshairLayer.strokeColor = planeType.color.cgColor
    }
    
    private func updateCrosshair() {
        let path = UIBezierPath()
        
        let centerX = bounds.width * crosshairPosition.x
        let centerY = bounds.height * crosshairPosition.y
        
        // Horizontal line
        path.move(to: CGPoint(x: 0, y: centerY))
        path.addLine(to: CGPoint(x: bounds.width, y: centerY))
        
        // Vertical line
        path.move(to: CGPoint(x: centerX, y: 0))
        path.addLine(to: CGPoint(x: centerX, y: bounds.height))
        
        // Center circle
        path.move(to: CGPoint(x: centerX + 10, y: centerY))
        path.addArc(withCenter: CGPoint(x: centerX, y: centerY),
                   radius: 10,
                   startAngle: 0,
                   endAngle: .pi * 2,
                   clockwise: true)
        
        crosshairLayer.path = path.cgPath
    }
    
    private func updateSliceLabel() {
        sliceLabel.text = "Slice \(currentSlice + 1)"
    }
    
    // MARK: - Gestures
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: overlayView)
        
        switch gesture.state {
        case .began:
            // Check if near crosshair
            let centerX = bounds.width * crosshairPosition.x
            let centerY = bounds.height * crosshairPosition.y
            let distance = hypot(location.x - centerX, location.y - centerY)
            isDraggingCrosshair = distance < 30
            
        case .changed:
            if isDraggingCrosshair {
                crosshairPosition = CGPoint(
                    x: location.x / bounds.width,
                    y: location.y / bounds.height
                )
                crosshairPosition.x = max(0, min(1, crosshairPosition.x))
                crosshairPosition.y = max(0, min(1, crosshairPosition.y))
                
                updateCrosshair()
                delegate?.planeView(self, didUpdateCrosshair: crosshairPosition)
                
                // Haptic feedback
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            }
            
        case .ended, .cancelled:
            isDraggingCrosshair = false
            
        default:
            break
        }
    }
    
    @objc private func handleScroll(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .changed else { return }
        
        let velocity = gesture.velocity(in: overlayView)
        let scrollDelta = Int(velocity.y / 100)
        
        if scrollDelta != 0 {
            let newSlice = currentSlice - scrollDelta
            // Clamp to valid range
            currentSlice = max(0, min(99, newSlice)) // Placeholder max
            updateSliceLabel()
            delegate?.planeView(self, didScrollToSlice: currentSlice)
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: overlayView)
        crosshairPosition = CGPoint(
            x: location.x / bounds.width,
            y: location.y / bounds.height
        )
        updateCrosshair()
        delegate?.planeView(self, didUpdateCrosshair: crosshairPosition)
        
        // Animate crosshair movement
        let animation = CABasicAnimation(keyPath: "strokeColor")
        animation.fromValue = UIColor.white.cgColor
        animation.toValue = planeType.color.cgColor
        animation.duration = 0.3
        animation.autoreverses = true
        crosshairLayer.add(animation, forKey: "pulse")
    }
}

// MARK: - Crosshair Control
class CrosshairControlView: UIView {
    
    var onCrosshairMoved: ((CGPoint) -> Void)?
    
    private let controlKnob = UIView()
    private var currentPosition = CGPoint(x: 0.5, y: 0.5)
    
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
        layer.cornerRadius = 30
        
        // Control knob
        controlKnob.backgroundColor = MedicalColorPalette.accentPrimary
        controlKnob.layer.cornerRadius = 10
        controlKnob.layer.shadowColor = MedicalColorPalette.accentPrimary.cgColor
        controlKnob.layer.shadowOffset = .zero
        controlKnob.layer.shadowRadius = 10
        controlKnob.layer.shadowOpacity = 0.5
        
        addSubview(controlKnob)
        
        // Gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateKnobPosition()
    }
    
    private func updateKnobPosition() {
        let x = bounds.width * currentPosition.x
        let y = bounds.height * currentPosition.y
        controlKnob.frame = CGRect(x: x - 10, y: y - 10, width: 20, height: 20)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        currentPosition = CGPoint(
            x: location.x / bounds.width,
            y: location.y / bounds.height
        )
        currentPosition.x = max(0, min(1, currentPosition.x))
        currentPosition.y = max(0, min(1, currentPosition.y))
        
        updateKnobPosition()
        onCrosshairMoved?(currentPosition)
        
        if gesture.state == .changed {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
}

// MARK: - Slice Navigator
class SliceNavigatorView: UIView {
    
    var onSliceChanged: ((PlaneType, Int) -> Void)?
    
    private let axialSlider = createSlider(color: PlaneType.axial.color)
    private let coronalSlider = createSlider(color: PlaneType.coronal.color)
    private let sagittalSlider = createSlider(color: PlaneType.sagittal.color)
    
    private let axialLabel = UILabel()
    private let coronalLabel = UILabel()
    private let sagittalLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupNavigator()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNavigator()
    }
    
    private static func createSlider(color: UIColor) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 99
        slider.tintColor = color
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }
    
    private func setupNavigator() {
        backgroundColor = MedicalColorPalette.primaryMedium.withAlphaComponent(0.3)
        layer.cornerRadius = 16
        
        // Configure labels
        [axialLabel, coronalLabel, sagittalLabel].enumerated().forEach { index, label in
            label.font = MedicalTypography.bodySmall
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
            
            switch index {
            case 0: label.text = "A: 1/100"
            case 1: label.text = "C: 1/100"
            case 2: label.text = "S: 1/100"
            default: break
            }
        }
        
        // Add targets
        axialSlider.addTarget(self, action: #selector(axialChanged), for: .valueChanged)
        coronalSlider.addTarget(self, action: #selector(coronalChanged), for: .valueChanged)
        sagittalSlider.addTarget(self, action: #selector(sagittalChanged), for: .valueChanged)
        
        // Layout
        let stackView = UIStackView(arrangedSubviews: [
            createSliderRow(slider: axialSlider, label: axialLabel),
            createSliderRow(slider: coronalSlider, label: coronalLabel),
            createSliderRow(slider: sagittalSlider, label: sagittalLabel)
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    private func createSliderRow(slider: UISlider, label: UILabel) -> UIView {
        let container = UIView()
        container.addSubview(slider)
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            slider.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    func updateSliceCounts(axial: Int, coronal: Int, sagittal: Int) {
        axialSlider.maximumValue = Float(axial - 1)
        coronalSlider.maximumValue = Float(coronal - 1)
        sagittalSlider.maximumValue = Float(sagittal - 1)
    }
    
    func updateCurrentSlices(_ slices: (axial: Int, coronal: Int, sagittal: Int)) {
        axialSlider.value = Float(slices.axial)
        coronalSlider.value = Float(slices.coronal)
        sagittalSlider.value = Float(slices.sagittal)
        
        updateLabels()
    }
    
    private func updateLabels() {
        axialLabel.text = "A: \(Int(axialSlider.value) + 1)/\(Int(axialSlider.maximumValue) + 1)"
        coronalLabel.text = "C: \(Int(coronalSlider.value) + 1)/\(Int(coronalSlider.maximumValue) + 1)"
        sagittalLabel.text = "S: \(Int(sagittalSlider.value) + 1)/\(Int(sagittalSlider.maximumValue) + 1)"
    }
    
    @objc private func axialChanged() {
        onSliceChanged?(.axial, Int(axialSlider.value))
        updateLabels()
    }
    
    @objc private func coronalChanged() {
        onSliceChanged?(.coronal, Int(coronalSlider.value))
        updateLabels()
    }
    
    @objc private func sagittalChanged() {
        onSliceChanged?(.sagittal, Int(sagittalSlider.value))
        updateLabels()
    }
}

// MARK: - MPR Layout Selector
enum MPRLayout {
    case grid2x2
    case axialFocus
    case coronalFocus
    case sagittalFocus
    case volume3DFocus
    case custom
}

class MPRLayoutSelector: UIView {
    
    var onLayoutChanged: ((MPRLayout) -> Void)?
    
    private let layouts: [(MPRLayout, String)] = [
        (.grid2x2, "square.grid.2x2"),
        (.axialFocus, "square.lefthalf.filled"),
        (.coronalFocus, "square.tophalf.filled"),
        (.sagittalFocus, "square.righthalf.filled"),
        (.volume3DFocus, "cube")
    ]
    
    private var layoutButtons: [UIButton] = []
    private var selectedLayout: MPRLayout = .grid2x2
    
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
        layer.cornerRadius = 20
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for (layout, icon) in layouts {
            let button = createLayoutButton(layout: layout, icon: icon)
            layoutButtons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        
        // Select default
        selectLayout(.grid2x2)
    }
    
    private func createLayoutButton(layout: MPRLayout, icon: String) -> UIButton {
        let button = UIButton()
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = .white
        button.backgroundColor = MedicalColorPalette.primaryDark.withAlphaComponent(0.5)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(layoutTapped(_:)), for: .touchUpInside)
        button.tag = layouts.firstIndex(where: { $0.0 == layout }) ?? 0
        return button
    }
    
    @objc private func layoutTapped(_ sender: UIButton) {
        let layout = layouts[sender.tag].0
        selectLayout(layout)
        onLayoutChanged?(layout)
    }
    
    private func selectLayout(_ layout: MPRLayout) {
        selectedLayout = layout
        
        for (index, button) in layoutButtons.enumerated() {
            let isSelected = layouts[index].0 == layout
            button.backgroundColor = isSelected ?
                MedicalColorPalette.accentPrimary.withAlphaComponent(0.3) :
                MedicalColorPalette.primaryDark.withAlphaComponent(0.5)
            button.tintColor = isSelected ? MedicalColorPalette.accentPrimary : .white
        }
    }
}

// MARK: - Other MPR Controls
class SliceThicknessControl: UIView {
    var onThicknessChanged: ((Int) -> Void)?
    
    // Implementation for slice thickness control
}

class OrientationCubeView: UIView {
    // 3D orientation cube implementation
}