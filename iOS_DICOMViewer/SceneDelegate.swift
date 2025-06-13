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
        
        // Set window background to red to test visibility
        window?.backgroundColor = .red
        
        print("🔄 SceneDelegate: Window created with bounds: \(self.window?.bounds ?? .zero)")
        
        // Create a simple test view controller with bright colors
        let testViewController = UIViewController()
        testViewController.view.backgroundColor = .blue
        
        // Add a large label to ensure visibility
        let label = UILabel()
        label.text = "TEST VIEW LOADED"
        label.textColor = .yellow
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.backgroundColor = .purple
        label.translatesAutoresizingMaskIntoConstraints = false
        testViewController.view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: testViewController.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: testViewController.view.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 300),
            label.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        print("🔄 SceneDelegate: Test view controller created")
        
        // Set root view controller directly (no navigation controller)
        window?.rootViewController = testViewController
        print("🔄 SceneDelegate: Root view controller set")
        
        // Make window key and visible
        window?.makeKeyAndVisible()
        
        print("✅ SceneDelegate: Window made key and visible")
        print("✅ SceneDelegate: Final window bounds: \(self.window?.bounds ?? .zero)")
        print("✅ SceneDelegate: Window isKeyWindow: \(self.window?.isKeyWindow ?? false)")
        print("✅ SceneDelegate: Root view controller: \(String(describing: self.window?.rootViewController))")
        
        // Force layout
        window?.layoutIfNeeded()
        testViewController.view.layoutIfNeeded()
        
        print("✅ SceneDelegate: Layout forced")
        
        // Handle any files opened during app launch
        handleIncomingFiles(connectionOptions.urlContexts)
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
