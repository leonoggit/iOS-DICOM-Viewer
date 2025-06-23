//
//  UltraModernDesignSystem.swift
//  iOS_DICOMViewer
//
//  Ultra-sophisticated design system for medical imaging excellence
//  Leverages iOS 26 capabilities for the ultimate "wow effect"
//

import UIKit
import SwiftUI
import Metal
import CoreHaptics
import RealityKit

// MARK: - Design Philosophy
/*
 * Precision Medicine Aesthetics: Clean, professional, and cutting-edge
 * Spatial Computing Ready: Optimized for future Apple Vision Pro
 * Haptic Intelligence: Medical-grade tactile feedback
 * Fluid Dynamics: Physics-based animations and interactions
 * Adaptive Intelligence: Context-aware UI that adapts to usage patterns
 */

// MARK: - Color System
struct MedicalColorPalette {
    // Primary Colors - Medical Grade
    static let primaryDark = UIColor(hex: "#0A0E1A")      // Deep space blue
    static let primaryMedium = UIColor(hex: "#1A2332")    // Medical navy
    static let primaryLight = UIColor(hex: "#2A3444")     // Surgical steel
    
    // Accent Colors - Clinical Precision
    static let accentPrimary = UIColor(hex: "#00D4FF")    // Medical cyan
    static let accentSecondary = UIColor(hex: "#00FF88")  // Vitals green
    static let accentTertiary = UIColor(hex: "#FF00F7")   // Diagnostic purple
    static let accentWarning = UIColor(hex: "#FFB800")    // Alert amber
    static let accentCritical = UIColor(hex: "#FF0055")   // Emergency red
    
    // Gradient System
    static let primaryGradient = [
        UIColor(hex: "#0A0E1A").cgColor,
        UIColor(hex: "#1A2332").cgColor,
        UIColor(hex: "#2A3444").cgColor
    ]
    
    static let accentGradient = [
        UIColor(hex: "#00D4FF").cgColor,
        UIColor(hex: "#00FF88").cgColor
    ]
    
    // Semantic Colors
    static let successColor = UIColor(hex: "#00FF88")
    static let warningColor = UIColor(hex: "#FFB800")
    static let errorColor = UIColor(hex: "#FF0055")
    static let infoColor = UIColor(hex: "#00D4FF")
    
    // Adaptive Colors
    static func adaptiveColor(for context: MedicalContext) -> UIColor {
        switch context {
        case .emergency: return accentCritical
        case .urgent: return accentWarning
        case .routine: return accentPrimary
        case .archived: return primaryLight.withAlphaComponent(0.6)
        }
    }
}

// MARK: - Typography System
struct MedicalTypography {
    // Display Fonts - For impact
    static let displayLarge = UIFont.systemFont(ofSize: 48, weight: .black, width: .expanded)
    static let displayMedium = UIFont.systemFont(ofSize: 36, weight: .bold, width: .expanded)
    static let displaySmall = UIFont.systemFont(ofSize: 28, weight: .semibold, width: .standard)
    
    // Interface Fonts - For clarity
    static let headlineLarge = UIFont.systemFont(ofSize: 24, weight: .bold)
    static let headlineMedium = UIFont.systemFont(ofSize: 20, weight: .semibold)
    static let headlineSmall = UIFont.systemFont(ofSize: 18, weight: .medium)
    
    // Body Fonts - For readability
    static let bodyLarge = UIFont.systemFont(ofSize: 17, weight: .regular)
    static let bodyMedium = UIFont.systemFont(ofSize: 15, weight: .regular)
    static let bodySmall = UIFont.systemFont(ofSize: 13, weight: .regular)
    
    // Monospace - For medical data
    static let monoLarge = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)
    static let monoMedium = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
    static let monoSmall = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .light)
}

// MARK: - Spacing System
struct MedicalSpacing {
    static let micro: CGFloat = 4
    static let tiny: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let huge: CGFloat = 32
    static let massive: CGFloat = 48
}

// MARK: - Animation System
struct FluidAnimations {
    // Spring animations with medical precision
    static let quickResponse = UISpringTimingParameters(
        mass: 1.0,
        stiffness: 500,
        damping: 30,
        initialVelocity: CGVector(dx: 0, dy: 0)
    )
    
    static let smoothTransition = UISpringTimingParameters(
        mass: 2.0,
        stiffness: 200,
        damping: 25,
        initialVelocity: CGVector(dx: 0, dy: 0)
    )
    
    static let elasticBounce = UISpringTimingParameters(
        mass: 1.5,
        stiffness: 300,
        damping: 15,
        initialVelocity: CGVector(dx: 0, dy: 0)
    )
    
    // Bezier curves for specific effects
    static let easeInOutQuart = UIBezierPath.easeInOutQuart
    static let medicalPrecision = UIBezierPath.customMedicalCurve
}

// MARK: - Glass Morphism Components
class GlassMorphismView: UIView {
    
    private let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    private lazy var blurView = UIVisualEffectView(effect: blurEffect)
    private let glassLayer = CALayer()
    
    var glassIntensity: CGFloat = 0.7 {
        didSet { updateGlassEffect() }
    }
    
    var glassColor: UIColor = .white {
        didSet { updateGlassEffect() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGlassMorphism()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlassMorphism()
    }
    
    private func setupGlassMorphism() {
        // Add blur
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Add glass overlay
        glassLayer.backgroundColor = glassColor.withAlphaComponent(0.05).cgColor
        layer.addSublayer(glassLayer)
        
        // Add subtle border
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        // Rounded corners
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        clipsToBounds = true
        
        // Shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 10)
        layer.shadowRadius = 20
        layer.shadowOpacity = 0.3
    }
    
    private func updateGlassEffect() {
        glassLayer.backgroundColor = glassColor.withAlphaComponent(0.05 * glassIntensity).cgColor
        layer.borderColor = glassColor.withAlphaComponent(0.2 * glassIntensity).cgColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        glassLayer.frame = bounds
    }
}

// MARK: - Neumorphic Components
class NeumorphicButton: UIButton {
    
    private let lightShadow = CALayer()
    private let darkShadow = CALayer()
    private let colorLayer = CAGradientLayer()
    
    var isPressed = false {
        didSet { updateNeumorphicState() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupNeumorphism()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNeumorphism()
    }
    
    private func setupNeumorphism() {
        // Base styling
        backgroundColor = MedicalColorPalette.primaryMedium
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        
        // Light shadow (top-left)
        lightShadow.shadowColor = UIColor.white.withAlphaComponent(0.1).cgColor
        lightShadow.shadowOffset = CGSize(width: -6, height: -6)
        lightShadow.shadowRadius = 8
        lightShadow.shadowOpacity = 1
        layer.insertSublayer(lightShadow, at: 0)
        
        // Dark shadow (bottom-right)
        darkShadow.shadowColor = UIColor.black.withAlphaComponent(0.3).cgColor
        darkShadow.shadowOffset = CGSize(width: 6, height: 6)
        darkShadow.shadowRadius = 8
        darkShadow.shadowOpacity = 1
        layer.insertSublayer(darkShadow, at: 0)
        
        // Gradient overlay
        colorLayer.colors = [
            UIColor.white.withAlphaComponent(0.05).cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.05).cgColor
        ]
        colorLayer.locations = [0, 0.5, 1]
        colorLayer.cornerRadius = 16
        layer.addSublayer(colorLayer)
        
        // Touch handlers
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    @objc private func touchDown() {
        isPressed = true
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    @objc private func touchUp() {
        isPressed = false
    }
    
    private func updateNeumorphicState() {
        if isPressed {
            // Inset effect
            lightShadow.shadowOffset = CGSize(width: -2, height: -2)
            lightShadow.shadowRadius = 4
            darkShadow.shadowOffset = CGSize(width: 2, height: 2)
            darkShadow.shadowRadius = 4
            
            transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } else {
            // Normal state
            lightShadow.shadowOffset = CGSize(width: -6, height: -6)
            lightShadow.shadowRadius = 8
            darkShadow.shadowOffset = CGSize(width: 6, height: 6)
            darkShadow.shadowRadius = 8
            
            transform = .identity
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        lightShadow.frame = bounds
        darkShadow.frame = bounds
        colorLayer.frame = bounds
        
        lightShadow.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
        darkShadow.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
    }
}

// MARK: - Particle Effects System
class ParticleEffectView: UIView {
    
    private var particleEmitter: CAEmitterLayer!
    
    enum ParticleType {
        case medical
        case success
        case loading
        case critical
    }
    
    func startParticleEffect(type: ParticleType) {
        particleEmitter?.removeFromSuperlayer()
        
        particleEmitter = CAEmitterLayer()
        particleEmitter.emitterPosition = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        particleEmitter.emitterShape = .circle
        particleEmitter.emitterSize = CGSize(width: 50, height: 50)
        
        let cell = CAEmitterCell()
        
        switch type {
        case .medical:
            cell.contents = createMedicalParticle().cgImage
            cell.birthRate = 30
            cell.lifetime = 3.0
            cell.velocity = 100
            cell.velocityRange = 50
            cell.emissionRange = .pi * 2
            cell.scale = 0.1
            cell.scaleRange = 0.05
            cell.alphaSpeed = -0.3
            cell.color = MedicalColorPalette.accentPrimary.cgColor
            
        case .success:
            cell.contents = createSuccessParticle().cgImage
            cell.birthRate = 50
            cell.lifetime = 1.5
            cell.velocity = 200
            cell.velocityRange = 100
            cell.emissionRange = .pi * 2
            cell.scale = 0.2
            cell.scaleSpeed = -0.1
            cell.color = MedicalColorPalette.successColor.cgColor
            
        case .loading:
            cell.contents = createLoadingParticle().cgImage
            cell.birthRate = 20
            cell.lifetime = 2.0
            cell.velocity = 50
            cell.velocityRange = 20
            cell.emissionRange = .pi * 2
            cell.scale = 0.15
            cell.spin = .pi
            cell.spinRange = .pi * 2
            cell.color = MedicalColorPalette.accentSecondary.cgColor
            
        case .critical:
            cell.contents = createCriticalParticle().cgImage
            cell.birthRate = 100
            cell.lifetime = 1.0
            cell.velocity = 300
            cell.velocityRange = 150
            cell.emissionRange = .pi * 2
            cell.scale = 0.3
            cell.scaleSpeed = 0.2
            cell.alphaSpeed = -1.0
            cell.color = MedicalColorPalette.accentCritical.cgColor
        }
        
        particleEmitter.emitterCells = [cell]
        layer.addSublayer(particleEmitter)
    }
    
    func stopParticleEffect() {
        particleEmitter?.birthRate = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.particleEmitter?.removeFromSuperlayer()
        }
    }
    
    private func createMedicalParticle() -> UIImage {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 20))
        path.move(to: CGPoint(x: 0, y: 10))
        path.addLine(to: CGPoint(x: 20, y: 10))
        
        UIColor.white.setStroke()
        path.lineWidth = 3
        path.stroke()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    private func createSuccessParticle() -> UIImage {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 10))
        path.addLine(to: CGPoint(x: 8, y: 13))
        path.addLine(to: CGPoint(x: 15, y: 6))
        
        UIColor.white.setStroke()
        path.lineWidth = 2
        path.stroke()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    private func createLoadingParticle() -> UIImage {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        let rect = CGRect(x: 2, y: 2, width: 16, height: 16)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
        
        UIColor.white.setFill()
        path.fill()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    private func createCriticalParticle() -> UIImage {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 10, y: 2))
        path.addLine(to: CGPoint(x: 18, y: 18))
        path.addLine(to: CGPoint(x: 2, y: 18))
        path.close()
        
        UIColor.white.setFill()
        path.fill()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
}

// MARK: - Liquid Animation View
class LiquidAnimationView: UIView {
    
    private var displayLink: CADisplayLink?
    private var phase: CGFloat = 0
    private let waveLayer = CAShapeLayer()
    
    var waveColor: UIColor = MedicalColorPalette.accentPrimary {
        didSet { waveLayer.fillColor = waveColor.cgColor }
    }
    
    var waveHeight: CGFloat = 20
    var waveSpeed: CGFloat = 0.02
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupWave()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWave()
    }
    
    private func setupWave() {
        waveLayer.fillColor = waveColor.cgColor
        layer.addSublayer(waveLayer)
    }
    
    func startAnimating() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateWave))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateWave() {
        phase += waveSpeed
        
        let path = UIBezierPath()
        let width = bounds.width
        let height = bounds.height
        
        path.move(to: CGPoint(x: 0, y: height))
        
        for x in stride(from: 0, to: width, by: 1) {
            let relativeX = x / width
            let y = sin((relativeX + phase) * 2 * .pi) * waveHeight + (height / 2)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.close()
        
        waveLayer.path = path.cgPath
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        waveLayer.frame = bounds
    }
}

// MARK: - Holographic Card View
class HolographicCardView: GlassMorphismView {
    
    private let holographicLayer = CAGradientLayer()
    private var displayLink: CADisplayLink?
    private var animationPhase: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHolographic()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupHolographic()
    }
    
    private func setupHolographic() {
        // Holographic gradient
        holographicLayer.colors = [
            UIColor(hex: "#00D4FF").withAlphaComponent(0.3).cgColor,
            UIColor(hex: "#00FF88").withAlphaComponent(0.3).cgColor,
            UIColor(hex: "#FF00F7").withAlphaComponent(0.3).cgColor,
            UIColor(hex: "#00D4FF").withAlphaComponent(0.3).cgColor
        ]
        holographicLayer.locations = [0, 0.33, 0.66, 1]
        holographicLayer.startPoint = CGPoint(x: 0, y: 0)
        holographicLayer.endPoint = CGPoint(x: 1, y: 1)
        
        layer.addSublayer(holographicLayer)
        
        // Start animation
        displayLink = CADisplayLink(target: self, selector: #selector(updateHolographic))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateHolographic() {
        animationPhase += 0.01
        
        let colors = [
            UIColor(hue: animationPhase.truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 1, alpha: 0.3).cgColor,
            UIColor(hue: (animationPhase + 0.33).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 1, alpha: 0.3).cgColor,
            UIColor(hue: (animationPhase + 0.66).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 1, alpha: 0.3).cgColor,
            UIColor(hue: animationPhase.truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 1, alpha: 0.3).cgColor
        ]
        
        holographicLayer.colors = colors
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        holographicLayer.frame = bounds
    }
    
    deinit {
        displayLink?.invalidate()
    }
}

// MARK: - 3D Transform Card
class Transform3DCardView: UIView {
    
    private var transformLayer: CATransformLayer!
    private var frontLayer: CALayer!
    private var backLayer: CALayer!
    
    var isFlipped = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup3DCard()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup3DCard()
    }
    
    private func setup3DCard() {
        transformLayer = CATransformLayer()
        layer.addSublayer(transformLayer)
        
        // Front face
        frontLayer = CALayer()
        frontLayer.backgroundColor = MedicalColorPalette.primaryMedium.cgColor
        frontLayer.cornerRadius = 16
        frontLayer.borderWidth = 1
        frontLayer.borderColor = MedicalColorPalette.accentPrimary.withAlphaComponent(0.3).cgColor
        
        // Back face
        backLayer = CALayer()
        backLayer.backgroundColor = MedicalColorPalette.accentPrimary.cgColor
        backLayer.cornerRadius = 16
        backLayer.transform = CATransform3DMakeRotation(.pi, 0, 1, 0)
        
        transformLayer.addSublayer(frontLayer)
        transformLayer.addSublayer(backLayer)
        
        // Add perspective
        var perspective = CATransform3DIdentity
        perspective.m34 = -1.0 / 500.0
        layer.sublayerTransform = perspective
    }
    
    func flip(duration: TimeInterval = 0.6) {
        let animation = CABasicAnimation(keyPath: "transform.rotation.y")
        animation.fromValue = isFlipped ? .pi : 0
        animation.toValue = isFlipped ? 0 : .pi
        animation.duration = duration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        transformLayer.add(animation, forKey: "flip")
        
        isFlipped.toggle()
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        transformLayer.frame = bounds
        frontLayer.frame = bounds
        backLayer.frame = bounds
    }
}

// MARK: - Magnetic Interaction View
class MagneticInteractionView: UIView {
    
    private var animator: UIDynamicAnimator!
    private var magneticBehavior: UIFieldBehavior!
    private var collisionBehavior: UICollisionBehavior!
    private var magneticItems: [UIView] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMagneticField()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMagneticField()
    }
    
    private func setupMagneticField() {
        animator = UIDynamicAnimator(referenceView: self)
        
        // Radial gravity field
        magneticBehavior = UIFieldBehavior.radialGravityField(position: center)
        magneticBehavior.strength = -2.0 // Negative for repulsion
        magneticBehavior.minimumRadius = 50
        magneticBehavior.falloff = 2.0
        
        // Collision boundaries
        collisionBehavior = UICollisionBehavior()
        collisionBehavior.translatesReferenceBoundsIntoBoundary = true
        
        animator.addBehavior(magneticBehavior)
        animator.addBehavior(collisionBehavior)
    }
    
    func addMagneticItem(_ item: UIView) {
        addSubview(item)
        magneticItems.append(item)
        
        magneticBehavior.addItem(item)
        collisionBehavior.addItem(item)
        
        // Add some random initial velocity
        let push = UIPushBehavior(items: [item], mode: .instantaneous)
        push.pushDirection = CGVector(
            dx: CGFloat.random(in: -0.5...0.5),
            dy: CGFloat.random(in: -0.5...0.5)
        )
        animator.addBehavior(push)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        magneticBehavior.position = location
    }
}

// MARK: - Haptic Feedback Manager
class HapticManager {
    static let shared = HapticManager()
    
    private var engine: CHHapticEngine?
    
    private init() {
        setupHapticEngine()
    }
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine failed: \(error)")
        }
    }
    
    func playMedicalAlert() {
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [sharpness, intensity],
            relativeTime: 0,
            duration: 0.5
        )
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
    
    func playSuccessFeedback() {
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
        
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [sharpness, intensity],
            relativeTime: 0
        )
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
}

// MARK: - Context Types
enum MedicalContext {
    case emergency
    case urgent
    case routine
    case archived
}

// MARK: - Extensions
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}

// MARK: - Quantum Loading Indicator
class QuantumLoadingIndicator: UIView {
    
    private var isAnimating = false
    private let circleLayer = CAShapeLayer()
    private let pulseLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        // Pulse layer
        let pulsePath = UIBezierPath(ovalIn: bounds.insetBy(dx: 5, dy: 5))
        pulseLayer.path = pulsePath.cgPath
        pulseLayer.fillColor = MedicalColorPalette.accentPrimary.cgColor
        pulseLayer.opacity = 0
        layer.addSublayer(pulseLayer)
        
        // Circle layer
        let circlePath = UIBezierPath(ovalIn: bounds.insetBy(dx: 20, dy: 20))
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = MedicalColorPalette.accentPrimary.cgColor
        circleLayer.lineWidth = 3
        circleLayer.strokeEnd = 0.8
        layer.addSublayer(circleLayer)
    }
    
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        
        // Rotation animation
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = 2 * Double.pi
        rotation.duration = 1.5
        rotation.repeatCount = .infinity
        circleLayer.add(rotation, forKey: "rotation")
        
        // Pulse animation
        let pulse = CAAnimationGroup()
        pulse.duration = 1.5
        pulse.repeatCount = .infinity
        
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 1.3
        
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.5
        opacity.toValue = 0
        
        pulse.animations = [scale, opacity]
        pulseLayer.add(pulse, forKey: "pulse")
    }
    
    func stopAnimating() {
        isAnimating = false
        circleLayer.removeAllAnimations()
        pulseLayer.removeAllAnimations()
    }
}

// MARK: - Transform 3D Card View
class Transform3DCardView: UIView {
    
    var cardLayer: CATransformLayer!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCard()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCard()
    }
    
    private func setupCard() {
        cardLayer = CATransformLayer()
        cardLayer.frame = bounds
        
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 500.0
        cardLayer.transform = transform
        
        layer.addSublayer(cardLayer)
    }
    
    func flip() {
        let animation = CABasicAnimation(keyPath: "transform.rotation.y")
        animation.fromValue = 0
        animation.toValue = Double.pi
        animation.duration = 0.6
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        cardLayer.add(animation, forKey: "flip")
    }
}

extension UIBezierPath {
    static var easeInOutQuart: UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(to: CGPoint(x: 1, y: 1),
                     controlPoint1: CGPoint(x: 0.77, y: 0),
                     controlPoint2: CGPoint(x: 0.175, y: 1))
        return path
    }
    
    static var customMedicalCurve: UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(to: CGPoint(x: 1, y: 1),
                     controlPoint1: CGPoint(x: 0.25, y: 0.1),
                     controlPoint2: CGPoint(x: 0.25, y: 1))
        return path
    }
}