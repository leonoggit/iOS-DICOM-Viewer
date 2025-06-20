//
//  SettingsViewController.swift
//  iOS_DICOMViewer
//
//  Settings and preferences for DICOM Viewer
//  Modern medical imaging app settings interface
//

import UIKit

class SettingsViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupSettingsSections()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        // Colors from HTML template
        let backgroundDark = UIColor(red: 17/255, green: 22/255, blue: 24/255, alpha: 1.0) // #111618
        view.backgroundColor = backgroundDark
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }
    
    private func setupNavigationBar() {
        title = "Settings"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    private func setupSettingsSections() {
        // Viewer Settings Section
        let viewerSection = createSettingsSection(
            title: "Viewer Settings",
            settings: [
                SettingsItem(title: "Window/Level Presets", subtitle: "CT, MR, X-Ray presets", type: .disclosure),
                SettingsItem(title: "Default Zoom Level", subtitle: "Fit to window", type: .disclosure),
                SettingsItem(title: "Touch Gestures", subtitle: "Pan, zoom, window/level", type: .toggle(true)),
                SettingsItem(title: "Overlay Information", subtitle: "Patient info, study details", type: .toggle(true))
            ]
        )
        
        // 3D Rendering Section
        let renderingSection = createSettingsSection(
            title: "3D Rendering",
            settings: [
                SettingsItem(title: "Quality Level", subtitle: "High", type: .disclosure),
                SettingsItem(title: "Ray Casting", subtitle: "GPU acceleration", type: .toggle(true)),
                SettingsItem(title: "Volume Lighting", subtitle: "Enhanced visualization", type: .toggle(false)),
                SettingsItem(title: "Transfer Functions", subtitle: "CT, MR presets", type: .disclosure)
            ]
        )
        
        // AI Segmentation Section
        let aiSection = createSettingsSection(
            title: "AI Segmentation",
            settings: [
                SettingsItem(title: "Auto-Segmentation", subtitle: "Urinary tract, organs", type: .toggle(true)),
                SettingsItem(title: "Model Quality", subtitle: "Clinical grade", type: .disclosure),
                SettingsItem(title: "Processing Mode", subtitle: "GPU accelerated", type: .disclosure),
                SettingsItem(title: "Validation Metrics", subtitle: "Dice coefficient, Jaccard", type: .toggle(true))
            ]
        )
        
        // Data Management Section
        let dataSection = createSettingsSection(
            title: "Data Management",
            settings: [
                SettingsItem(title: "Storage Location", subtitle: "Local device", type: .disclosure),
                SettingsItem(title: "Auto-Import", subtitle: "ZIP files, DICOM archives", type: .toggle(true)),
                SettingsItem(title: "Cache Size", subtitle: "2GB limit", type: .disclosure),
                SettingsItem(title: "Export Options", subtitle: "JPEG, PNG, DICOM", type: .disclosure)
            ]
        )
        
        // Privacy & Security Section
        let privacySection = createSettingsSection(
            title: "Privacy & Security",
            settings: [
                SettingsItem(title: "PHI Protection", subtitle: "HIPAA compliant", type: .info),
                SettingsItem(title: "Data Encryption", subtitle: "AES-256", type: .info),
                SettingsItem(title: "Audit Logging", subtitle: "View access logs", type: .disclosure),
                SettingsItem(title: "Clear Cache", subtitle: "Remove temporary files", type: .action)
            ]
        )
        
        // About Section
        let aboutSection = createSettingsSection(
            title: "About",
            settings: [
                SettingsItem(title: "Version", subtitle: "1.0.0 (iOS 18+)", type: .info),
                SettingsItem(title: "DCMTK Version", subtitle: "3.6.7", type: .info),
                SettingsItem(title: "Metal Support", subtitle: "iPhone 16 Pro Max optimized", type: .info),
                SettingsItem(title: "Medical Disclaimer", subtitle: "For educational use only", type: .disclosure)
            ]
        )
        
        contentStackView.addArrangedSubview(viewerSection)
        contentStackView.addArrangedSubview(renderingSection)
        contentStackView.addArrangedSubview(aiSection)
        contentStackView.addArrangedSubview(dataSection)
        contentStackView.addArrangedSubview(privacySection)
        contentStackView.addArrangedSubview(aboutSection)
    }
    
    private func createSettingsSection(title: String, settings: [SettingsItem]) -> UIView {
        let sectionView = UIView()
        let sectionStackView = UIStackView()
        sectionStackView.axis = .vertical
        sectionStackView.spacing = 0
        sectionStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Section header
        let headerLabel = UILabel()
        headerLabel.text = title
        headerLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        headerLabel.textColor = UIColor.white
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Section container
        let containerView = UIView()
        let surfaceDarkSecondary = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 1.0) // #283539
        containerView.backgroundColor = surfaceDarkSecondary
        containerView.layer.cornerRadius = 12
        containerView.layer.masksToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        sectionView.addSubview(headerLabel)
        sectionView.addSubview(containerView)
        containerView.addSubview(sectionStackView)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: sectionView.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor),
            headerLabel.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor),
            
            containerView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: sectionView.bottomAnchor),
            
            sectionStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            sectionStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            sectionStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            sectionStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Add settings items
        for (index, setting) in settings.enumerated() {
            let settingView = createSettingItemView(setting)
            sectionStackView.addArrangedSubview(settingView)
            
            // Add separator (except for last item)
            if index < settings.count - 1 {
                let separator = UIView()
                let borderDark = UIColor(red: 59/255, green: 78/255, blue: 84/255, alpha: 1.0) // #3b4e54
                separator.backgroundColor = borderDark
                separator.translatesAutoresizingMaskIntoConstraints = false
                sectionStackView.addArrangedSubview(separator)
                separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
            }
        }
        
        return sectionView
    }
    
    private func createSettingItemView(_ item: SettingsItem) -> UIView {
        let itemView = UIView()
        itemView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title and subtitle stack
        let textStackView = UIStackView()
        textStackView.axis = .vertical
        textStackView.spacing = 2
        
        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.white
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = item.subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        let textSecondary = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0) // #9cb2ba
        subtitleLabel.textColor = textSecondary
        
        textStackView.addArrangedSubview(titleLabel)
        textStackView.addArrangedSubview(subtitleLabel)
        
        stackView.addArrangedSubview(textStackView)
        
        // Add appropriate control based on type
        switch item.type {
        case .toggle(let isOn):
            let toggle = UISwitch()
            toggle.isOn = isOn
            let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0) // #0cb8f2
            toggle.onTintColor = primaryColor
            stackView.addArrangedSubview(toggle)
            
        case .disclosure:
            let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
            chevron.tintColor = textSecondary
            chevron.contentMode = .scaleAspectFit
            stackView.addArrangedSubview(chevron)
            
            // Add tap gesture
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(settingItemTapped(_:)))
            itemView.addGestureRecognizer(tapGesture)
            itemView.isUserInteractionEnabled = true
            
        case .action:
            let actionLabel = UILabel()
            actionLabel.text = "Clear"
            actionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            let accentTeal = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0) // #14b8a6
            actionLabel.textColor = accentTeal
            stackView.addArrangedSubview(actionLabel)
            
            // Add tap gesture
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(settingActionTapped(_:)))
            itemView.addGestureRecognizer(tapGesture)
            itemView.isUserInteractionEnabled = true
            
        case .info:
            break // No additional control needed
        }
        
        itemView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: itemView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: itemView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: itemView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: itemView.bottomAnchor, constant: -16)
        ])
        
        return itemView
    }
    
    // MARK: - Actions
    
    @objc private func settingItemTapped(_ gesture: UITapGestureRecognizer) {
        // Handle disclosure settings
        print("⚙️ Settings: Disclosure item tapped")
    }
    
    @objc private func settingActionTapped(_ gesture: UITapGestureRecognizer) {
        // Handle action settings like "Clear Cache"
        let alert = UIAlertController(
            title: "Clear Cache",
            message: "This will remove all temporary DICOM files and cached data. Continue?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            // Implement cache clearing
            print("🗑️ Settings: Clearing cache...")
        })
        
        present(alert, animated: true)
    }
}

// MARK: - Settings Data Models

struct SettingsItem {
    let title: String
    let subtitle: String
    let type: SettingsItemType
}

enum SettingsItemType {
    case toggle(Bool)
    case disclosure
    case action
    case info
}