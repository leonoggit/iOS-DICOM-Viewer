//
//  StudyListViewController+Preview.swift
//  iOS_DICOMViewer
//
//  SwiftUI Preview for StudyListViewController
//

#if DEBUG
import SwiftUI

struct StudyListViewControllerPreview: UIViewControllerRepresentable {
    let showMockData: Bool
    
    init(showMockData: Bool = true) {
        self.showMockData = showMockData
    }
    
    func makeUIViewController(context: Context) -> StudyListViewController {
        let studyListVC = StudyListViewController()
        
        if showMockData {
            // Create mock studies for preview
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.addMockStudies(to: studyListVC)
            }
        }
        
        return studyListVC
    }
    
    func updateUIViewController(_ uiViewController: StudyListViewController, context: Context) {
        // No updates needed for preview
    }
    
    private func addMockStudies(to viewController: StudyListViewController) {
        // Use MockDataProvider for consistent mock data
        let mockStudies = MockDataProvider.shared.createMockStudies()
        
        // Simulate studies being loaded
        NotificationCenter.default.post(
            name: .studiesDidUpdate,
            object: nil,
            userInfo: ["studies": mockStudies]
        )
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let studiesDidUpdate = Notification.Name("studiesDidUpdate")
}

#Preview("Study List - With Data") {
    StudyListViewControllerPreview(showMockData: true)
        .previewDisplayName("Study List (With Mock Data)")
}

#Preview("Study List - Empty State") {
    StudyListViewControllerPreview(showMockData: false)
        .previewDisplayName("Study List (Empty State)")
}

#Preview("Study List - Dark Mode") {
    StudyListViewControllerPreview(showMockData: true)
        .preferredColorScheme(.dark)
        .previewDisplayName("Study List (Dark Mode)")
}

#Preview("Study List - iPad") {
    StudyListViewControllerPreview(showMockData: true)
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
        .previewDisplayName("Study List (iPad)")
}
#endif 