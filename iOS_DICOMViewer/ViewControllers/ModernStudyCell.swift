import UIKit

class ModernStudyCell: UICollectionViewCell {
    static let identifier = "ModernStudyCell"
    
    private lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.systemGray6
        imageView.layer.cornerRadius = DeviceLayoutUtility.shared.cornerRadius(base: 8)
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = DeviceLayoutUtility.shared.scaledFont(size: 16, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = DeviceLayoutUtility.shared.scaledFont(size: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var modalityLabel: UILabel = {
        let label = UILabel()
        label.font = DeviceLayoutUtility.shared.scaledFont(size: 12, weight: .bold)
        label.textColor = .systemBlue
        label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        label.textAlignment = .center
        label.layer.cornerRadius = DeviceLayoutUtility.shared.cornerRadius(base: 8)
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = DeviceLayoutUtility.shared.cornerRadius(base: 12)
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: DeviceLayoutUtility.shared.scaled(2))
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = DeviceLayoutUtility.shared.scaled(4)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(thumbnailImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(modalityLabel)
        containerView.addSubview(loadingIndicator)
        
        // Device-specific spacing
        let spacing = DeviceLayoutUtility.shared.spacing(8)
        let padding = DeviceLayoutUtility.shared.spacing(4)
        let contentPadding = DeviceLayoutUtility.shared.spacing(12)
        
        NSLayoutConstraint.activate([
            // Container with device-specific padding
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),
            
            // Thumbnail image with device-specific spacing
            thumbnailImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: spacing),
            thumbnailImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: spacing),
            thumbnailImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -spacing),
            thumbnailImageView.heightAnchor.constraint(equalTo: thumbnailImageView.widthAnchor, multiplier: 0.75),
            
            // Loading indicator (centered on thumbnail)
            loadingIndicator.centerXAnchor.constraint(equalTo: thumbnailImageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: thumbnailImageView.centerYAnchor),
            
            // Modality badge with device-specific sizing
            modalityLabel.topAnchor.constraint(equalTo: thumbnailImageView.topAnchor, constant: spacing),
            modalityLabel.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: -spacing),
            modalityLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: DeviceLayoutUtility.shared.scaled(32)),
            modalityLabel.heightAnchor.constraint(equalToConstant: DeviceLayoutUtility.shared.scaled(20)),
            
            // Title and subtitle with device-specific spacing
            titleLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: spacing),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: contentPadding),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -contentPadding),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DeviceLayoutUtility.shared.spacing(4)),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: contentPadding),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -contentPadding),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -contentPadding)
        ])
    }
    
    func configure(with study: DICOMStudy) {
        titleLabel.text = study.patientName ?? "Unknown Patient"
        subtitleLabel.text = study.studyDescription ?? "No Description"
        
        // Set modality badge
        let modality = study.series.first?.modality ?? "UN"
        modalityLabel.text = modality
        modalityLabel.backgroundColor = modalityColor(for: modality)
        
        // Load thumbnail image asynchronously
        loadThumbnailImage(for: study)
    }
    
    private func modalityColor(for modality: String) -> UIColor {
        switch modality.uppercased() {
        case "CT":
            return UIColor.systemBlue.withAlphaComponent(0.2)
        case "MR":
            return UIColor.systemGreen.withAlphaComponent(0.2)
        case "US":
            return UIColor.systemPurple.withAlphaComponent(0.2)
        case "XA", "RF":
            return UIColor.systemOrange.withAlphaComponent(0.2)
        case "CR", "DX":
            return UIColor.systemIndigo.withAlphaComponent(0.2)
        default:
            return UIColor.systemGray.withAlphaComponent(0.2)
        }
    }
    
    private func loadThumbnailImage(for study: DICOMStudy) {
        // Reset image state
        thumbnailImageView.image = nil
        loadingIndicator.startAnimating()
        
        // Get the first instance from the first series for thumbnail
        guard let firstSeries = study.series.first,
              let firstInstance = firstSeries.instances.first,
              let filePath = firstInstance.filePath else {
            print("❌ ModernStudyCell: No instances found for thumbnail or missing file path")
            loadingIndicator.stopAnimating()
            setPlaceholderImage()
            return
        }
        
        print("🖼️ ModernStudyCell: Loading thumbnail for instance: \(firstInstance.sopInstanceUID)")
        
        // Load thumbnail asynchronously
        Task {
            do {
                let renderer = DICOMImageRenderer()
                let image = try await renderer.renderImage(from: filePath, windowLevel: .abdomen)
                
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    if let image = image {
                        print("✅ ModernStudyCell: Successfully loaded thumbnail image")
                        self.thumbnailImageView.image = image
                    } else {
                        print("❌ ModernStudyCell: Failed to render thumbnail image")
                        self.setPlaceholderImage()
                    }
                }
            } catch {
                print("❌ ModernStudyCell: Error loading thumbnail: \(error)")
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.setPlaceholderImage()
                }
            }
        }
    }
    
    private func setPlaceholderImage() {
        // Create a simple medical-themed placeholder
        let size = CGSize(width: 100, height: 75)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let placeholderImage = renderer.image { context in
            // Background
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Medical cross icon
            UIColor.systemGray4.setStroke()
            let crossPath = UIBezierPath()
            // Vertical line
            crossPath.move(to: CGPoint(x: size.width/2, y: size.height*0.3))
            crossPath.addLine(to: CGPoint(x: size.width/2, y: size.height*0.7))
            // Horizontal line
            crossPath.move(to: CGPoint(x: size.width*0.3, y: size.height/2))
            crossPath.addLine(to: CGPoint(x: size.width*0.7, y: size.height/2))
            crossPath.lineWidth = 3
            crossPath.stroke()
        }
        
        thumbnailImageView.image = placeholderImage
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        loadingIndicator.stopAnimating()
        titleLabel.text = nil
        subtitleLabel.text = nil
        modalityLabel.text = nil
    }
}