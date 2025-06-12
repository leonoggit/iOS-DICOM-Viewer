import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register for file type handling
        setupFileTypeHandling()
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }
    
    // MARK: - File Handling
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Store the URL and handle it once services are initialized
        DispatchQueue.main.async {
            // Try to handle the file, but don't crash if services aren't ready
            do {
                _ = DICOMFileImporter.shared.handleIncomingFile(url: url)
            } catch {
                print("⚠️ Failed to handle incoming file: \(error)")
            }
        }
        return true
    }
    
    private func setupFileTypeHandling() {
        // Register supported file types for DICOM import
        // This enables AirDrop, Files app, and other import methods
    }
}
