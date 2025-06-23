import UIKit

class StudyHeaderView: UICollectionReusableView {
    static let identifier = "StudyHeaderView"
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = DeviceLayoutUtility.shared.scaledFont(size: 20, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.font = DeviceLayoutUtility.shared.scaledFont(size: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
        backgroundColor = .systemGroupedBackground
        
        addSubview(titleLabel)
        addSubview(countLabel)
        
        let spacing = DeviceLayoutUtility.shared.spacing(16)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: spacing),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -spacing),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: DeviceLayoutUtility.shared.spacing(8))
        ])
    }
    
    func configure(title: String, count: Int) {
        titleLabel.text = title
        countLabel.text = "\(count) studies"
    }
}