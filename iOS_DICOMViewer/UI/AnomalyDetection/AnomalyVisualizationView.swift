//
//  AnomalyVisualizationView.swift
//  iOS_DICOMViewer
//
//  Revolutionary Anomaly Detection Visualization Interface
//  The most advanced medical anomaly visualization ever created
//

import SwiftUI
import Metal
import MetalKit
import Charts
import Combine

// MARK: - Main Anomaly Visualization View

struct AnomalyVisualizationView: View {
    @StateObject private var detector = AnomalyDetectionSystem()
    @State private var selectedAnomaly: MedicalAnomaly?
    @State private var visualizationMode: VisualizationMode = .heatmap
    @State private var showDetails = false
    @State private var animateHeatmap = true
    @State private var confidenceThreshold: Float = 0.5
    
    let study: DICOMStudy
    let images: [DICOMInstance]
    
    var body: some View {
        ZStack {
            // Dark medical-grade background
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with controls
                AnomalyControlHeader(
                    visualizationMode: $visualizationMode,
                    confidenceThreshold: $confidenceThreshold,
                    onDetect: startDetection
                )
                
                // Main visualization area
                GeometryReader { geometry in
                    ZStack {
                        // Base DICOM image with overlays
                        AnomalyOverlayView(
                            study: study,
                            anomalies: detector.detectedAnomalies,
                            heatmaps: detector.heatmaps,
                            visualizationMode: visualizationMode,
                            selectedAnomaly: $selectedAnomaly,
                            geometry: geometry
                        )
                        
                        // Animated scanning effect during detection
                        if detector.detectionProgress.phase != .idle &&
                           detector.detectionProgress.phase != .completed {
                            ScanningAnimationView(progress: detector.detectionProgress)
                        }
                    }
                }
                
                // Bottom panel with anomaly list and statistics
                AnomalyBottomPanel(
                    anomalies: detector.detectedAnomalies,
                    selectedAnomaly: $selectedAnomaly,
                    showDetails: $showDetails
                )
            }
            
            // Floating confidence metrics
            if !detector.detectedAnomalies.isEmpty {
                ConfidenceMetricsOverlay(metrics: detector.confidenceMetrics)
                    .position(x: 100, y: 100)
            }
            
            // Detail sheet
            if showDetails, let anomaly = selectedAnomaly {
                AnomalyDetailSheet(
                    anomaly: anomaly,
                    isPresented: $showDetails
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if detector.detectedAnomalies.isEmpty {
                startDetection()
            }
        }
    }
    
    private func startDetection() {
        Task {
            do {
                _ = try await detector.detectAnomalies(
                    in: images,
                    studyContext: study,
                    detectionMode: .comprehensive,
                    sensitivityLevel: .high
                )
            } catch {
                print("Detection error: \(error)")
            }
        }
    }
}

// MARK: - Control Header

struct AnomalyControlHeader: View {
    @Binding var visualizationMode: VisualizationMode
    @Binding var confidenceThreshold: Float
    let onDetect: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Title
                Text("AI Anomaly Detection")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Run detection button
                Button(action: onDetect) {
                    HStack {
                        Image(systemName: "brain")
                        Text("Detect")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cyan)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .shadow(color: .cyan.opacity(0.5), radius: 8)
                }
            }
            
            HStack(spacing: 20) {
                // Visualization mode picker
                Picker("Mode", selection: $visualizationMode) {
                    ForEach(VisualizationMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)
                
                // Confidence threshold slider
                VStack(alignment: .leading) {
                    Text("Confidence Threshold: \(Int(confidenceThreshold * 100))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Slider(value: $confidenceThreshold, in: 0...1) {
                        Text("Confidence")
                    }
                    .accentColor(.cyan)
                    .frame(width: 200)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(white: 0.1))
    }
}

// MARK: - Anomaly Overlay View

struct AnomalyOverlayView: View {
    let study: DICOMStudy
    let anomalies: [MedicalAnomaly]
    let heatmaps: [AnomalyHeatmap]
    let visualizationMode: VisualizationMode
    @Binding var selectedAnomaly: MedicalAnomaly?
    let geometry: GeometryProxy
    
    @State private var currentImageIndex = 0
    @State private var overlayOpacity: Double = 0.7
    
    var body: some View {
        ZStack {
            // Base DICOM image
            if let currentImage = getCurrentImage() {
                DICOMImageView(instance: currentImage)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            
            // Visualization overlay based on mode
            switch visualizationMode {
            case .heatmap:
                if let heatmap = heatmaps.first {
                    HeatmapOverlay(
                        heatmap: heatmap,
                        opacity: overlayOpacity
                    )
                }
                
            case .boundingBoxes:
                BoundingBoxOverlay(
                    anomalies: anomalies,
                    selectedAnomaly: $selectedAnomaly,
                    imageSize: geometry.size
                )
                
            case .contours:
                ContourOverlay(
                    anomalies: anomalies,
                    selectedAnomaly: $selectedAnomaly,
                    imageSize: geometry.size
                )
                
            case .combined:
                // Show both heatmap and bounding boxes
                if let heatmap = heatmaps.first {
                    HeatmapOverlay(
                        heatmap: heatmap,
                        opacity: overlayOpacity * 0.5
                    )
                }
                BoundingBoxOverlay(
                    anomalies: anomalies,
                    selectedAnomaly: $selectedAnomaly,
                    imageSize: geometry.size
                )
            }
            
            // Opacity control
            VStack {
                HStack {
                    Spacer()
                    OpacityControl(opacity: $overlayOpacity)
                        .padding()
                }
                Spacer()
            }
        }
    }
    
    private func getCurrentImage() -> DICOMInstance? {
        study.allInstances[safe: currentImageIndex]
    }
}

// MARK: - Heatmap Overlay

struct HeatmapOverlay: View {
    let heatmap: AnomalyHeatmap
    let opacity: Double
    
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Metal view for GPU-accelerated heatmap rendering
                MetalHeatmapView(
                    heatmap: heatmap,
                    size: geometry.size
                )
                .opacity(opacity)
                .blendMode(.screen)
                
                // Animated pulse effect for high-confidence areas
                if animationPhase > 0 {
                    PulseEffectView(
                        heatmap: heatmap,
                        phase: animationPhase,
                        size: geometry.size
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
        }
    }
}

// MARK: - Metal Heatmap View

struct MetalHeatmapView: UIViewRepresentable {
    let heatmap: AnomalyHeatmap
    let size: CGSize
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 30
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.heatmap = heatmap
        uiView.setNeedsDisplay()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(heatmap: heatmap)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var heatmap: AnomalyHeatmap
        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?
        
        init(heatmap: AnomalyHeatmap) {
            self.heatmap = heatmap
            super.init()
            setupMetal()
        }
        
        private func setupMetal() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeCommandQueue() else { return }
            
            self.commandQueue = commandQueue
            
            // Create pipeline state for heatmap rendering
            // Implementation details...
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size changes
        }
        
        func draw(in view: MTKView) {
            // Render heatmap using Metal
            guard let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            
            // Configure render pass
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            // Render heatmap texture
            // Implementation details...
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Bounding Box Overlay

struct BoundingBoxOverlay: View {
    let anomalies: [MedicalAnomaly]
    @Binding var selectedAnomaly: MedicalAnomaly?
    let imageSize: CGSize
    
    var body: some View {
        ZStack {
            ForEach(anomalies) { anomaly in
                AnomalyBoundingBox(
                    anomaly: anomaly,
                    isSelected: selectedAnomaly?.id == anomaly.id,
                    imageSize: imageSize,
                    onTap: {
                        withAnimation(.spring()) {
                            selectedAnomaly = anomaly
                        }
                    }
                )
            }
        }
    }
}

struct AnomalyBoundingBox: View {
    let anomaly: MedicalAnomaly
    let isSelected: Bool
    let imageSize: CGSize
    let onTap: () -> Void
    
    @State private var showLabel = true
    @State private var pulseAnimation = false
    
    var boundingColor: Color {
        switch anomaly.severity {
        case .critical: return .red
        case .severe: return .orange
        case .moderate: return .yellow
        case .mild: return .cyan
        case .minimal: return .green
        }
    }
    
    var body: some View {
        let rect = denormalizeRect(anomaly.location, in: imageSize)
        
        ZStack(alignment: .topLeading) {
            // Bounding box
            RoundedRectangle(cornerRadius: 4)
                .stroke(boundingColor, lineWidth: isSelected ? 3 : 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(boundingColor.opacity(0.1))
                )
                .frame(width: rect.width, height: rect.height)
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
            
            // Confidence label
            if showLabel {
                HStack(spacing: 4) {
                    Image(systemName: iconForAnomaly(anomaly))
                        .font(.system(size: 12))
                    
                    Text("\(Int(anomaly.confidence.overall * 100))%")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(boundingColor)
                        .shadow(radius: 4)
                )
                .foregroundColor(.black)
                .offset(x: -2, y: -20)
            }
        }
        .position(x: rect.midX, y: rect.midY)
        .onTapGesture(perform: onTap)
        .onAppear {
            if anomaly.severity.rawValue >= 3 {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
    }
    
    private func denormalizeRect(_ normalized: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: normalized.origin.x * size.width,
            y: normalized.origin.y * size.height,
            width: normalized.width * size.width,
            height: normalized.height * size.height
        )
    }
    
    private func iconForAnomaly(_ anomaly: MedicalAnomaly) -> String {
        switch anomaly.type {
        case .mass: return "circle.fill"
        case .nodule: return "circlebadge.fill"
        case .lesion: return "hexagon.fill"
        case .hemorrhage: return "drop.fill"
        case .edema: return "cloud.fill"
        case .calcification: return "diamond.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Anomaly Bottom Panel

struct AnomalyBottomPanel: View {
    let anomalies: [MedicalAnomaly]
    @Binding var selectedAnomaly: MedicalAnomaly?
    @Binding var showDetails: Bool
    
    @State private var sortBy: SortCriteria = .severity
    
    enum SortCriteria: String, CaseIterable {
        case severity = "Severity"
        case confidence = "Confidence"
        case size = "Size"
    }
    
    var sortedAnomalies: [MedicalAnomaly] {
        switch sortBy {
        case .severity:
            return anomalies.sorted { $0.severity.rawValue > $1.severity.rawValue }
        case .confidence:
            return anomalies.sorted { $0.confidence.overall > $1.confidence.overall }
        case .size:
            return anomalies.sorted { 
                ($0.measurements.first?.value ?? 0) > ($1.measurements.first?.value ?? 0)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Detected Anomalies (\(anomalies.count))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Sort picker
                Picker("Sort by", selection: $sortBy) {
                    ForEach(SortCriteria.allCases, id: \.self) { criteria in
                        Text(criteria.rawValue).tag(criteria)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .accentColor(.cyan)
            }
            .padding()
            .background(Color(white: 0.15))
            
            // Anomaly list
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sortedAnomalies) { anomaly in
                        AnomalyCard(
                            anomaly: anomaly,
                            isSelected: selectedAnomaly?.id == anomaly.id,
                            onTap: {
                                selectedAnomaly = anomaly
                                showDetails = true
                            }
                        )
                    }
                }
                .padding()
            }
            .frame(height: 140)
            .background(Color(white: 0.1))
        }
    }
}

// MARK: - Anomaly Card

struct AnomalyCard: View {
    let anomaly: MedicalAnomaly
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type and severity
            HStack {
                Text(anomaly.type.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                SeverityBadge(severity: anomaly.severity)
            }
            
            // Location
            Text(anomaly.anatomicalRegion)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            // Confidence bar
            VStack(alignment: .leading, spacing: 2) {
                Text("Confidence: \(Int(anomaly.confidence.overall * 100))%")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(confidenceColor(anomaly.confidence.overall))
                            .frame(width: geometry.size.width * CGFloat(anomaly.confidence.overall))
                    }
                }
                .frame(height: 4)
            }
            
            // Measurements
            if let size = anomaly.measurements.first {
                Text("\(size.value, specifier: "%.1f") \(size.unit)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cyan)
            }
        }
        .padding()
        .frame(width: 200, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: isSelected ? 0.2 : 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
                )
        )
        .shadow(color: isSelected ? Color.cyan.opacity(0.3) : Color.clear, radius: 8)
        .onTapGesture(perform: onTap)
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .yellow
        } else {
            return .orange
        }
    }
}

// MARK: - Severity Badge

struct SeverityBadge: View {
    let severity: MedicalAnomaly.Severity
    
    var backgroundColor: Color {
        switch severity {
        case .critical: return .red
        case .severe: return .orange
        case .moderate: return .yellow
        case .mild: return .cyan
        case .minimal: return .green
        }
    }
    
    var body: some View {
        Text(severity.displayName.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }
}

// MARK: - Supporting Types

enum VisualizationMode: String, CaseIterable {
    case heatmap = "Heatmap"
    case boundingBoxes = "Boxes"
    case contours = "Contours"
    case combined = "Combined"
    
    var displayName: String { rawValue }
}

// MARK: - Scanning Animation

struct ScanningAnimationView: View {
    let progress: DetectionProgress
    @State private var scanLineOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Scanning grid overlay
                ScanningGrid()
                    .opacity(0.3)
                
                // Animated scan line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0),
                                Color.cyan.opacity(0.8),
                                Color.cyan.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .offset(y: scanLineOffset)
                    .shadow(color: .cyan, radius: 10)
                
                // Progress indicator
                VStack {
                    Spacer()
                    DetectionProgressBar(progress: progress)
                        .padding()
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                scanLineOffset = UIScreen.main.bounds.height
            }
        }
    }
}

struct ScanningGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let gridSize: CGFloat = 50
                
                // Vertical lines
                for x in stride(from: 0, to: geometry.size.width, by: gridSize) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                
                // Horizontal lines
                for y in stride(from: 0, to: geometry.size.height, by: gridSize) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.cyan.opacity(0.2), lineWidth: 0.5)
        }
    }
}

// MARK: - Helpers

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct DICOMImageView: View {
    let instance: DICOMInstance
    
    var body: some View {
        // Placeholder for actual DICOM image display
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Text("DICOM Image")
                    .foregroundColor(.gray)
            )
    }
}

struct OpacityControl: View {
    @Binding var opacity: Double
    
    var body: some View {
        VStack {
            Image(systemName: "eye.fill")
                .foregroundColor(.gray)
            
            Slider(value: $opacity, in: 0...1) {
                Text("Opacity")
            }
            .frame(height: 100)
            .rotationEffect(.degrees(-90))
            .frame(width: 100, height: 30)
            
            Text("\(Int(opacity * 100))%")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
        )
    }
}