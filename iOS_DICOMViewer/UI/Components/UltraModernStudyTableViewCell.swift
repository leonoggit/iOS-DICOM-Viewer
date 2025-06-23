//
//  UltraModernStudyTableViewCell.swift
//  iOS_DICOMViewer
//
//  Sophisticated table view cell for DICOM studies
//

import UIKit

class UltraModernStudyTableViewCell: UITableViewCell, NightModeObserver {
    
    // MARK: - UI Components
    
    private let containerView = UIView()
    private let thumbnailImageView = UIImageView()
    private let modalityBadge = UIView()
    private let modalityLabel = UILabel()
    
    private let patientNameLabel = UILabel()
    private let studyDescriptionLabel = UILabel()
    private let dateLabel = UILabel()
    private let imageCountLabel = UILabel()
    private let accessionLabel = UILabel()
    
    private let chevronImageView = UIImageView()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
        
        // Setup night mode
        NightModeManager.shared.addObserver(self)
        nightModeDidChange(NightModeManager.shared.isNightMode)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
        
        // Setup night mode
        NightModeManager.shared.addObserver(self)
        nightModeDidChange(NightModeManager.shared.isNightMode)
    }
    
    deinit {
        NightModeManager.shared.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Container view
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Thumbnail
        thumbnailImageView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 12
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(thumbnailImageView)
        
        // Modality badge
        modalityBadge.backgroundColor = MedicalColorPalette.accentPrimary
        modalityBadge.layer.cornerRadius = 10
        modalityBadge.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(modalityBadge)
        
        modalityLabel.font = .systemFont(ofSize: 12, weight: .bold)
        modalityLabel.textColor = .white
        modalityLabel.textAlignment = .center
        modalityLabel.translatesAutoresizingMaskIntoConstraints = false
        modalityBadge.addSubview(modalityLabel)
        
        // Labels
        patientNameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        patientNameLabel.textColor = .white
        patientNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        studyDescriptionLabel.font = .systemFont(ofSize: 15, weight: .regular)
        studyDescriptionLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        studyDescriptionLabel.numberOfLines = 1
        studyDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        dateLabel.font = .systemFont(ofSize: 13, weight: .regular)
        dateLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        imageCountLabel.font = .systemFont(ofSize: 13, weight: .regular)
        imageCountLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        imageCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        accessionLabel.font = .systemFont(ofSize: 12, weight: .regular)
        accessionLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        accessionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Chevron
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = UIColor.white.withAlphaComponent(0.3)
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(patientNameLabel)
        containerView.addSubview(studyDescriptionLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(imageCountLabel)
        containerView.addSubview(accessionLabel)
        containerView.addSubview(chevronImageView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Thumbnail
            thumbnailImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            thumbnailImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 64),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 64),
            
            // Modality badge
            modalityBadge.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 4),
            modalityBadge.bottomAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 4),
            modalityBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
            modalityBadge.heightAnchor.constraint(equalToConstant: 20),
            
            modalityLabel.leadingAnchor.constraint(equalTo: modalityBadge.leadingAnchor, constant: 6),
            modalityLabel.trailingAnchor.constraint(equalTo: modalityBadge.trailingAnchor, constant: -6),
            modalityLabel.centerYAnchor.constraint(equalTo: modalityBadge.centerYAnchor),
            
            // Patient name
            patientNameLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 16),
            patientNameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            patientNameLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            
            // Study description
            studyDescriptionLabel.leadingAnchor.constraint(equalTo: patientNameLabel.leadingAnchor),
            studyDescriptionLabel.topAnchor.constraint(equalTo: patientNameLabel.bottomAnchor, constant: 4),
            studyDescriptionLabel.trailingAnchor.constraint(equalTo: patientNameLabel.trailingAnchor),
            
            // Date and image count (horizontal stack)
            dateLabel.leadingAnchor.constraint(equalTo: patientNameLabel.leadingAnchor),
            dateLabel.topAnchor.constraint(equalTo: studyDescriptionLabel.bottomAnchor, constant: 8),
            
            imageCountLabel.leadingAnchor.constraint(equalTo: dateLabel.trailingAnchor, constant: 12),
            imageCountLabel.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            
            // Accession
            accessionLabel.leadingAnchor.constraint(equalTo: patientNameLabel.leadingAnchor),
            accessionLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            accessionLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16),
            
            // Chevron
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with study: DICOMStudy) {
        // Patient info
        patientNameLabel.text = formatPatientName(study.patientName)
        
        // Study description
        studyDescriptionLabel.text = study.studyDescription ?? "Medical Imaging Study"
        
        // Date
        if let studyDate = study.studyDate {
            dateLabel.text = formatDate(studyDate)
        } else {
            dateLabel.text = "Date unknown"
        }
        
        // Image count
        let totalImages = study.series.reduce(0) { $0 + $1.instances.count }
        imageCountLabel.text = "\(totalImages) image\(totalImages == 1 ? "" : "s")"
        
        // Accession number
        if let accession = study.accessionNumber, !accession.isEmpty {
            accessionLabel.text = "Accession #: \(accession)"
            accessionLabel.isHidden = false
        } else {
            accessionLabel.isHidden = true
        }
        
        // Modality
        if let modality = study.series.first?.modality {
            modalityLabel.text = modality
            modalityBadge.backgroundColor = colorForModality(modality)
        } else {
            modalityLabel.text = "???"
            modalityBadge.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        }
        
        // Load thumbnail
        loadThumbnail(for: study)
    }
    
    private func formatPatientName(_ name: String?) -> String {
        guard let name = name, !name.isEmpty else {
            return "Unknown Patient"
        }
        
        // Handle DICOM format (LastName^FirstName^MiddleName)
        let components = name.components(separatedBy: "^")
        if components.count >= 2 {
            let lastName = components[0]
            let firstName = components[1]
            return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        }
        
        return name
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // Check if today or yesterday
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: date)
    }
    
    private func colorForModality(_ modality: String) -> UIColor {
        switch modality.uppercased() {
        case "CT":
            return UIColor.systemBlue
        case "MR", "MRI":
            return UIColor.systemPurple
        case "CR", "DX":
            return UIColor.systemOrange
        case "US":
            return UIColor.systemGreen
        case "NM":
            return UIColor.systemRed
        case "PT":
            return UIColor.systemYellow
        default:
            return MedicalColorPalette.accentPrimary
        }
    }
    
    private func loadThumbnail(for study: DICOMStudy) {
        // Set placeholder
        thumbnailImageView.image = UIImage(systemName: "photo")
        thumbnailImageView.tintColor = UIColor.white.withAlphaComponent(0.3)
        thumbnailImageView.contentMode = .scaleAspectFit
        
        // Try to load actual thumbnail
        if let firstInstance = study.series.first?.instances.first {
            Task {
                do {
                    if let image = try await DICOMImageRenderer.shared.renderImage(
                        from: firstInstance,
                        windowWidth: 400,
                        windowCenter: 40
                    ) {
                        await MainActor.run {
                            self.thumbnailImageView.image = image
                            self.thumbnailImageView.contentMode = .scaleAspectFill
                        }
                    }
                } catch {
                    // Keep placeholder
                }
            }
        }
    }
    
    // MARK: - Selection
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            UIView.animate(withDuration: 0.1) {
                self.containerView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                self.containerView.alpha = 0.8
            }
        } else {
            UIView.animate(withDuration: 0.1) {
                self.containerView.transform = .identity
                self.containerView.alpha = 1.0
            }
        }
    }
    
    // MARK: - Night Mode
    
    func nightModeDidChange(_ isNightMode: Bool) {
        UIView.animate(withDuration: 0.3) {
            if isNightMode {
                self.containerView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
                self.containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.05).cgColor
                self.patientNameLabel.textColor = MedicalColorPalette.textPrimaryNight
                self.studyDescriptionLabel.textColor = MedicalColorPalette.textSecondaryNight
                self.dateLabel.textColor = MedicalColorPalette.textSecondaryNight.withAlphaComponent(0.8)
                self.imageCountLabel.textColor = MedicalColorPalette.textSecondaryNight.withAlphaComponent(0.8)
                self.accessionLabel.textColor = MedicalColorPalette.textSecondaryNight.withAlphaComponent(0.6)
            } else {
                self.containerView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
                self.containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
                self.patientNameLabel.textColor = .white
                self.studyDescriptionLabel.textColor = UIColor.white.withAlphaComponent(0.8)
                self.dateLabel.textColor = UIColor.white.withAlphaComponent(0.6)
                self.imageCountLabel.textColor = UIColor.white.withAlphaComponent(0.6)
                self.accessionLabel.textColor = UIColor.white.withAlphaComponent(0.5)
            }
        }
    }
}