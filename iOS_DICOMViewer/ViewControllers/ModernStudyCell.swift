import UIKit

class ModernStudyCell: UICollectionViewCell {
    static let identifier = "ModernStudyCell"
    
    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.systemGray6
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .label
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let modalityLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.textColor = .systemBlue
        label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 4
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
        
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // Thumbnail image (top area)
            thumbnailImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            thumbnailImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            thumbnailImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            thumbnailImageView.heightAnchor.constraint(equalTo: thumbnailImageView.widthAnchor, multiplier: 0.75),
            
            // Loading indicator (centered on thumbnail)
            loadingIndicator.centerXAnchor.constraint(equalTo: thumbnailImageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: thumbnailImageView.centerYAnchor),
            
            // Modality badge (top-right corner of thumbnail)
            modalityLabel.topAnchor.constraint(equalTo: thumbnailImageView.topAnchor, constant: 8),
            modalityLabel.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: -8),
            modalityLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),
            modalityLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // Title and subtitle below thumbnail
            titleLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12)
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