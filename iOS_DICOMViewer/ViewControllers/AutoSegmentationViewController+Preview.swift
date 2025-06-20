//
//  AutoSegmentationViewController+Preview.swift
//  iOS_DICOMViewer
//
//  SwiftUI Preview for AutoSegmentationViewController
//

#if DEBUG
import SwiftUI

struct AutoSegmentationViewControllerPreview: UIViewControllerRepresentable {
    let withMockData: Bool
    
    init(withMockData: Bool = true) {
        self.withMockData = withMockData
    }
    
    func makeUIViewController(context: Context) -> AutoSegmentationViewController {
        let segmentationVC = AutoSegmentationViewController()
        
        if withMockData {
            // Set up mock DICOM data after view loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setupMockData(for: segmentationVC)
            }
        }
        
        return segmentationVC
    }
    
    func updateUIViewController(_ uiViewController: AutoSegmentationViewController, context: Context) {
        // No updates needed for preview
    }
    
    private func setupMockData(for viewController: AutoSegmentationViewController) {
        // Use MockDataProvider for consistent mock data
        let mockInstance = MockDataProvider.shared.createMockCTInstance()
        
        // Update status label to show mock data is loaded
        if let statusLabel = findStatusLabel(in: viewController.view) {
            statusLabel.text = "Mock CT data loaded - Ready for segmentation"
        }
        
        // Enable segmentation controls
        enableSegmentationControls(in: viewController.view)
    }
    
    private func findStatusLabel(in view: UIView) -> UILabel? {
        for subview in view.subviews {
            if let label = subview as? UILabel {
                return label
            }
            if let foundLabel = findStatusLabel(in: subview) {
                return foundLabel
            }
        }
        return nil
    }
    
    private func enableSegmentationControls(in view: UIView) {
        for subview in view.subviews {
            if let button = subview as? UIButton {
                button.isEnabled = true
            }
            enableSegmentationControls(in: subview)
        }
    }
}

#Preview("Auto Segmentation - With Mock Data") {
    AutoSegmentationViewControllerPreview(withMockData: true)
        .previewDisplayName("Auto Segmentation (With Mock Data)")
}

#Preview("Auto Segmentation - Empty State") {
    AutoSegmentationViewControllerPreview(withMockData: false)
        .previewDisplayName("Auto Segmentation (Empty State)")
}

#Preview("Auto Segmentation - Dark Mode") {
    AutoSegmentationViewControllerPreview(withMockData: true)
        .preferredColorScheme(.dark)
        .previewDisplayName("Auto Segmentation (Dark Mode)")
}

#Preview("Auto Segmentation - iPad") {
    AutoSegmentationViewControllerPreview(withMockData: true)
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
        .previewDisplayName("Auto Segmentation (iPad)")
}
#endif 