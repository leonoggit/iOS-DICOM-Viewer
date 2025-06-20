import UIKit
import os.log

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    private let logger = Logger(subsystem: "com.dicomviewer.iOS-DICOMViewer", category: "SceneDelegate")
    
    override init() {
        super.init()
        print("🏗️ SceneDelegate: init() called - Class instantiated")
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use print for immediate debugging since os.log might be filtered
        print("🔄 SceneDelegate: scene willConnectTo called")
        NSLog("🔄 SceneDelegate: scene willConnectTo called")
        
        guard let windowScene = (scene as? UIWindowScene) else { 
            print("❌ SceneDelegate: Failed to get window scene")
            NSLog("❌ SceneDelegate: Failed to get window scene")
            return 
        }
        
        print("🔄 SceneDelegate: Setting up scene with window...")
        print("🔄 SceneDelegate: Window scene bounds: \(windowScene.coordinateSpace.bounds)")
        
        // Create window
        window = UIWindow(windowScene: windowScene)
        
        // Set window background to dark theme
        let backgroundDark = UIColor(red: 17/255, green: 22/255, blue: 24/255, alpha: 1.0) // #111618
        window?.backgroundColor = backgroundDark
        
        print("🔄 SceneDelegate: Window created with bounds: \(self.window?.bounds ?? .zero)")
        
        // TEMPORARY DEBUG: Create simple test controller for direct DICOM study display
        print("🎯 SceneDelegate: Creating simple test controller for direct study display")
        let testVC = createTestViewController()
        let navController = UINavigationController(rootViewController: testVC)
        
        print("🎯 SceneDelegate: TestViewController created and wrapped in navigation controller")
        
        // Set root view controller directly to TestViewController
        window?.rootViewController = navController
        print("🔄 SceneDelegate: Root view controller set")
        
        // Make window key and visible
        window?.makeKeyAndVisible()
        
        print("✅ SceneDelegate: Window made key and visible")
        print("✅ SceneDelegate: Final window bounds: \(self.window?.bounds ?? .zero)")
        print("✅ SceneDelegate: Window isKeyWindow: \(self.window?.isKeyWindow ?? false)")
        print("✅ SceneDelegate: Root view controller: \(String(describing: self.window?.rootViewController))")
        
        // Force layout
        window?.layoutIfNeeded()
        navController.view.layoutIfNeeded()
        
        print("✅ SceneDelegate: Layout forced")
        
        // Initialize DICOM services immediately for debugging
        print("🎯 SceneDelegate: Initializing DICOM services immediately")
        Task {
            do {
                print("🎯 SceneDelegate: Starting DICOM service initialization")
                try await DICOMServiceManager.shared.initialize()
                print("🎯 SceneDelegate: DICOM services initialized successfully")
                
                // TestViewController will load studies automatically
                await MainActor.run {
                    print("🎯 SceneDelegate: DICOM services ready - TestViewController will handle display")
                }
            } catch {
                print("❌ SceneDelegate: Failed to initialize DICOM services: \(error)")
            }
        }
        
        // Handle any files opened during app launch
        handleIncomingFiles(connectionOptions.urlContexts)
    }
    
    // MARK: - Test Controller
    
    private func createTestViewController() -> UIViewController {
        let testVC = UIViewController()
        testVC.view.backgroundColor = .systemBackground
        testVC.title = "DICOM Test"
        
        print("🧪 SceneDelegate: Creating test UI...")
        
        let label = UILabel()
        label.text = "DICOM Studies Loading..."
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        testVC.view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: testVC.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: testVC.view.centerYAnchor)
        ])
        
        // Load studies after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.loadAndDisplayStudiesInViewController(testVC)
        }
        
        return testVC
    }
    
    private func loadAndDisplayStudiesInViewController(_ viewController: UIViewController) {
        print("🧪 SceneDelegate: Loading studies in test controller...")
        
        Task {
            do {
                print("🧪 SceneDelegate: Initializing DICOM services for test...")
                try await DICOMServiceManager.shared.initialize()
                print("🧪 SceneDelegate: Services initialized, checking metadata store...")
                
                await MainActor.run {
                    if let store = DICOMServiceManager.shared.metadataStore {
                        let studies = store.getAllStudies()
                        let stats = store.getStatistics()
                        
                        print("🧪 SceneDelegate: Found \(studies.count) studies")
                        print("🧪 SceneDelegate: Store stats - Studies: \(stats.studies), Series: \(stats.series), Instances: \(stats.instances)")
                        
                        self.displayStudyResults(in: viewController, studies: studies, stats: stats)
                    } else {
                        print("🧪 SceneDelegate: Metadata store is nil!")
                        self.displayError(in: viewController, message: "Metadata store not available")
                    }
                }
            } catch {
                print("🧪 SceneDelegate: Failed to initialize services: \(error)")
                await MainActor.run {
                    self.displayError(in: viewController, message: "Failed to initialize: \(error)")
                }
            }
        }
    }
    
    private func displayStudyResults(in viewController: UIViewController, studies: [DICOMStudy], stats: (studies: Int, series: Int, instances: Int)) {
        // Clear existing views
        viewController.view.subviews.forEach { $0.removeFromSuperview() }
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(scrollView)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // Stats header
        let statsLabel = UILabel()
        statsLabel.text = "📊 DICOM Statistics:\nStudies: \(stats.studies)\nSeries: \(stats.series)\nInstances: \(stats.instances)"
        statsLabel.numberOfLines = 0
        statsLabel.textAlignment = .center
        statsLabel.font = .boldSystemFont(ofSize: 16)
        stackView.addArrangedSubview(statsLabel)
        
        // Study list
        if studies.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "❌ No studies found in metadata store"
            emptyLabel.textAlignment = .center
            emptyLabel.textColor = .systemRed
            stackView.addArrangedSubview(emptyLabel)
        } else {
            for (index, study) in studies.enumerated() {
                let studyLabel = UILabel()
                studyLabel.text = "📚 Study \(index + 1):\nPatient: \(study.patientName ?? "Unknown")\nDescription: \(study.studyDescription ?? "No description")\nSeries: \(study.series.count)"
                studyLabel.numberOfLines = 0
                studyLabel.backgroundColor = .secondarySystemBackground
                studyLabel.layer.cornerRadius = 8
                studyLabel.textAlignment = .center
                stackView.addArrangedSubview(studyLabel)
            }
        }
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func displayError(in viewController: UIViewController, message: String) {
        viewController.view.subviews.forEach { $0.removeFromSuperview() }
        
        let label = UILabel()
        label.text = "❌ Error: \(message)"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .systemRed
        label.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor, constant: -20)
        ])
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handleIncomingFiles(URLContexts)
    }
    
    private func handleIncomingFiles(_ urlContexts: Set<UIOpenURLContext>) {
        for context in urlContexts {
            DispatchQueue.main.async {
                if let fileImporter = DICOMServiceManager.shared.fileImporter {
                    do {
                        _ = fileImporter.handleIncomingFile(url: context.url)
                    } catch {
                        print("⚠️ Failed to handle incoming file: \(error)")
                    }
                } else {
                    print("⚠️ DICOM services not ready yet")
                }
            }
        }
    }
}
