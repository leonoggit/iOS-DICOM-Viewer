//
//  ViewerSelectorViewController.swift
//  iOS_DICOMViewer
//
//  Ultra-modern viewer selection with 3D flip animations
//

import UIKit

class ViewerSelectorViewController: UIViewController {
    
    // MARK: - Properties
    var study: DICOMStudy?
    
    // MARK: - UI Components
    private let backgroundView = UIView()
    private let containerView = Transform3DCardView()
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private lazy var viewer2DCard = createViewerCard(
        title: "2D Viewer",
        subtitle: "Professional DICOM viewing",
        icon: "square.stack.3d.down.right",
        color: MedicalColorPalette.accentPrimary
    )
    
    private lazy var viewerMPRCard = createViewerCard(
        title: "MPR Viewer",
        subtitle: "Multi-planar reconstruction",
        icon: "cube.transparent",
        color: MedicalColorPalette.accentSecondary
    )
    
    private lazy var viewer3DAICard = createViewerCard(
        title: "3D/AI Viewer",
        subtitle: "Volume rendering & AI analysis",
        icon: "brain",
        color: MedicalColorPalette.accentTertiary
    )
    
    private let cancelButton = NeumorphicButton()
    private let particleView = ParticleEffectView()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        performEntranceAnimation()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        // Background blur
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
        
        // Particle background
        particleView.frame = view.bounds
        particleView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(particleView)
        particleView.startParticleEffect(type: .loading)
        
        // Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Title
        titleLabel.text = "Select Viewer Mode"
        titleLabel.font = MedicalTypography.displaySmall
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Subtitle
        subtitleLabel.text = study?.patientName ?? "Medical Study"
        subtitleLabel.font = MedicalTypography.bodyLarge
        subtitleLabel.textColor = MedicalColorPalette.primaryLight
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Viewer cards stack
        let stackView = UIStackView(arrangedSubviews: [viewer2DCard, viewerMPRCard, viewer3DAICard])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = MedicalTypography.bodyMedium
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(stackView)
        view.addSubview(cancelButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 320),
            containerView.heightAnchor.constraint(equalToConstant: 480),
            
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.widthAnchor.constraint(equalToConstant: 280),
            stackView.heightAnchor.constraint(equalToConstant: 360),
            
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 120),
            cancelButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func createViewerCard(title: String, subtitle: String, icon: String, color: UIColor) -> UIView {
        let card = HolographicCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon container
        let iconContainer = GlassMorphismView()
        iconContainer.glassColor = color
        iconContainer.glassIntensity = 0.3
        iconContainer.layer.cornerRadius = 30
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = MedicalTypography.headlineMedium
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = MedicalTypography.bodySmall
        subtitleLabel.textColor = MedicalColorPalette.primaryLight
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Pulse animation layer
        let pulseLayer = CAShapeLayer()
        let pulsePath = UIBezierPath(arcCenter: CGPoint(x: 30, y: 30), radius: 35, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        pulseLayer.path = pulsePath.cgPath
        pulseLayer.fillColor = UIColor.clear.cgColor
        pulseLayer.strokeColor = color.withAlphaComponent(0.3).cgColor
        pulseLayer.lineWidth = 2
        iconContainer.layer.addSublayer(pulseLayer)
        
        // Pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1
        pulseAnimation.toValue = 1.2
        pulseAnimation.duration = 2
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        pulseLayer.add(pulseAnimation, forKey: "pulse")
        
        // Add subviews
        iconContainer.addSubview(iconView)
        card.addSubview(iconContainer)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 100),
            
            iconContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 60),
            iconContainer.heightAnchor.constraint(equalToConstant: 60),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(viewerCardTapped(_:)))
        card.addGestureRecognizer(tapGesture)
        card.tag = [viewer2DCard, viewerMPRCard, viewer3DAICard].firstIndex(where: { $0 === card }) ?? 0
        
        return card
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Animations
    
    private func performEntranceAnimation() {
        // Initial state
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: -20)
        
        subtitleLabel.alpha = 0
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: -20)
        
        viewer2DCard.alpha = 0
        viewer2DCard.transform = CGAffineTransform(translationX: -100, y: 0)
        
        viewerMPRCard.alpha = 0
        viewerMPRCard.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        viewer3DAICard.alpha = 0
        viewer3DAICard.transform = CGAffineTransform(translationX: 100, y: 0)
        
        cancelButton.alpha = 0
        cancelButton.transform = CGAffineTransform(translationX: 0, y: 20)
        
        // Animate
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }
        
        UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
            self.subtitleLabel.alpha = 1
            self.subtitleLabel.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.viewer2DCard.alpha = 1
            self.viewer2DCard.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.3, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.viewerMPRCard.alpha = 1
            self.viewerMPRCard.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.4, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.viewer3DAICard.alpha = 1
            self.viewer3DAICard.transform = .identity
        }
        
        UIView.animate(withDuration: 0.4, delay: 0.5, options: .curveEaseOut) {
            self.cancelButton.alpha = 1
            self.cancelButton.transform = .identity
        }
        
        // Container flip
        containerView.flip(duration: 0.8)
    }
    
    private func performExitAnimation(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.alpha = 0
            self.view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            completion()
        }
    }
    
    // MARK: - Actions
    
    @objc private func viewerCardTapped(_ sender: UITapGestureRecognizer) {
        guard let card = sender.view else { return }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Animate selection
        UIView.animate(withDuration: 0.2, animations: {
            card.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                card.transform = .identity
            }
        }
        
        // Navigate to viewer
        performExitAnimation { [weak self] in
            guard let self = self, let study = self.study else { return }
            
            let viewerVC: UIViewController
            
            switch card.tag {
            case 0: // 2D Viewer
                viewerVC = UltraModernViewerViewController()
                (viewerVC as? UltraModernViewerViewController)?.study = study
                
            case 1: // MPR Viewer
                viewerVC = UltraModernMPRViewController()
                (viewerVC as? UltraModernMPRViewController)?.study = study
                
            case 2: // 3D/AI Viewer
                viewerVC = UltraModern3DAIViewController()
                (viewerVC as? UltraModern3DAIViewController)?.study = study
                
            default:
                return
            }
            
            viewerVC.modalPresentationStyle = .fullScreen
            viewerVC.modalTransitionStyle = .crossDissolve
            
            self.dismiss(animated: false) {
                if let presentingVC = self.presentingViewController {
                    presentingVC.present(viewerVC, animated: true)
                }
            }
        }
    }
    
    @objc private func cancelTapped() {
        performExitAnimation { [weak self] in
            self?.dismiss(animated: false)
        }
    }
    
    @objc private func backgroundTapped() {
        // Optional: dismiss on background tap
    }
}