import UIKit

protocol StudyListCoordinatorDelegate: AnyObject {
    func studyListCoordinator(_ coordinator: StudyListCoordinator, didSelectStudy study: DICOMStudy)
}

final class StudyListCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var navigationController: UINavigationController
    weak var delegate: StudyListCoordinatorDelegate?

    init(navigationController: UINavigationController, delegate: StudyListCoordinatorDelegate?) {
        self.navigationController = navigationController
        self.delegate = delegate
    }

    func start() {
        let viewModel = StudyListViewModel()
        let viewController = StudyListViewController(viewModel: viewModel, coordinator: self)
        navigationController.pushViewController(viewController, animated: false)
    }

    func showViewer(for study: DICOMStudy) {
        let viewerCoordinator = ViewerCoordinator(
            navigationController: navigationController,
            study: study
        )
        childCoordinators.append(viewerCoordinator)
        viewerCoordinator.start()
    }
}

extension AppCoordinator: StudyListCoordinatorDelegate {
    func studyListCoordinator(_ coordinator: StudyListCoordinator, didSelectStudy study: DICOMStudy) {
        coordinator.showViewer(for: study)
    }
}

// Placeholder classes that would need to be implemented
class StudyListViewModel {
    // Implementation would go here
}

class ViewerCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var navigationController: UINavigationController
    let study: DICOMStudy
    
    init(navigationController: UINavigationController, study: DICOMStudy) {
        self.navigationController = navigationController
        self.study = study
    }
    
    func start() {
        // Implementation would show viewer for study
    }
}
