//
//  AutoSegmentationViewController+Enhanced.swift
//  iOS_DICOMViewer
//
//  Enhanced 3D visualization and AI segmentation with Metal-based rendering
//

import UIKit
import Metal
import MetalKit
import simd

extension AutoSegmentationViewController: MTKViewDelegate {
    
    // MARK: - Volume Rendering Setup
    
    func setupVolumeRenderer() {
        guard let device = volumeRenderingView.device else { return }
        
        volumeRenderer = VolumeRenderer()
        volumeRenderer?.delegate = self
        volumeRenderingView.delegate = self
        
        // Configure for iPhone 16 Pro Max performance
        if device.supportsFamily(.apple7) {
            volumeRenderer?.setQualityLevel(.ultra)
        } else {
            volumeRenderer?.setQualityLevel(.high)
        }
        
        // Set initial rendering parameters
        volumeRenderer?.setRenderingTechnique(.rayCasting)
        volumeRenderer?.setTransferFunction(.defaultCT)
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        volumeRenderer?.updateViewportSize(size)
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let volumeRenderer = volumeRenderer else { return }
        
        volumeRenderer.render(to: drawable, viewportSize: view.drawableSize)
    }
    
    // MARK: - Enhanced Study Loading
    
    func loadStudyWithVolume(_ study: DICOMStudy) {
        self.study = study
        
        Task {
            do {
                // Show loading indicator
                await MainActor.run {
                    showLoadingOverlay()
                }
                
                // Load volume data
                let volumeData = try await loadVolumeData(from: study)
                
                // Create 3D texture
                guard let volumeTexture = createVolumeTexture(from: volumeData) else {
                    throw DICOMError.renderingFailed("Failed to create volume texture")
                }
                
                // Update renderer
                await MainActor.run {
                    self.volumeRenderer?.loadVolume(from: volumeTexture, voxelSpacing: volumeData.spacing)
                    self.updateUIForStudyLoaded()
                    self.hideLoadingOverlay()
                    
                    // Remove placeholder
                    self.volumeRenderingView.subviews.forEach { $0.removeFromSuperview() }
                }
                
                print("✅ 3D volume loaded successfully")
                
            } catch {
                await MainActor.run {
                    self.hideLoadingOverlay()
                    self.showError(error)
                }
            }
        }
    }
    
    // MARK: - Segmentation Integration
    
    func performUrinaryTractSegmentationEnhanced() {
        guard let study = study else {
            showAlert(title: "No Study", message: "Please load a DICOM study first")
            return
        }
        
        Task {
            do {
                // Show progress
                await MainActor.run {
                    self.showSegmentationProgress(title: "Urinary Tract Segmentation", progress: 0)
                }
                
                // Get segmentation service
                let segmentationService = DICOMServiceManager.shared.urinaryTractSegmentationService
                
                // Perform segmentation with progress updates
                let result = try await segmentationService.performSegmentation(
                    on: study,
                    progressHandler: { progress in
                        Task { @MainActor in
                            self.updateSegmentationProgress(progress)
                        }
                    }
                )
                
                // Display results
                await MainActor.run {
                    self.hideSegmentationProgress()
                    self.displaySegmentationResults(result)
                    self.overlaySegmentationOnVolume(result)
                }
                
            } catch {
                await MainActor.run {
                    self.hideSegmentationProgress()
                    self.showError(error)
                }
            }
        }
    }
    
    func performMultiOrganSegmentationEnhanced() {
        guard let study = study else {
            showAlert(title: "No Study", message: "Please load a DICOM study first")
            return
        }
        
        Task {
            do {
                // Show progress
                await MainActor.run {
                    self.showSegmentationProgress(title: "Multi-Organ Segmentation", progress: 0)
                }
                
                // Get segmentation service
                let segmentationService = DICOMServiceManager.shared.automaticSegmentationService
                
                // Perform segmentation
                let volumes = try await segmentationService.segment(
                    series: study.series.first!,
                    progressHandler: { progress in
                        Task { @MainActor in
                            self.updateSegmentationProgress(progress)
                        }
                    }
                )
                
                // Convert to results
                let results = volumes.map { volume in
                    SegmentationResult(
                        organName: volume.name,
                        volume: volume.volumeInML,
                        confidence: volume.confidence,
                        processingTime: 0,
                        qualityMetrics: [
                            "Dice": volume.diceCoefficient ?? 0,
                            "Jaccard": volume.jaccardIndex ?? 0
                        ]
                    )
                }
                
                // Display results
                await MainActor.run {
                    self.hideSegmentationProgress()
                    self.segmentationResults = results
                    self.displayMultiOrganResults(results)
                    self.overlayMultiOrganSegmentation(volumes)
                }
                
            } catch {
                await MainActor.run {
                    self.hideSegmentationProgress()
                    self.showError(error)
                }
            }
        }
    }
    
    // MARK: - Volume Data Loading
    
    private func loadVolumeData(from study: DICOMStudy) async throws -> VolumeData {
        guard let series = study.series.first else {
            throw DICOMError.invalidData("No series found in study")
        }
        
        let instances = series.instances.sorted { $0.metadata.instanceNumber ?? 0 < $1.metadata.instanceNumber ?? 0 }
        
        guard !instances.isEmpty else {
            throw DICOMError.invalidData("No instances in series")
        }
        
        // Get volume dimensions
        let firstInstance = instances[0]
        let width = firstInstance.metadata.columns
        let height = firstInstance.metadata.rows
        let depth = instances.count
        
        // Get voxel spacing
        let pixelSpacing = firstInstance.metadata.pixelSpacing ?? [1.0, 1.0]
        let sliceThickness = firstInstance.metadata.sliceThickness ?? 1.0
        let spacing = simd_float3(
            Float(pixelSpacing[0]),
            Float(pixelSpacing[1]),
            Float(sliceThickness)
        )
        
        // Allocate volume data
        var volumeData = [UInt16](repeating: 0, count: width * height * depth)
        
        // Load slices
        for (z, instance) in instances.enumerated() {
            if let pixelData = try? await loadSliceData(from: instance) {
                let sliceOffset = z * width * height
                for i in 0..<(width * height) {
                    volumeData[sliceOffset + i] = pixelData[i]
                }
            }
        }
        
        return VolumeData(
            data: volumeData,
            dimensions: (width: width, height: height, depth: depth),
            spacing: spacing
        )
    }
    
    private func loadSliceData(from instance: DICOMInstance) async throws -> [UInt16] {
        // Use DICOMImageRenderer to get pixel data
        // This is a simplified version - actual implementation would use DCMTKBridge
        return [UInt16](repeating: 0, count: instance.metadata.columns * instance.metadata.rows)
    }
    
    private func createVolumeTexture(from volumeData: VolumeData) -> MTLTexture? {
        guard let device = volumeRenderingView.device else { return nil }
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.pixelFormat = .r16Uint
        textureDescriptor.width = volumeData.dimensions.width
        textureDescriptor.height = volumeData.dimensions.height
        textureDescriptor.depth = volumeData.dimensions.depth
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return nil }
        
        volumeData.data.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegion(
                    origin: MTLOrigin(x: 0, y: 0, z: 0),
                    size: MTLSize(
                        width: volumeData.dimensions.width,
                        height: volumeData.dimensions.height,
                        depth: volumeData.dimensions.depth
                    )
                ),
                mipmapLevel: 0,
                slice: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: volumeData.dimensions.width * 2,
                bytesPerImage: volumeData.dimensions.width * volumeData.dimensions.height * 2
            )
        }
        
        return texture
    }
    
    // MARK: - UI Updates
    
    private func showLoadingOverlay() {
        let overlay = UIView()
        overlay.tag = 999
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "Loading 3D Volume..."
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        overlay.addSubview(activityIndicator)
        overlay.addSubview(label)
        view.addSubview(overlay)
        
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),
            
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor)
        ])
    }
    
    private func hideLoadingOverlay() {
        view.viewWithTag(999)?.removeFromSuperview()
    }
    
    private func showSegmentationProgress(title: String, progress: Float) {
        // Implementation for progress overlay
    }
    
    private func updateSegmentationProgress(_ progress: Float) {
        // Update progress overlay
    }
    
    private func hideSegmentationProgress() {
        // Hide progress overlay
    }
    
    private func displaySegmentationResults(_ result: Any) {
        // Update results view with segmentation data
    }
    
    private func displayMultiOrganResults(_ results: [SegmentationResult]) {
        // Clear previous results
        resultsView.subviews.forEach { $0.removeFromSuperview() }
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = createSectionTitle("📊 Analysis Results")
        stackView.addArrangedSubview(titleLabel)
        
        // Add result cards for each organ
        for result in results {
            let card = createResultCard(for: result)
            stackView.addArrangedSubview(card)
        }
        
        resultsView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: resultsView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: resultsView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: resultsView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: resultsView.bottomAnchor, constant: -16)
        ])
    }
    
    private func createResultCard(for result: SegmentationResult) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(red: 27/255, green: 36/255, blue: 39/255, alpha: 1.0)
        card.layer.cornerRadius = 8
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Organ icon and name
        let nameLabel = UILabel()
        nameLabel.text = result.organName
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .white
        
        // Volume label
        let volumeLabel = UILabel()
        volumeLabel.text = String(format: "%.1f mL", result.volume)
        volumeLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        volumeLabel.textColor = UIColor(red: 12/255, green: 184/255, blue: 242/255, alpha: 1.0)
        volumeLabel.textAlignment = .right
        
        // Confidence indicator
        let confidenceView = createConfidenceIndicator(result.confidence)
        
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(UIView()) // Spacer
        stackView.addArrangedSubview(confidenceView)
        stackView.addArrangedSubview(volumeLabel)
        
        card.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            card.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        return card
    }
    
    private func createConfidenceIndicator(_ confidence: Double) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = String(format: "%.0f%%", confidence * 100)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = confidenceColor(for: confidence)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 40)
        ])
        
        return containerView
    }
    
    private func confidenceColor(for confidence: Double) -> UIColor {
        if confidence >= 0.9 {
            return UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1.0) // Green
        } else if confidence >= 0.7 {
            return UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1.0) // Yellow
        } else {
            return UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0) // Red
        }
    }
    
    private func overlaySegmentationOnVolume(_ result: Any) {
        // Overlay segmentation masks on 3D volume
        volumeRenderer?.enableSegmentationOverlay(true)
    }
    
    private func overlayMultiOrganSegmentation(_ volumes: [SegmentedVolume]) {
        // Create color map for organs
        var colorMap: [String: simd_float4] = [:]
        let colors: [simd_float4] = [
            simd_float4(1.0, 0.0, 0.0, 0.5),  // Red
            simd_float4(0.0, 1.0, 0.0, 0.5),  // Green
            simd_float4(0.0, 0.0, 1.0, 0.5),  // Blue
            simd_float4(1.0, 1.0, 0.0, 0.5),  // Yellow
            simd_float4(1.0, 0.0, 1.0, 0.5),  // Magenta
            simd_float4(0.0, 1.0, 1.0, 0.5),  // Cyan
        ]
        
        for (index, volume) in volumes.enumerated() {
            colorMap[volume.name] = colors[index % colors.count]
        }
        
        volumeRenderer?.setSegmentationColorMap(colorMap)
        volumeRenderer?.enableSegmentationOverlay(true)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - VolumeRendererDelegate

extension AutoSegmentationViewController: VolumeRendererDelegate {
    func volumeRenderer(_ renderer: VolumeRenderer, didUpdateRenderingTime time: TimeInterval) {
        // Update performance metrics if needed
    }
    
    func volumeRenderer(_ renderer: VolumeRenderer, didEncounterError error: Error) {
        showError(error)
    }
}

// MARK: - Supporting Types

private struct VolumeData {
    let data: [UInt16]
    let dimensions: (width: Int, height: Int, depth: Int)
    let spacing: simd_float3
}

// Add properties to main class
extension AutoSegmentationViewController {
    private struct AssociatedKeys {
        static var volumeRenderer = "volumeRenderer"
    }
    
    var volumeRenderer: VolumeRenderer? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.volumeRenderer) as? VolumeRenderer
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.volumeRenderer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}