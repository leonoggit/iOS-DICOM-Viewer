//
//  StudyTableViewCell.swift
//  iOS_DICOMViewer
//
//  Custom table view cell for DICOM study display
//  Matches modern medical imaging UI design from HTML template
//

import UIKit

class StudyTableViewCell: UITableViewCell {
    
    static let identifier = "StudyTableViewCell"
    
    // MARK: - UI Components
    
    private lazy var containerView: UIView = {
        let view = UIView()
        let surfaceDarkSecondary = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 1.0) // #283539
        view.backgroundColor = surfaceDarkSecondary
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var iconContainerView: UIView = {
        let view = UIView()
        let backgroundDark = UIColor(red: 17/255, green: 22/255, blue: 24/255, alpha: 1.0) // #111618
        view.backgroundColor = backgroundDark
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        let accentBlue = UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1.0) // #3b82f6
        imageView.tintColor = accentBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var patientNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.white
        label.numberOfLines = 1
        return label
    }()
    
    private lazy var studyInfoLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        let textSecondary = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0) // #9cb2ba
        label.textColor = textSecondary
        label.numberOfLines = 2
        return label
    }()
    
    private lazy var chevronImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        let textSecondary = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0) // #9cb2ba
        imageView.tintColor = textSecondary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        iconContainerView.addSubview(iconImageView)
        containerView.addSubview(iconContainerView)
        containerView.addSubview(contentStackView)
        containerView.addSubview(chevronImageView)
        
        contentStackView.addArrangedSubview(patientNameLabel)
        contentStackView.addArrangedSubview(studyInfoLabel)
        
        setupConstraints()
        setupHighlighting()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            // Icon container
            iconContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconContainerView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconContainerView.widthAnchor.constraint(equalToConstant: 48),
            iconContainerView.heightAnchor.constraint(equalToConstant: 48),
            
            // Icon image
            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // Content stack
            contentStackView.leadingAnchor.constraint(equalTo: iconContainerView.trailingAnchor, constant: 16),
            contentStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -12),
            
            // Chevron
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 16),
            chevronImageView.heightAnchor.constraint(equalToConstant: 16),
            
            // Minimum height for better touch targets on iPhone 16 Pro Max
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
    }
    
    private func setupHighlighting() {
        // Add touch highlighting similar to HTML template hover effects
        let tapGesture = UITapGestureRecognizer()
        containerView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Configuration
    
    func configure(with study: DICOMStudy) {
        // Patient name with privacy-friendly display
        if !study.patientName.isEmpty {
            patientNameLabel.text = "Patient: \(formatPatientName(study.patientName))"
        } else {
            patientNameLabel.text = "Patient: Unknown"
        }
        
        // Study information
        var studyInfoParts: [String] = []
        
        // Study date
        if !study.studyDate.isEmpty {
            studyInfoParts.append("Study Date: \(formatStudyDate(study.studyDate))")
        }
        
        // Modality (from first series)
        if let firstSeries = study.series.first, !firstSeries.modality.isEmpty {
            studyInfoParts.append("Modality: \(firstSeries.modality)")
        }
        
        // Series count
        let seriesCount = study.series.count
        if seriesCount > 0 {
            studyInfoParts.append("\(seriesCount) Series")
        }
        
        // Instance count
        let instanceCount = study.series.reduce(0) { $0 + $1.instances.count }
        if instanceCount > 0 {
            studyInfoParts.append("\(instanceCount) Images")
        }
        
        studyInfoLabel.text = studyInfoParts.joined(separator: " | ")
        
        // Icon based on modality
        setIconForModality(study.series.first?.modality ?? "")
        
        // Study description if available
        if !study.studyDescription.isEmpty {
            let descriptionText = study.studyDescription
            studyInfoLabel.text = (studyInfoLabel.text ?? "") + "\n\(descriptionText)"
        }
    }
    
    private func setIconForModality(_ modality: String) {
        let iconName: String
        
        switch modality.uppercased() {
        case "CT":
            iconName = "brain.head.profile"
        case "MR", "MRI":
            iconName = "brain"
        case "US", "ULTRASOUND":
            iconName = "waveform.path.ecg"
        case "XR", "X-RAY", "DX":
            iconName = "lungs"
        case "PET", "PT":
            iconName = "heart.circle"
        case "NM":
            iconName = "radiowaves.left.and.right"
        case "MG", "MAMMOGRAPHY":
            iconName = "person.crop.circle"
        default:
            iconName = "photo.on.rectangle"
        }
        
        iconImageView.image = UIImage(systemName: iconName)
    }
    
    private func formatPatientName(_ name: String) -> String {
        // DICOM patient names are often in format: "LastName^FirstName^MiddleName"
        let components = name.components(separatedBy: "^")
        if components.count >= 2 {
            let lastName = components[0].isEmpty ? "Unknown" : components[0]
            let firstName = components[1].isEmpty ? "" : components[1]
            return firstName.isEmpty ? lastName : "\(firstName) \(lastName)"
        }
        return name.isEmpty ? "Unknown" : name
    }
    
    private func formatStudyDate(_ date: String) -> String {
        // DICOM dates are in format YYYYMMDD
        guard date.count == 8,
              let year = Int(String(date.prefix(4))),
              let month = Int(String(date.dropFirst(4).prefix(2))),
              let day = Int(String(date.suffix(2))) else {
            return date
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let calendar = Calendar.current
        if let studyDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
            return dateFormatter.string(from: studyDate)
        }
        
        return date
    }
    
    // MARK: - Highlighting
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        UIView.animate(withDuration: 0.2) {
            if highlighted {
                let borderDark = UIColor(red: 59/255, green: 78/255, blue: 84/255, alpha: 0.6) // #3b4e54/60
                self.containerView.backgroundColor = borderDark
            } else {
                let surfaceDarkSecondary = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 1.0) // #283539
                self.containerView.backgroundColor = surfaceDarkSecondary
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        patientNameLabel.text = nil
        studyInfoLabel.text = nil
        iconImageView.image = nil
    }
}