import UIKit

final class DICOMGestureHandler: NSObject {
    weak var scrollView: UIScrollView?
    weak var delegate: DICOMGestureHandlerDelegate?

    // Gesture recognizers
    private var windowLevelGesture: UIPanGestureRecognizer!
    private var measurementGesture: UILongPressGestureRecognizer!
    private var magnifyGesture: UIPinchGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!

    // State tracking
    private var initialWindowLevel: DICOMImageRenderer.WindowLevel?
    private var isWindowLevelActive = false
    private var activeMeasurement: DICOMMeasurement?

    override init() {
        super.init()
        setupGestures()
    }

    private func setupGestures() {
        // Window/Level gesture (two-finger pan)
        windowLevelGesture = UIPanGestureRecognizer(target: self, action: #selector(handleWindowLevel(_:)))
        windowLevelGesture.minimumNumberOfTouches = 2
        windowLevelGesture.maximumNumberOfTouches = 2
        windowLevelGesture.delegate = self

        // Measurement gesture (long press + drag)
        measurementGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleMeasurement(_:)))
        measurementGesture.minimumPressDuration = 0.5
        measurementGesture.delegate = self

        // Magnify gesture for spot zoom
        magnifyGesture = UIPinchGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
        magnifyGesture.delegate = self

        // Rotation for image orientation
        rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationGesture.delegate = self
    }

    func attachToScrollView(_ scrollView: UIScrollView) {
        self.scrollView = scrollView

        scrollView.addGestureRecognizer(windowLevelGesture)
        scrollView.addGestureRecognizer(measurementGesture)
        scrollView.addGestureRecognizer(magnifyGesture)
        scrollView.addGestureRecognizer(rotationGesture)
    }

    @objc private func handleWindowLevel(_ gesture: UIPanGestureRecognizer) {
        guard let scrollView = scrollView else { return }

        switch gesture.state {
        case .began:
            isWindowLevelActive = true
            initialWindowLevel = delegate?.currentWindowLevel()
            scrollView.isScrollEnabled = false
            HapticFeedback.windowLevelChanged()

        case .changed:
            guard let initial = initialWindowLevel else { return }

            let translation = gesture.translation(in: scrollView)
            let sensitivity: Float = 2.0

            let newWindow = initial.window + Float(translation.x) * sensitivity
            let newLevel = initial.level - Float(translation.y) * sensitivity

            let windowLevel = DICOMImageRenderer.WindowLevel(
                window: max(1, newWindow),
                level: newLevel
            )

            delegate?.didUpdateWindowLevel(windowLevel)

        case .ended, .cancelled, .failed:
            isWindowLevelActive = false
            scrollView.isScrollEnabled = true
            initialWindowLevel = nil
            HapticFeedback.windowLevelReset()

        default:
            break
        }
    }

    @objc private func handleMeasurement(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: scrollView)

        switch gesture.state {
        case .began:
            // Start measurement
            activeMeasurement = DICOMMeasurement(startPoint: location)
            delegate?.didBeginMeasurement(activeMeasurement!)
            HapticFeedback.measurementStarted()

        case .changed:
            // Update measurement
            activeMeasurement?.endPoint = location
            if let measurement = activeMeasurement {
                delegate?.didUpdateMeasurement(measurement)
            }

        case .ended:
            // Finalize measurement
            if let measurement = activeMeasurement {
                delegate?.didEndMeasurement(measurement)
                HapticFeedback.measurementCompleted()
            }
            activeMeasurement = nil

        default:
            break
        }
    }

    @objc private func handleMagnify(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.numberOfTouches == 2 else { return }

        switch gesture.state {
        case .began:
            let center = gesture.location(in: scrollView)
            delegate?.didBeginMagnification(at: center)

        case .changed:
            delegate?.didUpdateMagnification(scale: gesture.scale)

        case .ended:
            delegate?.didEndMagnification()

        default:
            break
        }
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        delegate?.didRotate(radians: gesture.rotation)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension DICOMGestureHandler: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow magnify and rotation to work together
        if (gestureRecognizer == magnifyGesture && otherGestureRecognizer == rotationGesture) ||
           (gestureRecognizer == rotationGesture && otherGestureRecognizer == magnifyGesture) {
            return true
        }

        // Prevent scroll while window/level is active
        if gestureRecognizer == windowLevelGesture && otherGestureRecognizer == scrollView?.panGestureRecognizer {
            return false
        }

        return false
    }
}

// MARK: - Supporting Types
protocol DICOMGestureHandlerDelegate: AnyObject {
    func currentWindowLevel() -> DICOMImageRenderer.WindowLevel
    func didUpdateWindowLevel(_ windowLevel: DICOMImageRenderer.WindowLevel)
    func didBeginMeasurement(_ measurement: DICOMMeasurement)
    func didUpdateMeasurement(_ measurement: DICOMMeasurement)
    func didEndMeasurement(_ measurement: DICOMMeasurement)
    func didBeginMagnification(at point: CGPoint)
    func didUpdateMagnification(scale: CGFloat)
    func didEndMagnification()
    func didRotate(radians: CGFloat)
}

struct DICOMMeasurement {
    var startPoint: CGPoint
    var endPoint: CGPoint?
    var type: MeasurementType = .distance

    enum MeasurementType {
        case distance
        case angle
        case area
        case ellipse
        case rectangle
    }

    var distance: CGFloat? {
        guard let endPoint = endPoint else { return nil }
        return hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
    }
}
