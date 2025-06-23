//
//  AnomalyDetectionUIComponents.swift
//  iOS_DICOMViewer
//
//  Custom UI components for anomaly detection visualization
//

import UIKit
import Metal

// MARK: - Anomaly Cell
class AnomalyCell: UITableViewCell {
    
    private let typeLabel = UILabel()
    private let confidenceLabel = UILabel()
    private let severityIndicator = UIView()
    private let explanationLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        let containerView = UIView()
        containerView.backgroundColor = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 1.0)
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(containerView)
        
        // Setup labels
        typeLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        typeLabel.textColor = .white
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        confidenceLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        confidenceLabel.textColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        severityIndicator.layer.cornerRadius = 4
        severityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        explanationLabel.font = .systemFont(ofSize: 14, weight: .regular)
        explanationLabel.textColor = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        explanationLabel.numberOfLines = 2
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(severityIndicator)
        containerView.addSubview(typeLabel)
        containerView.addSubview(confidenceLabel)
        containerView.addSubview(explanationLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            severityIndicator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            severityIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            severityIndicator.widthAnchor.constraint(equalToConstant: 8),
            severityIndicator.heightAnchor.constraint(equalToConstant: 40),
            
            typeLabel.leadingAnchor.constraint(equalTo: severityIndicator.trailingAnchor, constant: 12),
            typeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            
            confidenceLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            confidenceLabel.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            
            explanationLabel.leadingAnchor.constraint(equalTo: typeLabel.leadingAnchor),
            explanationLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 4),
            explanationLabel.trailingAnchor.constraint(equalTo: confidenceLabel.leadingAnchor, constant: -8),
            explanationLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with anomaly: DetectedAnomaly) {
        typeLabel.text = anomaly.type.rawValue
        confidenceLabel.text = "\(Int(anomaly.confidence * 100))%"
        severityIndicator.backgroundColor = anomaly.severity.color
        explanationLabel.text = anomaly.explanation
    }
}

// MARK: - Confidence Meter View
class ConfidenceMeterView: UIView {
    
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let progressView = UIProgressView()
    private let descriptionLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        titleLabel.text = "Overall Confidence"
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        valueLabel.text = "0%"
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        progressView.progressTintColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        progressView.trackTintColor = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 1.0)
        progressView.layer.cornerRadius = 4
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        descriptionLabel.text = "AI confidence in detected anomalies"
        descriptionLabel.font = .systemFont(ofSize: 12, weight: .regular)
        descriptionLabel.textColor = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 0.7)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(progressView)
        addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            progressView.heightAnchor.constraint(equalToConstant: 8),
            
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 4),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func setConfidence(_ confidence: Float) {
        UIView.animate(withDuration: 0.3) {
            self.progressView.setProgress(confidence, animated: true)
            self.valueLabel.text = "\(Int(confidence * 100))%"
            
            // Update color based on confidence level
            if confidence >= 0.8 {
                self.progressView.progressTintColor = UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1.0)
            } else if confidence >= 0.6 {
                self.progressView.progressTintColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
            } else {
                self.progressView.progressTintColor = UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1.0)
            }
        }
    }
}

// MARK: - Processing Indicator View
class ProcessingIndicatorView: UIView {
    
    private let circleLayer = CAShapeLayer()
    private let pulseLayer = CAShapeLayer()
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor(red: 27/255, green: 36/255, blue: 39/255, alpha: 0.95)
        layer.cornerRadius = 12
        
        // Create circle path
        let circlePath = UIBezierPath(
            arcCenter: CGPoint(x: 50, y: 40),
            radius: 20,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        
        // Setup pulse layer
        pulseLayer.path = circlePath.cgPath
        pulseLayer.fillColor = UIColor.clear.cgColor
        pulseLayer.strokeColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 0.3).cgColor
        pulseLayer.lineWidth = 3
        layer.addSublayer(pulseLayer)
        
        // Setup circle layer
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0).cgColor
        circleLayer.lineWidth = 3
        circleLayer.strokeEnd = 0
        layer.addSublayer(circleLayer)
        
        // Setup label
        label.text = "Analyzing..."
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    func startAnimating() {
        // Rotation animation
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: Double.pi * 2)
        rotation.duration = 1.5
        rotation.repeatCount = .infinity
        circleLayer.add(rotation, forKey: "rotation")
        
        // Stroke animation
        let strokeAnimation = CABasicAnimation(keyPath: "strokeEnd")
        strokeAnimation.fromValue = 0
        strokeAnimation.toValue = 1
        strokeAnimation.duration = 1.0
        strokeAnimation.repeatCount = .infinity
        circleLayer.add(strokeAnimation, forKey: "stroke")
        
        // Pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1
        pulseAnimation.toValue = 1.2
        pulseAnimation.duration = 1.0
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        pulseLayer.add(pulseAnimation, forKey: "pulse")
    }
    
    func stopAnimating() {
        circleLayer.removeAllAnimations()
        pulseLayer.removeAllAnimations()
    }
}

// MARK: - Explanation Detail View
class ExplanationDetailView: UIView {
    
    private let containerView = UIView()
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let explanationTextView = UITextView()
    private let heatmapImageView = UIImageView()
    private let differentialDiagnosisView = UIStackView()
    private let relatedFindingsView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        containerView.backgroundColor = UIColor(red: 27/255, green: 36/255, blue: 39/255, alpha: 1.0)
        containerView.layer.cornerRadius = 24
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        explanationTextView.backgroundColor = .clear
        explanationTextView.font = .systemFont(ofSize: 16, weight: .regular)
        explanationTextView.textColor = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        explanationTextView.isEditable = false
        explanationTextView.isScrollEnabled = false
        explanationTextView.translatesAutoresizingMaskIntoConstraints = false
        
        heatmapImageView.contentMode = .scaleAspectFit
        heatmapImageView.layer.cornerRadius = 12
        heatmapImageView.clipsToBounds = true
        heatmapImageView.translatesAutoresizingMaskIntoConstraints = false
        
        differentialDiagnosisView.axis = .vertical
        differentialDiagnosisView.spacing = 8
        differentialDiagnosisView.translatesAutoresizingMaskIntoConstraints = false
        
        relatedFindingsView.axis = .vertical
        relatedFindingsView.spacing = 8
        relatedFindingsView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerView)
        containerView.addSubview(closeButton)
        containerView.addSubview(titleLabel)
        containerView.addSubview(explanationTextView)
        containerView.addSubview(heatmapImageView)
        containerView.addSubview(differentialDiagnosisView)
        containerView.addSubview(relatedFindingsView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -16),
            
            heatmapImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            heatmapImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            heatmapImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            heatmapImageView.heightAnchor.constraint(equalToConstant: 200),
            
            explanationTextView.topAnchor.constraint(equalTo: heatmapImageView.bottomAnchor, constant: 16),
            explanationTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            explanationTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            differentialDiagnosisView.topAnchor.constraint(equalTo: explanationTextView.bottomAnchor, constant: 16),
            differentialDiagnosisView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            differentialDiagnosisView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            relatedFindingsView.topAnchor.constraint(equalTo: differentialDiagnosisView.bottomAnchor, constant: 16),
            relatedFindingsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            relatedFindingsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            relatedFindingsView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    func showAnomaly(_ anomaly: DetectedAnomaly) {
        titleLabel.text = anomaly.type.rawValue
        explanationTextView.text = anomaly.explanation
        
        // Clear previous views
        differentialDiagnosisView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        relatedFindingsView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add differential diagnosis
        if !anomaly.differentialDiagnosis.isEmpty {
            let ddTitle = createSectionTitle("Differential Diagnosis")
            differentialDiagnosisView.addArrangedSubview(ddTitle)
            
            for diagnosis in anomaly.differentialDiagnosis {
                let label = createItemLabel(diagnosis)
                differentialDiagnosisView.addArrangedSubview(label)
            }
        }
        
        // Add related findings
        if !anomaly.relatedFindings.isEmpty {
            let rfTitle = createSectionTitle("Related Findings")
            relatedFindingsView.addArrangedSubview(rfTitle)
            
            for finding in anomaly.relatedFindings {
                let label = createItemLabel(finding)
                relatedFindingsView.addArrangedSubview(label)
            }
        }
    }
    
    private func createSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }
    
    private func createItemLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = "• \(text)"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }
    
    @objc private func closeTapped() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
            self.isHidden = true
            self.alpha = 1
        }
    }
}

// MARK: - Clinical Actions Panel
protocol ClinicalActionsPanelDelegate: AnyObject {
    func clinicalActionsPanel(_ panel: ClinicalActionsPanel, didSelectAction action: ClinicalAction)
}

enum ClinicalAction {
    case requestConsultation
    case exportToPACS
    case generateReport
    case markForFollowUp
}

class ClinicalActionsPanel: UIView {
    
    weak var delegate: ClinicalActionsPanelDelegate?
    
    private let stackView = UIStackView()
    private var urgencyLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        urgencyLabel = createUrgencyLabel()
        
        let consultButton = createActionButton(
            title: "Request Consultation",
            icon: "person.2.fill",
            action: .requestConsultation
        )
        
        let exportButton = createActionButton(
            title: "Export to PACS",
            icon: "square.and.arrow.up",
            action: .exportToPACS
        )
        
        let reportButton = createActionButton(
            title: "Generate Report",
            icon: "doc.text.fill",
            action: .generateReport
        )
        
        let followUpButton = createActionButton(
            title: "Mark for Follow-up",
            icon: "calendar.badge.plus",
            action: .markForFollowUp
        )
        
        stackView.addArrangedSubview(urgencyLabel)
        stackView.addArrangedSubview(consultButton)
        stackView.addArrangedSubview(exportButton)
        stackView.addArrangedSubview(reportButton)
        stackView.addArrangedSubview(followUpButton)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func createUrgencyLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        return label
    }
    
    private func createActionButton(title: String, icon: String, action: ClinicalAction) -> UIButton {
        let button = UIButton(type: .system)
        
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.baseBackgroundColor = UIColor(red: 40/255, green: 53/255, blue: 57/255, alpha: 1.0)
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        
        button.configuration = config
        button.tag = action.hashValue
        button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        
        return button
    }
    
    func updateWithContext(_ context: ClinicalContext) {
        // Update urgency label
        switch context.urgencyLevel {
        case .stat:
            urgencyLabel.text = "⚠️ STAT - Immediate Action Required"
            urgencyLabel.backgroundColor = .systemRed
            urgencyLabel.textColor = .white
        case .emergent:
            urgencyLabel.text = "🚨 Emergent - Urgent Review Needed"
            urgencyLabel.backgroundColor = .systemOrange
            urgencyLabel.textColor = .white
        case .urgent:
            urgencyLabel.text = "⏰ Urgent - Prompt Review Recommended"
            urgencyLabel.backgroundColor = .systemYellow
            urgencyLabel.textColor = .black
        case .routine:
            urgencyLabel.text = "✓ Routine - Standard Follow-up"
            urgencyLabel.backgroundColor = .systemGreen
            urgencyLabel.textColor = .white
        }
    }
    
    @objc private func actionButtonTapped(_ sender: UIButton) {
        let actions: [ClinicalAction] = [.requestConsultation, .exportToPACS, .generateReport, .markForFollowUp]
        if let action = actions.first(where: { $0.hashValue == sender.tag }) {
            delegate?.clinicalActionsPanel(self, didSelectAction: action)
        }
    }
}

// MARK: - Anomaly Results Exporter
class AnomalyResultsExporter {
    
    func exportResults(_ results: AnomalyDetectionResult, from viewController: UIViewController) {
        // Create export options
        let alertController = UIAlertController(
            title: "Export Results",
            message: "Choose export format",
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: "DICOM SR", style: .default) { _ in
            self.exportAsDICOMSR(results)
        })
        
        alertController.addAction(UIAlertAction(title: "PDF Report", style: .default) { _ in
            self.exportAsPDF(results, from: viewController)
        })
        
        alertController.addAction(UIAlertAction(title: "JSON", style: .default) { _ in
            self.exportAsJSON(results, from: viewController)
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        viewController.present(alertController, animated: true)
    }
    
    private func exportAsDICOMSR(_ results: AnomalyDetectionResult) {
        // Export as DICOM Structured Report
    }
    
    private func exportAsPDF(_ results: AnomalyDetectionResult, from viewController: UIViewController) {
        // Export as PDF report
    }
    
    private func exportAsJSON(_ results: AnomalyDetectionResult, from viewController: UIViewController) {
        // Export as JSON
    }
}