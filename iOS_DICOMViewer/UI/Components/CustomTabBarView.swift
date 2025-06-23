//
//  CustomTabBarView.swift
//  iOS_DICOMViewer
//
//  Custom tab bar with sophisticated design
//

import UIKit

class CustomTabBarView: UIView, NightModeObserver {
    
    // MARK: - Properties
    
    var onTabSelected: ((TabItem) -> Void)?
    
    private var tabButtons: [TabButton] = []
    private var selectedTab: TabItem = .studies
    
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let separatorView = UIView()
    
    // Warning label
    private let warningLabel = UILabel()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTabBar()
        
        // Setup night mode
        NightModeManager.shared.addObserver(self)
        nightModeDidChange(NightModeManager.shared.isNightMode)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTabBar()
        
        // Setup night mode
        NightModeManager.shared.addObserver(self)
        nightModeDidChange(NightModeManager.shared.isNightMode)
    }
    
    deinit {
        NightModeManager.shared.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupTabBar() {
        // Background
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)
        
        // Separator
        separatorView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorView)
        
        // Warning label
        warningLabel.text = "⚠️ Not suitable for Primary Diagnosis"
        warningLabel.font = .systemFont(ofSize: 12, weight: .medium)
        warningLabel.textColor = UIColor.systemYellow
        warningLabel.textAlignment = .center
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(warningLabel)
        
        // Create tab buttons
        let tabs: [(TabItem, String, String)] = [
            (.studies, "Studies", "square.stack.3d.up"),
            (.falconSolutions, "Falcon Solutions", "waveform.path.ecg"),
            (.sources, "Sources", "globe"),
            (.settings, "Settings", "gearshape")
        ]
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for (tab, title, icon) in tabs {
            let button = TabButton()
            button.configure(title: title, icon: icon, isSelected: tab == selectedTab)
            button.tag = tabs.firstIndex(where: { $0.0 == tab }) ?? 0
            button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
            
            tabButtons.append(button)
            stackView.addArrangedSubview(button)
            
            // Add badge to specific tabs
            if tab == .falconSolutions || tab == .settings {
                addBadge(to: button)
            }
        }
        
        addSubview(stackView)
        
        // Constraints
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            separatorView.topAnchor.constraint(equalTo: topAnchor),
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),
            
            warningLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            warningLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            warningLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            stackView.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 4),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func addBadge(to button: TabButton) {
        let badgeView = UIView()
        badgeView.backgroundColor = .systemRed
        badgeView.layer.cornerRadius = 4
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(badgeView)
        
        NSLayoutConstraint.activate([
            badgeView.topAnchor.constraint(equalTo: button.iconImageView.topAnchor, constant: -2),
            badgeView.trailingAnchor.constraint(equalTo: button.iconImageView.trailingAnchor, constant: 2),
            badgeView.widthAnchor.constraint(equalToConstant: 8),
            badgeView.heightAnchor.constraint(equalToConstant: 8)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func tabButtonTapped(_ sender: UIButton) {
        let tabs: [TabItem] = [.studies, .falconSolutions, .sources, .settings]
        guard sender.tag < tabs.count else { return }
        
        let selectedTab = tabs[sender.tag]
        self.selectedTab = selectedTab
        
        // Update button states
        for (index, button) in tabButtons.enumerated() {
            button.setSelected(index == sender.tag)
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // Notify delegate
        onTabSelected?(selectedTab)
    }
    
    // MARK: - Night Mode
    
    func nightModeDidChange(_ isNightMode: Bool) {
        UIView.animate(withDuration: 0.3) {
            if isNightMode {
                self.separatorView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
            } else {
                self.separatorView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            }
        }
    }
}

// MARK: - Tab Button
class TabButton: UIButton {
    
    let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        // Icon
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title
        titleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
    
    func configure(title: String, icon: String, isSelected: Bool) {
        iconImageView.image = UIImage(systemName: icon)
        titleLabel.text = title
        setSelected(isSelected)
    }
    
    func setSelected(_ selected: Bool) {
        if selected {
            iconImageView.tintColor = MedicalColorPalette.accentPrimary
            titleLabel.textColor = MedicalColorPalette.accentPrimary
        } else {
            iconImageView.tintColor = UIColor.white.withAlphaComponent(0.6)
            titleLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        }
    }
}