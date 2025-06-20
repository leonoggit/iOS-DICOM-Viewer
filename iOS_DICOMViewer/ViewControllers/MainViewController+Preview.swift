//
//  MainViewController+Preview.swift
//  iOS_DICOMViewer
//
//  SwiftUI Preview for MainViewController
//

#if DEBUG
import SwiftUI

struct MainViewControllerPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MainViewController {
        let mainVC = MainViewController()
        
        // The MainViewController handles its own initialization
        // and service setup in viewDidLoad, so we don't need to
        // provide any mock data here
        
        return mainVC
    }
    
    func updateUIViewController(_ uiViewController: MainViewController, context: Context) {
        // No updates needed for preview
    }
}

#Preview("Main View Controller") {
    MainViewControllerPreview()
        .previewDisplayName("Main View Controller")
}

#Preview("Main View Controller - Dark Mode") {
    MainViewControllerPreview()
        .preferredColorScheme(.dark)
        .previewDisplayName("Main View Controller (Dark)")
}

#Preview("Main View Controller - iPad") {
    MainViewControllerPreview()
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
        .previewDisplayName("Main View Controller (iPad)")
}
#endif 