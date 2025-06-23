//
//  UltraModernComponents.swift
//  iOS_DICOMViewer
//
//  Cutting-edge UI components for medical imaging excellence
//

import UIKit
import SwiftUI
import Metal
import MetalKit
import AVFoundation

// MARK: - Quantum Loading Indicator
class QuantumLoadingIndicator: UIView {
    
    private var orbits: [CAShapeLayer] = []
    private var particles: [CALayer] = []
    private let particleCount = 8
    private let orbitCount = 3
    
    private var displayLink: CADisplayLink?
    private var phase: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupQuantumAnimation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupQuantumAnimation()
    }
    
    private func setupQuantumAnimation() {
        backgroundColor = .clear
        
        // Create orbits
        for i in 0..<orbitCount {
            let orbit = CAShapeLayer()
            let radius = CGFloat(30 + i * 20)
            let path = UIBezierPath(
                arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                radius: radius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            orbit.path = path.cgPath
            orbit.fillColor = UIColor.clear.cgColor
            orbit.strokeColor = MedicalColorPalette.accentPrimary.withAlphaComponent(0.2).cgColor
            orbit.lineWidth = 0.5
            orbit.lineDashPattern = [2, 4]
            
            layer.addSublayer(orbit)
            orbits.append(orbit)
        }
        
        // Create particles
        for i in 0..<particleCount {
            let particle = CALayer()
            particle.bounds = CGRect(x: 0, y: 0, width: 8, height: 8)
            particle.cornerRadius = 4
            particle.backgroundColor = MedicalColorPalette.accentPrimary.cgColor
            
            // Add glow effect
            particle.shadowColor = MedicalColorPalette.accentPrimary.cgColor
            particle.shadowOffset = .zero
            particle.shadowRadius = 10
            particle.shadowOpacity = 0.8
            
            layer.addSublayer(particle)
            particles.append(particle)
        }
    }
    
    func startAnimating() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateAnimation() {
        phase += 0.05
        
        for (index, particle) in particles.enumerated() {
            let angle = (CGFloat(index) / CGFloat(particleCount)) * .pi * 2 + phase
            let orbitIndex = index % orbitCount
            let radius = CGFloat(30 + orbitIndex * 20)
            
            let x = bounds.midX + cos(angle) * radius
            let y = bounds.midY + sin(angle) * radius
            
            particle.position = CGPoint(x: x, y: y)
            
            // Pulse effect
            let scale = 1.0 + sin(phase * 2 + CGFloat(index)) * 0.3
            particle.transform = CATransform3DMakeScale(scale, scale, 1)
            
            // Color shift
            let hue = (phase + CGFloat(index) * 0.1).truncatingRemainder(dividingBy: 1)
            particle.backgroundColor = UIColor(hue: hue, saturation: 0.8, brightness: 1, alpha: 1).cgColor
            particle.shadowColor = UIColor(hue: hue, saturation: 0.8, brightness: 1, alpha: 1).cgColor
        }
        
        // Rotate orbits
        for (index, orbit) in orbits.enumerated() {
            let rotation = CATransform3DMakeRotation(phase * CGFloat(index + 1) * 0.3, 0, 0, 1)
            orbit.transform = rotation
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update orbit paths
        for (index, orbit) in orbits.enumerated() {
            let radius = CGFloat(30 + index * 20)
            let path = UIBezierPath(
                arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                radius: radius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            orbit.path = path.cgPath
        }
    }
}

// MARK: - Neural Network Visualization
class NeuralNetworkVisualization: UIView {
    
    private var nodes: [[CALayer]] = []
    private var connections: [CAShapeLayer] = []
    private let layerCounts = [4, 6, 8, 6, 3] // Neural network structure
    
    private var activationTimer: Timer?
    private var currentActivation = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupNeuralNetwork()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNeuralNetwork()
    }
    
    private func setupNeuralNetwork() {
        backgroundColor = .clear
        
        // Create nodes
        let layerWidth = bounds.width / CGFloat(layerCounts.count + 1)
        
        for (layerIndex, nodeCount) in layerCounts.enumerated() {
            var layerNodes: [CALayer] = []
            let x = layerWidth * CGFloat(layerIndex + 1)
            let nodeSpacing = bounds.height / CGFloat(nodeCount + 1)
            
            for nodeIndex in 0..<nodeCount {
                let y = nodeSpacing * CGFloat(nodeIndex + 1)
                
                let node = CALayer()
                node.bounds = CGRect(x: 0, y: 0, width: 12, height: 12)
                node.position = CGPoint(x: x, y: y)
                node.cornerRadius = 6
                node.backgroundColor = MedicalColorPalette.primaryLight.cgColor
                node.borderWidth = 1
                node.borderColor = MedicalColorPalette.accentPrimary.withAlphaComponent(0.3).cgColor
                
                layer.addSublayer(node)
                layerNodes.append(node)
            }
            
            nodes.append(layerNodes)
        }
        
        // Create connections
        for layerIndex in 0..<(nodes.count - 1) {
            let currentLayer = nodes[layerIndex]
            let nextLayer = nodes[layerIndex + 1]
            
            for currentNode in currentLayer {
                for nextNode in nextLayer {
                    let connection = CAShapeLayer()
                    let path = UIBezierPath()
                    path.move(to: currentNode.position)
                    path.addLine(to: nextNode.position)
                    
                    connection.path = path.cgPath
                    connection.strokeColor = MedicalColorPalette.accentPrimary.withAlphaComponent(0.1).cgColor
                    connection.lineWidth = 0.5
                    connection.lineCap = .round
                    
                    layer.insertSublayer(connection, at: 0)
                    connections.append(connection)
                }
            }
        }
    }
    
    func startActivation() {
        activationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.activateNextLayer()
        }
    }
    
    func stopActivation() {
        activationTimer?.invalidate()
        activationTimer = nil
    }
    
    private func activateNextLayer() {
        // Reset previous activation
        for layerNodes in nodes {
            for node in layerNodes {
                node.backgroundColor = MedicalColorPalette.primaryLight.cgColor
                node.shadowOpacity = 0
            }
        }
        
        // Activate current layer
        let layerIndex = currentActivation % nodes.count
        let layerNodes = nodes[layerIndex]
        
        for (nodeIndex, node) in layerNodes.enumerated() {
            let delay = Double(nodeIndex) * 0.02
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UIView.animate(withDuration: 0.3) {
                    node.backgroundColor = MedicalColorPalette.accentPrimary.cgColor
                    node.shadowColor = MedicalColorPalette.accentPrimary.cgColor
                    node.shadowOffset = .zero
                    node.shadowRadius = 10
                    node.shadowOpacity = 0.8
                }
            }
        }
        
        // Activate connections
        if layerIndex < nodes.count - 1 {
            let startIndex = layerIndex * (nodes[layerIndex].count * nodes[layerIndex + 1].count)
            let endIndex = startIndex + (nodes[layerIndex].count * nodes[layerIndex + 1].count)
            
            for i in startIndex..<min(endIndex, connections.count) {
                let connection = connections[i]
                
                let animation = CABasicAnimation(keyPath: "strokeColor")
                animation.fromValue = MedicalColorPalette.accentPrimary.withAlphaComponent(0.1).cgColor
                animation.toValue = MedicalColorPalette.accentPrimary.cgColor
                animation.duration = 0.3
                animation.autoreverses = true
                
                connection.add(animation, forKey: "pulse")
            }
        }
        
        currentActivation += 1
    }
}

// MARK: - DNA Helix Loading Animation
class DNAHelixLoadingView: UIView {
    
    private var helixLayers: [CAShapeLayer] = []
    private var displayLink: CADisplayLink?
    private var phase: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupDNAHelix()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDNAHelix()
    }
    
    private func setupDNAHelix() {
        backgroundColor = .clear
        
        // Create two helixes
        for i in 0..<2 {
            let helix = CAShapeLayer()
            helix.fillColor = UIColor.clear.cgColor
            helix.strokeColor = i == 0 ? 
                MedicalColorPalette.accentPrimary.cgColor : 
                MedicalColorPalette.accentSecondary.cgColor
            helix.lineWidth = 3
            helix.lineCap = .round
            
            layer.addSublayer(helix)
            helixLayers.append(helix)
        }
    }
    
    func startAnimating() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateHelix))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateHelix() {
        phase += 0.05
        
        for (index, helix) in helixLayers.enumerated() {
            let path = UIBezierPath()
            let phaseOffset = index == 0 ? 0 : .pi
            
            for x in stride(from: 0, to: bounds.width, by: 2) {
                let relativeX = x / bounds.width
                let y = bounds.height / 2 + sin((relativeX * 4 + phase) * .pi + phaseOffset) * 30
                
                if x == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            helix.path = path.cgPath
        }
        
        // Add connecting bars
        if helixLayers.count >= 2 {
            let barSpacing: CGFloat = 40
            for x in stride(from: 0, to: bounds.width, by: barSpacing) {
                let relativeX = x / bounds.width
                let y1 = bounds.height / 2 + sin((relativeX * 4 + phase) * .pi) * 30
                let y2 = bounds.height / 2 + sin((relativeX * 4 + phase) * .pi + .pi) * 30
                
                let bar = CAShapeLayer()
                let barPath = UIBezierPath()
                barPath.move(to: CGPoint(x: x, y: y1))
                barPath.addLine(to: CGPoint(x: x, y: y2))
                
                bar.path = barPath.cgPath
                bar.strokeColor = MedicalColorPalette.primaryLight.cgColor
                bar.lineWidth = 1
                bar.opacity = 0.5
                
                layer.insertSublayer(bar, at: 0)
                
                // Remove bar after animation cycle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    bar.removeFromSuperlayer()
                }
            }
        }
    }
}

// MARK: - Floating Action Menu
class FloatingActionMenu: UIView {
    
    private var centerButton: NeumorphicButton!
    private var menuButtons: [NeumorphicButton] = []
    private var isExpanded = false
    
    var menuItems: [(icon: String, action: () -> Void)] = [] {
        didSet { setupMenuButtons() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupFloatingMenu()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFloatingMenu()
    }
    
    private func setupFloatingMenu() {
        // Center button
        centerButton = NeumorphicButton(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        centerButton.setImage(UIImage(systemName: "plus"), for: .normal)
        centerButton.tintColor = MedicalColorPalette.accentPrimary
        centerButton.addTarget(self, action: #selector(toggleMenu), for: .touchUpInside)
        
        addSubview(centerButton)
        
        centerButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerButton.widthAnchor.constraint(equalToConstant: 60),
            centerButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func setupMenuButtons() {
        // Remove existing menu buttons
        menuButtons.forEach { $0.removeFromSuperview() }
        menuButtons.removeAll()
        
        // Create new menu buttons
        for (index, item) in menuItems.enumerated() {
            let button = NeumorphicButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
            button.setImage(UIImage(systemName: item.icon), for: .normal)
            button.tintColor = MedicalColorPalette.accentPrimary
            button.alpha = 0
            button.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            button.tag = index
            button.addTarget(self, action: #selector(menuItemTapped(_:)), for: .touchUpInside)
            
            insertSubview(button, belowSubview: centerButton)
            menuButtons.append(button)
            
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: centerXAnchor),
                button.centerYAnchor.constraint(equalTo: centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 50),
                button.heightAnchor.constraint(equalToConstant: 50)
            ])
        }
    }
    
    @objc private func toggleMenu() {
        isExpanded.toggle()
        
        if isExpanded {
            expandMenu()
        } else {
            collapseMenu()
        }
        
        // Rotate center button
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.centerButton.transform = self.isExpanded ? 
                CGAffineTransform(rotationAngle: .pi / 4) : .identity
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func expandMenu() {
        let angleStep = (2 * CGFloat.pi) / CGFloat(menuButtons.count)
        let radius: CGFloat = 80
        
        for (index, button) in menuButtons.enumerated() {
            let angle = angleStep * CGFloat(index) - .pi / 2
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            
            UIView.animate(
                withDuration: 0.5,
                delay: Double(index) * 0.05,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.5,
                options: [],
                animations: {
                    button.alpha = 1
                    button.transform = CGAffineTransform(translationX: x, y: y)
                }
            )
        }
    }
    
    private func collapseMenu() {
        for (index, button) in menuButtons.enumerated().reversed() {
            UIView.animate(
                withDuration: 0.3,
                delay: Double(menuButtons.count - index - 1) * 0.05,
                options: [],
                animations: {
                    button.alpha = 0
                    button.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                }
            )
        }
    }
    
    @objc private func menuItemTapped(_ sender: UIButton) {
        let index = sender.tag
        if index < menuItems.count {
            menuItems[index].action()
            toggleMenu()
        }
    }
}

// MARK: - Biometric Security View
class BiometricSecurityView: UIView {
    
    private let scannerLayer = CAShapeLayer()
    private let pulseLayer = CAShapeLayer()
    private var displayLink: CADisplayLink?
    private var scanPhase: CGFloat = 0
    
    var onAuthenticationComplete: ((Bool) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBiometricScanner()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBiometricScanner()
    }
    
    private func setupBiometricScanner() {
        backgroundColor = MedicalColorPalette.primaryDark
        layer.cornerRadius = 20
        
        // Fingerprint outline
        let fingerprintPath = createFingerprintPath()
        
        scannerLayer.path = fingerprintPath.cgPath
        scannerLayer.strokeColor = MedicalColorPalette.accentPrimary.cgColor
        scannerLayer.fillColor = UIColor.clear.cgColor
        scannerLayer.lineWidth = 2
        scannerLayer.lineCap = .round
        scannerLayer.strokeStart = 0
        scannerLayer.strokeEnd = 0
        
        layer.addSublayer(scannerLayer)
        
        // Pulse effect
        pulseLayer.path = fingerprintPath.cgPath
        pulseLayer.strokeColor = MedicalColorPalette.accentPrimary.cgColor
        pulseLayer.fillColor = UIColor.clear.cgColor
        pulseLayer.lineWidth = 2
        pulseLayer.opacity = 0
        
        layer.insertSublayer(pulseLayer, below: scannerLayer)
    }
    
    private func createFingerprintPath() -> UIBezierPath {
        let path = UIBezierPath()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = 40
        
        // Create concentric arcs for fingerprint
        for i in 0..<5 {
            let arcRadius = radius - CGFloat(i) * 8
            path.move(to: CGPoint(x: center.x - arcRadius, y: center.y))
            path.addArc(
                withCenter: center,
                radius: arcRadius,
                startAngle: .pi,
                endAngle: 0,
                clockwise: false
            )
        }
        
        return path
    }
    
    func startScanning() {
        // Animate scanner
        let scanAnimation = CABasicAnimation(keyPath: "strokeEnd")
        scanAnimation.fromValue = 0
        scanAnimation.toValue = 1
        scanAnimation.duration = 2.0
        scanAnimation.fillMode = .forwards
        scanAnimation.isRemovedOnCompletion = false
        
        scannerLayer.add(scanAnimation, forKey: "scan")
        
        // Pulse animation
        displayLink = CADisplayLink(target: self, selector: #selector(updatePulse))
        displayLink?.add(to: .main, forMode: .common)
        
        // Simulate authentication
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.completeAuthentication(success: true)
        }
    }
    
    @objc private func updatePulse() {
        scanPhase += 0.05
        
        let scale = 1.0 + sin(scanPhase) * 0.1
        pulseLayer.transform = CATransform3DMakeScale(scale, scale, 1)
        pulseLayer.opacity = Float(1.0 - abs(sin(scanPhase)) * 0.5)
    }
    
    private func completeAuthentication(success: Bool) {
        displayLink?.invalidate()
        displayLink = nil
        
        if success {
            // Success animation
            scannerLayer.strokeColor = MedicalColorPalette.successColor.cgColor
            
            let successAnimation = CABasicAnimation(keyPath: "transform.scale")
            successAnimation.fromValue = 1.0
            successAnimation.toValue = 1.2
            successAnimation.duration = 0.3
            successAnimation.autoreverses = true
            
            scannerLayer.add(successAnimation, forKey: "success")
            
            // Haptic feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } else {
            // Failure animation
            scannerLayer.strokeColor = MedicalColorPalette.errorColor.cgColor
            
            let shakeAnimation = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shakeAnimation.values = [0, -10, 10, -10, 10, 0]
            shakeAnimation.duration = 0.5
            
            layer.add(shakeAnimation, forKey: "shake")
            
            // Haptic feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }
        
        onAuthenticationComplete?(success)
    }
}

// MARK: - Volumetric Display View
class VolumetricDisplayView: MTKView {
    
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var volumeTexture: MTLTexture?
    
    private var rotation: Float = 0
    private var displayLink: CADisplayLink?
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        setupVolumetric()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupVolumetric()
    }
    
    private func setupVolumetric() {
        guard let device = device else { return }
        
        commandQueue = device.makeCommandQueue()
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        // Setup render pipeline
        setupRenderPipeline()
        
        // Create volumetric texture
        createVolumetricTexture()
    }
    
    private func setupRenderPipeline() {
        // This would load custom Metal shaders for volumetric rendering
        // For now, we'll use a placeholder
    }
    
    private func createVolumetricTexture() {
        guard let device = device else { return }
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = 128
        textureDescriptor.height = 128
        textureDescriptor.depth = 128
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        volumeTexture = device.makeTexture(descriptor: textureDescriptor)
        
        // Fill with volumetric data (placeholder)
        generateVolumetricData()
    }
    
    private func generateVolumetricData() {
        // Generate procedural volumetric data
        // In real implementation, this would be medical volume data
    }
    
    func startRotation() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateRotation))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopRotation() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateRotation() {
        rotation += 0.01
        setNeedsDisplay()
    }
}

// MARK: - Medical Data Card
class MedicalDataCard: HolographicCardView {
    
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let trendIndicator = UIImageView()
    private let sparklineView = SparklineView()
    
    var icon: UIImage? {
        didSet { iconView.image = icon }
    }
    
    var title: String? {
        didSet { titleLabel.text = title }
    }
    
    var value: String? {
        didSet { valueLabel.text = value }
    }
    
    var trend: TrendDirection = .stable {
        didSet { updateTrendIndicator() }
    }
    
    var sparklineData: [CGFloat] = [] {
        didSet { sparklineView.data = sparklineData }
    }
    
    enum TrendDirection {
        case up, down, stable
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCard()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCard()
    }
    
    private func setupCard() {
        // Icon
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = MedicalColorPalette.accentPrimary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title
        titleLabel.font = MedicalTypography.bodySmall
        titleLabel.textColor = MedicalColorPalette.primaryLight
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Value
        valueLabel.font = MedicalTypography.displaySmall
        valueLabel.textColor = .white
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Trend
        trendIndicator.contentMode = .scaleAspectFit
        trendIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Sparkline
        sparklineView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(trendIndicator)
        addSubview(sparklineView)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            
            trendIndicator.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 8),
            trendIndicator.centerYAnchor.constraint(equalTo: valueLabel.centerYAnchor),
            trendIndicator.widthAnchor.constraint(equalToConstant: 16),
            trendIndicator.heightAnchor.constraint(equalToConstant: 16),
            
            sparklineView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            sparklineView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            sparklineView.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 12),
            sparklineView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            sparklineView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func updateTrendIndicator() {
        switch trend {
        case .up:
            trendIndicator.image = UIImage(systemName: "arrow.up.circle.fill")
            trendIndicator.tintColor = MedicalColorPalette.successColor
        case .down:
            trendIndicator.image = UIImage(systemName: "arrow.down.circle.fill")
            trendIndicator.tintColor = MedicalColorPalette.errorColor
        case .stable:
            trendIndicator.image = UIImage(systemName: "minus.circle.fill")
            trendIndicator.tintColor = MedicalColorPalette.primaryLight
        }
    }
}

// MARK: - Sparkline View
class SparklineView: UIView {
    
    var data: [CGFloat] = [] {
        didSet { setNeedsDisplay() }
    }
    
    var lineColor: UIColor = MedicalColorPalette.accentPrimary
    var fillColor: UIColor = MedicalColorPalette.accentPrimary.withAlphaComponent(0.2)
    
    override func draw(_ rect: CGRect) {
        guard !data.isEmpty else { return }
        
        let path = UIBezierPath()
        let fillPath = UIBezierPath()
        
        let maxValue = data.max() ?? 1
        let minValue = data.min() ?? 0
        let range = maxValue - minValue
        
        let xStep = rect.width / CGFloat(data.count - 1)
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * xStep
            let normalizedValue = (value - minValue) / range
            let y = rect.height - (normalizedValue * rect.height)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
                fillPath.move(to: CGPoint(x: x, y: rect.height))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Complete fill path
        if let lastX = data.indices.last {
            fillPath.addLine(to: CGPoint(x: CGFloat(lastX) * xStep, y: rect.height))
        }
        fillPath.close()
        
        // Draw fill
        fillColor.setFill()
        fillPath.fill()
        
        // Draw line
        lineColor.setStroke()
        path.lineWidth = 2
        path.stroke()
        
        // Add glow effect
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.setShadow(offset: .zero, blur: 4, color: lineColor.cgColor)
        path.stroke()
        context?.restoreGState()
    }
}