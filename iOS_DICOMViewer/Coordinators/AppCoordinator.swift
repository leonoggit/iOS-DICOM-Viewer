import UIKit

protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get set }

    func start()
}

final class AppCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var navigationController: UINavigationController

    private let serviceManager: DICOMServiceManager

    init(navigationController: UINavigationController, serviceManager: DICOMServiceManager = .shared) {
        self.navigationController = navigationController
        self.serviceManager = serviceManager
    }

    func start() {
        Task {
            do {
                try await serviceManager.initialize()
                showStudyList()
            } catch {
                showError(error)
            }
        }
    }

    private func showStudyList() {
        let studyListCoordinator = StudyListCoordinator(
            navigationController: navigationController,
            delegate: self
        )
        childCoordinators.append(studyListCoordinator)
        studyListCoordinator.start()
    }
    
    private func showError(_ error: Error) {
        // Handle error display
        print("App startup error: \(error)")
    }
}
