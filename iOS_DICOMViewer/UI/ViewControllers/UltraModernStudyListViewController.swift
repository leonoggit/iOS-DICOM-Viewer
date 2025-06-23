//
//  UltraModernStudyListViewController.swift
//  iOS_DICOMViewer
//
//  Ultra-sophisticated study list with wow-factor design
//

import UIKit
import SwiftUI

class UltraModernStudyListViewController: UIViewController, NightModeObserver {
    
    // MARK: - UI Components
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Animated gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = MedicalColorPalette.primaryGradient
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.addSublayer(gradientLayer)
        
        // Animated gradient shift
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = MedicalColorPalette.primaryGradient
        animation.toValue = MedicalColorPalette.primaryGradient.reversed()
        animation.duration = 10.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "gradientShift")
        
        return view
    }()
    
    private lazy var headerView: GlassMorphismView = {
        let view = GlassMorphismView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.glassIntensity = 0.8
        return view
    }()
    
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search patients, studies, or modalities..."
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = MedicalColorPalette.accentPrimary
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Custom styling
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = MedicalColorPalette.primaryDark.withAlphaComponent(0.3)
            textField.textColor = .white
            textField.font = MedicalTypography.bodyMedium
            
            if let placeholderLabel = textField.value(forKey: "placeholderLabel") as? UILabel {
                placeholderLabel.textColor = MedicalColorPalette.primaryLight
            }
        }
        
        return searchBar
    }()
    
    private lazy var filterChips: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(FilterChipCell.self, forCellWithReuseIdentifier: "FilterChip")
        
        return collectionView
    }()
    
    private lazy var studyCollectionView: UICollectionView = {
        let layout = createAdvancedLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(UltraModernStudyCell.self, forCellWithReuseIdentifier: "StudyCell")
        collectionView.register(StudyHeaderView.self, 
                              forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                              withReuseIdentifier: "Header")
        
        return collectionView
    }()
    
    private lazy var floatingActionMenu: FloatingActionMenu = {
        let menu = FloatingActionMenu()
        menu.translatesAutoresizingMaskIntoConstraints = false
        menu.menuItems = [
            ("square.and.arrow.down", { [weak self] in self?.importStudies() }),
            ("brain", { [weak self] in self?.showAIAnalysis() }),
            ("chart.line.uptrend.xyaxis", { [weak self] in self?.showStatistics() }),
            ("gearshape", { [weak self] in self?.showSettings() })
        ]
        return menu
    }()
    
    private lazy var loadingIndicator: QuantumLoadingIndicator = {
        let indicator = QuantumLoadingIndicator()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isHidden = true
        return indicator
    }()
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // DNA Helix animation
        let dnaHelix = DNAHelixLoadingView()
        dnaHelix.translatesAutoresizingMaskIntoConstraints = false
        
        // Empty state label
        let label = UILabel()
        label.text = "No medical studies found"
        label.font = MedicalTypography.headlineLarge
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Subtitle
        let subtitle = UILabel()
        subtitle.text = "Import DICOM files to begin advanced medical imaging"
        subtitle.font = MedicalTypography.bodyMedium
        subtitle.textColor = MedicalColorPalette.primaryLight
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(dnaHelix)
        view.addSubview(label)
        view.addSubview(subtitle)
        
        NSLayoutConstraint.activate([
            dnaHelix.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dnaHelix.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            dnaHelix.widthAnchor.constraint(equalToConstant: 200),
            dnaHelix.heightAnchor.constraint(equalToConstant: 100),
            
            label.topAnchor.constraint(equalTo: dnaHelix.bottomAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            subtitle.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            subtitle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
        
        dnaHelix.startAnimating()
        
        return view
    }()
    
    // Night mode toggle
    private let nightModeToggle = NightModeToggle()
    
    // Data
    private var studies: [DICOMStudy] = []
    private var filteredStudies: [DICOMStudy] = []
    private var selectedFilters: Set<String> = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadStudies()
        setupNotifications()
        
        // Setup night mode
        NightModeManager.shared.addObserver(self)
        nightModeDidChange(NightModeManager.shared.isNightMode)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Add entrance animation
        performEntranceAnimation()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update gradient frame
        if let gradientLayer = backgroundView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = backgroundView.bounds
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = MedicalColorPalette.primaryDark
        
        // Add subviews
        view.addSubview(backgroundView)
        view.addSubview(headerView)
        headerView.addSubview(searchBar)
        headerView.addSubview(filterChips)
        view.addSubview(studyCollectionView)
        view.addSubview(floatingActionMenu)
        view.addSubview(loadingIndicator)
        view.addSubview(emptyStateView)
        
        // Setup delegates
        filterChips.delegate = self
        filterChips.dataSource = self
        searchBar.delegate = self
        
        NSLayoutConstraint.activate([
            // Background
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Header
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 120),
            
            // Search bar
            searchBar.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            searchBar.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            // Filter chips
            filterChips.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 12),
            filterChips.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            filterChips.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            filterChips.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            filterChips.heightAnchor.constraint(equalToConstant: 36),
            
            // Study collection
            studyCollectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            studyCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            studyCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            studyCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Floating action menu
            floatingActionMenu.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            floatingActionMenu.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            floatingActionMenu.widthAnchor.constraint(equalToConstant: 60),
            floatingActionMenu.heightAnchor.constraint(equalToConstant: 60),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 200),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 200),
            
            // Empty state
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -64),
            emptyStateView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        updateEmptyState()
        
        // Add night mode toggle
        nightModeToggle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nightModeToggle)
        
        NSLayoutConstraint.activate([
            nightModeToggle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            nightModeToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nightModeToggle.widthAnchor.constraint(equalToConstant: 60),
            nightModeToggle.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func setupNavigationBar() {
        title = "Medical Studies"
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: MedicalTypography.displayMedium
        ]
        
        navigationController?.navigationBar.standardAppearance = {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            return appearance
        }()
        
        // Add neural network visualization to navigation
        let neuralNetworkButton = UIBarButtonItem(
            image: UIImage(systemName: "brain.head.profile"),
            style: .plain,
            target: self,
            action: #selector(showNeuralNetwork)
        )
        neuralNetworkButton.tintColor = MedicalColorPalette.accentPrimary
        
        navigationItem.rightBarButtonItem = neuralNetworkButton
    }
    
    private func createAdvancedLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            // Dynamic layout based on content
            let itemCount = self?.filteredStudies.count ?? 0
            
            if itemCount == 0 {
                return self?.createEmptySection()
            } else if itemCount < 4 {
                return self?.createListSection()
            } else {
                return self?.createGridSection()
            }
        }
        
        // Add layout animation
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 16
        layout.configuration = config
        
        return layout
    }
    
    private func createListSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(200)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(200)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        
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
    
    private func createGridSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(250)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 8, bottom: 16, trailing: 8)
        
        // Add decorative background
        section.decorationItems = [
            NSCollectionLayoutDecorationItem.background(elementKind: "SectionBackground")
        ]
        
        return section
    }
    
    private func createEmptySection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(0)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        
        return NSCollectionLayoutSection(group: group)
    }
    
    // MARK: - Data Loading
    
    private func loadStudies() {
        showLoading(true)
        
        // Simulate loading with animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showLoading(false)
            
            // Load from metadata store
            if let store = DICOMServiceManager.shared.metadataStore {
                self?.studies = store.getAllStudies()
                self?.filteredStudies = self?.studies ?? []
                self?.studyCollectionView.reloadData()
                self?.updateEmptyState()
            }
        }
    }
    
    private func showLoading(_ show: Bool) {
        if show {
            loadingIndicator.isHidden = false
            loadingIndicator.startAnimating()
            studyCollectionView.alpha = 0.3
        } else {
            loadingIndicator.stopAnimating()
            loadingIndicator.isHidden = true
            
            UIView.animate(withDuration: 0.3) {
                self.studyCollectionView.alpha = 1.0
            }
        }
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !filteredStudies.isEmpty
        studyCollectionView.isHidden = filteredStudies.isEmpty
    }
    
    // MARK: - Animations
    
    private func performEntranceAnimation() {
        // Animate header
        headerView.transform = CGAffineTransform(translationX: 0, y: -120)
        
        // Animate collection view
        studyCollectionView.transform = CGAffineTransform(translationX: 0, y: 50)
        studyCollectionView.alpha = 0
        
        // Animate floating menu
        floatingActionMenu.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [],
            animations: {
                self.headerView.transform = .identity
                self.studyCollectionView.transform = .identity
                self.studyCollectionView.alpha = 1
                self.floatingActionMenu.transform = .identity
            }
        )
    }
    
    // MARK: - Actions
    
    @objc private func showNeuralNetwork() {
        let neuralNetworkVC = NeuralNetworkViewController()
        let navController = UINavigationController(rootViewController: neuralNetworkVC)
        navController.modalPresentationStyle = .pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(navController, animated: true)
    }
    
    private func importStudies() {
        // Show import UI with particle effects
        let importVC = ImportStudiesViewController()
        let navController = UINavigationController(rootViewController: importVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func showAIAnalysis() {
        // Show AI analysis dashboard
        guard #available(iOS 26.0, *) else { return }
        
        let aiDashboard = AIAnalysisDashboardViewController()
        navigationController?.pushViewController(aiDashboard, animated: true)
    }
    
    private func showStatistics() {
        // Show statistics view
        let statsVC = StatisticsViewController()
        navigationController?.pushViewController(statsVC, animated: true)
    }
    
    private func showSettings() {
        // Show settings
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(studiesDidUpdate),
            name: DICOMMetadataStore.studyAddedNotification,
            object: nil
        )
    }
    
    @objc private func studiesDidUpdate() {
        loadStudies()
        
        // Show success particle effect
        let particleView = ParticleEffectView(frame: view.bounds)
        view.addSubview(particleView)
        particleView.startParticleEffect(type: .success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            particleView.stopParticleEffect()
            particleView.removeFromSuperview()
        }
    }
}

// MARK: - UICollectionViewDataSource
extension UltraModernStudyListViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return collectionView == studyCollectionView ? 1 : 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == filterChips {
            return FilterType.allCases.count
        } else {
            return filteredStudies.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == filterChips {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterChip", for: indexPath) as! FilterChipCell
            let filter = FilterType.allCases[indexPath.item]
            cell.configure(with: filter, isSelected: selectedFilters.contains(filter.rawValue))
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StudyCell", for: indexPath) as! UltraModernStudyCell
            let study = filteredStudies[indexPath.item]
            cell.configure(with: study)
            
            // Add entrance animation
            cell.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            cell.alpha = 0
            
            UIView.animate(
                withDuration: 0.5,
                delay: Double(indexPath.item) * 0.05,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [],
                animations: {
                    cell.transform = .identity
                    cell.alpha = 1
                }
            )
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader && collectionView == studyCollectionView {
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "Header",
                for: indexPath
            ) as! StudyHeaderView
            
            header.configure(title: "Recent Studies", count: filteredStudies.count)
            return header
        }
        return UICollectionReusableView()
    }
}

// MARK: - UICollectionViewDelegate
extension UltraModernStudyListViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == filterChips {
            let filter = FilterType.allCases[indexPath.item]
            
            if selectedFilters.contains(filter.rawValue) {
                selectedFilters.remove(filter.rawValue)
            } else {
                selectedFilters.insert(filter.rawValue)
            }
            
            filterChips.reloadItems(at: [indexPath])
            applyFilters()
            
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
        } else {
            let study = filteredStudies[indexPath.item]
            
            // Create viewer selection with 3D flip animation
            let viewerSelector = ViewerSelectorViewController()
            viewerSelector.study = study
            viewerSelector.modalPresentationStyle = .overCurrentContext
            viewerSelector.modalTransitionStyle = .crossDissolve
            
            present(viewerSelector, animated: true)
        }
    }
    
    private func applyFilters() {
        if selectedFilters.isEmpty {
            filteredStudies = studies
        } else {
            filteredStudies = studies.filter { study in
                // Apply filter logic based on selected filters
                return true // Placeholder
            }
        }
        
        studyCollectionView.reloadData()
        updateEmptyState()
    }
}

// MARK: - UISearchBarDelegate
extension UltraModernStudyListViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredStudies = selectedFilters.isEmpty ? studies : applyFiltersToStudies(studies)
        } else {
            filteredStudies = studies.filter { study in
                let searchLower = searchText.lowercased()
                return (study.patientName?.lowercased().contains(searchLower) ?? false) ||
                       (study.studyDescription?.lowercased().contains(searchLower) ?? false) ||
                       (study.series.first?.modality?.lowercased().contains(searchLower) ?? false)
            }
            
            if !selectedFilters.isEmpty {
                filteredStudies = applyFiltersToStudies(filteredStudies)
            }
        }
        
        studyCollectionView.reloadData()
        updateEmptyState()
    }
    
    private func applyFiltersToStudies(_ studies: [DICOMStudy]) -> [DICOMStudy] {
        // Apply selected filters
        return studies // Placeholder
    }
}

// MARK: - Supporting Types
enum FilterType: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case urgent = "Urgent"
    case ct = "CT"
    case mri = "MRI"
    case xray = "X-Ray"
    case unread = "Unread"
}

// MARK: - Filter Chip Cell
class FilterChipCell: UICollectionViewCell {
    
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    private func setupCell() {
        contentView.backgroundColor = MedicalColorPalette.primaryMedium
        contentView.layer.cornerRadius = 18
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = MedicalColorPalette.primaryLight.withAlphaComponent(0.3).cgColor
        
        label.font = MedicalTypography.bodySmall
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with filter: FilterType, isSelected: Bool) {
        label.text = filter.rawValue
        
        if isSelected {
            contentView.backgroundColor = MedicalColorPalette.accentPrimary
            contentView.layer.borderColor = MedicalColorPalette.accentPrimary.cgColor
        } else {
            contentView.backgroundColor = MedicalColorPalette.primaryMedium
            contentView.layer.borderColor = MedicalColorPalette.primaryLight.withAlphaComponent(0.3).cgColor
        }
    }
}

// MARK: - Night Mode
extension UltraModernStudyListViewController {
    func nightModeDidChange(_ isNightMode: Bool) {
        UIView.animate(withDuration: 0.3) {
            if isNightMode {
                self.view.backgroundColor = MedicalColorPalette.primaryDarkNight
                self.headerView.glassColor = UIColor.white.withAlphaComponent(0.05)
                
                // Update gradient
                if let gradientLayer = self.backgroundView.layer.sublayers?.first as? CAGradientLayer {
                    gradientLayer.colors = [
                        MedicalColorPalette.primaryDarkNight.cgColor,
                        MedicalColorPalette.primaryMediumNight.cgColor
                    ]
                }
                
                // Update search bar
                if let textField = self.searchBar.value(forKey: "searchField") as? UITextField {
                    textField.backgroundColor = MedicalColorPalette.primaryMediumNight.withAlphaComponent(0.5)
                    textField.textColor = MedicalColorPalette.textPrimaryNight
                }
                
            } else {
                self.view.backgroundColor = MedicalColorPalette.primaryDark
                self.headerView.glassColor = UIColor.white.withAlphaComponent(0.1)
                
                // Update gradient
                if let gradientLayer = self.backgroundView.layer.sublayers?.first as? CAGradientLayer {
                    gradientLayer.colors = MedicalColorPalette.primaryGradient
                }
                
                // Update search bar
                if let textField = self.searchBar.value(forKey: "searchField") as? UITextField {
                    textField.backgroundColor = MedicalColorPalette.primaryDark.withAlphaComponent(0.3)
                    textField.textColor = .white
                }
            }
            
            // Update collection view
            self.studyCollectionView.reloadData()
        }
    }
}
EOF < /dev/null