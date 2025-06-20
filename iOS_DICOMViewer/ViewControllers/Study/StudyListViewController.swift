//
//  StudyListViewController.swift
//  iOS_DICOMViewer
//
//  Modern DICOM study management interface
//  Based on medical imaging workflow and HTML template design
//

import UIKit
import UniformTypeIdentifiers

class StudyListViewController: UIViewController {
    
    // MARK: - Properties
    
    private var studies: [DICOMStudy] = []
    private var filteredStudies: [DICOMStudy] = []
    private var searchText: String = ""
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.refreshControl = refreshControl
        return scrollView
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        refreshControl.tintColor = primaryColor
        refreshControl.addTarget(self, action: #selector(refreshStudies), for: .valueChanged)
        return refreshControl
    }()
    
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // Upload Section
    private lazy var uploadSectionView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Search Section
    private lazy var searchContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var searchTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Search recent files..."
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    // Studies Section
    private lazy var studiesTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(StudyTableViewCell.self, forCellReuseIdentifier: StudyTableViewCell.identifier)
        return tableView
    }()
    
    // Empty State View
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupUploadSection()
        setupSearchSection()
        setupStudiesSection()
        setupEmptyState()
        loadStudies()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshStudiesData()
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
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }
    
    private func setupNavigationBar() {
        title = "DICOM Viewer"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Add settings button (matching HTML template)
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsButtonTapped)
        )
        let accentTeal = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0) // #14b8a6
        settingsButton.tintColor = accentTeal
        navigationItem.rightBarButtonItem = settingsButton
    }
    
    private func setupUploadSection() {
        let sectionTitleLabel = createSectionTitle("Upload DICOM Files")
        
        // Upload container (matching HTML template design)
        let uploadContainer = UIView()
        let surfaceDarkSecondary = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 0.5) // #283539/50
        let borderDark = UIColor(red: 59/255, green: 78/255, blue: 84/255, alpha: 1.0) // #3b4e54
        
        uploadContainer.backgroundColor = surfaceDarkSecondary
        uploadContainer.layer.cornerRadius = 12
        uploadContainer.layer.borderWidth = 2
        uploadContainer.layer.borderColor = borderDark.cgColor
        uploadContainer.layer.lineDashPattern = [8, 4] // Dashed border
        uploadContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Upload content stack
        let uploadStackView = UIStackView()
        uploadStackView.axis = .vertical
        uploadStackView.spacing = 12
        uploadStackView.alignment = .center
        uploadStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Medical icon
        let iconLabel = UILabel()
        iconLabel.text = "🏥"
        iconLabel.font = UIFont.systemFont(ofSize: 48)
        
        // Main text
        let mainLabel = UILabel()
        mainLabel.text = "Tap to upload DICOM files"
        mainLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        mainLabel.textColor = UIColor.white
        mainLabel.textAlignment = .center
        
        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Ensure files are in .dcm format or ZIP archives"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        let textSecondary = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0) // #9cb2ba
        subtitleLabel.textColor = textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        // Upload button
        let uploadButton = UIButton(type: .system)
        uploadButton.setTitle("📁 Choose Files", for: .normal)
        uploadButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        uploadButton.setTitleColor(.white, for: .normal)
        let accentTeal = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0) // #14b8a6
        uploadButton.backgroundColor = accentTeal
        uploadButton.layer.cornerRadius = 8
        uploadButton.addTarget(self, action: #selector(uploadButtonTapped), for: .touchUpInside)
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        
        uploadStackView.addArrangedSubview(iconLabel)
        uploadStackView.addArrangedSubview(mainLabel)
        uploadStackView.addArrangedSubview(subtitleLabel)
        uploadStackView.addArrangedSubview(uploadButton)
        
        uploadContainer.addSubview(uploadStackView)
        uploadSectionView.addSubview(sectionTitleLabel)
        uploadSectionView.addSubview(uploadContainer)
        
        NSLayoutConstraint.activate([
            // Section title
            sectionTitleLabel.topAnchor.constraint(equalTo: uploadSectionView.topAnchor),
            sectionTitleLabel.leadingAnchor.constraint(equalTo: uploadSectionView.leadingAnchor),
            sectionTitleLabel.trailingAnchor.constraint(equalTo: uploadSectionView.trailingAnchor),
            
            // Upload container
            uploadContainer.topAnchor.constraint(equalTo: sectionTitleLabel.bottomAnchor, constant: 12),
            uploadContainer.leadingAnchor.constraint(equalTo: uploadSectionView.leadingAnchor),
            uploadContainer.trailingAnchor.constraint(equalTo: uploadSectionView.trailingAnchor),
            uploadContainer.bottomAnchor.constraint(equalTo: uploadSectionView.bottomAnchor),
            
            // Upload stack
            uploadStackView.topAnchor.constraint(equalTo: uploadContainer.topAnchor, constant: 24),
            uploadStackView.leadingAnchor.constraint(equalTo: uploadContainer.leadingAnchor, constant: 24),
            uploadStackView.trailingAnchor.constraint(equalTo: uploadContainer.trailingAnchor, constant: -24),
            uploadStackView.bottomAnchor.constraint(equalTo: uploadContainer.bottomAnchor, constant: -24),
            
            // Upload button
            uploadButton.heightAnchor.constraint(equalToConstant: 44),
            uploadButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
        
        contentStackView.addArrangedSubview(uploadSectionView)
    }
    
    private func setupSearchSection() {
        // Search container matching HTML template
        let searchBackgroundView = UIView()
        let surfaceDarkSecondary = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 1.0) // #283539
        searchBackgroundView.backgroundColor = surfaceDarkSecondary
        searchBackgroundView.layer.cornerRadius = 12
        searchBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        // Search icon
        let searchIconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        let textSecondary = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0) // #9cb2ba
        searchIconView.tintColor = textSecondary
        searchIconView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure text field
        searchTextField.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        searchTextField.textColor = UIColor.white
        searchTextField.backgroundColor = .clear
        searchTextField.borderStyle = .none
        
        // Placeholder color
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search recent files...",
            attributes: [.foregroundColor: textSecondary]
        )
        
        searchBackgroundView.addSubview(searchIconView)
        searchBackgroundView.addSubview(searchTextField)
        searchContainer.addSubview(searchBackgroundView)
        
        NSLayoutConstraint.activate([
            searchBackgroundView.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            searchBackgroundView.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor),
            searchBackgroundView.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor),
            searchBackgroundView.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),
            searchBackgroundView.heightAnchor.constraint(equalToConstant: 48),
            
            searchIconView.leadingAnchor.constraint(equalTo: searchBackgroundView.leadingAnchor, constant: 12),
            searchIconView.centerYAnchor.constraint(equalTo: searchBackgroundView.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 24),
            searchIconView.heightAnchor.constraint(equalToConstant: 24),
            
            searchTextField.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 8),
            searchTextField.trailingAnchor.constraint(equalTo: searchBackgroundView.trailingAnchor, constant: -12),
            searchTextField.topAnchor.constraint(equalTo: searchBackgroundView.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchBackgroundView.bottomAnchor)
        ])
        
        contentStackView.addArrangedSubview(searchContainer)
    }
    
    private func setupStudiesSection() {
        let sectionTitleLabel = createSectionTitle("Recent Files")
        
        let studiesContainerView = UIView()
        studiesContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        studiesContainerView.addSubview(sectionTitleLabel)
        studiesContainerView.addSubview(studiesTableView)
        
        NSLayoutConstraint.activate([
            sectionTitleLabel.topAnchor.constraint(equalTo: studiesContainerView.topAnchor),
            sectionTitleLabel.leadingAnchor.constraint(equalTo: studiesContainerView.leadingAnchor),
            sectionTitleLabel.trailingAnchor.constraint(equalTo: studiesContainerView.trailingAnchor),
            
            studiesTableView.topAnchor.constraint(equalTo: sectionTitleLabel.bottomAnchor, constant: 12),
            studiesTableView.leadingAnchor.constraint(equalTo: studiesContainerView.leadingAnchor),
            studiesTableView.trailingAnchor.constraint(equalTo: studiesContainerView.trailingAnchor),
            studiesTableView.bottomAnchor.constraint(equalTo: studiesContainerView.bottomAnchor),
            studiesTableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300) // Minimum height for iPhone 16 Pro Max
        ])
        
        contentStackView.addArrangedSubview(studiesContainerView)
    }
    
    private func setupEmptyState() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = "📁"
        iconLabel.font = UIFont.systemFont(ofSize: 64)
        
        let titleLabel = UILabel()
        titleLabel.text = "No DICOM Studies"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = UIColor.white
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Upload DICOM files to get started\nwith medical image analysis"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        let textSecondary = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        subtitleLabel.textColor = textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(iconLabel)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        emptyStateView.addSubview(stackView)
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: emptyStateView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: emptyStateView.trailingAnchor, constant: -40),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalTo: view.widthAnchor),
            emptyStateView.heightAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    private func createSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textColor = UIColor.white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    // MARK: - Data Methods
    
    private func loadStudies() {
        studies = DICOMMetadataStore.shared.getAllStudies()
        filterStudies()
        updateUI()
    }
    
    private func refreshStudiesData() {
        loadStudies()
    }
    
    private func filterStudies() {
        if searchText.isEmpty {
            filteredStudies = studies
        } else {
            filteredStudies = studies.filter { study in
                study.patientName.localizedCaseInsensitiveContains(searchText) ||
                study.studyDescription.localizedCaseInsensitiveContains(searchText) ||
                study.patientID.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            self.studiesTableView.reloadData()
            self.emptyStateView.isHidden = !self.filteredStudies.isEmpty
            self.refreshControl.endRefreshing()
        }
    }
    
    // MARK: - Actions
    
    @objc private func refreshStudies() {
        refreshStudiesData()
    }
    
    @objc private func settingsButtonTapped() {
        if let mainVC = findMainViewController() {
            mainVC.showSettingsView()
        }
    }
    
    @objc private func uploadButtonTapped() {
        presentDocumentPicker()
    }
    
    private func presentDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.data,
            UTType.zip,
            UTType(filenameExtension: "dcm") ?? UTType.data,
            UTType(filenameExtension: "dicom") ?? UTType.data
        ], asCopy: true)
        
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        documentPicker.modalPresentationStyle = .pageSheet
        
        present(documentPicker, animated: true)
    }
    
    private func findMainViewController() -> MainViewController? {
        // Find the MainViewController in the view hierarchy
        var currentVC: UIViewController? = self
        while let parent = currentVC?.parent {
            if let mainVC = parent as? MainViewController {
                return mainVC
            }
            currentVC = parent
        }
        
        // Check if it's the root view controller
        if let mainVC = view.window?.rootViewController as? MainViewController {
            return mainVC
        }
        
        return nil
    }
}

// MARK: - UITableView DataSource & Delegate

extension StudyListViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredStudies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StudyTableViewCell.identifier, for: indexPath) as! StudyTableViewCell
        let study = filteredStudies[indexPath.row]
        cell.configure(with: study)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let study = filteredStudies[indexPath.row]
        
        // Show options for viewing the study
        let alert = UIAlertController(
            title: "Open Study",
            message: "Choose how to view this DICOM study",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "2D Viewer", style: .default) { _ in
            if let mainVC = self.findMainViewController() {
                mainVC.showModern2DViewer(for: study)
            }
        })
        
        alert.addAction(UIAlertAction(title: "MPR Viewer", style: .default) { _ in
            if let mainVC = self.findMainViewController() {
                mainVC.showMPRViewer(for: study)
            }
        })
        
        alert.addAction(UIAlertAction(title: "3D & AI Analysis", style: .default) { _ in
            if let mainVC = self.findMainViewController() {
                mainVC.show3DSegmentationViewer(for: study)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView.cellForRow(at: indexPath)
            popover.sourceRect = tableView.cellForRow(at: indexPath)?.bounds ?? .zero
        }
        
        present(alert, animated: true)
    }
}

// MARK: - UITextField Delegate

extension StudyListViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let updatedText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? ""
        searchText = updatedText
        filterStudies()
        updateUI()
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        searchText = ""
        filterStudies()
        updateUI()
        return true
    }
}

// MARK: - UIDocumentPicker Delegate

extension StudyListViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            handleFileImport(url: url)
        }
    }
    
    private func handleFileImport(url: URL) {
        guard let fileImporter = DICOMServiceManager.shared.fileImporter else {
            showError("DICOM services not ready. Please try again.")
            return
        }
        
        do {
            _ = fileImporter.handleIncomingFile(url: url)
            // Refresh studies after import
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshStudiesData()
            }
        } catch {
            showError("Failed to import file: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Import Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}