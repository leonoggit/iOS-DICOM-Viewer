//
//  MainTabBarController.swift
//  iOS_DICOMViewer
//
//  Main tab bar controller for DICOM Viewer application
//  Based on modern medical imaging UI/UX principles
//

import UIKit

class MainTabBarController: UITabBarController {
    
    // MARK: - UI Components
    
    private var studyListController: StudyListViewController!
    private var viewerController: ModernViewerViewController!
    private var mprController: MPRViewController!
    private var segmentationController: AutoSegmentationViewController!
    private var settingsController: SettingsViewController!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBarAppearance()
        setupViewControllers()
        
        // Add revolutionary Quantum Interface
        addQuantumViewerTab()
        
        // Initialize global quantum features
        _ = QuantumFeatureManager.shared
    }
    
    // MARK: - Setup Methods
    
    private func setupTabBarAppearance() {
        // Modern dark theme based on HTML template
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Colors from HTML template
        let primaryColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0) // #0cb8f2
        let surfaceDark = UIColor(red: 27/255, green: 36/255, blue: 39/255, alpha: 1.0) // #1b2427
        let textSecondary = UIColor(red: 156/255, green: 178/255, blue: 186/255, alpha: 1.0) // #9cb2ba
        let borderDark = UIColor(red: 59/255, green: 78/255, blue: 84/255, alpha: 1.0) // #3b4e54
        
        appearance.backgroundColor = surfaceDark.withAlphaComponent(0.9)
        appearance.selectionIndicatorTintColor = primaryColor
        
        // Device-specific font sizing
        let deviceLayout = DeviceLayoutUtility.shared
        let tabBarFontSize = deviceLayout.scaled(10)
        
        // Normal state
        appearance.stackedLayoutAppearance.normal.iconColor = textSecondary
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: textSecondary,
            .font: UIFont.systemFont(ofSize: tabBarFontSize, weight: .medium)
        ]
        
        // Selected state
        appearance.stackedLayoutAppearance.selected.iconColor = primaryColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: primaryColor,
            .font: UIFont.systemFont(ofSize: tabBarFontSize, weight: .semibold)
        ]
        
        // Add subtle border
        appearance.shadowColor = borderDark
        appearance.shadowImage = UIImage()
        
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        
        // Add backdrop blur effect
        tabBar.isTranslucent = true
        
        // Safe area handling for iPhone 16 Pro Max
        additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    private func setupViewControllers() {
        // 1. Study List (Home) - File management and study selection
        studyListController = StudyListViewController()
        let studyListNav = createNavigationController(
            rootViewController: studyListController,
            title: "Home",
            iconName: "house.fill",
            selectedIconName: "house.fill"
        )
        
        // 2. 2D Viewer - Standard DICOM image viewing
        viewerController = ModernViewerViewController()
        let viewerNav = createNavigationController(
            rootViewController: viewerController,
            title: "2D Viewer",
            iconName: "photo.on.rectangle",
            selectedIconName: "photo.on.rectangle.fill"
        )
        
        // 3. MPR Viewer - Multi-planar reconstruction
        mprController = MPRViewController()
        let mprNav = createNavigationController(
            rootViewController: mprController,
            title: "MPR",
            iconName: "square.split.2x2",
            selectedIconName: "square.split.2x2.fill"
        )
        
        // 4. 3D/Segmentation - Volume rendering and AI segmentation
        segmentationController = AutoSegmentationViewController()
        let segmentationNav = createNavigationController(
            rootViewController: segmentationController,
            title: "3D/AI",
            iconName: "brain.head.profile",
            selectedIconName: "brain.head.profile.fill"
        )
        
        // 5. Settings - App configuration and preferences
        settingsController = SettingsViewController()
        let settingsNav = createNavigationController(
            rootViewController: settingsController,
            title: "Settings",
            iconName: "gearshape",
            selectedIconName: "gearshape.fill"
        )
        
        viewControllers = [
            studyListNav,
            viewerNav, 
            mprNav,
            segmentationNav,
            settingsNav
        ]
        
        // Set default selection to Study List
        selectedIndex = 0
    }
    
    private func createNavigationController(
        rootViewController: UIViewController,
        title: String,
        iconName: String,
        selectedIconName: String
    ) -> UINavigationController {
        
        let navController = UINavigationController(rootViewController: rootViewController)
        
        // Tab bar item
        navController.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: iconName),
            selectedImage: UIImage(systemName: selectedIconName)
        )
        
        // Navigation bar appearance matching template
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        
        let backgroundDark = UIColor(red: 17/255, green: 22/255, blue: 24/255, alpha: 1.0) // #111618
        let borderDark = UIColor(red: 59/255, green: 78/255, blue: 84/255, alpha: 1.0) // #3b4e54
        let textPrimary = UIColor.white
        
        navAppearance.backgroundColor = backgroundDark.withAlphaComponent(0.8)
        navAppearance.titleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: UIFont.systemFont(ofSize: 20, weight: .bold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        navAppearance.shadowColor = borderDark
        
        navController.navigationBar.standardAppearance = navAppearance
        navController.navigationBar.scrollEdgeAppearance = navAppearance
        navController.navigationBar.compactAppearance = navAppearance
        navController.navigationBar.prefersLargeTitles = false
        navController.navigationBar.isTranslucent = true
        
        return navController
    }
    
    // MARK: - Public Methods
    
    /// Navigate to specific study in viewer
    func openStudy(_ study: DICOMStudy, in viewerType: ViewerType = .viewer2D) {
        switch viewerType {
        case .viewer2D:
            if let viewer = viewerController {
                viewer.loadStudy(study)
                selectedIndex = 1 // Switch to 2D Viewer tab
            }
        case .mpr:
            if let mpr = mprController {
                mpr.loadStudy(study)
                selectedIndex = 2 // Switch to MPR tab
            }
        case .segmentation:
            if let segmentation = segmentationController {
                segmentation.loadStudy(study)
                selectedIndex = 3 // Switch to 3D/AI tab
            }
        }
    }
    
    /// Update study data across all viewers
    func refreshStudyData(_ study: DICOMStudy) {
        viewerController?.refreshStudy(study)
        mprController?.refreshStudy(study)
        // AutoSegmentationViewController will be refreshed through loadStudy
        segmentationController?.loadStudy(study)
    }
}

// MARK: - Extensions for View Controllers

extension ModernViewerViewController {
    func loadStudy(_ study: DICOMStudy) {
        self.study = study
        // loadFirstInstance() is automatically called when study is set
    }
    
    func refreshStudy(_ study: DICOMStudy) {
        self.study = study
        // UI updates happen automatically when study is set
    }
}

extension MPRViewController {
    func loadStudy(_ study: DICOMStudy) {
        // Implementation for MPR viewer
        print("📊 MPR: Loading study \(study.studyInstanceUID)")
    }
    
    func refreshStudy(_ study: DICOMStudy) {
        // Implementation for MPR refresh
        print("🔄 MPR: Refreshing study \(study.studyInstanceUID)")
    }
}

// Note: AutoSegmentationViewController already has loadStudy and refreshStudy methods
// extension AutoSegmentationViewController {
//     func loadStudy(_ study: DICOMStudy) {
//         // Implementation for segmentation viewer
//         print("🧠 Segmentation: Loading study \(study.studyInstanceUID)")
//     }
//     
//     func refreshStudy(_ study: DICOMStudy) {
//         // Implementation for segmentation refresh
//         print("🔄 Segmentation: Refreshing study \(study.studyInstanceUID)")
//     }
// }