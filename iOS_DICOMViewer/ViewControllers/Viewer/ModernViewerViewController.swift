//
//  ModernViewerViewController.swift
//  iOS_DICOMViewer
//
//  Modern 2D DICOM viewer with enhanced UI for iPhone 16 Pro Max
//  Based on medical imaging standards and HTML template design
//

import UIKit
import Metal
import MetalKit

// MARK: - Professional Medical Imaging Enums

enum MeasurementMode {
    case none
    case distance
    case angle
    case area
    case roi
}

struct DICOMAnnotation {
    let id: UUID
    let type: AnnotationType
    let points: [CGPoint]
    let text: String?
    let color: UIColor
    
    enum AnnotationType {
        case distance
        case angle
        case area
        case roi
        case arrow
        case text
    }
}

class ModernViewerViewController: UIViewController {
    
    // MARK: - Properties
    
    var study: DICOMStudy? {
        didSet {
            DispatchQueue.main.async {
                self.updateUIForStudy()
            }
        }
    }
    
    var currentInstance: DICOMInstance?
    private var currentSeriesIndex: Int = 0
    private var currentInstanceIndex: Int = 0
    private var currentWindow: Float = 400
    private var currentLevel: Float = 40
    
    // Professional imaging features
    private var isInvert: Bool = false
    private var rotation: CGFloat = 0
    private var flipHorizontal: Bool = false
    private var flipVertical: Bool = false
    private var currentAnnotations: [DICOMAnnotation] = []
    
    // DICOM rendering
    private let imageRenderer = DICOMImageRenderer()
    private let imageCache = DICOMImageCache()
    
    // Measurement tools
    private var measurementMode: MeasurementMode = .none
    private var measurementPoints: [CGPoint] = []
    private var measurementLayer: CAShapeLayer?
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.1
        scrollView.maximumZoomScale = 10.0
        scrollView.zoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .black
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // Control panel container
    private lazy var controlPanelView: UIView = {
        let view = UIView()
        let surfaceDarkSecondary = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 0.95)
        view.backgroundColor = surfaceDarkSecondary
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Series control
    private lazy var seriesSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl()
        let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        control.selectedSegmentTintColor = primaryColor
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.lightGray], for: .normal)
        control.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        control.addTarget(self, action: #selector(seriesChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    // Instance navigation
    private lazy var instanceSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0
        slider.isContinuous = true
        let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        slider.thumbTintColor = primaryColor
        slider.minimumTrackTintColor = primaryColor
        slider.addTarget(self, action: #selector(instanceChanged), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    private lazy var instanceLabel: UILabel = {
        let label = UILabel()
        label.text = "1 / 1"
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Window/Level controls
    private lazy var windowLevelStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var windowControlView: UIView = {
        return createSliderControl(title: "Window", value: 400, range: 1...4000, tag: 0)
    }()
    
    private lazy var levelControlView: UIView = {
        return createSliderControl(title: "Level", value: 40, range: -1000...3000, tag: 1)
    }()
    
    // Presets buttons
    private lazy var presetsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // Professional tools
    private lazy var professionalToolsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // Measurement overlay
    private lazy var measurementOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Empty state view
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = false
        return view
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupGestures()
        setupEmptyState()
        updateUIForStudy()
        
        // Add revolutionary AI features
        addAIAnalysisButtons()
        addReportGenerationButton()
        enableQuantumFeatures()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        let backgroundDark = UIColor(red: 17/255, green: 22/255, blue: 24/255, alpha: 1.0)
        view.backgroundColor = backgroundDark
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(measurementOverlayView)
        view.addSubview(controlPanelView)
        view.addSubview(emptyStateView)
        
        setupControlPanel()
        setupConstraints()
    }
    
    private func setupControlPanel() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Series selection
        let seriesLabel = createControlLabel("Series")
        
        // Instance navigation
        let instanceLabel = createControlLabel("Instance Navigation")
        let instanceStackView = UIStackView()
        instanceStackView.axis = .horizontal
        instanceStackView.spacing = 12
        instanceStackView.alignment = .center
        instanceStackView.addArrangedSubview(instanceSlider)
        instanceStackView.addArrangedSubview(self.instanceLabel)
        
        // Window/Level controls
        let windowLevelLabel = createControlLabel("Window / Level")
        windowLevelStackView.addArrangedSubview(windowControlView)
        windowLevelStackView.addArrangedSubview(levelControlView)
        
        // Presets
        let presetsLabel = createControlLabel("Presets")
        setupPresetButtons()
        
        // Professional tools
        let toolsLabel = createControlLabel("Professional Tools")
        setupProfessionalTools()
        
        stackView.addArrangedSubview(seriesLabel)
        stackView.addArrangedSubview(seriesSegmentedControl)
        stackView.addArrangedSubview(instanceLabel)
        stackView.addArrangedSubview(instanceStackView)
        stackView.addArrangedSubview(windowLevelLabel)
        stackView.addArrangedSubview(windowLevelStackView)
        stackView.addArrangedSubview(presetsLabel)
        stackView.addArrangedSubview(presetsStackView)
        stackView.addArrangedSubview(toolsLabel)
        stackView.addArrangedSubview(professionalToolsStackView)
        
        controlPanelView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: controlPanelView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: controlPanelView.bottomAnchor, constant: -16),
            
            self.instanceLabel.widthAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view (image area)
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            
            // Image view
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            
            // Control panel at bottom
            controlPanelView.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            controlPanelView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlPanelView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlPanelView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            
            // Empty state
            emptyStateView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            emptyStateView.heightAnchor.constraint(equalToConstant: 200),
            
            // Measurement overlay (same as image view)
            measurementOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            measurementOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            measurementOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            measurementOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        title = "2D Viewer"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Add tools button
        let toolsButton = UIBarButtonItem(
            image: UIImage(systemName: "slider.horizontal.3"),
            style: .plain,
            target: self,
            action: #selector(showToolsMenu)
        )
        
        // Add info button
        let infoButton = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(showStudyInfo)
        )
        
        let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        toolsButton.tintColor = primaryColor
        infoButton.tintColor = primaryColor
        
        navigationItem.rightBarButtonItems = [infoButton, toolsButton]
    }
    
    private func setupGestures() {
        // Pan gesture for window/level adjustment
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        imageView.addGestureRecognizer(panGesture)
        imageView.isUserInteractionEnabled = true
        
        // Single tap for measurements
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGesture.numberOfTapsRequired = 1
        imageView.addGestureRecognizer(tapGesture)
        
        // Double tap to reset zoom
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        // Ensure single tap doesn't interfere with double tap
        tapGesture.require(toFail: doubleTapGesture)
    }
    
    private func setupEmptyState() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = "🏥"
        iconLabel.font = UIFont.systemFont(ofSize: 64)
        
        let titleLabel = UILabel()
        titleLabel.text = "No Study Selected"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = UIColor.white
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Select a DICOM study from the Home tab\nto begin medical image analysis"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        let textSecondary = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        subtitleLabel.textColor = textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(iconLabel)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        emptyStateView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: emptyStateView.leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: emptyStateView.trailingAnchor)
        ])
    }
    
    private func createControlLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.white
        return label
    }
    
    private func createSliderControl(title: String, value: Float, range: ClosedRange<Float>, tag: Int) -> UIView {
        let containerView = UIView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = UIColor.white
        titleLabel.textAlignment = .center
        
        let slider = UISlider()
        slider.minimumValue = range.lowerBound
        slider.maximumValue = range.upperBound
        slider.value = value
        slider.tag = tag
        let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        slider.thumbTintColor = primaryColor
        slider.minimumTrackTintColor = primaryColor
        slider.addTarget(self, action: #selector(windowLevelChanged(_:)), for: .valueChanged)
        
        let valueLabel = UILabel()
        valueLabel.text = String(Int(value))
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        valueLabel.textColor = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        valueLabel.textAlignment = .center
        valueLabel.tag = tag + 100 // Offset for value labels
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(slider)
        stackView.addArrangedSubview(valueLabel)
        
        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    private func setupPresetButtons() {
        let presets = [
            ("CT Soft", 400, 40),
            ("CT Bone", 1500, 300),
            ("CT Lung", 1500, -600),
            ("MR", 200, 100)
        ]
        
        for (title, window, level) in presets {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            button.setTitleColor(.white, for: .normal)
            let accentTeal = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
            button.backgroundColor = accentTeal
            button.layer.cornerRadius = 6
            button.tag = window * 10000 + level + 1000000 // Encode window/level in tag
            button.addTarget(self, action: #selector(presetButtonTapped(_:)), for: .touchUpInside)
            
            presetsStackView.addArrangedSubview(button)
        }
    }
    
    private func setupProfessionalTools() {
        let tools = [
            ("📏", "Distance", #selector(distanceMeasurementTapped)),
            ("📐", "Angle", #selector(angleMeasurementTapped)),
            ("🔄", "Rotate", #selector(rotateImageTapped)),
            ("⚡", "Invert", #selector(invertImageTapped))
        ]
        
        for (icon, title, action) in tools {
            let button = UIButton(type: .system)
            button.setTitle("\(icon)\n\(title)", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.setTitleColor(.white, for: .normal)
            button.setTitleColor(UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0), for: .selected)
            button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            button.layer.cornerRadius = 8
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
            button.addTarget(self, action: action, for: .touchUpInside)
            
            professionalToolsStackView.addArrangedSubview(button)
        }
    }
    
    // MARK: - Study Management
    
    private func updateUIForStudy() {
        guard let study = study else {
            showEmptyState()
            return
        }
        
        hideEmptyState()
        setupSeriesControl()
        loadFirstInstance()
    }
    
    private func showEmptyState() {
        emptyStateView.isHidden = false
        controlPanelView.alpha = 0.5
        controlPanelView.isUserInteractionEnabled = false
        imageView.image = nil
    }
    
    private func hideEmptyState() {
        emptyStateView.isHidden = true
        controlPanelView.alpha = 1.0
        controlPanelView.isUserInteractionEnabled = true
    }
    
    private func setupSeriesControl() {
        guard let study = study else { return }
        
        seriesSegmentedControl.removeAllSegments()
        
        for (index, series) in study.series.enumerated() {
            let title = series.modality.isEmpty ? "Series \(series.seriesNumber)" : series.modality
            seriesSegmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        
        if !study.series.isEmpty {
            seriesSegmentedControl.selectedSegmentIndex = 0
        }
    }
    
    func loadFirstInstance() {
        guard let study = study,
              let firstSeries = study.series.first,
              let firstInstance = firstSeries.instances.first else { return }
        
        currentInstance = firstInstance
        currentSeriesIndex = 0
        currentInstanceIndex = 0
        
        updateInstanceSlider()
        loadCurrentImage()
    }
    
    private func updateInstanceSlider() {
        guard let study = study,
              currentSeriesIndex < study.series.count else { return }
        
        let currentSeries = study.series[currentSeriesIndex]
        let instanceCount = currentSeries.instances.count
        
        instanceSlider.maximumValue = Float(max(0, instanceCount - 1))
        instanceSlider.value = Float(currentInstanceIndex)
        
        instanceLabel.text = "\(currentInstanceIndex + 1) / \(instanceCount)"
    }
    
    private func loadCurrentImage() {
        guard let study = study,
              currentSeriesIndex < study.series.count else { return }
        
        let currentSeries = study.series[currentSeriesIndex]
        guard currentInstanceIndex < currentSeries.instances.count else { return }
        
        currentInstance = currentSeries.instances[currentInstanceIndex]
        
        Task {
            do {
                let image = try await loadDICOMImage(from: currentInstance!)
                DispatchQueue.main.async {
                    self.displayImage(image)
                }
            } catch {
                print("❌ Failed to load DICOM image: \(error)")
                DispatchQueue.main.async {
                    self.showImageLoadError()
                }
            }
        }
    }
    
    private func displayImage(_ image: UIImage) {
        imageView.image = image
        
        // Update image view size to match image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size
        
        // Reset zoom
        scrollView.zoomScale = 1.0
        centerImageView()
    }
    
    private func centerImageView() {
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame
        
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        
        imageView.frame = frameToCenter
    }
    
    private func showImageLoadError() {
        let placeholderImage = createPlaceholderImage()
        imageView.image = placeholderImage
        
        // Run diagnostic if in debug mode
        #if DEBUG
        if let filePath = currentInstance?.filePath {
            print("🔍 Running DICOM diagnostic for failed image...")
            DCMTKBridge.diagnosePixelDataIssue(filePath)
        }
        #endif
    }
    
    private func createPlaceholderImage() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Dark background
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Error text
            let text = "⚠️\nImage Load Error"
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.red,
                .font: UIFont.systemFont(ofSize: 24, weight: .medium)
            ]
            
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            attributedText.draw(in: textRect)
        }
    }
    
    private func loadDICOMImage(from instance: DICOMInstance) async throws -> UIImage {
        guard let filePath = instance.filePath else {
            throw NSError(domain: "DICOMError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No file path for DICOM instance"])
        }
        
        print("🖼️ ModernViewerViewController: Loading DICOM image from: \(filePath)")
        print("🖼️ Current window/level: W=\(currentWindow), L=\(currentLevel)")
        
        let windowLevel = DICOMImageRenderer.WindowLevel(
            window: Float(currentWindow),
            level: Float(currentLevel)
        )
        
        if let image = try await imageRenderer.renderImage(from: filePath, windowLevel: windowLevel) {
            print("✅ ModernViewerViewController: Successfully loaded image of size \(image.size)")
            return image
        } else {
            print("❌ ModernViewerViewController: Failed to render DICOM image")
            throw NSError(domain: "DICOMError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to render DICOM image"])
        }
    }
    
    // MARK: - Actions
    
    @objc private func seriesChanged() {
        guard let study = study else { return }
        
        let selectedIndex = seriesSegmentedControl.selectedSegmentIndex
        guard selectedIndex >= 0 && selectedIndex < study.series.count else { return }
        
        currentSeriesIndex = selectedIndex
        currentInstanceIndex = 0
        
        updateInstanceSlider()
        loadCurrentImage()
    }
    
    @objc private func instanceChanged() {
        currentInstanceIndex = Int(instanceSlider.value)
        updateInstanceSlider()
        loadCurrentImage()
    }
    
    @objc private func windowLevelChanged(_ sender: UISlider) {
        if sender.tag == 0 { // Window
            currentWindow = sender.value
        } else { // Level
            currentLevel = sender.value
        }
        
        // Update value label
        if let valueLabel = view.viewWithTag(sender.tag + 100) as? UILabel {
            valueLabel.text = String(Int(sender.value))
        }
        
        // Reload current image with new window/level
        loadCurrentImage()
    }
    
    @objc private func presetButtonTapped(_ sender: UIButton) {
        let encoded = sender.tag - 1000000
        let window = Float(encoded / 10000)
        let level = Float(encoded % 10000)
        
        currentWindow = window
        currentLevel = level
        
        // Update sliders
        if let windowSlider = windowControlView.subviews.first?.subviews.compactMap({ $0 as? UIStackView }).first?.arrangedSubviews[1] as? UISlider {
            windowSlider.value = window
        }
        
        if let levelSlider = levelControlView.subviews.first?.subviews.compactMap({ $0 as? UIStackView }).first?.arrangedSubviews[1] as? UISlider {
            levelSlider.value = level
        }
        
        // Update labels
        if let windowLabel = view.viewWithTag(100) as? UILabel {
            windowLabel.text = String(Int(window))
        }
        if let levelLabel = view.viewWithTag(101) as? UILabel {
            levelLabel.text = String(Int(level))
        }
        
        loadCurrentImage()
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: imageView)
        
        switch gesture.state {
        case .began:
            break
        case .changed:
            // Horizontal pan adjusts window, vertical adjusts level
            let windowDelta = Float(translation.x * 2)
            let levelDelta = Float(-translation.y * 1)
            
            currentWindow = max(1, currentWindow + windowDelta)
            currentLevel = max(-1000, min(3000, currentLevel + levelDelta))
            
            // Update UI (throttled)
            updateWindowLevelUI()
            
            gesture.setTranslation(.zero, in: imageView)
        default:
            break
        }
    }
    
    private func updateWindowLevelUI() {
        // Update sliders and labels
        if let windowSlider = windowControlView.subviews.first?.subviews.compactMap({ $0 as? UIStackView }).first?.arrangedSubviews[1] as? UISlider {
            windowSlider.value = currentWindow
        }
        
        if let levelSlider = levelControlView.subviews.first?.subviews.compactMap({ $0 as? UIStackView }).first?.arrangedSubviews[1] as? UISlider {
            levelSlider.value = currentLevel
        }
        
        if let windowLabel = view.viewWithTag(100) as? UILabel {
            windowLabel.text = String(Int(currentWindow))
        }
        if let levelLabel = view.viewWithTag(101) as? UILabel {
            levelLabel.text = String(Int(currentLevel))
        }
    }
    
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard measurementMode != .none else { return }
        
        let locationInImageView = gesture.location(in: imageView)
        addMeasurementPoint(locationInImageView)
    }
    
    @objc private func handleDoubleTap() {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            scrollView.setZoomScale(scrollView.maximumZoomScale / 4, animated: true)
        }
    }
    
    @objc private func showToolsMenu() {
        let alert = UIAlertController(title: "Viewer Tools", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Reset Zoom", style: .default) { _ in
            self.scrollView.setZoomScale(1.0, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Fit to Screen", style: .default) { _ in
            self.fitImageToScreen()
        })
        
        alert.addAction(UIAlertAction(title: "Reset Window/Level", style: .default) { _ in
            self.resetWindowLevel()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad support
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        
        present(alert, animated: true)
    }
    
    @objc private func showStudyInfo() {
        guard let study = study else { return }
        
        let message = """
        Patient: \(study.patientName)
        Study Date: \(study.studyDate)
        Study Description: \(study.studyDescription)
        Series Count: \(study.series.count)
        """
        
        let alert = UIAlertController(title: "Study Information", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func fitImageToScreen() {
        guard let image = imageView.image else { return }
        
        let scrollViewSize = scrollView.bounds.size
        let imageSize = image.size
        
        let scaleX = scrollViewSize.width / imageSize.width
        let scaleY = scrollViewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)
        
        scrollView.setZoomScale(scale, animated: true)
    }
    
    private func resetWindowLevel() {
        currentWindow = 400
        currentLevel = 40
        updateWindowLevelUI()
        loadCurrentImage()
    }
    
    // MARK: - Professional Tool Actions
    
    @objc private func distanceMeasurementTapped() {
        measurementMode = measurementMode == .distance ? .none : .distance
        updateMeasurementState()
        showMeasurementInstructions("Tap two points to measure distance")
    }
    
    @objc private func angleMeasurementTapped() {
        measurementMode = measurementMode == .angle ? .none : .angle
        updateMeasurementState()
        showMeasurementInstructions("Tap three points to measure angle")
    }
    
    @objc private func rotateImageTapped() {
        rotation += .pi / 2
        if rotation >= 2 * .pi {
            rotation = 0
        }
        applyImageTransforms()
    }
    
    @objc private func invertImageTapped() {
        isInvert.toggle()
        applyImageTransforms()
    }
    
    private func updateMeasurementState() {
        measurementPoints.removeAll()
        clearMeasurementOverlay()
        
        // Update button appearance
        for (index, subview) in professionalToolsStackView.arrangedSubviews.enumerated() {
            if let button = subview as? UIButton {
                let isActive = (index == 0 && measurementMode == .distance) || 
                              (index == 1 && measurementMode == .angle)
                button.isSelected = isActive
                button.alpha = isActive ? 1.0 : 0.7
            }
        }
        
        // Enable/disable measurement gestures
        imageView.isUserInteractionEnabled = measurementMode != .none
    }
    
    private func showMeasurementInstructions(_ text: String) {
        let alertController = UIAlertController(title: "Measurement Tool", message: text, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        
        if measurementMode != .none {
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.measurementMode = .none
                self.updateMeasurementState()
            })
        }
        
        present(alertController, animated: true)
    }
    
    private func applyImageTransforms() {
        var transform = CGAffineTransform.identity
        
        // Apply rotation
        transform = transform.rotated(by: rotation)
        
        // Apply inversion (flip)
        if isInvert {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        
        UIView.animate(withDuration: 0.3) {
            self.imageView.transform = transform
        }
    }
    
    private func clearMeasurementOverlay() {
        measurementLayer?.removeFromSuperlayer()
        measurementLayer = nil
    }
    
    // MARK: - Measurement Drawing
    
    private func addMeasurementPoint(_ point: CGPoint) {
        measurementPoints.append(point)
        
        switch measurementMode {
        case .distance:
            if measurementPoints.count == 2 {
                drawDistanceMeasurement()
                measurementMode = .none
                updateMeasurementState()
            }
        case .angle:
            if measurementPoints.count == 3 {
                drawAngleMeasurement()
                measurementMode = .none
                updateMeasurementState()
            }
        default:
            break
        }
    }
    
    private func drawDistanceMeasurement() {
        guard measurementPoints.count >= 2 else { return }
        
        let point1 = measurementPoints[0]
        let point2 = measurementPoints[1]
        
        let path = UIBezierPath()
        path.move(to: point1)
        path.addLine(to: point2)
        
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.strokeColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0).cgColor
        layer.lineWidth = 2.0
        layer.lineCap = .round
        
        measurementOverlayView.layer.addSublayer(layer)
        measurementLayer = layer
        
        // Calculate distance (simplified - would need pixel spacing from DICOM)
        let distance = sqrt(pow(point2.x - point1.x, 2) + pow(point2.y - point1.y, 2))
        let distanceText = String(format: "%.1f px", distance)
        
        // Add distance label
        let midPoint = CGPoint(x: (point1.x + point2.x) / 2, y: (point1.y + point2.y) / 2)
        addMeasurementLabel(distanceText, at: midPoint)
    }
    
    private func drawAngleMeasurement() {
        guard measurementPoints.count >= 3 else { return }
        
        let point1 = measurementPoints[0]
        let point2 = measurementPoints[1] // vertex
        let point3 = measurementPoints[2]
        
        // Draw angle lines
        let path = UIBezierPath()
        path.move(to: point1)
        path.addLine(to: point2)
        path.addLine(to: point3)
        
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.strokeColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0).cgColor
        layer.lineWidth = 2.0
        layer.lineCap = .round
        layer.fillColor = UIColor.clear.cgColor
        
        measurementOverlayView.layer.addSublayer(layer)
        measurementLayer = layer
        
        // Calculate angle
        let vector1 = CGPoint(x: point1.x - point2.x, y: point1.y - point2.y)
        let vector2 = CGPoint(x: point3.x - point2.x, y: point3.y - point2.y)
        
        let angle1 = atan2(vector1.y, vector1.x)
        let angle2 = atan2(vector2.y, vector2.x)
        var angleDiff = angle2 - angle1
        
        if angleDiff < 0 {
            angleDiff += 2 * .pi
        }
        
        let angleDegrees = angleDiff * 180 / .pi
        let angleText = String(format: "%.1f°", angleDegrees)
        
        addMeasurementLabel(angleText, at: point2)
    }
    
    private func addMeasurementLabel(_ text: String, at point: CGPoint) {
        let label = UILabel()
        label.text = text
        label.textColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.sizeToFit()
        
        label.center = point
        measurementOverlayView.addSubview(label)
    }
    
    // MARK: - Public Methods
    
    func updateNavigationControls() {
        updateInstanceSlider()
    }
}

// MARK: - UIScrollViewDelegate

extension ModernViewerViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageView()
    }
}