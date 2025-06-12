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
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.delegate = self
        table.dataSource = self
        table.register(StudyTableViewCell.self, forCellReuseIdentifier: StudyTableViewCell.identifier)
        table.separatorStyle = .singleLine
        table.backgroundColor = .systemGroupedBackground
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView(image: UIImage(systemName: "doc.text.image"))
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray3
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "No DICOM Studies"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .systemGray2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let sublabel = UILabel()
        sublabel.text = "Import DICOM files to get started"
        sublabel.font = .systemFont(ofSize: 14)
        sublabel.textColor = .systemGray3
        sublabel.textAlignment = .center
        sublabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(imageView)
        view.addSubview(label)
        view.addSubview(sublabel)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            sublabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            sublabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sublabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        return view
    }()
    
    // MARK: - Properties
    private var studies: [DICOMStudy] = []
    private let metadataStore = DICOMServiceManager.shared.metadataStore
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadStudies()
        
        // Listen for new studies
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(studiesDidUpdate),
            name: .studiesDidUpdate,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        updateEmptyState()
    }
    
    private func setupNavigationBar() {
        title = "DICOM Studies"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let importButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(importFiles)
        )
        navigationItem.rightBarButtonItem = importButton
    }
    
    // MARK: - Data Loading
    private func loadStudies() {
        studies = metadataStore?.getAllStudies() ?? []
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.updateEmptyState()
        }
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !studies.isEmpty
        tableView.isHidden = studies.isEmpty
    }
    
    // MARK: - Actions
    @objc private func importFiles() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        present(documentPicker, animated: true)
    }
    
    @objc private func studiesDidUpdate() {
        loadStudies()
    }
}

// MARK: - UITableViewDataSource
extension StudyListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return studies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: StudyTableViewCell.identifier, for: indexPath) as? StudyTableViewCell else {
            return UITableViewCell()
        }
        
        let study = studies[indexPath.row]
        cell.configure(with: study)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension StudyListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let study = studies[indexPath.row]
        
        // Log patient data access for audit compliance
        complianceManager.logPatientDataAccess(
            patientID: study.patientID ?? "UNKNOWN",
            studyUID: study.studyInstanceUID,
            action: .view
        )
        
        let viewerVC = ViewerViewController(study: study)
        navigationController?.pushViewController(viewerVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let study = studies[indexPath.row]
            
            let alert = UIAlertController(
                title: "Delete Study",
                message: "Are you sure you want to delete this study? This action cannot be undone.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                self.metadataStore?.removeStudy(byUID: study.studyInstanceUID)
                self.studies.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
                self.updateEmptyState()
            })
            
            present(alert, animated: true)
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension StudyListViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Task {
            do {
                try await DICOMServiceManager.shared.fileImporter?.importMultipleFiles(urls, 
                                                                                      progressHandler: { _ in })
            } catch {
                DispatchQueue.main.async {
                    self.showError(error)
                }
            }
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

// MARK: - StudyTableViewCell
class StudyTableViewCell: UITableViewCell {
    static let identifier = "StudyTableViewCell"
    
    private let studyLabel = UILabel()
    private let patientLabel = UILabel()
    private let dateLabel = UILabel()
    private let seriesCountLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        accessoryType = .disclosureIndicator
        
        studyLabel.font = .systemFont(ofSize: 16, weight: .medium)
        studyLabel.textColor = .label
        
        patientLabel.font = .systemFont(ofSize: 14)
        patientLabel.textColor = .secondaryLabel
        
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .tertiaryLabel
        
        seriesCountLabel.font = .systemFont(ofSize: 12)
        seriesCountLabel.textColor = .systemBlue
        
        let stackView = UIStackView(arrangedSubviews: [studyLabel, patientLabel, dateLabel, seriesCountLabel])
        stackView.axis = .vertical
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with study: DICOMStudy) {
        studyLabel.text = (study.studyDescription?.isEmpty == false) ? study.studyDescription! : "Unnamed Study"
        patientLabel.text = (study.patientName?.isEmpty == false) ? study.patientName! : "Unknown Patient"
        dateLabel.text = formatDate(study.studyDate ?? "")
        seriesCountLabel.text = "\(study.series.count) series"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        
        return dateString.isEmpty ? "Unknown Date" : dateString
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let studiesDidUpdate = Notification.Name("studiesDidUpdate")
}
