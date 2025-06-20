//
//  AutoSegmentationViewController.swift
//  iOS_DICOMViewer
//
//  Advanced 3D visualization and AI-powered segmentation interface
//  Combines volume rendering with automatic organ segmentation
//

import UIKit
import Metal
import MetalKit

class AutoSegmentationViewController: UIViewController {
    
    // MARK: - Properties
    
    private var study: DICOMStudy?
    private var currentInstance: DICOMInstance?
    private var segmentationResults: [SegmentationResult] = []
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    // 3D Volume Rendering View
    private lazy var volumeRenderingView: MTKView = {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        mtkView.layer.cornerRadius = 12
        mtkView.layer.masksToBounds = true
        return mtkView
    }()
    
    // Control Panel
    private lazy var controlPanelView: UIView = {
        let view = UIView()
        let surfaceDarkSecondary = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 1.0)
        view.backgroundColor = surfaceDarkSecondary
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Segmentation Controls
    private lazy var segmentationControlsView: UIView = {
        let view = UIView()
        let surfaceDarkSecondary = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 1.0)
        view.backgroundColor = surfaceDarkSecondary
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Results View
    private lazy var resultsView: UIView = {
        let view = UIView()
        let surfaceDarkSecondary = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 1.0)
        view.backgroundColor = surfaceDarkSecondary
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupVolumeRendering()
        setupControlPanels()
        setupWelcomeState()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        // Colors from HTML template
        let backgroundDark = UIColor(red: 17/255, green: 22/255, blue: 24/255, alpha: 1.0)
        view.backgroundColor = backgroundDark
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }
    
    private func setupNavigationBar() {
        title = "3D & AI Analysis"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Add info button
        let infoButton = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(showInfoTapped)
        )
        let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        infoButton.tintColor = primaryColor
        navigationItem.rightBarButtonItem = infoButton
    }
    
    private func setupVolumeRendering() {
        contentStackView.addArrangedSubview(volumeRenderingView)
        
        // Set aspect ratio for iPhone 16 Pro Max optimal viewing
        volumeRenderingView.heightAnchor.constraint(equalTo: volumeRenderingView.widthAnchor, multiplier: 0.75).isActive = true
        
        // Add placeholder content
        let placeholderLabel = UILabel()
        placeholderLabel.text = "📊 3D Volume Rendering\nLoad a DICOM study to begin"
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        placeholderLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        placeholderLabel.textColor = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        
        volumeRenderingView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: volumeRenderingView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: volumeRenderingView.centerYAnchor)
        ])
    }
    
    private func setupControlPanels() {
        contentStackView.addArrangedSubview(controlPanelView)
        contentStackView.addArrangedSubview(segmentationControlsView)
        contentStackView.addArrangedSubview(resultsView)
        
        setupControlPanelContent()
        setupSegmentationControlsContent()
        setupResultsContent()
    }
    
    private func setupControlPanelContent() {
        let titleLabel = createSectionTitle("🎛️ Rendering Controls")
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Rendering Mode Selector
        let renderingModeControl = createControlRow(
            title: "Rendering Mode",
            control: createSegmentedControl(items: ["Ray Casting", "MIP", "Isosurface"])
        )
        
        // Quality Selector
        let qualityControl = createControlRow(
            title: "Quality",
            control: createSegmentedControl(items: ["Low", "Medium", "High", "Ultra"])
        )
        
        // Transfer Function
        let transferFunctionControl = createControlRow(
            title: "Transfer Function",
            control: createSegmentedControl(items: ["CT", "MR", "Bone", "Soft"])
        )
        
        // Window/Level Controls
        let windowLevelView = createWindowLevelControls()
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(renderingModeControl)
        stackView.addArrangedSubview(qualityControl)
        stackView.addArrangedSubview(transferFunctionControl)
        stackView.addArrangedSubview(windowLevelView)
        
        controlPanelView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: controlPanelView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: controlPanelView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: controlPanelView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: controlPanelView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupSegmentationControlsContent() {
        let titleLabel = createSectionTitle("🧠 AI Segmentation")
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Segmentation buttons
        let buttonStackView = UIStackView()
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .fillEqually
        buttonStackView.spacing = 12
        
        let urinaryButton = createActionButton(
            title: "🩿 Urinary Tract",
            subtitle: "Kidneys, Ureters, Bladder",
            action: #selector(performUrinaryTractSegmentation)
        )
        
        let organButton = createActionButton(
            title: "🫀 Multi-Organ",
            subtitle: "Liver, Spleen, Pancreas",
            action: #selector(performMultiOrganSegmentation)
        )
        
        buttonStackView.addArrangedSubview(urinaryButton)
        buttonStackView.addArrangedSubview(organButton)
        
        // Progress indicator
        let progressView = UIProgressView(progressViewStyle: .default)
        let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        progressView.progressTintColor = primaryColor
        progressView.isHidden = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(buttonStackView)
        stackView.addArrangedSubview(progressView)
        
        segmentationControlsView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: segmentationControlsView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: segmentationControlsView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: segmentationControlsView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: segmentationControlsView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupResultsContent() {
        let titleLabel = createSectionTitle("📊 Analysis Results")
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let placeholderLabel = UILabel()
        placeholderLabel.text = "No segmentation results yet.\nRun AI analysis to see detailed metrics."
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        placeholderLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        placeholderLabel.textColor = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(placeholderLabel)
        
        resultsView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: resultsView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: resultsView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: resultsView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: resultsView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupWelcomeState() {
        // Show welcome message when no study is loaded
        updateUIForNoStudy()
    }
    
    // MARK: - Helper Methods
    
    private func createSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = UIColor.white
        return label
    }
    
    private func createSegmentedControl(items: [String]) -> UISegmentedControl {
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        segmentedControl.selectedSegmentTintColor = primaryColor
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        return segmentedControl
    }
    
    private func createControlRow(title: String, control: UIView) -> UIView {
        let containerView = UIView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.white
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(control)
        
        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    private func createWindowLevelControls() -> UIView {
        let containerView = UIView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Window/Level"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.white
        
        let slidersStackView = UIStackView()
        slidersStackView.axis = .horizontal
        slidersStackView.distribution = .fillEqually
        slidersStackView.spacing = 16
        
        let windowSlider = createSlider(title: "Window", value: 400, range: 1...2000)
        let levelSlider = createSlider(title: "Level", value: 40, range: -1000...1000)
        
        slidersStackView.addArrangedSubview(windowSlider)
        slidersStackView.addArrangedSubview(levelSlider)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(slidersStackView)
        
        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    private func createSlider(title: String, value: Float, range: ClosedRange<Float>) -> UIView {
        let containerView = UIView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        titleLabel.textColor = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        
        let slider = UISlider()
        slider.minimumValue = range.lowerBound
        slider.maximumValue = range.upperBound
        slider.value = value
        let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        slider.thumbTintColor = primaryColor
        slider.minimumTrackTintColor = primaryColor
        
        let valueLabel = UILabel()
        valueLabel.text = String(Int(value))
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        valueLabel.textColor = UIColor.white
        valueLabel.textAlignment = .center
        
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
    
    private func createActionButton(title: String, subtitle: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.addTarget(self, action: action, for: .touchUpInside)
        
        let accentTeal = UIColor(red: 20/255, green: 184/255, blue: 166/255, alpha: 1.0)
        button.backgroundColor = accentTeal
        button.layer.cornerRadius = 8
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        
        // Create attributed title with subtitle
        let attributedTitle = NSMutableAttributedString()
        attributedTitle.append(NSAttributedString(
            string: title + "\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
        ))
        attributedTitle.append(NSAttributedString(
            string: subtitle,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8)
            ]
        ))
        
        button.setAttributedTitle(attributedTitle, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        
        button.heightAnchor.constraint(equalToConstant: 80).isActive = true
        
        return button
    }
    
    private func updateUIForNoStudy() {
        // Disable controls when no study is loaded
        controlPanelView.alpha = 0.5
        segmentationControlsView.alpha = 0.5
        controlPanelView.isUserInteractionEnabled = false
        segmentationControlsView.isUserInteractionEnabled = false
    }
    
    private func updateUIForStudyLoaded() {
        // Enable controls when study is loaded
        controlPanelView.alpha = 1.0
        segmentationControlsView.alpha = 1.0
        controlPanelView.isUserInteractionEnabled = true
        segmentationControlsView.isUserInteractionEnabled = true
    }
    
    // MARK: - Actions
    
    @objc private func showInfoTapped() {
        let alert = UIAlertController(
            title: "3D & AI Analysis",
            message: "Advanced volume rendering and AI-powered segmentation for medical imaging analysis.\n\n• GPU-accelerated 3D rendering\n• Clinical-grade segmentation\n• Real-time visualization\n• Quantitative analysis",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func performUrinaryTractSegmentation() {
        print("🩿 Starting urinary tract segmentation...")
        // Implementation will use existing UrinaryTractSegmentationService
    }
    
    @objc private func performMultiOrganSegmentation() {
        print("🫀 Starting multi-organ segmentation...")
        // Implementation will use AutomaticSegmentationService
    }
    
    // MARK: - Public Methods
    
    func loadStudy(_ study: DICOMStudy) {
        self.study = study
        DispatchQueue.main.async {
            self.updateUIForStudyLoaded()
            self.refreshVolumeRendering()
        }
    }
    
    private func refreshVolumeRendering() {
        // Implementation for 3D volume rendering
        print("📊 3D: Refreshing volume rendering for study")
    }
}

// MARK: - Segmentation Result Model

struct SegmentationResult {
    let organName: String
    let volume: Double
    let confidence: Double
    let processingTime: TimeInterval
    let qualityMetrics: [String: Double]
}