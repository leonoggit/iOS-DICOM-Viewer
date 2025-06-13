import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🚀 AppDelegate: didFinishLaunchingWithOptions called")
        NSLog("🚀 AppDelegate: didFinishLaunchingWithOptions called")
        print("🚀 AppDelegate: Launch options: \(String(describing: launchOptions))")
        
        // Set up window manually
        setupWindow()
        
        // Register for file type handling
        setupFileTypeHandling()
        
        print("✅ AppDelegate: Initialization completed")
        NSLog("✅ AppDelegate: Initialization completed")
        return true
    }
    
    private func setupWindow() {
        print("🔄 AppDelegate: Setting up window...")
        NSLog("🔄 AppDelegate: Setting up window...")
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .systemBlue
        
        print("🔄 AppDelegate: Window created with bounds: \(window?.bounds ?? .zero)")
        
        let mainViewController = MainViewController()
        let navigationController = UINavigationController(rootViewController: mainViewController)
        
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        print("✅ AppDelegate: Window setup completed")
        NSLog("✅ AppDelegate: Window setup completed")
        print("✅ AppDelegate: Window isKeyWindow: \(window?.isKeyWindow ?? false)")
    }

    
    // MARK: - File Handling
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Store the URL and handle it once services are initialized
        DispatchQueue.main.async {
            // Try to handle the file, but don't crash if services aren't ready
            if let fileImporter = DICOMServiceManager.shared.fileImporter {
                do {
                    _ = fileImporter.handleIncomingFile(url: url)
                } catch {
                    print("⚠️ Failed to handle incoming file: \(error)")
                }
            } else {
                print("⚠️ DICOM services not ready yet")
            }
        }
        return true
    }
    
    private func setupFileTypeHandling() {
        // Register supported file types for DICOM import
        // This enables AirDrop, Files app, and other import methods
    }
}
