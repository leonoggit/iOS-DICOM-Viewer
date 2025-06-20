//
//  AllViewControllers+Preview.swift
//  iOS_DICOMViewer
//
//  Comprehensive SwiftUI Preview for all UIKit View Controllers
//

#if DEBUG
import SwiftUI

struct AllViewControllersPreview: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Main View Controller
            MainViewControllerPreview()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Main")
                }
                .tag(0)
            
            // Study List View Controller
            StudyListViewControllerPreview(showMockData: true)
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Studies")
                }
                .tag(1)
            
            // Viewer View Controller
            ViewerViewControllerPreview()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("Viewer")
                }
                .tag(2)
            
            // Auto Segmentation View Controller
            AutoSegmentationViewControllerPreview(withMockData: true)
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Segmentation")
                }
                .tag(3)
        }
        .preferredColorScheme(.light)
    }
}

struct ViewControllerShowcase: View {
    var body: some View {
        NavigationView {
            List {
                Section("Main Controllers") {
                    NavigationLink("Main View Controller") {
                        MainViewControllerPreview()
                            .navigationTitle("Main View Controller")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    
                    NavigationLink("Study List Controller") {
                        StudyListViewControllerPreview(showMockData: true)
                            .navigationTitle("Study List")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
                
                Section("Viewer Controllers") {
                    NavigationLink("DICOM Viewer") {
                        ViewerViewControllerPreview()
                            .navigationTitle("DICOM Viewer")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    
                    NavigationLink("Auto Segmentation") {
                        AutoSegmentationViewControllerPreview(withMockData: true)
                            .navigationTitle("Auto Segmentation")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
                
                Section("Empty States") {
                    NavigationLink("Study List (Empty)") {
                        StudyListViewControllerPreview(showMockData: false)
                            .navigationTitle("Study List (Empty)")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    
                    NavigationLink("Segmentation (Empty)") {
                        AutoSegmentationViewControllerPreview(withMockData: false)
                            .navigationTitle("Segmentation (Empty)")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
                
                Section("Device Variations") {
                    NavigationLink("iPad Layout") {
                        AllViewControllersPreview()
                            .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
                            .navigationTitle("iPad Layout")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    
                    NavigationLink("Dark Mode") {
                        AllViewControllersPreview()
                            .preferredColorScheme(.dark)
                            .navigationTitle("Dark Mode")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            .navigationTitle("DICOM Viewer Controllers")
        }
    }
}

// MARK: - Individual Preview Wrappers

struct UIKitViewControllerGrid: View {
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                VStack {
                    Text("Main Controller")
                        .font(.headline)
                    MainViewControllerPreview()
                        .frame(height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                
                VStack {
                    Text("Study List")
                        .font(.headline)
                    StudyListViewControllerPreview(showMockData: true)
                        .frame(height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                
                VStack {
                    Text("DICOM Viewer")
                        .font(.headline)
                    ViewerViewControllerPreview()
                        .frame(height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                
                VStack {
                    Text("Auto Segmentation")
                        .font(.headline)
                    AutoSegmentationViewControllerPreview(withMockData: true)
                        .frame(height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
            }
            .padding()
        }
        .navigationTitle("UIKit Controllers Grid")
    }
}

// MARK: - Preview Definitions

#Preview("All Controllers - Tabbed") {
    AllViewControllersPreview()
        .previewDisplayName("All Controllers (Tabbed)")
}

#Preview("Controller Showcase") {
    ViewControllerShowcase()
        .previewDisplayName("Controller Showcase")
}

#Preview("Controllers Grid") {
    UIKitViewControllerGrid()
        .previewDisplayName("Controllers Grid")
}

#Preview("All Controllers - Dark Mode") {
    AllViewControllersPreview()
        .preferredColorScheme(.dark)
        .previewDisplayName("All Controllers (Dark)")
}

#Preview("All Controllers - iPad") {
    AllViewControllersPreview()
        .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
        .previewDisplayName("All Controllers (iPad)")
}

#Preview("Controllers - iPhone SE") {
    AllViewControllersPreview()
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
        .previewDisplayName("All Controllers (iPhone SE)")
}
#endif 