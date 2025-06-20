//
//  StudyListViewController.swift
//  iOS_DICOMViewer
//
//  Created on 6/9/25.
//

import UIKit

class StudyListViewController: UIViewController {
    
    // MARK: - Properties
    private let complianceManager = ClinicalComplianceManager.shared
    
    // MARK: - UI Components
    private lazy var collectionView: UICollectionView = {
        let layout = createModernLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.delegate = self
        collection.dataSource = self
        collection.backgroundColor = .clear
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.register(ModernStudyCell.self, forCellWithReuseIdentifier: ModernStudyCell.identifier)
        collection.register(StudyHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: StudyHeaderView.identifier)
        collection.showsVerticalScrollIndicator = false
        return collection
    }()
    
    private func createModernLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            // Create item - increased height for thumbnail images
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(220)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            
            // Create group
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(220)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            // Create section
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 16
            section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            
            // Add header
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(60)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            
            return section
        }
        return layout
    }
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Modern empty state card
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        cardView.layer.cornerRadius = 24
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 8)
        cardView.layer.shadowRadius = 16
        cardView.layer.shadowOpacity = 0.1
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        // Medical icon with background
        let iconBackground = UIView()
        iconBackground.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        iconBackground.layer.cornerRadius = 40
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView(image: UIImage(systemName: "heart.text.square.fill"))
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title and subtitle
        let titleLabel = UILabel()
        titleLabel.text = "No Medical Studies"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Import DICOM files to begin medical imaging analysis"
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Action button
        let actionButton = UIButton(type: .system)
        actionButton.setTitle("Import Studies", for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        actionButton.backgroundColor = .systemBlue
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 12
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.addTarget(self, action: #selector(importFiles), for: .touchUpInside)
        
        // Assembly
        iconBackground.addSubview(imageView)
        cardView.addSubview(iconBackground)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(actionButton)
        view.addSubview(cardView)
        
        NSLayoutConstraint.activate([
            // Card view
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            // Icon background
            iconBackground.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 40),
            iconBackground.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconBackground.widthAnchor.constraint(equalToConstant: 80),
            iconBackground.heightAnchor.constraint(equalToConstant: 80),
            
            // Icon
            imageView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconBackground.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            
            // Action button
            actionButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            actionButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 160),
            actionButton.heightAnchor.constraint(equalToConstant: 48),
            actionButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40)
        ])
        
        return view
    }()
    
    // MARK: - Properties
    private var studies: [DICOMStudy] = []
    private var metadataStore: DICOMMetadataStore? {
        return DICOMServiceManager.shared.metadataStore
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📺 StudyListViewController: viewDidLoad() called")
        setupModernUI()
        setupElegantNavigationBar()
        loadStudies()
        
        // Listen for new studies
        print("📻 StudyListViewController: Setting up notification observers")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(studiesDidUpdate),
            name: DICOMMetadataStore.studyAddedNotification,
            object: nil
        )
        
        // Listen for metadata updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(studiesDidUpdate),
            name: DICOMMetadataStore.metadataUpdatedNotification,
            object: nil
        )
        print("📻 StudyListViewController: Notification observers set up for: studyAdded and metadataUpdated")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("👁️ StudyListViewController: viewDidAppear - forcing data reload")
        loadStudies()
    }
    
    private func setupModernUI() {
        view.backgroundColor = .systemGroupedBackground
        
        // Setup gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = [
            UIColor.systemBlue.withAlphaComponent(0.05).cgColor,
            UIColor.systemBackground.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Add collection view
        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        updateEmptyState()
    }
    
    private func setupElegantNavigationBar() {
        title = "Medical Studies"
        
        // Add modern search and filter buttons
        let searchButton = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(searchButtonTapped)
        )
        
        let filterButton = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(filterButtonTapped)
        )
        
        navigationItem.rightBarButtonItems = [filterButton, searchButton]
        
        // Style buttons
        searchButton.tintColor = .systemBlue
        filterButton.tintColor = .systemBlue
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Data Loading
    func loadStudies() {
        print("📚 StudyListViewController: loadStudies() called")
        
        // Get metadata store and check its state
        guard let store = metadataStore else {
            print("❌ StudyListViewController: metadataStore is nil!")
            return
        }
        
        let loadedStudies = store.getAllStudies()
        print("📚 StudyListViewController: Metadata store returned \(loadedStudies.count) studies")
        
        // Get store statistics for debugging
        let stats = store.getStatistics()
        print("📊 StudyListViewController: Store stats - Studies: \(stats.studies), Series: \(stats.series), Instances: \(stats.instances)")
        
        studies = loadedStudies
        
        // Log each study for debugging
        for (index, study) in studies.enumerated() {
            print("  📖 Study \(index + 1): \(study.patientName ?? "Unknown") - \(study.studyDescription ?? "No description") [UID: \(study.studyInstanceUID)]")
            print("    Series count: \(study.series.count)")
        }
        
        print("🔄 StudyListViewController: About to reload UI with \(self.studies.count) studies")
        
        DispatchQueue.main.async {
            print("🔄 StudyListViewController: On main thread - reloading collection view")
            self.collectionView.reloadData()
            self.updateEmptyState()
            print("✅ StudyListViewController: Collection view reloaded and empty state updated")
        }
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !studies.isEmpty
        collectionView.isHidden = studies.isEmpty
    }
    
    // MARK: - Actions
    @objc private func searchButtonTapped() {
        // Implement search functionality
        let alert = UIAlertController(title: "Search", message: "Search functionality coming soon", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func filterButtonTapped() {
        // Implement filter functionality
        let alert = UIAlertController(title: "Filter", message: "Filter functionality coming soon", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func studiesDidUpdate() {
        print("🔔 StudyListViewController: Received studiesDidUpdate notification")
        print("🔔 StudyListViewController: Current thread: \(Thread.current)")
        print("🔔 StudyListViewController: Is main thread: \(Thread.isMainThread)")
        
        DispatchQueue.main.async {
            print("🔄 StudyListViewController: Executing loadStudies on main thread")
            print("🔄 StudyListViewController: Current studies count before load: \(self.studies.count)")
            
            self.loadStudies()
            
            print("🔄 StudyListViewController: Current studies count after load: \(self.studies.count)")
            
            // Force complete UI refresh
            print("🔄 StudyListViewController: Forcing complete UI refresh")
            self.updateEmptyState()
            
            // Check if collection view is visible
            print("🔄 StudyListViewController: CollectionView isHidden: \(self.collectionView.isHidden)")
            print("🔄 StudyListViewController: EmptyStateView isHidden: \(self.emptyStateView.isHidden)")
            
            self.collectionView.reloadData()
            
            // Force layout update
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            
            // Additional UI refresh attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔄 StudyListViewController: Secondary UI refresh attempt")
                self.collectionView.reloadData()
                self.updateEmptyState()
            }
            
            print("✅ StudyListViewController: Complete UI refresh finished")
        }
    }
    
    // MARK: - File Import
    @objc private func importFiles() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        present(documentPicker, animated: true)
    }
}

// MARK: - UICollectionViewDataSource
extension StudyListViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return studies.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ModernStudyCell.identifier, for: indexPath) as? ModernStudyCell else {
            return UICollectionViewCell()
        }
        
        let study = studies[indexPath.item]
        cell.configure(with: study)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: StudyHeaderView.identifier, for: indexPath) as? StudyHeaderView else {
            return UICollectionReusableView()
        }
        
        let studyCount = studies.count
        let title = studyCount == 0 ? "No Studies" : "Medical Studies"
        header.configure(title: title, count: studyCount)
        
        return header
    }
}

// MARK: - UICollectionViewDelegate
extension StudyListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let study = studies[indexPath.item]
        
        // Log patient data access for audit compliance
        complianceManager.logPatientDataAccess(
            patientID: study.patientID ?? "UNKNOWN",
            studyUID: study.studyInstanceUID,
            action: .view
        )
        
        // Add haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.impactOccurred()
        
        let viewerVC = ViewerViewController(study: study)
        navigationController?.pushViewController(viewerVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let study = studies[indexPath.item]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let deleteAction = UIAction(
                title: "Delete Study",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                self.showDeleteConfirmation(for: study, at: indexPath)
            }
            
            let infoAction = UIAction(
                title: "Study Info",
                image: UIImage(systemName: "info.circle")
            ) { _ in
                self.showStudyInfo(for: study)
            }
            
            return UIMenu(title: "", children: [infoAction, deleteAction])
        }
    }
    
    private func showDeleteConfirmation(for study: DICOMStudy, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Delete Study",
            message: "Are you sure you want to delete this study? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.metadataStore?.removeStudy(byUID: study.studyInstanceUID)
            self.studies.remove(at: indexPath.item)
            self.collectionView.deleteItems(at: [indexPath])
            self.updateEmptyState()
        })
        
        present(alert, animated: true)
    }
    
    private func showStudyInfo(for study: DICOMStudy) {
        let message = """
        Patient: \(study.patientName ?? "Unknown")
        Study Date: \(study.studyDate?.description ?? "Unknown")
        Modality: \(study.series.first?.modality ?? "Unknown")
        Series Count: \(study.series.count)
        Study UID: \(study.studyInstanceUID)
        """
        
        let alert = UIAlertController(title: "Study Information", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate
extension StudyListViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("📁 StudyListViewController: Document picker selected \(urls.count) files")
        
        Task {
            guard let fileImporter = DICOMServiceManager.shared.fileImporter else {
                print("❌ StudyListViewController: File importer not available")
                await MainActor.run {
                    self.showError(NSError(domain: "DICOMViewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "File importer not available"]))
                }
                return
            }
            
            print("🚀 StudyListViewController: Starting import of \(urls.count) files")
            await fileImporter.importMultipleFiles(urls) { progress in
                print("📊 Import progress: \(Int(progress * 100))%")
            }
            print("✅ StudyListViewController: Import completed successfully")
        }
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Import Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - StudyListViewControllerDelegate
protocol StudyListViewControllerDelegate: AnyObject {
    func didSelectStudy(_ study: DICOMStudy)
    func didDeleteStudy(_ study: DICOMStudy)
}


// MARK: - Notifications
// Notification names are now defined in DICOMMetadataStore
