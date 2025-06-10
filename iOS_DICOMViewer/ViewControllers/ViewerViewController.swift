//
//  ViewerViewController.swift
//  iOS_DICOMViewer
//
//  Created on 6/9/25.
//

import UIKit
import Metal
import MetalKit

class ViewerViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.delegate = self
        scroll.minimumZoomScale = 0.1
        scroll.maximumZoomScale = 10.0
        scroll.zoomScale = 1.0
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var seriesSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl()
        control.backgroundColor = .systemGray6
        control.selectedSegmentTintColor = .systemBlue
        control.addTarget(self, action: #selector(seriesChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private lazy var instanceSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0
        slider.isContinuous = true
        slider.addTarget(self, action: #selector(instanceChanged), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    private lazy var instanceLabel: UILabel = {
        let label = UILabel()
        label.text = "1 / 1"
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var windowLevelControlsView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        view.layer.cornerRadius = 12
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let windowLabel = UILabel()
        windowLabel.text = "Window"
        windowLabel.textColor = .white
        windowLabel.font = .systemFont(ofSize: 12)
        windowLabel.translatesAutoresizingMaskIntoConstraints = false
        
        windowSlider.translatesAutoresizingMaskIntoConstraints = false
        
        let levelLabel = UILabel()
        levelLabel.text = "Level"
        levelLabel.textColor = .white
        levelLabel.font = .systemFont(ofSize: 12)
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        
        levelSlider.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [windowLabel, windowSlider, levelLabel, levelSlider])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
        
        return view
    }()
    
    private lazy var windowSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 1
        slider.maximumValue = 4000
        slider.value = 400
        slider.addTarget(self, action: #selector(windowLevelChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var levelSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = -1000
        slider.maximumValue = 3000
        slider.value = 40
        slider.addTarget(self, action: #selector(windowLevelChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var toolsButton: UIBarButtonItem = {
        return UIBarButtonItem(
            image: UIImage(systemName: "slider.horizontal.3"),
            style: .plain,
            target: self,
            action: #selector(toggleWindowLevelControls)
        )
    }()
    
    // MARK: - Properties
    private let study: DICOMStudy
    private var currentSeriesIndex: Int = 0
    private var currentInstanceIndex: Int = 0
    private var currentWindow: Float = 400
    private var currentLevel: Float = 40
    private var isShowingWindowLevelControls = false
    
    // Gesture recognizers
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var lastPanLocation: CGPoint = .zero
    
    // DICOM rendering
    private let imageRenderer = DICOMImageRenderer()
    private let imageCache = DICOMImageCache()
    
    // MARK: - Lifecycle
    init(study: DICOMStudy) {
        self.study = study
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupGestures()
        loadInitialImage()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        view.addSubview(seriesSegmentedControl)
        view.addSubview(instanceSlider)
        view.addSubview(instanceLabel)
        view.addSubview(windowLevelControlsView)
        
        setupConstraints()
        setupSeriesControl()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: seriesSegmentedControl.topAnchor, constant: -16),
            
            // Image view
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            // Series control
            seriesSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            seriesSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            seriesSegmentedControl.bottomAnchor.constraint(equalTo: instanceSlider.topAnchor, constant: -16),
            seriesSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            // Instance slider
            instanceSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            instanceSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            instanceSlider.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            
            // Instance label
            instanceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instanceLabel.bottomAnchor.constraint(equalTo: instanceSlider.topAnchor, constant: -8),
            instanceLabel.widthAnchor.constraint(equalToConstant: 80),
            instanceLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // Window/Level controls
            windowLevelControlsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            windowLevelControlsView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            windowLevelControlsView.widthAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func setupNavigationBar() {
        title = study.studyDescription.isEmpty ? "DICOM Viewer" : study.studyDescription
        
        navigationItem.rightBarButtonItem = toolsButton
        
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        navigationItem.leftBarButtonItem = backButton
    }
    
    private func setupSeriesControl() {
        seriesSegmentedControl.removeAllSegments()
        
        for (index, series) in study.series.enumerated() {
            let title = series.seriesDescription.isEmpty ? "Series \(index + 1)" : series.seriesDescription
            seriesSegmentedControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        
        if !study.series.isEmpty {
            seriesSegmentedControl.selectedSegmentIndex = 0
            setupInstanceSlider()
        }
    }
    
    private func setupInstanceSlider() {
        guard currentSeriesIndex < study.series.count else { return }
        
        let series = study.series[currentSeriesIndex]
        let instanceCount = series.instances.count
        
        if instanceCount > 1 {
            instanceSlider.minimumValue = 0
            instanceSlider.maximumValue = Float(instanceCount - 1)
            instanceSlider.value = 0
            instanceSlider.isHidden = false
            instanceLabel.isHidden = false
        } else {
            instanceSlider.isHidden = true
            instanceLabel.isHidden = true
        }
        
        updateInstanceLabel()
    }
    
    private func setupGestures() {
        // Pan gesture for window/level adjustment
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer?.minimumNumberOfTouches = 1
        panGestureRecognizer?.maximumNumberOfTouches = 1
        if let panGesture = panGestureRecognizer {
            scrollView.addGestureRecognizer(panGesture)
        }
        
        // Double tap to reset zoom
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
    }
    
    // MARK: - Image Loading
    private func loadInitialImage() {
        loadCurrentImage()
    }
    
    private func loadCurrentImage() {
        guard currentSeriesIndex < study.series.count else { return }
        
        let series = study.series[currentSeriesIndex]
        guard currentInstanceIndex < series.instances.count else { return }
        
        let instance = series.instances[currentInstanceIndex]
        
        Task {
            do {
                let image = try await loadDICOMImage(from: instance)
                DispatchQueue.main.async {
                    self.displayImage(image)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError(error)
                }
            }
        }
    }
    
    private func loadDICOMImage(from instance: DICOMInstance) async throws -> UIImage {
        let windowLevel = DICOMImageRenderer.WindowLevel(window: currentWindow, level: currentLevel)
        let cacheKey = instance.sopInstanceUID
        
        // Check cache first
        if let cachedImage = imageCache.image(forKey: cacheKey, windowLevel: windowLevel) {
            return cachedImage
        }
        
        // Load from file if available
        if let filePath = instance.filePath {
            if let image = try await imageRenderer.renderImage(from: filePath, windowLevel: windowLevel) {
                imageCache.setImage(image, forKey: cacheKey, windowLevel: windowLevel)
                return image
            }
        }
        
        // Fallback to placeholder
        return createPlaceholderImage(for: instance)
    }
    
    private func createPlaceholderImage(for instance: DICOMInstance) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Create a gradient representing DICOM data
            let colors = [UIColor.black.cgColor, UIColor.gray.cgColor, UIColor.white.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: colors as CFArray, locations: [0.0, 0.5, 1.0])
            
            if let gradient = gradient {
                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: size.width/2, y: size.height/2),
                    startRadius: 0,
                    endCenter: CGPoint(x: size.width/2, y: size.height/2),
                    endRadius: size.width/2,
                    options: []
                )
            }
            
            // Add some text overlay to simulate DICOM info
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 16)
            ]
            
            let text = "DICOM Image\n\(instance.sopInstanceUID.prefix(8))...\nW: \(Int(currentWindow)) L: \(Int(currentLevel))"
            let textRect = CGRect(x: 20, y: 20, width: size.width - 40, height: 100)
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func displayImage(_ image: UIImage) {
        imageView.image = image
        scrollView.zoomScale = 1.0
        
        // Center the image
        centerImageInScrollView()
    }
    
    private func centerImageInScrollView() {
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame
        
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        
        imageView.frame = frameToCenter
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func seriesChanged() {
        currentSeriesIndex = seriesSegmentedControl.selectedSegmentIndex
        currentInstanceIndex = 0
        setupInstanceSlider()
        loadCurrentImage()
    }
    
    @objc private func instanceChanged() {
        currentInstanceIndex = Int(instanceSlider.value)
        updateInstanceLabel()
        loadCurrentImage()
    }
    
    @objc private func windowLevelChanged() {
        currentWindow = windowSlider.value
        currentLevel = levelSlider.value
        
        // Apply window/level adjustment to current image
        loadCurrentImage()
    }
    
    @objc private func toggleWindowLevelControls() {
        isShowingWindowLevelControls.toggle()
        
        UIView.animate(withDuration: 0.3) {
            self.windowLevelControlsView.isHidden = !self.isShowingWindowLevelControls
        }
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard gesture.numberOfTouches == 1 else { return }
        
        let location = gesture.location(in: scrollView)
        
        switch gesture.state {
        case .began:
            lastPanLocation = location
            
        case .changed:
            let deltaX = location.x - lastPanLocation.x
            let deltaY = location.y - lastPanLocation.y
            
            // Adjust window (horizontal) and level (vertical)
            let windowDelta = deltaX * 2.0
            let levelDelta = deltaY * 2.0
            
            currentWindow = max(1, currentWindow + Float(windowDelta))
            currentLevel = currentLevel + Float(levelDelta)
            
            // Update sliders
            windowSlider.value = currentWindow
            levelSlider.value = currentLevel
            
            lastPanLocation = location
            
            // Apply changes
            loadCurrentImage()
            
        default:
            break
        }
    }
    
    @objc private func handleDoubleTap() {
        if scrollView.zoomScale == 1.0 {
            scrollView.setZoomScale(2.0, animated: true)
        } else {
            scrollView.setZoomScale(1.0, animated: true)
        }
    }
    
    private func updateInstanceLabel() {
        guard currentSeriesIndex < study.series.count else { return }
        
        let series = study.series[currentSeriesIndex]
        let total = series.instances.count
        let current = currentInstanceIndex + 1
        
        instanceLabel.text = "\(current) / \(total)"
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error Loading Image",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIScrollViewDelegate
extension ViewerViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageInScrollView()
    }
}
