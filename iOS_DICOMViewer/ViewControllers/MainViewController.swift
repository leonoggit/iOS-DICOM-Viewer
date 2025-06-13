import UIKit
import Combine
import os.log

/// Main view controller that coordinates the entire DICOM viewer
/// Inspired by OHIF's main application structure
class MainViewController: UIViewController {
    
    private let logger = Logger(subsystem: "com.dicomviewer.iOS-DICOMViewer", category: "MainViewController")
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let studyListViewController = StudyListViewController()
    private var viewerViewController: ViewerViewController?
    
    // MARK: - Services
    private var metadataStore: DICOMMetadataStore? {
        return DICOMServiceManager.shared.metadataStore
    }
    private var fileImporter: DICOMFileImporter? {
        return DICOMServiceManager.shared.fileImporter
    }
    private var automaticSegmentationService: AutomaticSegmentationService?
    private var urinaryTractService: UrinaryTractSegmentationService?
    private var coreMLService: CoreMLSegmentationService?
    
    // MARK: - State
    private var currentStudy: DICOMStudy?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UI References
    private var statusLabel: UILabel?
    private var activityIndicator: UIActivityIndicatorView?
    private var welcomeCard: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logger.info("🔄 MainViewController: viewDidLoad started")
        
        setupModernUI()
        setupElegantNavigationBar()
        
        logger.info("✅ MainViewController: Modern UI setup completed")
        
        // Initialize services asynchronously
        initializeDICOMServices()
        
        logger.info("✅ MainViewController: viewDidLoad completed")
    }
    
    private func setupModernUI() {
        // Modern gradient background
        view.backgroundColor = .systemBackground
        setupGradientBackground()
        
        // Setup main content area
        setupContentArea()
        
        // Setup welcome interface
        setupWelcomeInterface()
    }
    
    private func setupGradientBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = [
            UIColor.systemBlue.withAlphaComponent(0.1).cgColor,
            UIColor.systemBackground.cgColor,
            UIColor.systemTeal.withAlphaComponent(0.05).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func setupContentArea() {
        containerView.backgroundColor = .clear
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOpacity = 0.1
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupWelcomeInterface() {
        // Create welcome card
        welcomeCard = UIView()
        welcomeCard!.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        welcomeCard!.layer.cornerRadius = 20
        welcomeCard!.layer.shadowColor = UIColor.black.cgColor
        welcomeCard!.layer.shadowOffset = CGSize(width: 0, height: 8)
        welcomeCard!.layer.shadowRadius = 20
        welcomeCard!.layer.shadowOpacity = 0.15
        welcomeCard!.translatesAutoresizingMaskIntoConstraints = false
        
        // Medical icon
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: "stethoscope.circle.fill")
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "DICOM Viewer Pro"
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Subtitle label
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Professional Medical Imaging"
        subtitleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Status label
        statusLabel = UILabel()
        statusLabel!.text = "Initializing Services..."
        statusLabel!.font = .systemFont(ofSize: 16, weight: .regular)
        statusLabel!.textColor = .systemBlue
        statusLabel!.textAlignment = .center
        statusLabel!.translatesAutoresizingMaskIntoConstraints = false
        
        // Activity indicator
        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator!.color = .systemBlue
        activityIndicator!.startAnimating()
        activityIndicator!.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to welcome card
        welcomeCard!.addSubview(iconImageView)
        welcomeCard!.addSubview(titleLabel)
        welcomeCard!.addSubview(subtitleLabel)
        welcomeCard!.addSubview(statusLabel!)
        welcomeCard!.addSubview(activityIndicator!)
        
        containerView.addSubview(welcomeCard!)
        
        NSLayoutConstraint.activate([
            // Welcome card
            welcomeCard!.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            welcomeCard!.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            welcomeCard!.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            welcomeCard!.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            welcomeCard!.heightAnchor.constraint(equalToConstant: 320),
            
            // Icon
            iconImageView.topAnchor.constraint(equalTo: welcomeCard!.topAnchor, constant: 40),
            iconImageView.centerXAnchor.constraint(equalTo: welcomeCard!.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: welcomeCard!.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: welcomeCard!.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: welcomeCard!.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: welcomeCard!.trailingAnchor, constant: -20),
            
            // Status
            statusLabel!.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            statusLabel!.leadingAnchor.constraint(equalTo: welcomeCard!.leadingAnchor, constant: 20),
            statusLabel!.trailingAnchor.constraint(equalTo: welcomeCard!.trailingAnchor, constant: -20),
            
            // Activity indicator
            activityIndicator!.topAnchor.constraint(equalTo: statusLabel!.bottomAnchor, constant: 16),
            activityIndicator!.centerXAnchor.constraint(equalTo: welcomeCard!.centerXAnchor)
        ])
    }
    
    private func initializeDICOMServices() {
        Task {
            do {
                logger.info("🔄 MainViewController: Initializing DICOM services...")
                try await DICOMServiceManager.shared.initialize()
                
                // Initialize advanced segmentation services
                await initializeSegmentationServices()
                
                await MainActor.run {
                    logger.info("✅ MainViewController: DICOM services initialized successfully")
                    self.updateUIForServicesReady()
                }
            } catch {
                logger.error("❌ MainViewController: Failed to initialize DICOM services: \(error.localizedDescription)")
                await MainActor.run {
                    self.updateUIForServicesError()
                }
            }
        }
    }
    
    private func initializeSegmentationServices() async {
        do {
            // Initialize Metal device
            guard let device = MTLCreateSystemDefaultDevice() else {
                logger.warning("⚠️ Metal device not available - segmentation features will be limited")
                return
            }
            
            logger.info("🔄 Initializing automatic segmentation service...")
            automaticSegmentationService = try AutomaticSegmentationService(device: device)
            
            logger.info("🔄 Initializing urinary tract segmentation service...")
            urinaryTractService = try UrinaryTractSegmentationService(
                device: device
            )
            
            logger.info("🔄 Initializing CoreML segmentation service...")
            coreMLService = try CoreMLSegmentationService(
                device: device,
                urinaryTractService: urinaryTractService!
            )
            
            logger.info("✅ Advanced segmentation services initialized successfully")
            
        } catch {
            logger.error("❌ Failed to initialize segmentation services: \(error.localizedDescription)")
        }
    }
    
    private func updateUIForServicesReady() {
        statusLabel?.text = "Ready for Medical Imaging"
        statusLabel?.textColor = .systemGreen
        activityIndicator?.stopAnimating()
        activityIndicator?.isHidden = true
        
        // Animate transition
        UIView.animate(withDuration: 0.5, delay: 1.0, options: .curveEaseInOut) {
            self.statusLabel?.alpha = 0.0
        } completion: { _ in
            self.transitionToMainInterface()
        }
    }
    
    private func updateUIForServicesError() {
        statusLabel?.text = "Service initialization failed"
        statusLabel?.textColor = .systemRed
        activityIndicator?.stopAnimating()
        activityIndicator?.isHidden = true
    }
    
    private func transitionToMainInterface() {
        // Animate welcome card out
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut) {
            self.welcomeCard?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.welcomeCard?.alpha = 0.0
        } completion: { _ in
            self.welcomeCard?.removeFromSuperview()
            self.showStudyList()
            self.setupObservers()
            self.showDisclaimerIfNeeded()
        }
    }
    
    private func setupElegantNavigationBar() {
        // Modern navigation bar styling
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.largeTitleTextAttributes = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 34, weight: .bold),
            NSAttributedString.Key.foregroundColor: UIColor.label
        ]
        
        // Configure appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.3)
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        
        title = "DICOM Viewer Pro"
        
        // Add elegant buttons later when services are ready
        setupBasicNavigationButtons()
    }
    
    private func setupBasicNavigationButtons() {
        // Import button with elegant styling
        let importButton = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(importButtonTapped)
        )
        importButton.tintColor = .systemBlue
        
        navigationItem.rightBarButtonItem = importButton
    }
    
    private func setupFullUI() {
        // This will be called after services are ready
        setupUI()
        setupNavigationBar()
        setupObservers()
        showDisclaimerIfNeeded()
        refreshContent()
    }
    
    private func refreshContent() {
        // Refresh the study list view once services are ready
        showStudyList()
    }
    
    private func showServiceInitializationError() {
        let alert = UIAlertController(
            title: "Initialization Error",
            message: "Failed to initialize DICOM services. Some features may not work properly.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "DICOM Viewer"
        
        // Setup container view
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Show study list initially
        showStudyList()
    }
    
    private func setupNavigationBar() {
        // Import button
        let importButton = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle"),
            style: .plain,
            target: self,
            action: #selector(importButtonTapped)
        )
        
        // Auto Segmentation button
        let segmentationButton = UIBarButtonItem(
            image: UIImage(systemName: "brain.head.profile"),
            style: .plain,
            target: self,
            action: #selector(segmentationButtonTapped)
        )
        
        // Settings button
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(settingsButtonTapped)
        )
        
        navigationItem.rightBarButtonItems = [settingsButton, segmentationButton, importButton]
        
        // Back button for viewer mode
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        navigationItem.leftBarButtonItem?.isEnabled = false
    }
    
    private func setupObservers() {
        // Listen for study additions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(studyAdded(_:)),
            name: DICOMMetadataStore.studyAddedNotification,
            object: nil
        )
        
        // Listen for import errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(importError(_:)),
            name: NSNotification.Name("DICOMImportError"),
            object: nil
        )
    }
    
    private func setupFileImporter() {
        guard let fileImporter = fileImporter,
              let metadataStore = metadataStore else {
            print("⚠️ Services not ready for file importer setup")
            return
        }
        fileImporter.delegate = metadataStore
    }
    
    // MARK: - View Management
    
    private func showStudyList() {
        // Remove current child view controller
        removeCurrentChildViewController()
        
        // Add study list
        addChild(studyListViewController)
        containerView.addSubview(studyListViewController.view)
        studyListViewController.view.frame = containerView.bounds
        studyListViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        studyListViewController.didMove(toParent: self)
        
        // Note: StudyListViewController delegate not needed in embedded mode
        
        // Update navigation
        navigationItem.leftBarButtonItem?.isEnabled = false
        title = "DICOM Viewer"
    }
    
    private func showViewer(for study: DICOMStudy) {
        currentStudy = study
        
        // Remove current child view controller
        removeCurrentChildViewController()
        
        // Create and add viewer
        viewerViewController = ViewerViewController(study: study)
        guard let viewerVC = viewerViewController else { return }
        
        addChild(viewerVC)
        containerView.addSubview(viewerVC.view)
        viewerVC.view.frame = containerView.bounds
        viewerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewerVC.didMove(toParent: self)
        
        // Update navigation
        navigationItem.leftBarButtonItem?.isEnabled = true
        title = study.studyDescription ?? "Study Viewer"
    }
    
    private func removeCurrentChildViewController() {
        children.forEach { child in
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
    
    // MARK: - Actions
    
    @objc private func importButtonTapped() {
        showImportOptions()
    }
    
    @objc private func settingsButtonTapped() {
        // Create a simple settings view controller
        let settingsVC = UIViewController()
        settingsVC.title = "Settings"
        settingsVC.view.backgroundColor = .systemBackground
        
        let label = UILabel()
        label.text = "Settings coming soon..."
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        settingsVC.view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: settingsVC.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: settingsVC.view.centerYAnchor)
        ])
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
    
    @objc private func segmentationButtonTapped() {
        showAutoSegmentationViewController()
    }
    
    @objc private func backButtonTapped() {
        showStudyList()
    }
    
    // MARK: - Import Options
    
    private func showImportOptions() {
        let alertController = UIAlertController(
            title: "Import DICOM Files",
            message: "Choose import method",
            preferredStyle: .actionSheet
        )
        
        // Files app
        alertController.addAction(UIAlertAction(title: "Browse Files", style: .default) { _ in
            self.showDocumentPicker()
        })
        
        // Sample data (for development)
        #if DEBUG
        alertController.addAction(UIAlertAction(title: "Load Sample Data", style: .default) { _ in
            self.loadSampleData()
        })
        #endif
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alertController.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        
        present(alertController, animated: true)
    }
    
    private func showDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: DICOMFileImporter.supportedTypes,
            asCopy: true
        )
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        present(documentPicker, animated: true)
    }
    
    #if DEBUG
    private func loadSampleData() {
        // Load sample DICOM data for development
        Task {
            await createSampleStudy()
        }
    }
    
    private func createSampleStudy() async {
        // Create sample study for testing
        let study = DICOMStudy(
            studyInstanceUID: "1.2.3.4.5.6.7.8.9.0.1",
            studyDate: "20250609",
            studyDescription: "Sample CT Study",
            patientName: "SAMPLE^PATIENT",
            patientID: "12345"
        )
        
        let series = DICOMSeries(
            seriesInstanceUID: "1.2.3.4.5.6.7.8.9.0.2",
            seriesNumber: 1,
            seriesDescription: "Sample CT Series",
            modality: "CT",
            studyInstanceUID: study.studyInstanceUID
        )
        
        study.addSeries(series)
        
        await MainActor.run {
            metadataStore?.addStudy(study)
        }
    }
    #endif
    
    // MARK: - Disclaimer
    
    private func showDisclaimerIfNeeded() {
        let hasShownDisclaimer = UserDefaults.standard.bool(forKey: "HasShownDisclaimer")
        
        if !hasShownDisclaimer {
            showDisclaimer()
        }
    }
    
    private func showDisclaimer() {
        let alertController = UIAlertController(
            title: "Medical Disclaimer",
            message: """
            ⚠️ IMPORTANT NOTICE ⚠️
            
            This DICOM viewer is for informational and educational purposes only.
            
            • NOT FOR DIAGNOSTIC USE
            • NOT FOR CLINICAL DECISION MAKING
            • NOT CE/FDA APPROVED
            
            Always consult qualified medical professionals for diagnosis and treatment decisions.
            """,
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "I Understand", style: .default) { _ in
            UserDefaults.standard.set(true, forKey: "HasShownDisclaimer")
        })
        
        present(alertController, animated: true)
    }
    
    // MARK: - Notifications
    
    @objc private func studyAdded(_ notification: Notification) {
        DispatchQueue.main.async {
            // Refresh study list if currently showing
            if self.children.first is StudyListViewController {
                // Refresh the study list view
                self.showStudyList()
            }
        }
    }
    
    @objc private func importError(_ notification: Notification) {
        guard let error = notification.userInfo?["error"] as? Error else { return }
        
        DispatchQueue.main.async {
            self.showError(error)
        }
    }
    
    private func showError(_ error: Error) {
        let alertController = UIAlertController(
            title: "Import Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
    
    // MARK: - Navigation
    
    private func navigateToStudyList() {
        let studyListVC = StudyListViewController()
        let navController = UINavigationController(rootViewController: studyListVC)
        
        // Present as full screen
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
}

// MARK: - StudyListViewControllerDelegate
extension MainViewController: StudyListViewControllerDelegate {
    func didSelectStudy(_ study: DICOMStudy) {
        showViewer(for: study)
    }
    
    func didDeleteStudy(_ study: DICOMStudy) {
        // Study deletion is handled by StudyListViewController
    }
}

// MARK: - UIDocumentPickerDelegate  
extension MainViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        // Show progress
        let progressAlert = UIAlertController(
            title: "Importing DICOM Files",
            message: "Please wait...",
            preferredStyle: .alert
        )
        
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressAlert.view.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            progressView.centerXAnchor.constraint(equalTo: progressAlert.view.centerXAnchor),
            progressView.topAnchor.constraint(equalTo: progressAlert.view.topAnchor, constant: 80),
            progressView.widthAnchor.constraint(equalToConstant: 200)
        ])
        
        present(progressAlert, animated: true)
        
        // Import files
        Task {
            await fileImporter?.importMultipleFiles(urls) { progress in
                Task { @MainActor in
                    progressView.progress = Float(progress)
                }
            }
            
            await MainActor.run {
                progressAlert.dismiss(animated: true)
            }
        }
    }
    
    // MARK: - Auto Segmentation
    
    private func showAutoSegmentationViewController() {
        guard let urinaryTractService = urinaryTractService else {
            showSegmentationServiceUnavailable()
            return
        }
        
        let alertController = UIAlertController(
            title: "🧠 Advanced Segmentation",
            message: "Choose segmentation type for your DICOM study:",
            preferredStyle: .actionSheet
        )
        
        // Urinary Tract Segmentation (Main feature)
        alertController.addAction(UIAlertAction(title: "🩿 Urinary Tract Segmentation", style: .default) { _ in
            self.performUrinaryTractSegmentation()
        })
        
        // Individual organ segmentation
        alertController.addAction(UIAlertAction(title: "🩺 Bilateral Kidney Segmentation", style: .default) { _ in
            self.performKidneySegmentation()
        })
        
        // Traditional multi-organ
        alertController.addAction(UIAlertAction(title: "🫁 Multi-Organ Segmentation", style: .default) { _ in
            self.performMultiOrganSegmentation()
        })
        
        // Stone detection
        alertController.addAction(UIAlertAction(title: "💎 Urinary Stone Detection", style: .default) { _ in
            self.performStoneDetection()
        })
        
        // Info
        alertController.addAction(UIAlertAction(title: "ℹ️ Learn More", style: .default) { _ in
            self.showSegmentationInfo()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alertController.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        
        present(alertController, animated: true)
    }
    
    private func showSegmentationServiceUnavailable() {
        let alert = UIAlertController(
            title: "Service Unavailable",
            message: "Segmentation services are not available. This may be due to Metal compatibility issues or initialization failures.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func performUrinaryTractSegmentation() {
        guard let currentStudy = currentStudy,
              let firstSeries = currentStudy.series.first,
              let firstInstance = firstSeries.instances.first else {
            showNoStudySelectedAlert()
            return
        }
        
        // Show progress
        let progressAlert = createProgressAlert(title: "Urinary Tract Segmentation", message: "Analyzing CT images...")
        present(progressAlert, animated: true)
        
        // Setup progress observation
        let progressView = progressAlert.view.subviews.compactMap { $0 as? UIProgressView }.first
        
        // Note: For now, we'll use a simple progress update without Publishers
        // In a future implementation, the segmentation services would have proper Publisher support
        let cancellable: AnyCancellable? = nil
        let phaseCancellable: AnyCancellable? = nil
        
        // Perform segmentation
        urinaryTractService?.performClinicalUrinaryTractSegmentation(
            on: firstInstance,
            parameters: UrinaryTractSegmentationService.ClinicalSegmentationParams(
                contrastEnhanced: true,
                enhancementThreshold: 100.0
            )
        ) { [weak self] result in
            DispatchQueue.main.async {
                cancellable?.cancel()
                phaseCancellable?.cancel()
                progressAlert.dismiss(animated: true) {
                    self?.handleSegmentationResult(result, type: "Urinary Tract")
                }
            }
        }
    }
    
    private func performKidneySegmentation() {
        guard let urinaryTractService = urinaryTractService,
              let currentStudy = currentStudy,
              let firstSeries = currentStudy.series.first,
              let firstInstance = firstSeries.instances.first else {
            showNoStudySelectedAlert()
            return
        }
        
        let progressAlert = createProgressAlert(title: "Kidney Segmentation", message: "Detecting bilateral kidneys...")
        present(progressAlert, animated: true)
        
        urinaryTractService.performClinicalUrinaryTractSegmentation(on: firstInstance) { [weak self] result in
            DispatchQueue.main.async {
                progressAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let segmentationResult):
                        let allSegmentations = segmentationResult.kidneySegmentations + segmentationResult.ureterSegmentations
                        self?.showSegmentationSuccess(segmentations: allSegmentations, type: "Kidney")
                    case .failure(let error):
                        self?.showSegmentationError(error)
                    }
                }
            }
        }
    }
    
    private func performMultiOrganSegmentation() {
        guard let automaticSegmentationService = automaticSegmentationService,
              let currentStudy = currentStudy,
              let firstSeries = currentStudy.series.first,
              let firstInstance = firstSeries.instances.first else {
            showNoStudySelectedAlert()
            return
        }
        
        let progressAlert = createProgressAlert(title: "Multi-Organ Segmentation", message: "Analyzing multiple organs...")
        present(progressAlert, animated: true)
        
        automaticSegmentationService.performMultiOrganSegmentation(
            on: firstInstance,
            targetOrgans: ["liver", "kidneys", "spleen", "pancreas"]
        ) { [weak self] result in
            DispatchQueue.main.async {
                progressAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let segmentation):
                        self?.showSegmentationSuccess(segmentations: [segmentation], type: "Multi-Organ")
                    case .failure(let error):
                        self?.showSegmentationError(error)
                    }
                }
            }
        }
    }
    
    private func performStoneDetection() {
        guard let currentStudy = currentStudy,
              let firstSeries = currentStudy.series.first,
              let firstInstance = firstSeries.instances.first else {
            showNoStudySelectedAlert()
            return
        }
        
        let progressAlert = createProgressAlert(title: "Stone Detection", message: "Scanning for urinary stones...")
        present(progressAlert, animated: true)
        
        // Use stone-specific parameters
        let stoneParams = UrinaryTractSegmentationService.ClinicalSegmentationParams(
            contrastEnhanced: false,  // Better for stone detection
            enhancementThreshold: 75.0
        )
        
        urinaryTractService?.performClinicalUrinaryTractSegmentation(
            on: firstInstance,
            parameters: stoneParams
        ) { [weak self] result in
            DispatchQueue.main.async {
                progressAlert.dismiss(animated: true) {
                    self?.handleSegmentationResult(result, type: "Stone Detection")
                }
            }
        }
    }
    
    // MARK: - Segmentation Result Handling
    
    private func handleSegmentationResult(
        _ result: Result<UrinaryTractSegmentationService.UrinaryTractSegmentationResult, Error>,
        type: String
    ) {
        switch result {
        case .success(let segmentationResult):
            showUrinaryTractSegmentationResults(segmentationResult, type: type)
        case .failure(let error):
            showSegmentationError(error)
        }
    }
    
    private func showUrinaryTractSegmentationResults(
        _ result: UrinaryTractSegmentationService.UrinaryTractSegmentationResult,
        type: String
    ) {
        let message = """
        ✅ \(type) completed successfully!
        
        📊 Results:
        • Processing time: \(String(format: "%.1f", result.processingTime))s
        • Quality score: \(String(format: "%.1f", result.qualityMetrics.overallQualityScore * 100))%
        • Kidneys detected: \(result.kidneySegmentations.count)
        • Ureters found: \(result.ureterSegmentations.count)
        • Stones detected: \(result.stoneSegmentations.count)
        
        📈 Clinical Findings:
        • Left kidney volume: \(String(format: "%.1f", result.clinicalFindings.leftKidneyVolume)) mL
        • Right kidney volume: \(String(format: "%.1f", result.clinicalFindings.rightKidneyVolume)) mL
        • Bladder volume: \(String(format: "%.1f", result.clinicalFindings.bladderVolume)) mL
        
        \(result.qualityMetrics.meetsClinicaStandards ? "✅ Meets clinical standards" : "⚠️ Below clinical threshold")
        """
        
        let alert = UIAlertController(
            title: "🎯 \(type) Results",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Export Report", style: .default) { _ in
            self.exportSegmentationReport(result)
        })
        
        alert.addAction(UIAlertAction(title: "View Segmentation", style: .default) { _ in
            self.viewSegmentationOverlay(result.combinedSegmentation)
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showSegmentationSuccess(segmentations: [DICOMSegmentation], type: String) {
        let alert = UIAlertController(
            title: "✅ \(type) Complete",
            message: "Successfully segmented \(segmentations.count) structure(s). View results in the DICOM viewer.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "View Results", style: .default) { _ in
            if let combined = segmentations.first {
                self.viewSegmentationOverlay(combined)
            }
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showSegmentationError(_ error: Error) {
        let alert = UIAlertController(
            title: "❌ Segmentation Failed",
            message: "Error: \(error.localizedDescription)\n\nPlease ensure you have selected a valid CT study with proper DICOM metadata.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showNoStudySelectedAlert() {
        let alert = UIAlertController(
            title: "No Study Selected",
            message: "Please select a DICOM study first before performing segmentation.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func createProgressAlert(title: String, message: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            progressView.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            progressView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 80),
            progressView.widthAnchor.constraint(equalToConstant: 220)
        ])
        
        return alert
    }
    
    private func exportSegmentationReport(_ result: UrinaryTractSegmentationService.UrinaryTractSegmentationResult) {
        guard let data = urinaryTractService?.exportClinicalReport(from: result, format: .json) else {
            showError(NSError(domain: "Export", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to export report"]))
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(activityVC, animated: true)
    }
    
    private func viewSegmentationOverlay(_ segmentation: DICOMSegmentation) {
        // This would integrate with the viewer to show segmentation overlay
        // For now, show a placeholder
        let alert = UIAlertController(
            title: "Segmentation Viewer",
            message: "Segmentation overlay viewing will be integrated with the DICOM viewer in the next update.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showSegmentationInfo() {
        let infoAlert = UIAlertController(
            title: "Segmentation Capabilities",
            message: """
            🫁 Lung Segmentation:
            • Automatic lung parenchyma detection
            • Airway tree extraction
            • Vessel segmentation within lungs
            
            🦴 Bone Analysis:
            • Cortical vs trabecular bone separation
            • Automatic bone density analysis
            
            🩸 Vessel Enhancement:
            • Contrast-enhanced vessel detection
            • 3D vascular tree reconstruction
            
            🎯 Multi-Organ:
            • Liver, kidney, spleen detection
            • Customizable tissue thresholds
            • Real-time preview
            """,
            preferredStyle: .alert
        )
        
        infoAlert.addAction(UIAlertAction(title: "Awesome!", style: .default))
        present(infoAlert, animated: true)
    }
}
