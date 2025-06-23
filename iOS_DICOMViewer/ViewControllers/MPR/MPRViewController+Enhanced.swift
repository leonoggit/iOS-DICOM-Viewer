//
//  MPRViewController+Enhanced.swift
//  iOS_DICOMViewer
//
//  Enhanced MPR functionality including oblique slicing and curved MPR
//

import UIKit
import MetalKit
import simd

extension MPRViewController {
    
    // MARK: - Oblique MPR Support
    
    /// Sets an oblique slice plane defined by a normal vector and position
    func setObliqueSlice(normal: simd_float3, position: simd_float3) {
        mprRenderer.setObliqueSlice(normal: normal, position: position)
        updateUI()
        
        // Update UI to show oblique mode
        if let obliqueModeLabel = view.viewWithTag(999) as? UILabel {
            obliqueModeLabel.text = "Oblique Mode"
            obliqueModeLabel.isHidden = false
        }
    }
    
    /// Resets to standard orthogonal planes
    func resetToOrthogonalPlanes() {
        let plane = MPRRenderer.MPRPlane.allCases[planeSegmentedControl.selectedSegmentIndex]
        mprRenderer.setPlane(plane)
        
        if let obliqueModeLabel = view.viewWithTag(999) as? UILabel {
            obliqueModeLabel.isHidden = true
        }
    }
    
    // MARK: - Curved MPR Support
    
    /// Sets up curved MPR along a path (useful for vessel analysis)
    func setCurvedMPR(path: [simd_float3], radius: Float = 10.0) {
        mprRenderer.setCurvedMPR(path: path, radius: radius)
        updateUI()
        
        // Show curved MPR mode indicator
        if let curvedModeLabel = view.viewWithTag(998) as? UILabel {
            curvedModeLabel.text = "Curved MPR Mode"
            curvedModeLabel.isHidden = false
        }
    }
    
    /// Clears curved MPR and returns to planar mode
    func clearCurvedMPR() {
        mprRenderer.clearCurvedMPR()
        
        if let curvedModeLabel = view.viewWithTag(998) as? UILabel {
            curvedModeLabel.isHidden = true
        }
    }
    
    // MARK: - Thick Slab Support
    
    /// Enables thick slab mode with specified thickness and projection type
    func setThickSlab(thickness: Int, projectionType: ThickSlabProjection) {
        mprRenderer.setThickSlab(thickness: thickness, projectionType: projectionType)
        updateUI()
    }
    
    /// Disables thick slab mode
    func disableThickSlab() {
        mprRenderer.disableThickSlab()
        updateUI()
    }
    
    // MARK: - Multi-Resolution Support
    
    /// Loads volume with multiple resolution levels for efficient viewing
    func loadMultiResolutionVolume(levels: [VolumeLevel]) {
        mprRenderer.loadMultiResolutionVolume(levels: levels)
        updateUI()
    }
    
    /// Sets the quality level based on interaction state
    func setQualityLevel(_ level: QualityLevel) {
        mprRenderer.setQualityLevel(level)
    }
    
    // MARK: - Advanced Window/Level Presets
    
    /// Applies predefined window/level preset
    func applyWindowLevelPreset(_ preset: WindowLevelPreset) {
        let (center, width) = preset.values
        windowCenterSlider.value = center
        windowWidthSlider.value = width
        mprRenderer.setWindowLevel(center: center, width: width)
        updateUI()
        
        // Show preset name temporarily
        showToast("Applied: \(preset.name)")
    }
    
    // MARK: - Measurement Tools
    
    /// Activates distance measurement tool
    func activateDistanceMeasurement() {
        mprRenderer.activateMeasurementTool(.distance)
        showToast("Distance measurement active")
    }
    
    /// Activates angle measurement tool
    func activateAngleMeasurement() {
        mprRenderer.activateMeasurementTool(.angle)
        showToast("Angle measurement active")
    }
    
    /// Activates ROI measurement tool
    func activateROIMeasurement() {
        mprRenderer.activateMeasurementTool(.roi)
        showToast("ROI measurement active")
    }
    
    /// Clears all measurements
    func clearMeasurements() {
        mprRenderer.clearAllMeasurements()
        showToast("Measurements cleared")
    }
    
    // MARK: - Export Functions
    
    /// Exports current view as image
    func exportCurrentView() -> UIImage? {
        return mprRenderer.captureCurrentFrame()
    }
    
    /// Exports all slices as video
    func exportAsVideo(completion: @escaping (URL?) -> Void) {
        mprRenderer.exportSlicesAsVideo { url in
            completion(url)
        }
    }
    
    // MARK: - Helper Methods
    
    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toast.textColor = .white
        toast.textAlignment = .center
        toast.font = .systemFont(ofSize: 14)
        toast.layer.cornerRadius = 8
        toast.clipsToBounds = true
        toast.alpha = 0
        
        view.addSubview(toast)
        toast.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.heightAnchor.constraint(equalToConstant: 40),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
        
        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
}

// MARK: - Supporting Types

enum ThickSlabProjection {
    case mip      // Maximum Intensity Projection
    case minip    // Minimum Intensity Projection
    case average  // Average Intensity Projection
}

enum QualityLevel {
    case interactive  // Low quality for interaction
    case balanced     // Medium quality
    case diagnostic   // High quality for diagnosis
}

struct VolumeLevel {
    let resolution: MTLSize
    let texture: MTLTexture
}

enum WindowLevelPreset {
    case lungCT
    case boneCT
    case brainCT
    case abdomenCT
    case liverCT
    case angiographyCT
    case brainMR
    case spineMR
    
    var name: String {
        switch self {
        case .lungCT: return "Lung CT"
        case .boneCT: return "Bone CT"
        case .brainCT: return "Brain CT"
        case .abdomenCT: return "Abdomen CT"
        case .liverCT: return "Liver CT"
        case .angiographyCT: return "Angiography CT"
        case .brainMR: return "Brain MR"
        case .spineMR: return "Spine MR"
        }
    }
    
    var values: (center: Float, width: Float) {
        switch self {
        case .lungCT: return (center: -600.0/4096.0, width: 1500.0/4096.0)
        case .boneCT: return (center: 300.0/4096.0, width: 2000.0/4096.0)
        case .brainCT: return (center: 40.0/4096.0, width: 80.0/4096.0)
        case .abdomenCT: return (center: 40.0/4096.0, width: 350.0/4096.0)
        case .liverCT: return (center: 50.0/4096.0, width: 150.0/4096.0)
        case .angiographyCT: return (center: 200.0/4096.0, width: 600.0/4096.0)
        case .brainMR: return (center: 0.5, width: 1.0)
        case .spineMR: return (center: 0.4, width: 0.8)
        }
    }
}

// MARK: - Enhanced Tri-Planar Controller

extension TriPlanarViewController {
    
    /// Enables synchronized thick slab mode across all views
    func setSynchronizedThickSlab(thickness: Int, projectionType: ThickSlabProjection) {
        axialMPR.setThickSlab(thickness: thickness, projectionType: projectionType)
        sagittalMPR.setThickSlab(thickness: thickness, projectionType: projectionType)
        coronalMPR.setThickSlab(thickness: thickness, projectionType: projectionType)
    }
    
    /// Applies window/level preset to all views
    func applySynchronizedPreset(_ preset: WindowLevelPreset) {
        axialMPR.applyWindowLevelPreset(preset)
        sagittalMPR.applyWindowLevelPreset(preset)
        coronalMPR.applyWindowLevelPreset(preset)
    }
    
    /// Exports all three views as a composite image
    func exportCompositeImage() -> UIImage? {
        guard let axialImage = axialMPR.exportCurrentView(),
              let sagittalImage = sagittalMPR.exportCurrentView(),
              let coronalImage = coronalMPR.exportCurrentView() else {
            return nil
        }
        
        // Create composite image
        let size = CGSize(width: axialImage.size.width * 2, height: axialImage.size.height * 2)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        // Draw images in 2x2 grid
        axialImage.draw(at: CGPoint(x: 0, y: 0))
        sagittalImage.draw(at: CGPoint(x: axialImage.size.width, y: 0))
        coronalImage.draw(at: CGPoint(x: 0, y: axialImage.size.height))
        
        // Add labels
        let attributes = [
            NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20),
            NSAttributedString.Key.foregroundColor: UIColor.white
        ]
        
        "Axial".draw(at: CGPoint(x: 10, y: 10), withAttributes: attributes)
        "Sagittal".draw(at: CGPoint(x: axialImage.size.width + 10, y: 10), withAttributes: attributes)
        "Coronal".draw(at: CGPoint(x: 10, y: axialImage.size.height + 10), withAttributes: attributes)
        
        let compositeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return compositeImage
    }
}