//
//  UltraModernHomeViewController.swift
//  iOS_DICOMViewer
//
//  Ultra-sophisticated home screen with medical-grade design
//

import UIKit

class UltraModernHomeViewController: UIViewController, NightModeObserver {
    
    // MARK: - UI Components
    
    // Background gradient
    private let backgroundGradientView = UIView()
    private var gradientLayer: CAGradientLayer!
    
    // Night mode toggle
    private let nightModeToggle = NightModeToggle()
    
    // Header components
    private let headerContainerView = UIView()
    private let greetingLabel = UILabel()
    private let dateLabel = UILabel()
    private let studyCountLabel = UILabel()
    
    // Action buttons
    private let importButton = UIButton()
    private let sourcesButton = UIButton()
    private let moreButton = UIButton()
    
    // Main table view
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    // Empty state
    private let emptyStateView = UIView()
    
    // Bottom tab bar
    private let customTabBar = CustomTabBarView()
    
    // Data
    private var studies: [DICOMStudy] = []
    private var groupedStudies: [String: [DICOMStudy]] = [:]
    private var sectionTitles: [String] = []
    
    // Loading state
    private let loadingView = QuantumLoadingIndicator()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        
        // Setup night mode
        NightModeManager.shared.addObserver(self)
        nightModeDidChange(NightModeManager.shared.isNightMode)
        
        // Load studies
        loadStudies()
        
        // Setup notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(studiesDidUpdate),
            name: DICOMMetadataStore.studyAddedNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeader()
        performEntranceAnimation()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGradient()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    deinit {
        NightModeManager.shared.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = MedicalColorPalette.primaryDark
        
        // Hide navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Setup gradient background
        setupGradientBackground()
        
        // Setup header
        setupHeader()
        
        // Setup action buttons
        setupActionButtons()
        
        // Setup table view
        setupTableView()
        
        // Setup empty state
        setupEmptyState()
        
        // Setup custom tab bar
        setupCustomTabBar()
        
        // Setup loading view
        setupLoadingView()
        
        // Add night mode toggle
        nightModeToggle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nightModeToggle)
        
        NSLayoutConstraint.activate([
            nightModeToggle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            nightModeToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nightModeToggle.widthAnchor.constraint(equalToConstant: 50),
            nightModeToggle.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupGradientBackground() {
        gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            MedicalColorPalette.primaryDark.cgColor,
            MedicalColorPalette.primaryMedium.cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.3)
        
        backgroundGradientView.layer.insertSublayer(gradientLayer, at: 0)
        backgroundGradientView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundGradientView)
        
        NSLayoutConstraint.activate([
            backgroundGradientView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundGradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundGradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundGradientView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4)
        ])
    }
    
    private func setupHeader() {
        headerContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerContainerView)
        
        // Greeting label
        greetingLabel.font = .systemFont(ofSize: 34, weight: .bold)
        greetingLabel.textColor = .white
        greetingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Date label
        dateLabel.font = .systemFont(ofSize: 16, weight: .medium)
        dateLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Study count label
        studyCountLabel.font = .systemFont(ofSize: 14, weight: .regular)
        studyCountLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        studyCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerContainerView.addSubview(greetingLabel)
        headerContainerView.addSubview(dateLabel)
        headerContainerView.addSubview(studyCountLabel)
        
        NSLayoutConstraint.activate([
            headerContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            greetingLabel.topAnchor.constraint(equalTo: headerContainerView.topAnchor),
            greetingLabel.leadingAnchor.constraint(equalTo: headerContainerView.leadingAnchor),
            greetingLabel.trailingAnchor.constraint(equalTo: headerContainerView.trailingAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: greetingLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: headerContainerView.leadingAnchor),
            
            studyCountLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 8),
            studyCountLabel.leadingAnchor.constraint(equalTo: headerContainerView.leadingAnchor),
            studyCountLabel.bottomAnchor.constraint(equalTo: headerContainerView.bottomAnchor)
        ])
    }
    
    private func setupActionButtons() {
        // Configure buttons
        configureActionButton(importButton, title: "Import", icon: "plus", isPrimary: true)
        configureActionButton(sourcesButton, title: "Sources", icon: "folder", isPrimary: false)
        configureActionButton(moreButton, title: "More", icon: "ellipsis.circle", isPrimary: false)
        
        // Stack view for buttons
        let buttonStack = UIStackView(arrangedSubviews: [importButton, sourcesButton, moreButton])
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(buttonStack)
        
        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: headerContainerView.bottomAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func configureActionButton(_ button: UIButton, title: String, icon: String, isPrimary: Bool) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.cornerStyle = .medium
        
        if isPrimary {
            config.baseBackgroundColor = MedicalColorPalette.accentPrimary
            config.baseForegroundColor = .white
        } else {
            config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.1)
            config.baseForegroundColor = .white
        }
        
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 100, right: 0)
        tableView.showsVerticalScrollIndicator = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Register cell
        tableView.register(UltraModernStudyTableViewCell.self, forCellReuseIdentifier: "StudyCell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: importButton.bottomAnchor, constant: 24),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        
        let iconView = UIImageView(image: UIImage(systemName: "photo.on.rectangle.angled"))
        iconView.tintColor = UIColor.white.withAlphaComponent(0.3)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "No Studies Yet"
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Import DICOM files to begin\nmedical imaging analysis"
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        emptyStateView.addSubview(iconView)
        emptyStateView.addSubview(titleLabel)
        emptyStateView.addSubview(subtitleLabel)
        
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40),
            
            iconView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])
    }
    
    private func setupCustomTabBar() {
        customTabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customTabBar)
        
        NSLayoutConstraint.activate([
            customTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customTabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            customTabBar.heightAnchor.constraint(equalToConstant: 83)
        ])
        
        customTabBar.onTabSelected = { [weak self] tab in
            self?.handleTabSelection(tab)
        }
    }
    
    private func setupLoadingView() {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.isHidden = true
        view.addSubview(loadingView)
        
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 100),
            loadingView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    // MARK: - Actions
    
    private func setupActions() {
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        sourcesButton.addTarget(self, action: #selector(sourcesTapped), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
    }
    
    @objc private func importTapped() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        present(documentPicker, animated: true)
    }
    
    @objc private func sourcesTapped() {
        // Show sources configuration
        let sourcesVC = SourcesViewController()
        let nav = UINavigationController(rootViewController: sourcesVC)
        present(nav, animated: true)
    }
    
    @objc private func moreTapped() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            let settingsVC = SettingsViewController()
            let nav = UINavigationController(rootViewController: settingsVC)
            self.present(nav, animated: true)
        })
        
        alertController.addAction(UIAlertAction(title: "About", style: .default) { _ in
            // Show about screen
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = moreButton
            popover.sourceRect = moreButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    private func handleTabSelection(_ tab: TabItem) {
        switch tab {
        case .studies:
            // Already on studies
            break
        case .falconSolutions:
            // Navigate to Falcon Solutions
            break
        case .sources:
            sourcesTapped()
        case .settings:
            let settingsVC = SettingsViewController()
            let nav = UINavigationController(rootViewController: settingsVC)
            present(nav, animated: true)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadStudies() {
        showLoading(true)
        
        Task {
            do {
                try await DICOMServiceManager.shared.initialize()
                
                await MainActor.run {
                    if let store = DICOMServiceManager.shared.metadataStore {
                        self.studies = store.getAllStudies()
                        self.groupStudiesByDate()
                        self.tableView.reloadData()
                        self.updateEmptyState()
                        self.updateHeader()
                    }
                    self.showLoading(false)
                }
            } catch {
                await MainActor.run {
                    self.showLoading(false)
                    self.showError(error)
                }
            }
        }
    }
    
    private func groupStudiesByDate() {
        groupedStudies.removeAll()
        sectionTitles.removeAll()
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for study in studies {
            let studyDate = study.studyDate ?? Date()
            let key: String
            
            if calendar.isDateInToday(studyDate) {
                key = "Today"
            } else if calendar.isDateInYesterday(studyDate) {
                key = "Yesterday"
            } else if calendar.isDate(studyDate, equalTo: today, toGranularity: .weekOfYear) {
                key = "This Week"
            } else if calendar.isDate(studyDate, equalTo: today, toGranularity: .month) {
                key = "This Month"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                key = formatter.string(from: studyDate)
            }
            
            if groupedStudies[key] == nil {
                groupedStudies[key] = []
                sectionTitles.append(key)
            }
            groupedStudies[key]?.append(study)
        }
        
        // Sort sections
        sectionTitles.sort { section1, section2 in
            let order = ["Today", "Yesterday", "This Week", "This Month"]
            let index1 = order.firstIndex(of: section1) ?? Int.max
            let index2 = order.firstIndex(of: section2) ?? Int.max
            
            if index1 != Int.max || index2 != Int.max {
                return index1 < index2
            }
            
            // For month-year sections, sort by date
            return section1 > section2
        }
    }
    
    @objc private func studiesDidUpdate() {
        loadStudies()
    }
    
    private func showLoading(_ show: Bool) {
        if show {
            loadingView.isHidden = false
            loadingView.startAnimating()
            tableView.alpha = 0.3
        } else {
            loadingView.stopAnimating()
            loadingView.isHidden = true
            UIView.animate(withDuration: 0.3) {
                self.tableView.alpha = 1.0
            }
        }
    }
    
    private func updateEmptyState() {
        let isEmpty = studies.isEmpty
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }
    
    private func updateHeader() {
        greetingLabel.text = getGreeting()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        dateLabel.text = formatter.string(from: Date())
        
        let totalImages = studies.reduce(0) { $0 + $1.series.reduce(0) { $0 + $1.instances.count } }
        studyCountLabel.text = "\(studies.count) studies • \(totalImages) images"
    }
    
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }
    
    private func updateGradient() {
        gradientLayer.frame = backgroundGradientView.bounds
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Animations
    
    private func performEntranceAnimation() {
        // Initial states
        headerContainerView.alpha = 0
        headerContainerView.transform = CGAffineTransform(translationX: 0, y: -20)
        
        importButton.alpha = 0
        importButton.transform = CGAffineTransform(translationX: -50, y: 0)
        
        sourcesButton.alpha = 0
        sourcesButton.transform = CGAffineTransform(translationX: 0, y: 20)
        
        moreButton.alpha = 0
        moreButton.transform = CGAffineTransform(translationX: 50, y: 0)
        
        tableView.alpha = 0
        
        // Animate
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.headerContainerView.alpha = 1
            self.headerContainerView.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.importButton.alpha = 1
            self.importButton.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.15, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.sourcesButton.alpha = 1
            self.sourcesButton.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.moreButton.alpha = 1
            self.moreButton.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.3) {
            self.tableView.alpha = 1
        }
    }
    
    // MARK: - Night Mode
    
    func nightModeDidChange(_ isNightMode: Bool) {
        UIView.animate(withDuration: 0.3) {
            if isNightMode {
                self.view.backgroundColor = MedicalColorPalette.primaryDarkNight
                self.gradientLayer.colors = [
                    MedicalColorPalette.primaryDarkNight.cgColor,
                    MedicalColorPalette.primaryMediumNight.cgColor
                ]
                self.tableView.backgroundColor = .clear
            } else {
                self.view.backgroundColor = MedicalColorPalette.primaryDark
                self.gradientLayer.colors = [
                    MedicalColorPalette.primaryDark.cgColor,
                    MedicalColorPalette.primaryMedium.cgColor
                ]
                self.tableView.backgroundColor = .clear
            }
        }
        
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension UltraModernHomeViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionTitle = sectionTitles[section]
        return groupedStudies[sectionTitle]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StudyCell", for: indexPath) as! UltraModernStudyTableViewCell
        
        let sectionTitle = sectionTitles[indexPath.section]
        if let studies = groupedStudies[sectionTitle] {
            let study = studies[indexPath.row]
            cell.configure(with: study)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }
}

// MARK: - UITableViewDelegate
extension UltraModernHomeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let sectionTitle = sectionTitles[indexPath.section]
        if let studies = groupedStudies[sectionTitle] {
            let study = studies[indexPath.row]
            
            // Show viewer selector
            let viewerSelector = ViewerSelectorViewController()
            viewerSelector.study = study
            viewerSelector.modalPresentationStyle = .overCurrentContext
            viewerSelector.modalTransitionStyle = .crossDissolve
            
            present(viewerSelector, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = UIColor.white.withAlphaComponent(0.6)
            headerView.textLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension UltraModernHomeViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileImporter = DICOMServiceManager.shared.fileImporter else { return }
        
        showLoading(true)
        
        Task {
            var importedCount = 0
            
            for url in urls {
                do {
                    let _ = try await fileImporter.importFile(from: url)
                    importedCount += 1
                } catch {
                    print("Failed to import file: \(error)")
                }
            }
            
            await MainActor.run {
                self.showLoading(false)
                
                if importedCount > 0 {
                    // Show success message
                    let message = importedCount == 1 ? "1 file imported" : "\(importedCount) files imported"
                    self.showToast(message)
                    
                    // Reload studies
                    self.loadStudies()
                }
            }
        }
    }
    
    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.backgroundColor = MedicalColorPalette.accentPrimary
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = .systemFont(ofSize: 14, weight: .medium)
        toast.layer.cornerRadius = 20
        toast.clipsToBounds = true
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toast)
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            toast.heightAnchor.constraint(equalToConstant: 40),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])
        
        // Add padding
        toast.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
}

// MARK: - Tab Items
enum TabItem {
    case studies
    case falconSolutions
    case sources
    case settings
}