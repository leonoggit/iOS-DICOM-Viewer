//
//  UltraModernStudyCell.swift
//  iOS_DICOMViewer
//
//  Ultra-sophisticated study cell with advanced visual effects
//

import UIKit
import SwiftUI

class UltraModernStudyCell: UICollectionViewCell, NightModeObserver {
    
    // MARK: - UI Components
    
    private let cardView = HolographicCardView()
    
    private let thumbnailContainer = UIView()
    private let thumbnailImageView = UIImageView()
    private let modalityBadge = GlassMorphismView()
    private let modalityIcon = UIImageView()
    
    private let patientNameLabel = UILabel()
    private let studyDateLabel = UILabel()
    private let studyDescriptionLabel = UILabel()
    
    private let urgencyIndicator = LiquidAnimationView()
    private let sparklineView = SparklineView()
    
    private let statusIndicators = UIStackView()
    private let unreadBadge = UIView()
    private let criticalBadge = UIView()
    private let aiAnalyzedBadge = UIView()
    
    private let interactionFeedback = UIView()
    
    // MARK: - Properties
    
    static let identifier = "UltraModernStudyCell"
    private var isPressed = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
        
        // Setup night mode
        NightModeManager.shared.addObserver(self)
        nightModeDidChange(NightModeManager.shared.isNightMode)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    // MARK: - Setup
    
    private func setupCell() {
        contentView.backgroundColor = .clear
        
        // Card view
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        
        // Thumbnail container
        thumbnailContainer.backgroundColor = MedicalColorPalette.primaryDark
        thumbnailContainer.layer.cornerRadius = 12
        thumbnailContainer.clipsToBounds = true
        thumbnailContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Thumbnail image
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Modality badge
        modalityBadge.glassIntensity = 0.9
        modalityBadge.layer.cornerRadius = 20
        modalityBadge.translatesAutoresizingMaskIntoConstraints = false
        
        modalityIcon.contentMode = .scaleAspectFit
        modalityIcon.tintColor = .white
        modalityIcon.translatesAutoresizingMaskIntoConstraints = false
        
        // Labels
        patientNameLabel.font = MedicalTypography.headlineSmall
        patientNameLabel.textColor = .white
        patientNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        studyDateLabel.font = MedicalTypography.bodySmall
        studyDateLabel.textColor = MedicalColorPalette.primaryLight
        studyDateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        studyDescriptionLabel.font = MedicalTypography.bodyMedium
        studyDescriptionLabel.textColor = MedicalColorPalette.primaryLight.withAlphaComponent(0.8)
        studyDescriptionLabel.numberOfLines = 2
        studyDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Urgency indicator
        urgencyIndicator.waveColor = MedicalColorPalette.accentCritical
        urgencyIndicator.isHidden = true
        urgencyIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Sparkline
        sparklineView.translatesAutoresizingMaskIntoConstraints = false
        sparklineView.isHidden = true
        
        // Status indicators
        statusIndicators.axis = .horizontal
        statusIndicators.spacing = 8
        statusIndicators.translatesAutoresizingMaskIntoConstraints = false
        
        setupStatusBadges()
        
        // Interaction feedback
        interactionFeedback.backgroundColor = MedicalColorPalette.accentPrimary.withAlphaComponent(0.1)
        interactionFeedback.layer.cornerRadius = 20
        interactionFeedback.alpha = 0
        interactionFeedback.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        thumbnailContainer.addSubview(thumbnailImageView)
        modalityBadge.addSubview(modalityIcon)
        
        cardView.addSubview(thumbnailContainer)
        cardView.addSubview(modalityBadge)
        cardView.addSubview(patientNameLabel)
        cardView.addSubview(studyDateLabel)
        cardView.addSubview(studyDescriptionLabel)
        cardView.addSubview(urgencyIndicator)
        cardView.addSubview(sparklineView)
        cardView.addSubview(statusIndicators)
        cardView.addSubview(interactionFeedback)
        
        setupConstraints()
        setupGestures()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Card view
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Thumbnail container
            thumbnailContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            thumbnailContainer.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            thumbnailContainer.widthAnchor.constraint(equalToConstant: 80),
            thumbnailContainer.heightAnchor.constraint(equalToConstant: 80),
            
            // Thumbnail image
            thumbnailImageView.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor),
            
            // Modality badge
            modalityBadge.centerXAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor, constant: -8),
            modalityBadge.centerYAnchor.constraint(equalTo: thumbnailContainer.bottomAnchor, constant: -8),
            modalityBadge.widthAnchor.constraint(equalToConstant: 40),
            modalityBadge.heightAnchor.constraint(equalToConstant: 40),
            
            // Modality icon
            modalityIcon.centerXAnchor.constraint(equalTo: modalityBadge.centerXAnchor),
            modalityIcon.centerYAnchor.constraint(equalTo: modalityBadge.centerYAnchor),
            modalityIcon.widthAnchor.constraint(equalToConstant: 24),
            modalityIcon.heightAnchor.constraint(equalToConstant: 24),
            
            // Patient name
            patientNameLabel.leadingAnchor.constraint(equalTo: thumbnailContainer.trailingAnchor, constant: 16),
            patientNameLabel.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor),
            patientNameLabel.trailingAnchor.constraint(equalTo: statusIndicators.leadingAnchor, constant: -8),
            
            // Study date
            studyDateLabel.leadingAnchor.constraint(equalTo: patientNameLabel.leadingAnchor),
            studyDateLabel.topAnchor.constraint(equalTo: patientNameLabel.bottomAnchor, constant: 4),
            
            // Study description
            studyDescriptionLabel.leadingAnchor.constraint(equalTo: patientNameLabel.leadingAnchor),
            studyDescriptionLabel.topAnchor.constraint(equalTo: studyDateLabel.bottomAnchor, constant: 8),
            studyDescriptionLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            // Status indicators
            statusIndicators.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            statusIndicators.centerYAnchor.constraint(equalTo: patientNameLabel.centerYAnchor),
            
            // Urgency indicator
            urgencyIndicator.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            urgencyIndicator.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            urgencyIndicator.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            urgencyIndicator.heightAnchor.constraint(equalToConstant: 4),
            
            // Sparkline
            sparklineView.leadingAnchor.constraint(equalTo: thumbnailContainer.leadingAnchor),
            sparklineView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            sparklineView.topAnchor.constraint(equalTo: studyDescriptionLabel.bottomAnchor, constant: 12),
            sparklineView.heightAnchor.constraint(equalToConstant: 40),
            sparklineView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            
            // Interaction feedback
            interactionFeedback.topAnchor.constraint(equalTo: cardView.topAnchor),
            interactionFeedback.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            interactionFeedback.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            interactionFeedback.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])
    }
    
    private func setupStatusBadges() {
        // Unread badge
        unreadBadge.backgroundColor = MedicalColorPalette.accentPrimary
        unreadBadge.layer.cornerRadius = 6
        unreadBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            unreadBadge.widthAnchor.constraint(equalToConstant: 12),
            unreadBadge.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        // Critical badge
        criticalBadge.backgroundColor = MedicalColorPalette.accentCritical
        criticalBadge.layer.cornerRadius = 6
        criticalBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            criticalBadge.widthAnchor.constraint(equalToConstant: 12),
            criticalBadge.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        // AI analyzed badge
        let aiImageView = UIImageView(image: UIImage(systemName: "brain"))
        aiImageView.tintColor = MedicalColorPalette.accentSecondary
        aiImageView.contentMode = .scaleAspectFit
        aiImageView.translatesAutoresizingMaskIntoConstraints = false
        aiAnalyzedBadge.addSubview(aiImageView)
        NSLayoutConstraint.activate([
            aiImageView.widthAnchor.constraint(equalToConstant: 20),
            aiImageView.heightAnchor.constraint(equalToConstant: 20),
            aiImageView.centerXAnchor.constraint(equalTo: aiAnalyzedBadge.centerXAnchor),
            aiImageView.centerYAnchor.constraint(equalTo: aiAnalyzedBadge.centerYAnchor)
        ])
        
        statusIndicators.addArrangedSubview(unreadBadge)
        statusIndicators.addArrangedSubview(criticalBadge)
        statusIndicators.addArrangedSubview(aiAnalyzedBadge)
        
        // Initially hide all badges
        unreadBadge.isHidden = true
        criticalBadge.isHidden = true
        aiAnalyzedBadge.isHidden = true
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - Configuration
    
    func configure(with study: DICOMStudy) {
        // Patient info
        patientNameLabel.text = study.patientName ?? "Unknown Patient"
        
        // Date formatting
        if let studyDate = study.studyDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            studyDateLabel.text = formatter.string(from: studyDate)
        } else {
            studyDateLabel.text = "Date Unknown"
        }
        
        // Description
        studyDescriptionLabel.text = study.studyDescription ?? "No description available"
        
        // Modality
        if let modality = study.series.first?.modality {
            modalityIcon.image = getModalityIcon(for: modality)
        }
        
        // Thumbnail
        loadThumbnail(for: study)
        
        // Status indicators
        updateStatusIndicators(for: study)
        
        // Sparkline data (simulated)
        if Bool.random() {
            sparklineView.isHidden = false
            sparklineView.data = generateRandomSparklineData()
        } else {
            sparklineView.isHidden = true
        }
        
        // Urgency (simulated)
        if Bool.random() && Bool.random() {
            urgencyIndicator.isHidden = false
            urgencyIndicator.startAnimating()
        } else {
            urgencyIndicator.isHidden = true
            urgencyIndicator.stopAnimating()
        }
    }
    
    private func getModalityIcon(for modality: String) -> UIImage? {
        switch modality.uppercased() {
        case "CT":
            return UIImage(systemName: "cube.transparent")
        case "MR", "MRI":
            return UIImage(systemName: "waveform.path.ecg")
        case "CR", "DX":
            return UIImage(systemName: "xray")
        case "US":
            return UIImage(systemName: "waveform")
        case "NM":
            return UIImage(systemName: "atom")
        default:
            return UIImage(systemName: "photo")
        }
    }
    
    private func loadThumbnail(for study: DICOMStudy) {
        // Load actual thumbnail or use placeholder
        if let firstInstance = study.series.first?.instances.first {
            // Attempt to load thumbnail
            Task {
                if let image = await loadDICOMThumbnail(instance: firstInstance) {
                    await MainActor.run {
                        self.thumbnailImageView.image = image
                    }
                }
            }
        } else {
            // Placeholder
            thumbnailImageView.image = UIImage(systemName: "photo")
            thumbnailImageView.tintColor = MedicalColorPalette.primaryLight
        }
    }
    
    private func loadDICOMThumbnail(instance: DICOMInstance) async -> UIImage? {
        // Simplified thumbnail loading
        return nil
    }
    
    private func updateStatusIndicators(for study: DICOMStudy) {
        // Unread status (simulated)
        unreadBadge.isHidden = !Bool.random()
        
        // Critical status (simulated)
        criticalBadge.isHidden = !Bool.random() || Bool.random()
        
        // AI analyzed (simulated)
        aiAnalyzedBadge.isHidden = !Bool.random()
        
        // Animate badges
        for (index, badge) in statusIndicators.arrangedSubviews.enumerated() {
            if !badge.isHidden {
                badge.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                UIView.animate(
                    withDuration: 0.3,
                    delay: Double(index) * 0.1,
                    usingSpringWithDamping: 0.6,
                    initialSpringVelocity: 0.8,
                    options: [],
                    animations: {
                        badge.transform = .identity
                    }
                )
            }
        }
    }
    
    private func generateRandomSparklineData() -> [CGFloat] {
        return (0..<20).map { _ in CGFloat.random(in: 0...1) }
    }
    
    // MARK: - Gestures
    
    @objc private func handleTap() {
        // Animate interaction feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.interactionFeedback.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.interactionFeedback.alpha = 0
            }
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            animatePress(true)
        case .ended, .cancelled:
            animatePress(false)
        default:
            break
        }
    }
    
    private func animatePress(_ pressed: Bool) {
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: .allowUserInteraction,
            animations: {
                if pressed {
                    self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                    self.cardView.layer.shadowRadius = 5
                } else {
                    self.transform = .identity
                    self.cardView.layer.shadowRadius = 20
                }
            }
        )
        
        if pressed {
            // Enhanced haptic for long press
            HapticManager.shared.playMedicalAlert()
        }
    }
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        thumbnailImageView.image = nil
        sparklineView.data = []
        sparklineView.isHidden = true
        urgencyIndicator.isHidden = true
        urgencyIndicator.stopAnimating()
        
        unreadBadge.isHidden = true
        criticalBadge.isHidden = true
        aiAnalyzedBadge.isHidden = true
        
        transform = .identity
        interactionFeedback.alpha = 0
    }
    
    deinit {
        NightModeManager.shared.removeObserver(self)
    }
}

// MARK: - Night Mode
extension UltraModernStudyCell {
    func nightModeDidChange(_ isNightMode: Bool) {
        UIView.animate(withDuration: 0.3) {
            if isNightMode {
                self.cardView.backgroundColor = MedicalColorPalette.primaryMediumNight.withAlphaComponent(0.5)
                self.thumbnailContainer.backgroundColor = MedicalColorPalette.primaryDarkNight
                self.patientNameLabel.textColor = MedicalColorPalette.textPrimaryNight
                self.studyDateLabel.textColor = MedicalColorPalette.textSecondaryNight
                self.studyDescriptionLabel.textColor = MedicalColorPalette.textSecondaryNight.withAlphaComponent(0.8)
                self.sliceLabel.textColor = MedicalColorPalette.textSecondaryNight
            } else {
                self.cardView.backgroundColor = MedicalColorPalette.primaryMedium.withAlphaComponent(0.3)
                self.thumbnailContainer.backgroundColor = MedicalColorPalette.primaryDark
                self.patientNameLabel.textColor = .white
                self.studyDateLabel.textColor = MedicalColorPalette.primaryLight
                self.studyDescriptionLabel.textColor = MedicalColorPalette.primaryLight.withAlphaComponent(0.8)
                self.sliceLabel.textColor = MedicalColorPalette.primaryLight
            }
        }
    }
}