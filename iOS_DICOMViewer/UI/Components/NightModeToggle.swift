//
//  NightModeToggle.swift
//  iOS_DICOMViewer
//
//  Circular night mode toggle button with smooth transitions
//

import UIKit

// MARK: - Night Mode Manager
class NightModeManager {
    static let shared = NightModeManager()
    
    private let nightModeKey = "isNightModeEnabled"
    
    var isNightMode: Bool {
        get {
            UserDefaults.standard.bool(forKey: nightModeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: nightModeKey)
            notifyObservers()
        }
    }
    
    private var observers: [WeakObserver] = []
    
    private init() {}
    
    func addObserver(_ observer: NightModeObserver) {
        observers.append(WeakObserver(observer))
        observers = observers.filter { $0.observer != nil }
    }
    
    func removeObserver(_ observer: NightModeObserver) {
        observers = observers.filter { $0.observer !== observer && $0.observer != nil }
    }
    
    private func notifyObservers() {
        observers = observers.filter { $0.observer != nil }
        observers.forEach { $0.observer?.nightModeDidChange(isNightMode) }
    }
}

// MARK: - Night Mode Observer Protocol
protocol NightModeObserver: AnyObject {
    func nightModeDidChange(_ isNightMode: Bool)
}

// MARK: - Weak Observer Wrapper
private class WeakObserver {
    weak var observer: NightModeObserver?
    
    init(_ observer: NightModeObserver) {
        self.observer = observer
    }
}

// MARK: - Night Mode Toggle Button
class NightModeToggle: UIView {
    
    // UI Components
    private let containerView = UIView()
    private let moonIcon = UIImageView()
    private let sunIcon = UIImageView()
    private let toggleButton = UIButton()
    
    // Animation layers
    private let moonLayer = CAShapeLayer()
    private let sunLayer = CAShapeLayer()
    private let starsLayer = CAEmitterLayer()
    
    // State
    private var isNightMode = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupToggle()
        updateAppearance(animated: false)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupToggle()
        updateAppearance(animated: false)
    }
    
    private func setupToggle() {
        // Container setup
        containerView.backgroundColor = MedicalColorPalette.primaryMedium.withAlphaComponent(0.3)
        containerView.layer.cornerRadius = 30
        containerView.layer.borderWidth = 2
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        // Add glass morphism
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = bounds
        blurView.layer.cornerRadius = 30
        blurView.clipsToBounds = true
        containerView.addSubview(blurView)
        
        // Moon icon
        moonIcon.image = UIImage(systemName: "moon.fill")
        moonIcon.tintColor = .white
        moonIcon.contentMode = .scaleAspectFit
        moonIcon.alpha = 0
        
        // Sun icon
        sunIcon.image = UIImage(systemName: "sun.max.fill")
        sunIcon.tintColor = MedicalColorPalette.accentWarning
        sunIcon.contentMode = .scaleAspectFit
        
        // Button
        toggleButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.3
        
        // Layout
        containerView.translatesAutoresizingMaskIntoConstraints = false
        moonIcon.translatesAutoresizingMaskIntoConstraints = false
        sunIcon.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerView)
        containerView.addSubview(moonIcon)
        containerView.addSubview(sunIcon)
        containerView.addSubview(toggleButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 60),
            containerView.heightAnchor.constraint(equalToConstant: 60),
            
            moonIcon.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            moonIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            moonIcon.widthAnchor.constraint(equalToConstant: 28),
            moonIcon.heightAnchor.constraint(equalToConstant: 28),
            
            sunIcon.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            sunIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            sunIcon.widthAnchor.constraint(equalToConstant: 32),
            sunIcon.heightAnchor.constraint(equalToConstant: 32),
            
            toggleButton.topAnchor.constraint(equalTo: containerView.topAnchor),
            toggleButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            toggleButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            toggleButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Setup stars
        setupStarsEmitter()
        
        // Load saved state
        isNightMode = NightModeManager.shared.isNightMode
    }
    
    private func setupStarsEmitter() {
        starsLayer.emitterPosition = CGPoint(x: 30, y: 30)
        starsLayer.emitterSize = CGSize(width: 60, height: 60)
        starsLayer.emitterShape = .circle
        starsLayer.emitterMode = .surface
        starsLayer.renderMode = .additive
        
        let star = CAEmitterCell()
        star.birthRate = 0
        star.lifetime = 2.0
        star.velocity = 20
        star.velocityRange = 10
        star.emissionRange = .pi * 2
        star.scale = 0.1
        star.scaleRange = 0.05
        star.alphaSpeed = -0.5
        
        star.contents = createStarImage().cgImage
        
        starsLayer.emitterCells = [star]
        containerView.layer.addSublayer(starsLayer)
    }
    
    private func createStarImage() -> UIImage {
        let size = CGSize(width: 10, height: 10)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        let path = UIBezierPath()
        let center = CGPoint(x: 5, y: 5)
        
        // Create 4-pointed star
        for i in 0..<4 {
            let angle = CGFloat(i) * .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * 4,
                y: center.y + sin(angle) * 4
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: center)
                path.addLine(to: point)
            }
        }
        
        UIColor.white.setFill()
        path.fill()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    @objc private func toggleTapped() {
        isNightMode.toggle()
        NightModeManager.shared.isNightMode = isNightMode
        updateAppearance(animated: true)
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func updateAppearance(animated: Bool) {
        let duration = animated ? 0.3 : 0
        
        if isNightMode {
            // Night mode
            UIView.animate(withDuration: duration) {
                self.moonIcon.alpha = 1
                self.sunIcon.alpha = 0
                self.moonIcon.transform = .identity
                self.sunIcon.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                self.containerView.backgroundColor = MedicalColorPalette.primaryDark.withAlphaComponent(0.5)
            }
            
            // Animate stars
            if animated {
                starsLayer.emitterCells?.first?.birthRate = 10
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.starsLayer.emitterCells?.first?.birthRate = 0
                }
            }
            
            // Rotate moon
            if animated {
                let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotation.fromValue = 0
                rotation.toValue = CGFloat.pi * 2
                rotation.duration = 0.5
                moonIcon.layer.add(rotation, forKey: "moonRotation")
            }
            
        } else {
            // Day mode
            UIView.animate(withDuration: duration) {
                self.moonIcon.alpha = 0
                self.sunIcon.alpha = 1
                self.moonIcon.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                self.sunIcon.transform = .identity
                self.containerView.backgroundColor = MedicalColorPalette.accentWarning.withAlphaComponent(0.2)
            }
            
            // Animate sun rays
            if animated {
                let pulse = CABasicAnimation(keyPath: "transform.scale")
                pulse.fromValue = 1.0
                pulse.toValue = 1.2
                pulse.duration = 0.3
                pulse.autoreverses = true
                sunIcon.layer.add(pulse, forKey: "sunPulse")
            }
        }
        
        // Animate container
        if animated {
            let bounce = CASpringAnimation(keyPath: "transform.scale")
            bounce.fromValue = 1.0
            bounce.toValue = 0.95
            bounce.duration = 0.2
            bounce.autoreverses = true
            bounce.initialVelocity = 0.5
            bounce.damping = 10
            containerView.layer.add(bounce, forKey: "bounce")
        }
    }
}

// MARK: - Night Mode Colors Extension
extension MedicalColorPalette {
    // Night mode variations
    static var primaryDarkNight: UIColor {
        return UIColor(hex: "#000000")
    }
    
    static var primaryMediumNight: UIColor {
        return UIColor(hex: "#0A0A0A")
    }
    
    static var primaryLightNight: UIColor {
        return UIColor(hex: "#1A1A1A")
    }
    
    static var accentPrimaryNight: UIColor {
        return UIColor(hex: "#0080AA") // Dimmed cyan
    }
    
    static var accentSecondaryNight: UIColor {
        return UIColor(hex: "#00AA55") // Dimmed green
    }
    
    static var textPrimaryNight: UIColor {
        return UIColor(hex: "#E0E0E0")
    }
    
    static var textSecondaryNight: UIColor {
        return UIColor(hex: "#A0A0A0")
    }
    
    // Helper method to get appropriate color
    static func adaptiveColor(day: UIColor, night: UIColor) -> UIColor {
        return NightModeManager.shared.isNightMode ? night : day
    }
}

// MARK: - UIView Extension for Night Mode
extension UIView {
    func applyNightMode() {
        if let self = self as? NightModeObserver {
            NightModeManager.shared.addObserver(self)
            self.nightModeDidChange(NightModeManager.shared.isNightMode)
        }
        
        // Apply to subviews
        subviews.forEach { $0.applyNightMode() }
    }
}