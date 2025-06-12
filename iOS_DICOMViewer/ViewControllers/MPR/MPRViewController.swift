import UIKit
import MetalKit
import simd

/// View controller for Multi-Planar Reconstruction (MPR) display
/// Supports single plane view and tri-planar synchronized views
class MPRViewController: UIViewController {
    
    // MARK: - UI Components
    @IBOutlet weak var metalView: MTKView!
    @IBOutlet weak var planeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var sliceSlider: UISlider!
    @IBOutlet weak var sliceLabel: UILabel!
    @IBOutlet weak var windowCenterSlider: UISlider!
    @IBOutlet weak var windowWidthSlider: UISlider!
    @IBOutlet weak var zoomSlider: UISlider!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var crosshairSwitch: UISwitch!
    @IBOutlet weak var annotationsSwitch: UISwitch!
    
    // MARK: - Rendering
    private var mprRenderer: MPRRenderer!
    private var volumeRenderer: VolumeRenderer?
    
    // MARK: - Data
    private var currentSeries: DICOMSeries?
    private var volumeTexture: MTLTexture?
    private var voxelSpacing = simd_float3(1, 1, 1)
    
    // MARK: - Gesture Recognition
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var pinchGestureRecognizer: UIPinchGestureRecognizer!
    private var rotationGestureRecognizer: UIRotationGestureRecognizer!
    private var tapGestureRecognizer: UITapGestureRecognizer!
    
    // MARK: - State
    private var lastPanTranslation = CGPoint.zero
    private var currentZoom: Float = 1.0
    private var currentRotation: Float = 0.0
    private var panOffset = simd_float2(0, 0)
    
    // MARK: - Delegate
    weak var delegate: MPRViewControllerDelegate?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMetalView()
        setupRenderer()
        setupGestures()
        setupUI()
        updateUI()
    }
    
    private func setupMetalView() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported")
        }
        
        metalView.device = device
        metalView.delegate = self
        metalView.framebufferOnly = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.drawableSize = metalView.frame.size
        metalView.isPaused = false
    }
    
    private func setupRenderer() {
        mprRenderer = MPRRenderer()
        
        // Set default transfer function
        let transferFunction = TransferFunction.defaultCT
        mprRenderer.updateTransferFunction(transferFunction)
    }
    
    private func setupGestures() {
        // Pan gesture for crosshair positioning and image panning
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        metalView.addGestureRecognizer(panGestureRecognizer)
        
        // Pinch gesture for zoom
        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        metalView.addGestureRecognizer(pinchGestureRecognizer)
        
        // Rotation gesture
        rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        metalView.addGestureRecognizer(rotationGestureRecognizer)
        
        // Tap gesture for crosshair positioning
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        metalView.addGestureRecognizer(tapGestureRecognizer)
        
        // Allow simultaneous gestures
        panGestureRecognizer.delegate = self
        pinchGestureRecognizer.delegate = self
        rotationGestureRecognizer.delegate = self
    }
    
    private func setupUI() {
        // Configure plane selection
        planeSegmentedControl.removeAllSegments()
        for (index, plane) in MPRRenderer.MPRPlane.allCases.enumerated() {
            planeSegmentedControl.insertSegment(withTitle: plane.displayName, at: index, animated: false)
        }
        planeSegmentedControl.selectedSegmentIndex = 0
        
        // Configure sliders
        zoomSlider.minimumValue = 0.1
        zoomSlider.maximumValue = 10.0
        zoomSlider.value = 1.0
        
        windowCenterSlider.minimumValue = 0.0
        windowCenterSlider.maximumValue = 1.0
        windowCenterSlider.value = 0.5
        
        windowWidthSlider.minimumValue = 0.01
        windowWidthSlider.maximumValue = 1.0
        windowWidthSlider.value = 1.0
        
        // Configure switches
        crosshairSwitch.isOn = true
        annotationsSwitch.isOn = true
    }
    
    // MARK: - Data Loading
    func loadSeries(_ series: DICOMSeries, volumeTexture: MTLTexture?, voxelSpacing: simd_float3) {
        self.currentSeries = series
        self.volumeTexture = volumeTexture
        self.voxelSpacing = voxelSpacing
        
        if let volumeTexture = volumeTexture {
            mprRenderer.loadVolume(from: volumeTexture, voxelSpacing: voxelSpacing)
            updateSliceControls()
            updateUI()
            
            // Auto-adjust window/level based on series modality
            configureWindowLevelForModality(series)
            
            print("MPR loaded series:", series.seriesDescription ?? "Unknown")
        }
    }
    
    func loadVolumeDirectly(texture: MTLTexture, spacing: simd_float3) {
        self.volumeTexture = texture
        self.voxelSpacing = spacing
        
        mprRenderer.loadVolume(from: texture, voxelSpacing: spacing)
        updateSliceControls()
        updateUI()
    }
    
    private func configureWindowLevelForModality(_ series: DICOMSeries) {
        guard let firstInstance = series.instances.first else { return }
        let metadata = firstInstance.metadata
        
        // Use DICOM window/level if available
        if let windowCenter = metadata.windowCenter?.first,
           let windowWidth = metadata.windowWidth?.first {
            
            // Normalize to [0,1] range
            let normalizedCenter = Float(windowCenter) / 4096.0 // Assume 12-bit range
            let normalizedWidth = Float(windowWidth) / 4096.0
            
            mprRenderer.setWindowLevel(center: normalizedCenter, width: normalizedWidth)
            
            windowCenterSlider.value = normalizedCenter
            windowWidthSlider.value = normalizedWidth
        } else {
            // Set defaults based on modality
            let modality = metadata.modality.uppercased()
            switch modality {
            case "CT":
                mprRenderer.setWindowLevel(center: 0.4, width: 0.8)
                windowCenterSlider.value = 0.4
                windowWidthSlider.value = 0.8
            case "MR", "MRI":
                mprRenderer.setWindowLevel(center: 0.5, width: 1.0)
                windowCenterSlider.value = 0.5
                windowWidthSlider.value = 1.0
            default:
                mprRenderer.setWindowLevel(center: 0.5, width: 1.0)
                windowCenterSlider.value = 0.5
                windowWidthSlider.value = 1.0
            }
        }
    }
    
    private func updateSliceControls() {
        let maxSlices = mprRenderer.maxSlices
        
        sliceSlider.minimumValue = 1
        sliceSlider.maximumValue = Float(maxSlices)
        sliceSlider.value = Float(mprRenderer.currentSliceIndex + 1)
        
        updateSliceLabel()
    }
    
    private func updateSliceLabel() {
        let current = mprRenderer.currentSliceIndex + 1
        let total = mprRenderer.maxSlices
        sliceLabel.text = "Slice \(current)/\(total)"
    }
    
    private func updateUI() {
        guard mprRenderer.isVolumeLoaded else {
            infoLabel.text = "No volume loaded"
            return
        }
        
        if let sliceInfo = mprRenderer.getSliceInfo() {
            infoLabel.text = sliceInfo.displayText
        }
        
        updateSliceLabel()
    }
    
    // MARK: - Actions
    @IBAction func planeChanged(_ sender: UISegmentedControl) {
        let plane = MPRRenderer.MPRPlane.allCases[sender.selectedSegmentIndex]
        mprRenderer.setPlane(plane)
        updateSliceControls()
        updateUI()
        
        delegate?.mprViewController(self, didChangePlane: plane)
    }
    
    @IBAction func sliceChanged(_ sender: UISlider) {
        let sliceIndex = Int(sender.value) - 1
        mprRenderer.setSliceIndex(sliceIndex)
        updateUI()
        
        delegate?.mprViewController(self, didChangeSlice: sliceIndex)
    }
    
    @IBAction func windowCenterChanged(_ sender: UISlider) {
        mprRenderer.setWindowLevel(center: sender.value, width: windowWidthSlider.value)
        updateUI()
    }
    
    @IBAction func windowWidthChanged(_ sender: UISlider) {
        mprRenderer.setWindowLevel(center: windowCenterSlider.value, width: sender.value)
        updateUI()
    }
    
    @IBAction func zoomChanged(_ sender: UISlider) {
        currentZoom = sender.value
        mprRenderer.setZoom(currentZoom)
    }
    
    @IBAction func crosshairToggled(_ sender: UISwitch) {
        mprRenderer.setCrosshairEnabled(sender.isOn)
    }
    
    @IBAction func annotationsToggled(_ sender: UISwitch) {
        mprRenderer.setAnnotationsEnabled(sender.isOn)
    }
    
    @IBAction func resetView(_ sender: UIButton) {
        resetViewTransforms()
    }
    
    @IBAction func previousSlice(_ sender: UIButton) {
        mprRenderer.previousSlice()
        sliceSlider.value = Float(mprRenderer.currentSliceIndex + 1)
        updateUI()
        
        delegate?.mprViewController(self, didChangeSlice: mprRenderer.currentSliceIndex)
    }
    
    @IBAction func nextSlice(_ sender: UIButton) {
        mprRenderer.nextSlice()
        sliceSlider.value = Float(mprRenderer.currentSliceIndex + 1)
        updateUI()
        
        delegate?.mprViewController(self, didChangeSlice: mprRenderer.currentSliceIndex)
    }
    
    private func resetViewTransforms() {
        currentZoom = 1.0
        currentRotation = 0.0
        panOffset = simd_float2(0, 0)
        
        mprRenderer.setZoom(currentZoom)
        mprRenderer.setRotation(currentRotation)
        mprRenderer.setPan(offset: panOffset)
        mprRenderer.setFlip(horizontal: false, vertical: false)
        
        zoomSlider.value = currentZoom
        
        print("🔄 View reset to defaults")
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: metalView)
        let viewSize = metalView.bounds.size
        
        let normalizedPosition = simd_float2(
            Float(location.x / viewSize.width),
            Float(location.y / viewSize.height)
        )
        
        mprRenderer.setCrosshairPosition(normalizedPosition)
        
        // Notify delegate about crosshair change
        let worldPosition = mprRenderer.slicePosition
        delegate?.mprViewController(self, didMoveCrosshair: worldPosition)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: metalView)
        let viewSize = metalView.bounds.size
        
        switch gesture.state {
        case .began:
            lastPanTranslation = CGPoint.zero
            
        case .changed:
            // Check if this is a crosshair move (single finger) or pan (requires modifier)
            if gesture.numberOfTouches == 1 {
                // Single finger - move crosshair
                let location = gesture.location(in: metalView)
                let normalizedPosition = simd_float2(
                    Float(location.x / viewSize.width),
                    Float(location.y / viewSize.height)
                )
                mprRenderer.setCrosshairPosition(normalizedPosition)
                
                let worldPosition = mprRenderer.slicePosition
                delegate?.mprViewController(self, didMoveCrosshair: worldPosition)
            } else {
                // Multi-finger - pan image
                let deltaTranslation = CGPoint(
                    x: translation.x - lastPanTranslation.x,
                    y: translation.y - lastPanTranslation.y
                )
                
                let normalizedDelta = simd_float2(
                    Float(deltaTranslation.x / viewSize.width),
                    Float(deltaTranslation.y / viewSize.height)
                )
                
                panOffset += normalizedDelta / currentZoom
                mprRenderer.setPan(offset: panOffset)
                
                lastPanTranslation = translation
            }
            
        case .ended, .cancelled:
            lastPanTranslation = CGPoint.zero
            
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .changed:
            let newZoom = currentZoom * Float(gesture.scale)
            currentZoom = max(0.1, min(10.0, newZoom))
            mprRenderer.setZoom(currentZoom)
            zoomSlider.value = currentZoom
            gesture.scale = 1.0
            
        default:
            break
        }
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .changed:
            currentRotation += Float(gesture.rotation)
            mprRenderer.setRotation(currentRotation)
            gesture.rotation = 0.0
            
        default:
            break
        }
    }
    
    // MARK: - Public Interface
    func setPlane(_ plane: MPRRenderer.MPRPlane) {
        planeSegmentedControl.selectedSegmentIndex = plane.rawValue
        mprRenderer.setPlane(plane)
        updateSliceControls()
        updateUI()
    }
    
    func setSliceIndex(_ index: Int) {
        mprRenderer.setSliceIndex(index)
        sliceSlider.value = Float(index + 1)
        updateUI()
    }
    
    func setCrosshairPosition(_ position: simd_float2) {
        mprRenderer.setCrosshairPosition(position)
    }
    
    func synchronizeWith(_ otherController: MPRViewController) {
        // Synchronize window/level
        let center = windowCenterSlider.value
        let width = windowWidthSlider.value
        otherController.windowCenterSlider.value = center
        otherController.windowWidthSlider.value = width
        otherController.mprRenderer.setWindowLevel(center: center, width: width)
        
        // Synchronize crosshair
        let crosshairPos = mprRenderer.slicePosition
        let normalizedPos = simd_float2(crosshairPos.x, crosshairPos.y)
        otherController.setCrosshairPosition(normalizedPos)
        
        otherController.updateUI()
    }
    
    var currentPlane: MPRRenderer.MPRPlane {
        return mprRenderer.currentPlaneType
    }
    
    var currentSliceIndex: Int {
        return mprRenderer.currentSliceIndex
    }
}

// MARK: - MTKViewDelegate
extension MPRViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle drawable size changes
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        
        mprRenderer.render(to: drawable, viewportSize: view.drawableSize)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension MPRViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - MPRViewControllerDelegate
protocol MPRViewControllerDelegate: AnyObject {
    func mprViewController(_ controller: MPRViewController, didChangePlane plane: MPRRenderer.MPRPlane)
    func mprViewController(_ controller: MPRViewController, didChangeSlice sliceIndex: Int)
    func mprViewController(_ controller: MPRViewController, didMoveCrosshair position: simd_float3)
}

// MARK: - Tri-Planar Container
class TriPlanarViewController: UIViewController {
    
    @IBOutlet weak var axialContainerView: UIView!
    @IBOutlet weak var sagittalContainerView: UIView!
    @IBOutlet weak var coronalContainerView: UIView!
    @IBOutlet weak var volumeContainerView: UIView!
    
    private var axialMPR: MPRViewController!
    private var sagittalMPR: MPRViewController!
    private var coronalMPR: MPRViewController!
    private var volumeViewController: ViewerViewController?
    
    private var currentSeries: DICOMSeries?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTriPlanarViews()
    }
    
    private func setupTriPlanarViews() {
        // Create MPR view controllers
        axialMPR = createMPRViewController(plane: .axial, in: axialContainerView)
        sagittalMPR = createMPRViewController(plane: .sagittal, in: sagittalContainerView)
        coronalMPR = createMPRViewController(plane: .coronal, in: coronalContainerView)
        
        // Set up delegation for synchronization
        axialMPR.delegate = self
        sagittalMPR.delegate = self
        coronalMPR.delegate = self
    }
    
    private func createMPRViewController(plane: MPRRenderer.MPRPlane, in containerView: UIView) -> MPRViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let mprVC = storyboard.instantiateViewController(withIdentifier: "MPRViewController") as! MPRViewController
        
        addChild(mprVC)
        containerView.addSubview(mprVC.view)
        mprVC.view.frame = containerView.bounds
        mprVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mprVC.didMove(toParent: self)
        
        mprVC.setPlane(plane)
        
        return mprVC
    }
    
    func loadSeries(_ series: DICOMSeries, volumeTexture: MTLTexture?, voxelSpacing: simd_float3) {
        self.currentSeries = series
        
        if let volumeTexture = volumeTexture {
            axialMPR.loadVolumeDirectly(texture: volumeTexture, spacing: voxelSpacing)
            sagittalMPR.loadVolumeDirectly(texture: volumeTexture, spacing: voxelSpacing)
            coronalMPR.loadVolumeDirectly(texture: volumeTexture, spacing: voxelSpacing)
            
            synchronizeCrosshairs()
            
            print("Tri-planar view loaded:", series.seriesDescription ?? "Unknown")
        }
    }
    
    private func synchronizeCrosshairs() {
        let centerPosition = simd_float2(0.5, 0.5)
        axialMPR.setCrosshairPosition(centerPosition)
        sagittalMPR.setCrosshairPosition(centerPosition)
        coronalMPR.setCrosshairPosition(centerPosition)
    }
}

// MARK: - TriPlanarViewController + MPRViewControllerDelegate
extension TriPlanarViewController: MPRViewControllerDelegate {
    func mprViewController(_ controller: MPRViewController, didChangePlane plane: MPRRenderer.MPRPlane) {
        // Plane changes are independent in tri-planar view
    }
    
    func mprViewController(_ controller: MPRViewController, didChangeSlice sliceIndex: Int) {
        // Synchronize crosshair position when slice changes
        synchronizeCrosshairs()
    }
    
    func mprViewController(_ controller: MPRViewController, didMoveCrosshair position: simd_float3) {
        // Synchronize crosshair across all three planes
        synchronizeCrosshairAtPosition(position, excludingController: controller)
    }
    
    private func synchronizeCrosshairAtPosition(_ position: simd_float3, excludingController: MPRViewController) {
        let controllers = [axialMPR, sagittalMPR, coronalMPR]
        
        for controller in controllers {
            guard controller != excludingController else { continue }
            
            // Convert 3D position to 2D slice coordinate for each plane
            let normalizedPos: simd_float2
            
            switch controller?.currentPlane {
            case .axial:
                normalizedPos = simd_float2(position.x, position.y)
            case .sagittal:
                normalizedPos = simd_float2(position.y, position.z)
            case .coronal:
                normalizedPos = simd_float2(position.x, position.z)
            case .none:
                continue
            }
            
            controller?.setCrosshairPosition(normalizedPos)
        }
    }
}