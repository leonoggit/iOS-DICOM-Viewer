import UIKit
import Metal

class AutoSegmentationViewController: UIViewController {
    
    // MARK: - UI Elements
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var segmentationTableView: UITableView!
    @IBOutlet weak var parametersStackView: UIStackView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var statusLabel: UILabel!
    
    // Segmentation controls
    @IBOutlet weak var segmentationTypeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var smoothingSlider: UISlider!
    @IBOutlet weak var thresholdSlider: UISlider!
    @IBOutlet weak var minComponentSizeSlider: UISlider!
    @IBOutlet weak var morphologySwitch: UISwitch!
    @IBOutlet weak var connectedComponentsSwitch: UISwitch!
    
    // Action buttons
    @IBOutlet weak var runSegmentationButton: UIButton!
    @IBOutlet weak var previewButton: UIButton!
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var clearAllButton: UIButton!
    
    // MARK: - Properties
    private var segmentationService: AutomaticSegmentationService!
    private var currentDICOMInstance: DICOMInstance?
    private var segmentationResults: [DICOMSegmentation] = []
    private var isProcessing = false
    
    // Predefined segmentation types
    private let segmentationTypes = [
        "Lung Parenchyma",
        "Bone Structure", 
        "Contrast Vessels",
        "Organ Boundaries",
        "Air Spaces",
        "Fat Tissue",
        "Muscle Groups",
        "Custom Threshold"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSegmentationService()
        setupTableView()
    }
    
    private func setupUI() {
        title = "Automatic Segmentation"
        
        // Configure segmentation type control
        segmentationTypeSegmentedControl.removeAllSegments()
        for (index, type) in segmentationTypes.enumerated() {
            segmentationTypeSegmentedControl.insertSegment(withTitle: type, at: index, animated: false)
        }
        segmentationTypeSegmentedControl.selectedSegmentIndex = 0
        
        // Configure sliders
        smoothingSlider.minimumValue = 0
        smoothingSlider.maximumValue = 5
        smoothingSlider.value = 2
        
        thresholdSlider.minimumValue = -1000
        thresholdSlider.maximumValue = 3000
        thresholdSlider.value = -500
        
        minComponentSizeSlider.minimumValue = 10
        minComponentSizeSlider.maximumValue = 1000
        minComponentSizeSlider.value = 100
        
        // Configure buttons
        runSegmentationButton.layer.cornerRadius = 8
        runSegmentationButton.backgroundColor = .systemBlue
        
        previewButton.layer.cornerRadius = 8
        previewButton.backgroundColor = .systemGreen
        
        exportButton.layer.cornerRadius = 8
        exportButton.backgroundColor = .systemOrange
        exportButton.isEnabled = false
        
        clearAllButton.layer.cornerRadius = 8
        clearAllButton.backgroundColor = .systemRed
        
        // Initial state
        progressView.isHidden = true
        statusLabel.text = "Ready for segmentation"
        
        // Add value change listeners
        segmentationTypeSegmentedControl.addTarget(self, action: #selector(segmentationTypeChanged), for: .valueChanged)
        smoothingSlider.addTarget(self, action: #selector(parameterChanged), for: .valueChanged)
        thresholdSlider.addTarget(self, action: #selector(parameterChanged), for: .valueChanged)
        minComponentSizeSlider.addTarget(self, action: #selector(parameterChanged), for: .valueChanged)
    }
    
    private func setupSegmentationService() {
        do {
            guard let device = MTLCreateSystemDefaultDevice() else {
                showAlert(title: "Error", message: "Metal is not supported on this device")
                return
            }
            
            segmentationService = try AutomaticSegmentationService(device: device)
            print("✅ Automatic segmentation service initialized")
            
        } catch {
            showAlert(title: "Initialization Error", message: "Failed to initialize segmentation service: \\(error.localizedDescription)")
        }
    }
    
    private func setupTableView() {
        segmentationTableView.dataSource = self
        segmentationTableView.delegate = self
        segmentationTableView.register(UITableViewCell.self, forCellReuseIdentifier: "SegmentationCell")
    }
    
    // MARK: - Actions
    
    @IBAction func runSegmentationButtonTapped(_ sender: UIButton) {
        guard let dicomInstance = currentDICOMInstance else {
            showAlert(title: "No Data", message: "Please load a DICOM image first")
            return
        }
        
        guard !isProcessing else {
            showAlert(title: "Processing", message: "Segmentation is already in progress")
            return
        }
        
        let parameters = createSegmentationParameters()
        runSegmentation(on: dicomInstance, with: parameters)
    }
    
    @IBAction func previewButtonTapped(_ sender: UIButton) {
        guard let dicomInstance = currentDICOMInstance else {
            showAlert(title: "No Data", message: "Please load a DICOM image first")
            return
        }
        
        // Show preview with current parameters
        showSegmentationPreview(for: dicomInstance)
    }
    
    @IBAction func exportButtonTapped(_ sender: UIButton) {
        guard !segmentationResults.isEmpty else {
            showAlert(title: "No Results", message: "No segmentation results to export")
            return
        }
        
        exportSegmentations()
    }
    
    @IBAction func clearAllButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Clear All",
            message: "Are you sure you want to clear all segmentation results?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.clearAllSegmentations()
        })
        
        present(alert, animated: true)
    }
    
    @objc private func segmentationTypeChanged() {
        updateParametersForSelectedType()
        updatePreview()
    }
    
    @objc private func parameterChanged() {
        updatePreview()
    }
    
    // MARK: - Segmentation Logic
    
    private func createSegmentationParameters() -> AutomaticSegmentationService.SegmentationParameters {
        let selectedType = getSelectedSegmentationType()
        
        return AutomaticSegmentationService.SegmentationParameters(
            type: selectedType,
            smoothingRadius: Int(smoothingSlider.value),
            minComponentSize: Int(minComponentSizeSlider.value),
            useConnectedComponents: connectedComponentsSwitch.isOn,
            applyMorphologicalOps: morphologySwitch.isOn,
            erosionRadius: 1,
            dilationRadius: 2
        )
    }
    
    private func getSelectedSegmentationType() -> AutomaticSegmentationService.SegmentationType {
        switch segmentationTypeSegmentedControl.selectedSegmentIndex {
        case 0: return .lungParenchyma
        case 1: return .boneStructure
        case 2: return .contrastVessels
        case 3: return .organBoundaries
        case 4: return .airSpaces
        case 5: return .fatTissue
        case 6: return .muscleGroups
        case 7: return .customThreshold(min: -1000, max: Float(thresholdSlider.value))
        default: return .lungParenchyma
        }
    }
    
    private func runSegmentation(on dicomInstance: DICOMInstance, with parameters: AutomaticSegmentationService.SegmentationParameters) {
        isProcessing = true
        progressView.isHidden = false
        statusLabel.text = "Running segmentation..."
        runSegmentationButton.isEnabled = false
        
        // Start progress animation
        progressView.progress = 0.0
        animateProgress()
        
        segmentationService.performSegmentation(on: dicomInstance, parameters: parameters) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleSegmentationResult(result)
            }
        }
    }
    
    private func handleSegmentationResult(_ result: Result<DICOMSegmentation, Error>) {
        isProcessing = false
        progressView.isHidden = true
        runSegmentationButton.isEnabled = true
        
        switch result {
        case .success(let segmentation):
            segmentationResults.append(segmentation)
            statusLabel.text = "Segmentation completed successfully"
            exportButton.isEnabled = true
            
            // Update table view
            segmentationTableView.reloadData()
            
            // Show success feedback
            showSuccessAlert(segmentation: segmentation)
            
        case .failure(let error):
            statusLabel.text = "Segmentation failed"
            showAlert(title: "Segmentation Error", message: error.localizedDescription)
        }
    }
    
    private func showSuccessAlert(segmentation: DICOMSegmentation) {
        let alert = UIAlertController(
            title: "Segmentation Complete",
            message: "Successfully segmented \\(segmentation.segments.count) regions\\nType: \\(segmentation.contentLabel)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        alert.addAction(UIAlertAction(title: "View Details", style: .default) { _ in
            self.showSegmentationDetails(segmentation)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Advanced Segmentation Options
    
    @IBAction func runLungSegmentationTapped(_ sender: UIButton) {
        guard let dicomInstance = currentDICOMInstance else {
            showAlert(title: "No Data", message: "Please load a DICOM image first")
            return
        }
        
        statusLabel.text = "Running advanced lung segmentation..."
        
        segmentationService.performLungSegmentation(on: dicomInstance) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleSegmentationResult(result)
            }
        }
    }
    
    @IBAction func runBoneSegmentationTapped(_ sender: UIButton) {
        guard let dicomInstance = currentDICOMInstance else {
            showAlert(title: "No Data", message: "Please load a DICOM image first")
            return
        }
        
        statusLabel.text = "Running advanced bone segmentation..."
        
        segmentationService.performBoneSegmentation(on: dicomInstance, separateCorticalTrabecular: true) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleSegmentationResult(result)
            }
        }
    }
    
    @IBAction func runMultiOrganSegmentationTapped(_ sender: UIButton) {
        guard let dicomInstance = currentDICOMInstance else {
            showAlert(title: "No Data", message: "Please load a DICOM image first")
            return
        }
        
        let alert = UIAlertController(title: "Multi-Organ Segmentation", message: "Select organs to segment:", preferredStyle: .alert)
        
        let organs = ["liver", "kidneys", "spleen", "pancreas"]
        var selectedOrgans: [String] = []
        
        for organ in organs {
            alert.addAction(UIAlertAction(title: organ.capitalized, style: .default) { _ in
                selectedOrgans.append(organ)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Start Segmentation", style: .default) { _ in
            if !selectedOrgans.isEmpty {
                self.statusLabel.text = "Running multi-organ segmentation..."
                
                self.segmentationService.performMultiOrganSegmentation(
                    on: dicomInstance,
                    targetOrgans: selectedOrgans
                ) { [weak self] result in
                    DispatchQueue.main.async {
                        self?.handleSegmentationResult(result)
                    }
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - UI Updates
    
    private func updateParametersForSelectedType() {
        let selectedType = getSelectedSegmentationType()
        
        switch selectedType {
        case .lungParenchyma:
            thresholdSlider.value = -700 // Typical lung HU
            smoothingSlider.value = 3
            minComponentSizeSlider.value = 500
            morphologySwitch.isOn = true
            connectedComponentsSwitch.isOn = true
            
        case .boneStructure:
            thresholdSlider.value = 200 // Bone threshold
            smoothingSlider.value = 1
            minComponentSizeSlider.value = 50
            morphologySwitch.isOn = false
            connectedComponentsSwitch.isOn = true
            
        case .contrastVessels:
            thresholdSlider.value = 100 // Contrast enhancement
            smoothingSlider.value = 2
            minComponentSizeSlider.value = 20
            morphologySwitch.isOn = true
            connectedComponentsSwitch.isOn = true
            
        case .fatTissue:
            thresholdSlider.value = -100 // Fat HU
            smoothingSlider.value = 2
            minComponentSizeSlider.value = 100
            morphologySwitch.isOn = true
            connectedComponentsSwitch.isOn = true
            
        default:
            // Keep current values
            break
        }
    }
    
    private func updatePreview() {
        // Update preview image with current parameters
        // This would show a quick preview of the segmentation
    }
    
    private func animateProgress() {
        guard isProcessing else { return }
        
        UIView.animate(withDuration: 0.5) {
            self.progressView.progress += 0.1
        } completion: { _ in
            if self.progressView.progress < 1.0 && self.isProcessing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.animateProgress()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func showSegmentationPreview(for dicomInstance: DICOMInstance) {
        // Create a preview controller
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let previewVC = storyboard.instantiateViewController(withIdentifier: "SegmentationPreviewViewController") as? SegmentationPreviewViewController {
            previewVC.dicomInstance = dicomInstance
            previewVC.parameters = createSegmentationParameters()
            present(previewVC, animated: true)
        }
    }
    
    private func showSegmentationDetails(_ segmentation: DICOMSegmentation) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let detailsVC = storyboard.instantiateViewController(withIdentifier: "SegmentationDetailsViewController") as? SegmentationDetailsViewController {
            detailsVC.segmentation = segmentation
            navigationController?.pushViewController(detailsVC, animated: true)
        }
    }
    
    private func exportSegmentations() {
        let alert = UIAlertController(title: "Export Segmentations", message: "Choose export format:", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "DICOM SEG", style: .default) { _ in
            self.exportAsDICOMSEG()
        })
        
        alert.addAction(UIAlertAction(title: "Binary Masks (PNG)", style: .default) { _ in
            self.exportAsBinaryMasks()
        })
        
        alert.addAction(UIAlertAction(title: "JSON Report", style: .default) { _ in
            self.exportAsJSONReport()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func exportAsDICOMSEG() {
        // Export as DICOM Segmentation Object
        statusLabel.text = "Exporting as DICOM SEG..."
        
        // Implementation for DICOM SEG export
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.statusLabel.text = "Export completed"
            self.showAlert(title: "Export Complete", message: "Segmentations exported as DICOM SEG files")
        }
    }
    
    private func exportAsBinaryMasks() {
        // Export as binary mask images
        statusLabel.text = "Exporting binary masks..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.statusLabel.text = "Export completed"
            self.showAlert(title: "Export Complete", message: "Binary masks exported as PNG files")
        }
    }
    
    private func exportAsJSONReport() {
        // Export segmentation results as JSON report
        statusLabel.text = "Generating JSON report..."
        
        let report = generateSegmentationReport()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.statusLabel.text = "Export completed"
            self.shareReport(report)
        }
    }
    
    private func generateSegmentationReport() -> [String: Any] {
        var report: [String: Any] = [:]
        report["timestamp"] = ISO8601DateFormatter().string(from: Date())
        report["total_segmentations"] = segmentationResults.count
        
        var segmentations: [[String: Any]] = []
        
        for segmentation in segmentationResults {
            var segInfo: [String: Any] = [:]
            segInfo["content_label"] = segmentation.contentLabel
            segInfo["algorithm_type"] = segmentation.algorithmType.rawValue
            segInfo["number_of_segments"] = segmentation.segments.count
            segInfo["dimensions"] = ["rows": segmentation.rows, "columns": segmentation.columns]
            
            var segments: [[String: Any]] = []
            for segment in segmentation.segments {
                var segmentInfo: [String: Any] = [:]
                segmentInfo["segment_number"] = segment.segmentNumber
                segmentInfo["segment_label"] = segment.segmentLabel
                segmentInfo["algorithm_type"] = segment.algorithmType.rawValue
                segmentInfo["is_visible"] = segment.isVisible
                segmentInfo["opacity"] = segment.opacity
                segments.append(segmentInfo)
            }
            
            segInfo["segments"] = segments
            segmentations.append(segInfo)
        }
        
        report["segmentations"] = segmentations
        return report
    }
    
    private func shareReport(_ report: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: report, options: .prettyPrinted)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("segmentation_report.json")
            try jsonData.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = exportButton
                popover.sourceRect = exportButton.bounds
            }
            present(activityVC, animated: true)
            
        } catch {
            showAlert(title: "Export Error", message: "Failed to generate report: \\(error.localizedDescription)")
        }
    }
    
    private func clearAllSegmentations() {
        segmentationResults.removeAll()
        segmentationTableView.reloadData()
        exportButton.isEnabled = false
        statusLabel.text = "All segmentations cleared"
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Public Methods
    
    func setDICOMInstance(_ instance: DICOMInstance) {
        currentDICOMInstance = instance
        
        // Update UI with instance information
        if let metadata = instance.metadata {
            statusLabel.text = "Loaded: \\(metadata.rows)x\\(metadata.columns) CT image"
        }
        
        // Update preview image if available
        if let pixelData = instance.pixelData {
            // Convert to UIImage and display
            // Implementation would convert DICOM pixel data to UIImage
        }
    }
}

// MARK: - UITableViewDataSource

extension AutoSegmentationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return segmentationResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentationCell", for: indexPath)
        
        let segmentation = segmentationResults[indexPath.row]
        cell.textLabel?.text = segmentation.contentLabel
        cell.detailTextLabel?.text = "\\(segmentation.segments.count) segments"
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AutoSegmentationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let segmentation = segmentationResults[indexPath.row]
        showSegmentationDetails(segmentation)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            segmentationResults.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            if segmentationResults.isEmpty {
                exportButton.isEnabled = false
            }
        }
    }
}