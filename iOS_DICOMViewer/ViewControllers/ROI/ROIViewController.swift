import UIKit
import MetalKit
import simd

/// View controller for ROI tools and measurement capabilities
/// Integrates with DICOM viewer for medical imaging annotations
class ROIViewController: UIViewController {
    
    // MARK: - UI Components
    @IBOutlet weak var toolbarStackView: UIStackView!
    @IBOutlet weak var measurementTableView: UITableView!
    @IBOutlet weak var toolSelectionSegmentedControl: UISegmentedControl!
    @IBOutlet weak var statisticsView: UIView!
    @IBOutlet weak var statisticsLabel: UILabel!
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var clearAllButton: UIButton!
    
    // MARK: - Core Components
    private let roiManager = ROIManager.shared
    private var roiRenderer: ROIRenderer!
    private var metalView: MTKView!
    
    // MARK: - Data
    private var currentInstance: DICOMInstance?
    private var pixelData: Data?
    private var imageToScreenTransform = matrix_identity_float4x4
    
    // MARK: - Gesture Recognition
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    
    // MARK: - State
    private var isEditingMode = false
    private var selectedToolIndex: Int = 0
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        setupRenderer()
        setupObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }
    
    private func setupUI() {
        title = "ROI Tools"
        
        // Configure tool selection
        toolSelectionSegmentedControl.removeAllSegments()
        for (index, toolType) in ROIManager.ROIToolType.allCases.enumerated() {
            toolSelectionSegmentedControl.insertSegment(withTitle: toolType.displayName, at: index, animated: false)
        }
        toolSelectionSegmentedControl.selectedSegmentIndex = 0
        
        // Configure table view
        measurementTableView.delegate = self
        measurementTableView.dataSource = self
        measurementTableView.register(ROIMeasurementCell.self, forCellReuseIdentifier: "ROIMeasurementCell")
        
        // Configure buttons
        exportButton.layer.cornerRadius = 8
        clearAllButton.layer.cornerRadius = 8
        clearAllButton.tintColor = .systemRed
        
        // Configure statistics view
        statisticsView.layer.cornerRadius = 8
        statisticsView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        statisticsLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        statisticsLabel.numberOfLines = 0
        
        setupAccessibility()
    }
    
    private func setupAccessibility() {
        toolSelectionSegmentedControl.accessibilityLabel = "ROI Tool Selection"
        exportButton.accessibilityLabel = "Export ROI Measurements"
        clearAllButton.accessibilityLabel = "Clear All ROI Tools"
        measurementTableView.accessibilityLabel = "Measurement Results"
        statisticsView.accessibilityLabel = "ROI Statistics"
    }
    
    private func setupGestures() {
        // Tap gesture for tool placement and selection
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        metalView?.addGestureRecognizer(tapGestureRecognizer)
        
        // Pan gesture for tool editing
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGestureRecognizer.delegate = self
        metalView?.addGestureRecognizer(panGestureRecognizer)
        
        // Long press for context menu
        longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        metalView?.addGestureRecognizer(longPressGestureRecognizer)
    }
    
    private func setupRenderer() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            showAlert(title: "Error", message: "Metal is not supported on this device")
            return
        }
        
        do {
            roiRenderer = try ROIRenderer(device: device)
            print("✅ ROI Renderer initialized")
        } catch {
            showAlert(title: "Renderer Error", message: "Failed to initialize ROI renderer: \(error.localizedDescription)")
        }
    }
    
    private func setupObservers() {
        // Observe ROI manager changes
        roiManager.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.updateUI()
            }
        }.store(in: &cancellables)
        
        // Observe app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Data Loading
    func loadInstance(_ instance: DICOMInstance, metalView: MTKView, imageTransform: simd_float4x4) {
        self.currentInstance = instance
        self.metalView = metalView
        self.pixelData = instance.pixelData
        self.imageToScreenTransform = imageTransform
        
        // Configure ROI manager for this instance
        let pixelSpacing = simd_float2(
            Float(instance.metadata.pixelSpacing?[0] ?? 1.0),
            Float(instance.metadata.pixelSpacing?[1] ?? 1.0)
        )
        let sliceThickness = Float(instance.metadata.sliceThickness ?? 1.0)
        
        roiManager.setCurrentInstance(
            instanceUID: instance.metadata.sopInstanceUID ?? UUID().uuidString,
            seriesUID: instance.metadata.seriesInstanceUID ?? "unknown",
            pixelSpacing: pixelSpacing,
            sliceThickness: sliceThickness
        )
        
        updateUI()
        print("📋 ROI tools loaded for instance: \(instance.metadata.sopInstanceUID ?? "unknown")")
    }
    
    private func updateUI() {
        DispatchQueue.main.async { [weak self] in
            self?.measurementTableView.reloadData()
            self?.updateStatistics()
            self?.updateToolbarState()
        }
    }
    
    private func updateStatistics() {
        guard let selectedTool = roiManager.selectedTool,
              let stats = selectedTool.statistics else {
            statisticsLabel.text = "Select a ROI tool to view statistics"
            statisticsView.isHidden = true
            return
        }
        
        statisticsLabel.text = stats.displayText
        statisticsView.isHidden = false
    }
    
    private func updateToolbarState() {
        let hasTools = roiManager.hasActiveTools
        exportButton.isEnabled = hasTools
        clearAllButton.isEnabled = hasTools
        
        // Update tool selection
        let currentToolType = roiManager.currentToolType
        if let index = ROIManager.ROIToolType.allCases.firstIndex(of: currentToolType) {
            toolSelectionSegmentedControl.selectedSegmentIndex = index
        }
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: metalView)
        let imagePoint = screenToImageCoordinates(location)
        let worldPoint = simd_float3(imagePoint.x, imagePoint.y, 0) // 2D for now
        
        if roiManager.isCreating {
            // Continue creating current tool
            roiManager.startTool(at: imagePoint, worldPoint: worldPoint)
        } else {
            // Try to select existing tool first
            if let selectedTool = roiManager.selectTool(at: imagePoint) {
                roiManager.selectedTool = selectedTool
                updateStatistics()
                highlightSelectedTool(selectedTool)
            } else {
                // Start new tool
                roiManager.startTool(at: imagePoint, worldPoint: worldPoint)
            }
        }
        
        updateUI()
        renderROIs()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        // Pan gesture for future tool editing implementation
        let location = gesture.location(in: metalView)
        let imagePoint = screenToImageCoordinates(location)
        
        switch gesture.state {
        case .began:
            // Check if we're starting to edit a tool
            if let tool = roiManager.selectTool(at: imagePoint) {
                isEditingMode = true
                roiManager.selectedTool = tool
            }
            
        case .changed:
            if isEditingMode {
                // Future: Implement tool point editing
            }
            
        case .ended, .cancelled:
            isEditingMode = false
            
        default:
            break
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: metalView)
        let imagePoint = screenToImageCoordinates(location)
        
        if let tool = roiManager.selectTool(at: imagePoint) {
            showToolContextMenu(for: tool, at: location)
        } else if roiManager.isCreating, roiManager.currentToolType == .polygon {
            // Close polygon on long press
            roiManager.closePolygon()
            updateUI()
            renderROIs()
        }
    }
    
    // MARK: - Actions
    @IBAction func toolSelectionChanged(_ sender: UISegmentedControl) {
        let selectedIndex = sender.selectedSegmentIndex
        let toolType = ROIManager.ROIToolType.allCases[selectedIndex]
        roiManager.selectToolType(toolType)
        
        print("🔧 Selected tool: \(toolType.displayName)")
    }
    
    @IBAction func exportButtonTapped(_ sender: UIButton) {
        exportMeasurements()
    }
    
    @IBAction func clearAllButtonTapped(_ sender: UIButton) {
        showClearAllConfirmation()
    }
    
    @IBAction func undoLastPoint(_ sender: UIButton) {
        roiManager.deleteLastPoint()
        updateUI()
        renderROIs()
    }
    
    @IBAction func finishCurrentTool(_ sender: UIButton) {
        roiManager.finishCurrentTool()
        updateUI()
        renderROIs()
    }
    
    // MARK: - Context Menu
    private func showToolContextMenu(for tool: ROITool, at location: CGPoint) {
        let alertController = UIAlertController(title: tool.name, message: nil, preferredStyle: .actionSheet)
        
        // Calculate statistics
        alertController.addAction(UIAlertAction(title: "Calculate Statistics", style: .default) { [weak self] _ in
            self?.calculateStatistics(for: tool)
        })
        
        // Duplicate tool
        alertController.addAction(UIAlertAction(title: "Duplicate", style: .default) { [weak self] _ in
            self?.roiManager.duplicateTool(tool)
            self?.updateUI()
            self?.renderROIs()
        })
        
        // Change color
        alertController.addAction(UIAlertAction(title: "Change Color", style: .default) { [weak self] _ in
            self?.showColorPicker(for: tool)
        })
        
        // Delete tool
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.roiManager.deleteTool(tool)
            self?.updateUI()
            self?.renderROIs()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad support
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = metalView
            popover.sourceRect = CGRect(origin: location, size: .zero)
        }
        
        present(alertController, animated: true)
    }
    
    private func showClearAllConfirmation() {
        let alertController = UIAlertController(
            title: "Clear All ROI Tools",
            message: "This will permanently delete all measurements and annotations. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            self?.roiManager.deleteAllTools()
            self?.updateUI()
            self?.renderROIs()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    private func showColorPicker(for tool: ROITool) {
        let colorPicker = UIColorPickerViewController()
        colorPicker.delegate = self
        colorPicker.selectedColor = tool.color
        colorPicker.title = "Choose ROI Color"
        
        // Store reference to tool for color change callback
        colorPicker.view.tag = tool.id.hashValue
        
        present(colorPicker, animated: true)
    }
    
    // MARK: - Statistics and Export
    private func calculateStatistics(for tool: ROITool) {
        guard let instance = currentInstance,
              let pixelData = self.pixelData else {
            showAlert(title: "Error", message: "No image data available for statistics calculation")
            return
        }
        
        let statistics = roiManager.calculateStatistics(for: tool, pixelData: pixelData, metadata: instance.metadata)
        
        if let stats = statistics {
            roiManager.selectedTool = tool
            updateStatistics()
            
            // Show detailed statistics popup
            showStatisticsDetail(stats)
        } else {
            showAlert(title: "Statistics Error", message: "Unable to calculate statistics for this ROI")
        }
    }
    
    private func showStatisticsDetail(_ statistics: ROIStatistics) {
        let alertController = UIAlertController(
            title: "ROI Statistics",
            message: statistics.displayText,
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "Copy to Clipboard", style: .default) { _ in
            UIPasteboard.general.string = statistics.displayText
        })
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alertController, animated: true)
    }
    
    private func exportMeasurements() {
        let report = roiManager.generateReport()
        
        let alertController = UIAlertController(
            title: "Export Measurements",
            message: "Choose export format",
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: "JSON", style: .default) { [weak self] _ in
            self?.exportAsJSON(report)
        })
        
        alertController.addAction(UIAlertAction(title: "Text Report", style: .default) { [weak self] _ in
            self?.exportAsText(report)
        })
        
        alertController.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] _ in
            self?.shareReport(report)
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad support
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    private func exportAsJSON(_ report: ROIReport) {
        guard let data = roiManager.exportTools() else {
            showAlert(title: "Export Error", message: "Failed to generate JSON export")
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "ROI_Export_\(Date().timeIntervalSince1970).json"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            shareFile(at: fileURL)
        } catch {
            showAlert(title: "Export Error", message: "Failed to save file: \(error.localizedDescription)")
        }
    }
    
    private func exportAsText(_ report: ROIReport) {
        let textContent = report.summaryText
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "ROI_Report_\(Date().timeIntervalSince1970).txt"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try textContent.write(to: fileURL, atomically: true, encoding: .utf8)
            shareFile(at: fileURL)
        } catch {
            showAlert(title: "Export Error", message: "Failed to save file: \(error.localizedDescription)")
        }
    }
    
    private func shareReport(_ report: ROIReport) {
        let textContent = report.summaryText
        let activityViewController = UIActivityViewController(activityItems: [textContent], applicationActivities: nil)
        
        // iPad support
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton.bounds
        }
        
        present(activityViewController, animated: true)
    }
    
    private func shareFile(at url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // iPad support
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton.bounds
        }
        
        present(activityViewController, animated: true)
    }
    
    // MARK: - Rendering
    private func renderROIs() {
        guard let roiRenderer = roiRenderer,
              let metalView = metalView,
              let drawable = metalView.currentDrawable else { return }
        
        let tools = roiManager.getToolsForCurrentInstance()
        roiRenderer.render(
            tools: tools,
            to: drawable,
            viewportSize: metalView.drawableSize,
            imageToScreenTransform: imageToScreenTransform
        )
    }
    
    private func highlightSelectedTool(_ tool: ROITool) {
        // Visual feedback for selected tool
        // This would typically involve updating the rendering to show selection
        print("🎯 Selected tool: \(tool.name) - \(tool.measurement?.description ?? "No measurement")")
    }
    
    // MARK: - Coordinate Conversion
    private func screenToImageCoordinates(_ screenPoint: CGPoint) -> simd_float2 {
        // Convert screen coordinates to image coordinates using inverse transform
        let screenPoint4 = simd_float4(Float(screenPoint.x), Float(screenPoint.y), 0, 1)
        let imagePoint4 = imageToScreenTransform.inverse * screenPoint4
        return simd_float2(imagePoint4.x, imagePoint4.y)
    }
    
    // MARK: - Lifecycle Management
    @objc private func appWillResignActive() {
        // Save current ROI tools
        if let instanceUID = currentInstance?.metadata.sopInstanceUID {
            roiManager.saveToolsForInstance(instanceUID)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Helper Methods
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}

// MARK: - Table View Data Source
extension ROIViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return roiManager.getToolsForCurrentInstance().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ROIMeasurementCell", for: indexPath) as! ROIMeasurementCell
        
        let tools = roiManager.getToolsForCurrentInstance()
        let tool = tools[indexPath.row]
        
        cell.configure(with: tool)
        
        return cell
    }
}

// MARK: - Table View Delegate
extension ROIViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let tools = roiManager.getToolsForCurrentInstance()
        let tool = tools[indexPath.row]
        
        roiManager.selectedTool = tool
        updateStatistics()
        highlightSelectedTool(tool)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let tools = roiManager.getToolsForCurrentInstance()
            let tool = tools[indexPath.row]
            
            roiManager.deleteTool(tool)
            updateUI()
            renderROIs()
        }
    }
}

// MARK: - Gesture Recognizer Delegate
extension ROIViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false // ROI gestures should have priority
    }
}

// MARK: - Color Picker Delegate
extension ROIViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        let selectedColor = viewController.selectedColor
        
        // Find tool by stored tag (hash value)
        let toolHash = viewController.view.tag
        if let tool = roiManager.getToolsForCurrentInstance().first(where: { $0.id.hashValue == toolHash }) {
            roiManager.setToolColor(selectedColor, for: tool)
            updateUI()
            renderROIs()
        }
    }
}

// MARK: - Custom Table View Cell
class ROIMeasurementCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let measurementLabel = UILabel()
    private let colorView = UIView()
    private let statisticsLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        [nameLabel, measurementLabel, colorView, statisticsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        measurementLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        measurementLabel.textColor = .secondaryLabel
        statisticsLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        statisticsLabel.textColor = .tertiaryLabel
        statisticsLabel.numberOfLines = 2
        
        colorView.layer.cornerRadius = 6
        colorView.layer.borderWidth = 1
        colorView.layer.borderColor = UIColor.separator.cgColor
        
        NSLayoutConstraint.activate([
            colorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            colorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            colorView.widthAnchor.constraint(equalToConstant: 12),
            colorView.heightAnchor.constraint(equalToConstant: 12),
            
            nameLabel.leadingAnchor.constraint(equalTo: colorView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            measurementLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            measurementLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            measurementLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            statisticsLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            statisticsLabel.topAnchor.constraint(equalTo: measurementLabel.bottomAnchor, constant: 2),
            statisticsLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            statisticsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with tool: ROITool) {
        nameLabel.text = tool.name
        measurementLabel.text = tool.measurement?.description ?? "No measurement"
        colorView.backgroundColor = tool.color
        
        if let stats = tool.statistics {
            statisticsLabel.text = "Area: \(String(format: "%.1f", stats.area)) mm² • Mean: \(String(format: "%.1f", stats.mean)) HU"
        } else {
            statisticsLabel.text = "Created: \(DateFormatter.localizedString(from: tool.creationDate, dateStyle: .none, timeStyle: .short))"
        }
    }
}

import Combine