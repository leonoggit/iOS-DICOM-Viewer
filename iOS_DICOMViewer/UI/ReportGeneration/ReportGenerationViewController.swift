//
//  ReportGenerationViewController.swift
//  iOS_DICOMViewer
//
//  Revolutionary AI-Powered Report Generation Interface
//

import UIKit
import SwiftUI
import Combine
import PDFKit

// MARK: - Report Generation View Controller

class ReportGenerationViewController: UIViewController {
    
    // MARK: - Properties
    
    private let reportEngine = MedicalReportEngine()
    private var study: DICOMStudy?
    private var images: [DICOMInstance] = []
    private var cancellables = Set<AnyCancellable>()
    
    // UI Components
    private lazy var scrollView = UIScrollView()
    private lazy var contentStackView = UIStackView()
    private lazy var progressView = ReportGenerationProgressView()
    private lazy var reportPreviewView = ReportPreviewView()
    private lazy var actionButtonsView = ReportActionButtonsView()
    
    // State
    @Published private var generationState: GenerationState = .idle
    @Published private var currentReport: MedicalReport?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        configureNavigationBar()
    }
    
    // MARK: - Public Methods
    
    func configure(with study: DICOMStudy, images: [DICOMInstance]) {
        self.study = study
        self.images = images
        updateUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.067, green: 0.086, blue: 0.094, alpha: 1.0)
        
        // Scroll view setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Content stack view
        contentStackView.axis = .vertical
        contentStackView.spacing = 20
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)
        
        // Add components
        contentStackView.addArrangedSubview(createHeaderView())
        contentStackView.addArrangedSubview(progressView)
        contentStackView.addArrangedSubview(reportPreviewView)
        contentStackView.addArrangedSubview(actionButtonsView)
        
        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        // Initial state
        progressView.isHidden = true
        reportPreviewView.isHidden = true
    }
    
    private func setupBindings() {
        // Bind generation progress
        reportEngine.$generationProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.updateProgress(progress)
            }
            .store(in: &cancellables)
        
        // Bind report updates
        reportEngine.$activeReport
            .receive(on: DispatchQueue.main)
            .sink { [weak self] report in
                self?.updateReportPreview(report)
            }
            .store(in: &cancellables)
        
        // Action buttons
        actionButtonsView.onGenerateReport = { [weak self] in
            self?.generateReport()
        }
        
        actionButtonsView.onExportPDF = { [weak self] in
            self?.exportReportAsPDF()
        }
        
        actionButtonsView.onSendReport = { [weak self] in
            self?.sendReport()
        }
    }
    
    // MARK: - Report Generation
    
    private func generateReport() {
        guard let study = study else { return }
        
        generationState = .generating
        progressView.isHidden = false
        
        Task {
            do {
                // Get additional data
                let segmentations = await getSegmentations()
                let measurements = await getMeasurements()
                let priorStudies = await getPriorStudies()
                
                // Generate report
                let report = try await reportEngine.generateReport(
                    for: study,
                    images: images,
                    segmentations: segmentations,
                    measurements: measurements,
                    priorStudies: priorStudies,
                    reportType: determineReportType()
                )
                
                await MainActor.run {
                    self.currentReport = report
                    self.generationState = .completed
                    self.showReportGenerated()
                }
                
            } catch {
                await MainActor.run {
                    self.generationState = .failed(error)
                    self.showError(error)
                }
            }
        }
    }
    
    // MARK: - UI Updates
    
    private func updateProgress(_ progress: GenerationProgress) {
        progressView.updateProgress(
            phase: progress.phase,
            value: progress.progress,
            status: progress.status
        )
        
        if let timeRemaining = progress.estimatedTimeRemaining {
            progressView.updateTimeRemaining(timeRemaining)
        }
    }
    
    private func updateReportPreview(_ report: MedicalReport?) {
        guard let report = report else {
            reportPreviewView.isHidden = true
            return
        }
        
        reportPreviewView.isHidden = false
        reportPreviewView.displayReport(report)
        
        // Enable action buttons
        actionButtonsView.enableActions(true)
    }
}

// MARK: - Progress View

class ReportGenerationProgressView: UIView {
    
    private let phaseLabel = UILabel()
    private let statusLabel = UILabel()
    private let progressBar = UIProgressView()
    private let timeRemainingLabel = UILabel()
    private let animationView = GenerationAnimationView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        layer.cornerRadius = 16
        
        // Configure labels
        phaseLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        phaseLabel.textColor = .cyan
        
        statusLabel.font = .systemFont(ofSize: 14, weight: .regular)
        statusLabel.textColor = .lightGray
        statusLabel.numberOfLines = 0
        
        timeRemainingLabel.font = .systemFont(ofSize: 12, weight: .medium)
        timeRemainingLabel.textColor = .gray
        
        // Progress bar
        progressBar.progressTintColor = .cyan
        progressBar.trackTintColor = UIColor(white: 0.2, alpha: 1.0)
        
        // Layout
        let stackView = UIStackView(arrangedSubviews: [
            animationView,
            phaseLabel,
            statusLabel,
            progressBar,
            timeRemainingLabel
        ])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            
            animationView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    func updateProgress(phase: GenerationProgress.GenerationPhase, value: Float, status: String) {
        phaseLabel.text = phase.displayName
        statusLabel.text = status
        progressBar.setProgress(value, animated: true)
        
        // Update animation based on phase
        animationView.updatePhase(phase)
    }
    
    func updateTimeRemaining(_ time: TimeInterval) {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        
        timeRemainingLabel.text = "Est. time remaining: \(formatter.string(from: time) ?? "calculating...")"
    }
}

// MARK: - Report Preview View

class ReportPreviewView: UIView {
    
    private let titleLabel = UILabel()
    private let reportTextView = UITextView()
    private let findingsCollectionView: UICollectionView
    private let tabSegmentedControl = UISegmentedControl()
    
    private var report: MedicalReport?
    
    override init(frame: CGRect) {
        // Collection view layout
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 200, height: 100)
        
        findingsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        layer.cornerRadius = 16
        
        // Title
        titleLabel.text = "Generated Report"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        
        // Segmented control
        tabSegmentedControl.insertSegment(withTitle: "Full Report", at: 0, animated: false)
        tabSegmentedControl.insertSegment(withTitle: "Key Findings", at: 1, animated: false)
        tabSegmentedControl.insertSegment(withTitle: "Impressions", at: 2, animated: false)
        tabSegmentedControl.selectedSegmentIndex = 0
        tabSegmentedControl.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        
        // Report text view
        reportTextView.backgroundColor = UIColor(white: 0.05, alpha: 1.0)
        reportTextView.textColor = .white
        reportTextView.font = .systemFont(ofSize: 14)
        reportTextView.isEditable = false
        reportTextView.layer.cornerRadius = 8
        
        // Findings collection view
        findingsCollectionView.backgroundColor = .clear
        findingsCollectionView.isHidden = true
        
        // Layout
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            tabSegmentedControl,
            reportTextView,
            findingsCollectionView
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            
            reportTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            findingsCollectionView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    func displayReport(_ report: MedicalReport) {
        self.report = report
        updateDisplay()
    }
    
    @objc private func tabChanged() {
        updateDisplay()
    }
    
    private func updateDisplay() {
        guard let report = report else { return }
        
        switch tabSegmentedControl.selectedSegmentIndex {
        case 0: // Full Report
            reportTextView.text = report.fullText
            reportTextView.isHidden = false
            findingsCollectionView.isHidden = true
            
        case 1: // Key Findings
            reportTextView.isHidden = true
            findingsCollectionView.isHidden = false
            findingsCollectionView.reloadData()
            
        case 2: // Impressions
            reportTextView.text = report.sections.impression
            reportTextView.isHidden = false
            findingsCollectionView.isHidden = true
            
        default:
            break
        }
    }
}

// MARK: - Action Buttons View

class ReportActionButtonsView: UIView {
    
    var onGenerateReport: (() -> Void)?
    var onExportPDF: (() -> Void)?
    var onSendReport: (() -> Void)?
    var onEditReport: (() -> Void)?
    
    private let generateButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private let editButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Configure buttons
        generateButton.setTitle("Generate Report", for: .normal)
        generateButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        generateButton.backgroundColor = .cyan
        generateButton.setTitleColor(.black, for: .normal)
        generateButton.layer.cornerRadius = 12
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        
        exportButton.setTitle("Export PDF", for: .normal)
        exportButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        exportButton.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 10
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        exportButton.isEnabled = false
        
        sendButton.setTitle("Send Report", for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        sendButton.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.layer.cornerRadius = 10
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.isEnabled = false
        
        editButton.setTitle("Edit", for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        editButton.setTitleColor(.cyan, for: .normal)
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        editButton.isEnabled = false
        
        // Layout
        let mainStackView = UIStackView(arrangedSubviews: [generateButton])
        mainStackView.axis = .vertical
        mainStackView.spacing = 16
        
        let secondaryStackView = UIStackView(arrangedSubviews: [exportButton, sendButton, editButton])
        secondaryStackView.axis = .horizontal
        secondaryStackView.spacing = 12
        secondaryStackView.distribution = .fillEqually
        
        let stackView = UIStackView(arrangedSubviews: [mainStackView, secondaryStackView])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            generateButton.heightAnchor.constraint(equalToConstant: 56),
            exportButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    func enableActions(_ enabled: Bool) {
        exportButton.isEnabled = enabled
        sendButton.isEnabled = enabled
        editButton.isEnabled = enabled
        
        UIView.animate(withDuration: 0.3) {
            self.exportButton.alpha = enabled ? 1.0 : 0.5
            self.sendButton.alpha = enabled ? 1.0 : 0.5
            self.editButton.alpha = enabled ? 1.0 : 0.5
        }
    }
    
    @objc private func generateTapped() {
        onGenerateReport?()
    }
    
    @objc private func exportTapped() {
        onExportPDF?()
    }
    
    @objc private func sendTapped() {
        onSendReport?()
    }
    
    @objc private func editTapped() {
        onEditReport?()
    }
}

// MARK: - Generation Animation View

class GenerationAnimationView: UIView {
    
    private var animationLayers: [CALayer] = []
    private var currentPhase: GenerationProgress.GenerationPhase = .idle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAnimation()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAnimation() {
        backgroundColor = .clear
        
        // Create multiple animated layers for complex visualization
        for i in 0..<3 {
            let layer = createAnimationLayer(index: i)
            animationLayers.append(layer)
            self.layer.addSublayer(layer)
        }
    }
    
    private func createAnimationLayer(index: Int) -> CALayer {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.cyan.withAlphaComponent(0.3).cgColor
        layer.strokeColor = UIColor.cyan.cgColor
        layer.lineWidth = 2.0
        
        // Create different shapes for each layer
        let path: UIBezierPath
        switch index {
        case 0:
            path = UIBezierPath(arcCenter: CGPoint(x: 50, y: 50),
                               radius: 30,
                               startAngle: 0,
                               endAngle: .pi * 2,
                               clockwise: true)
        case 1:
            path = UIBezierPath(rect: CGRect(x: 70, y: 30, width: 40, height: 40))
        default:
            path = UIBezierPath()
            path.move(to: CGPoint(x: 130, y: 50))
            path.addLine(to: CGPoint(x: 150, y: 20))
            path.addLine(to: CGPoint(x: 170, y: 50))
            path.addLine(to: CGPoint(x: 150, y: 80))
            path.close()
        }
        
        layer.path = path.cgPath
        return layer
    }
    
    func updatePhase(_ phase: GenerationProgress.GenerationPhase) {
        currentPhase = phase
        
        // Remove existing animations
        animationLayers.forEach { $0.removeAllAnimations() }
        
        // Add phase-specific animations
        switch phase {
        case .analyzing:
            addAnalyzingAnimation()
        case .extracting:
            addExtractingAnimation()
        case .generating:
            addGeneratingAnimation()
        case .formatting:
            addFormattingAnimation()
        case .completed:
            addCompletedAnimation()
        default:
            break
        }
    }
    
    private func addAnalyzingAnimation() {
        // Scanning animation
        for (index, layer) in animationLayers.enumerated() {
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = 0
            animation.toValue = CGFloat.pi * 2
            animation.duration = 2.0 + Double(index) * 0.5
            animation.repeatCount = .infinity
            layer.add(animation, forKey: "rotation")
        }
    }
    
    private func addExtractingAnimation() {
        // Pulsing animation
        for layer in animationLayers {
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.fromValue = 1.0
            animation.toValue = 1.2
            animation.duration = 0.8
            animation.autoreverses = true
            animation.repeatCount = .infinity
            layer.add(animation, forKey: "pulse")
        }
    }
    
    private func addGeneratingAnimation() {
        // Complex generation animation
        for (index, layer) in animationLayers.enumerated() {
            let group = CAAnimationGroup()
            
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [1.0, 1.3, 0.8, 1.0]
            scale.keyTimes = [0, 0.3, 0.6, 1.0]
            
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [1.0, 0.5, 1.0]
            opacity.keyTimes = [0, 0.5, 1.0]
            
            group.animations = [scale, opacity]
            group.duration = 1.5 + Double(index) * 0.3
            group.repeatCount = .infinity
            
            layer.add(group, forKey: "generate")
        }
    }
    
    private func addFormattingAnimation() {
        // Smooth transition animation
        for layer in animationLayers {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = 0
            animation.toValue = 1
            animation.duration = 1.0
            animation.repeatCount = .infinity
            layer.add(animation, forKey: "format")
        }
    }
    
    private func addCompletedAnimation() {
        // Success animation
        for layer in animationLayers {
            let animation = CASpringAnimation(keyPath: "transform.scale")
            animation.fromValue = 1.0
            animation.toValue = 1.5
            animation.damping = 10
            animation.initialVelocity = 5
            animation.duration = 0.5
            layer.add(animation, forKey: "complete")
            
            // Fade out
            UIView.animate(withDuration: 1.0, delay: 0.5) {
                layer.opacity = 0.3
            }
        }
    }
}

// MARK: - Supporting Types

enum GenerationState {
    case idle
    case generating
    case completed
    case failed(Error)
}

extension GenerationProgress.GenerationPhase {
    var displayName: String {
        switch self {
        case .idle:
            return "Ready"
        case .analyzing:
            return "Analyzing Images"
        case .extracting:
            return "Extracting Findings"
        case .generating:
            return "Generating Report"
        case .formatting:
            return "Formatting"
        case .completed:
            return "Completed"
        }
    }
}

// MARK: - Integration Extension

extension ModernViewerViewController {
    
    /// Add report generation button to viewer
    func addReportGenerationButton() {
        let reportButton = UIButton(type: .system)
        reportButton.setImage(UIImage(systemName: "doc.text.fill"), for: .normal)
        reportButton.tintColor = .cyan
        reportButton.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        reportButton.layer.cornerRadius = 22
        reportButton.addTarget(self, action: #selector(showReportGeneration), for: .touchUpInside)
        
        view.addSubview(reportButton)
        reportButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            reportButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            reportButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            reportButton.widthAnchor.constraint(equalToConstant: 44),
            reportButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func showReportGeneration() {
        guard let study = study else { return }
        
        let reportVC = ReportGenerationViewController()
        reportVC.configure(with: study, images: study.allInstances)
        
        let navController = UINavigationController(rootViewController: reportVC)
        navController.modalPresentationStyle = .fullScreen
        
        present(navController, animated: true)
    }
}