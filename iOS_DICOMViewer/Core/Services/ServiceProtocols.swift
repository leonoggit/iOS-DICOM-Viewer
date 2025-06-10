import Foundation

protocol ServiceLocator {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func resolve<T>(_ type: T.Type) -> T?
}

protocol DICOMServiceProtocol: AnyObject {
    var identifier: String { get }
    func initialize() async throws
    func shutdown() async
}
