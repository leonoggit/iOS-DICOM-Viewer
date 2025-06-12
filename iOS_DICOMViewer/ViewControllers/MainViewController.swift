import UIKit

/// Main view controller that coordinates the entire DICOM viewer
/// Inspired by OHIF's main application structure
class MainViewController: UIViewController {
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let studyListViewController = StudyListViewController()
    private var viewerViewController: ViewerViewController?
    
    // MARK: - Services
    private let metadataStore = DICOMServiceManager.shared.metadataStore!
    private let fileImporter = DICOMServiceManager.shared.fileImporter!
    
    // MARK: - State
    private var currentStudy: DICOMStudy?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupObservers()
        setupFileImporter()
        
        // Show disclaimer on first launch
        showDisclaimerIfNeeded()
        
        // Create sample data for testing
        Task {
            do {
                try await fileImporter.createSampleData()
            } catch {
                print("Failed to create sample data: \(error)")
            }
        }
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
        
        // Auto-navigate to dedicated study list view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.navigateToStudyList()
        }
    }
    
    private func setupNavigationBar() {
        // Import button
        let importButton = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle"),
            style: .plain,
            target: self,
            action: #selector(importButtonTapped)
        )
        
        // Settings button
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(settingsButtonTapped)
        )
        
        navigationItem.rightBarButtonItems = [settingsButton, importButton]
        
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
        
        // Setup delegate
        studyListViewController.delegate = self
        
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
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
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
            metadataStore.addStudy(study)
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
                self.studyListViewController.refreshData()
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
}

// MARK: - Navigation
    
private func navigateToStudyList() {
    let studyListVC = StudyListViewController()
    let navController = UINavigationController(rootViewController: studyListVC)
    
    // Present as full screen
    navController.modalPresentationStyle = .fullScreen
    present(navController, animated: true)
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
            await fileImporter.importMultipleFiles(urls) { progress in
                Task { @MainActor in
                    progressView.progress = Float(progress)
                }
            }
            
            await MainActor.run {
                progressAlert.dismiss(animated: true)
            }
        }
    }
}
