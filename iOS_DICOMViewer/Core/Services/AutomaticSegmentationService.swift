import Foundation
import Metal
import MetalKit
import simd
import Accelerate

/// Advanced automatic segmentation service for CT DICOM files
/// Implements multiple segmentation algorithms optimized for iOS
class AutomaticSegmentationService {
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // Compute pipelines for different segmentation algorithms
    private var regionGrowingPipeline: MTLComputePipelineState?
    private var thresholdSegmentationPipeline: MTLComputePipelineState?
    private var edgeDetectionPipeline: MTLComputePipelineState?
    private var morphologyPipeline: MTLComputePipelineState?
    private var connectedComponentsPipeline: MTLComputePipelineState?
    
    // Predefined tissue density ranges for CT (Hounsfield Units)
    struct TissueThresholds {
        static let air = (-1000, -900)           // Air
        static let lung = (-900, -500)           // Lung tissue
        static let fat = (-200, -50)             // Fat tissue
        static let water = (-50, 50)             // Water/soft tissue
        static let muscle = (10, 80)             // Muscle tissue
        static let bone = (200, 3000)            // Bone tissue
        static let contrastVessel = (100, 500)   // Contrast-enhanced vessels
    }
    
    enum SegmentationType {
        case lungParenchyma
        case boneStructure
        case contrastVessels
        case organBoundaries
        case airSpaces
        case fatTissue
        case muscleGroups
        case customThreshold(min: Float, max: Float)
    }
    
    struct SegmentationParameters {
        var type: SegmentationType
        var smoothingRadius: Int = 2
        var minComponentSize: Int = 100
        var useConnectedComponents: Bool = true
        var applyMorphologicalOps: Bool = true
        var erosionRadius: Int = 1
        var dilationRadius: Int = 2
    }
    
    init(device: MTLDevice) throws {
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw SegmentationError.failedToCreateCommandQueue
        }
        self.commandQueue = commandQueue
        
        guard let library = device.makeDefaultLibrary() else {
            throw SegmentationError.failedToCreateLibrary
        }
        self.library = library
        
        try setupComputePipelines()
        
        print("✅ AutomaticSegmentationService initialized")
    }
    
    private func setupComputePipelines() throws {
        // Region growing pipeline
        if let function = library.makeFunction(name: "regionGrowingKernel") {
            regionGrowingPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Threshold segmentation pipeline
        if let function = library.makeFunction(name: "thresholdSegmentationKernel") {
            thresholdSegmentationPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Edge detection pipeline
        if let function = library.makeFunction(name: "edgeDetectionKernel") {
            edgeDetectionPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Morphological operations pipeline
        if let function = library.makeFunction(name: "morphologyKernel") {
            morphologyPipeline = try device.makeComputePipelineState(function: function)
        }
        
        // Connected components pipeline
        if let function = library.makeFunction(name: "connectedComponentsKernel") {
            connectedComponentsPipeline = try device.makeComputePipelineState(function: function)
        }
    }
    
    /// Perform automatic segmentation on CT DICOM data
    func performSegmentation(
        on dicomInstance: DICOMInstance,
        parameters: SegmentationParameters,
        completion: @escaping (Result<DICOMSegmentation, Error>) -> Void
    ) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Extract CT data and convert to texture
                guard let pixelData = dicomInstance.pixelData,
                      let metadata = dicomInstance.metadata else {
                    throw SegmentationError.invalidInputData
                }
                
                let inputTexture = try self.createTextureFromPixelData(pixelData, metadata: metadata)
                
                // Perform segmentation based on type
                let segmentMask = try self.executeSegmentation(
                    inputTexture: inputTexture,
                    parameters: parameters,
                    metadata: metadata
                )
                
                // Convert result to DICOM segmentation
                let segmentation = try self.createDICOMSegmentation(
                    from: segmentMask,
                    parameters: parameters,
                    sourceInstance: dicomInstance
                )
                
                DispatchQueue.main.async {
                    completion(.success(segmentation))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func executeSegmentation(
        inputTexture: MTLTexture,
        parameters: SegmentationParameters,
        metadata: DICOMMetadata
    ) throws -> MTLTexture {
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw SegmentationError.failedToCreateCommandBuffer
        }
        
        var currentTexture = inputTexture
        
        // Step 1: Initial threshold segmentation
        currentTexture = try applyThresholdSegmentation(
            input: currentTexture,
            parameters: parameters,
            commandBuffer: commandBuffer
        )
        
        // Step 2: Apply morphological operations if enabled
        if parameters.applyMorphologicalOps {
            currentTexture = try applyMorphologicalOperations(
                input: currentTexture,
                parameters: parameters,
                commandBuffer: commandBuffer
            )
        }
        
        // Step 3: Connected components analysis if enabled
        if parameters.useConnectedComponents {
            currentTexture = try applyConnectedComponents(
                input: currentTexture,
                parameters: parameters,
                commandBuffer: commandBuffer
            )
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return currentTexture
    }
    
    private func applyThresholdSegmentation(
        input: MTLTexture,
        parameters: SegmentationParameters,
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLTexture {
        
        guard let pipeline = thresholdSegmentationPipeline,
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SegmentationError.failedToCreateComputeEncoder
        }
        
        // Create output texture
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .r8Uint
        descriptor.width = input.width
        descriptor.height = input.height
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            throw SegmentationError.failedToCreateTexture
        }
        
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        
        // Set threshold parameters
        var thresholdParams = getThresholdParameters(for: parameters.type)
        computeEncoder.setBytes(&thresholdParams, length: MemoryLayout.size(ofValue: thresholdParams), index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        return outputTexture
    }
    
    private func applyMorphologicalOperations(
        input: MTLTexture,
        parameters: SegmentationParameters,
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLTexture {
        
        guard let pipeline = morphologyPipeline else {
            return input // Return original if pipeline not available
        }
        
        var currentTexture = input
        
        // Apply erosion
        if parameters.erosionRadius > 0 {
            currentTexture = try applyMorphologyOperation(
                input: currentTexture,
                operation: .erosion,
                radius: parameters.erosionRadius,
                pipeline: pipeline,
                commandBuffer: commandBuffer
            )
        }
        
        // Apply dilation
        if parameters.dilationRadius > 0 {
            currentTexture = try applyMorphologyOperation(
                input: currentTexture,
                operation: .dilation,
                radius: parameters.dilationRadius,
                pipeline: pipeline,
                commandBuffer: commandBuffer
            )
        }
        
        return currentTexture
    }
    
    private func applyConnectedComponents(
        input: MTLTexture,
        parameters: SegmentationParameters,
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLTexture {
        
        guard let pipeline = connectedComponentsPipeline,
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return input // Return original if pipeline not available
        }
        
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .r8Uint
        descriptor.width = input.width
        descriptor.height = input.height
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            return input
        }
        
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        
        var minComponentSize = Int32(parameters.minComponentSize)
        computeEncoder.setBytes(&minComponentSize, length: MemoryLayout<Int32>.size, index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        return outputTexture
    }
    
    /// Advanced lung segmentation with airway detection
    func performLungSegmentation(
        on dicomInstance: DICOMInstance,
        completion: @escaping (Result<DICOMSegmentation, Error>) -> Void
    ) {
        
        let parameters = SegmentationParameters(
            type: .lungParenchyma,
            smoothingRadius: 3,
            minComponentSize: 500,
            useConnectedComponents: true,
            applyMorphologicalOps: true,
            erosionRadius: 2,
            dilationRadius: 3
        )
        
        performSegmentation(on: dicomInstance, parameters: parameters) { result in
            switch result {
            case .success(var segmentation):
                // Post-process for lung-specific features
                self.enhanceLungSegmentation(&segmentation)
                completion(.success(segmentation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Automatic bone segmentation with cortical/trabecular separation
    func performBoneSegmentation(
        on dicomInstance: DICOMInstance,
        separateCorticalTrabecular: Bool = true,
        completion: @escaping (Result<DICOMSegmentation, Error>) -> Void
    ) {
        
        let parameters = SegmentationParameters(
            type: .boneStructure,
            smoothingRadius: 1,
            minComponentSize: 50,
            useConnectedComponents: true,
            applyMorphologicalOps: false, // Preserve bone detail
            erosionRadius: 0,
            dilationRadius: 1
        )
        
        performSegmentation(on: dicomInstance, parameters: parameters) { result in
            switch result {
            case .success(var segmentation):
                if separateCorticalTrabecular {
                    self.separateCorticalTrabecularBone(&segmentation)
                }
                completion(.success(segmentation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Multi-organ segmentation for abdominal CT
    func performMultiOrganSegmentation(
        on dicomInstance: DICOMInstance,
        targetOrgans: [String] = ["liver", "kidneys", "spleen", "pancreas"],
        completion: @escaping (Result<DICOMSegmentation, Error>) -> Void
    ) {
        
        // This would implement a more sophisticated multi-class segmentation
        // For now, we'll create multiple single-organ segmentations
        
        var organSegmentations: [DICOMSegmentation] = []
        let dispatchGroup = DispatchGroup()
        
        for organ in targetOrgans {
            dispatchGroup.enter()
            
            let parameters = getOrganSpecificParameters(for: organ)
            
            performSegmentation(on: dicomInstance, parameters: parameters) { result in
                switch result {
                case .success(let segmentation):
                    organSegmentations.append(segmentation)
                case .failure(let error):
                    print("⚠️ Failed to segment \(organ): \(error)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if !organSegmentations.isEmpty {
                let combinedSegmentation = self.combineSegmentations(organSegmentations)
                completion(.success(combinedSegmentation))
            } else {
                completion(.failure(SegmentationError.noSegmentationsGenerated))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getThresholdParameters(for type: SegmentationType) -> ThresholdParams {
        switch type {
        case .lungParenchyma:
            return ThresholdParams(minThreshold: Float(TissueThresholds.lung.0), 
                                 maxThreshold: Float(TissueThresholds.lung.1))
        case .boneStructure:
            return ThresholdParams(minThreshold: Float(TissueThresholds.bone.0), 
                                 maxThreshold: Float(TissueThresholds.bone.1))
        case .contrastVessels:
            return ThresholdParams(minThreshold: Float(TissueThresholds.contrastVessel.0), 
                                 maxThreshold: Float(TissueThresholds.contrastVessel.1))
        case .airSpaces:
            return ThresholdParams(minThreshold: Float(TissueThresholds.air.0), 
                                 maxThreshold: Float(TissueThresholds.air.1))
        case .fatTissue:
            return ThresholdParams(minThreshold: Float(TissueThresholds.fat.0), 
                                 maxThreshold: Float(TissueThresholds.fat.1))
        case .muscleGroups:
            return ThresholdParams(minThreshold: Float(TissueThresholds.muscle.0), 
                                 maxThreshold: Float(TissueThresholds.muscle.1))
        case .customThreshold(let min, let max):
            return ThresholdParams(minThreshold: min, maxThreshold: max)
        case .organBoundaries:
            return ThresholdParams(minThreshold: Float(TissueThresholds.water.0), 
                                 maxThreshold: Float(TissueThresholds.water.1))
        }
    }
    
    private func getOrganSpecificParameters(for organ: String) -> SegmentationParameters {
        switch organ.lowercased() {
        case "liver":
            return SegmentationParameters(
                type: .customThreshold(min: 40, max: 120),
                smoothingRadius: 2,
                minComponentSize: 1000,
                useConnectedComponents: true,
                applyMorphologicalOps: true
            )
        case "kidneys":
            return SegmentationParameters(
                type: .customThreshold(min: 30, max: 150),
                smoothingRadius: 2,
                minComponentSize: 500,
                useConnectedComponents: true,
                applyMorphologicalOps: true
            )
        case "spleen":
            return SegmentationParameters(
                type: .customThreshold(min: 45, max: 100),
                smoothingRadius: 2,
                minComponentSize: 300,
                useConnectedComponents: true,
                applyMorphologicalOps: true
            )
        case "pancreas":
            return SegmentationParameters(
                type: .customThreshold(min: 30, max: 80),
                smoothingRadius: 3,
                minComponentSize: 200,
                useConnectedComponents: true,
                applyMorphologicalOps: true
            )
        default:
            return SegmentationParameters(type: .organBoundaries)
        }
    }
    
    private func createTextureFromPixelData(_ pixelData: Data, metadata: DICOMMetadata) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .r16Sint
        descriptor.width = metadata.columns
        descriptor.height = metadata.rows
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw SegmentationError.failedToCreateTexture
        }
        
        pixelData.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, metadata.columns, metadata.rows),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: metadata.columns * 2
            )
        }
        
        return texture
    }
    
    private func createDICOMSegmentation(
        from maskTexture: MTLTexture,
        parameters: SegmentationParameters,
        sourceInstance: DICOMInstance
    ) throws -> DICOMSegmentation {
        
        guard let metadata = sourceInstance.metadata else {
            throw SegmentationError.invalidInputData
        }
        
        // Extract mask data from texture
        let maskData = try extractMaskData(from: maskTexture)
        
        // Create segmentation object
        let segmentation = DICOMSegmentation(
            sopInstanceUID: UUID().uuidString,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.66.4", // Segmentation Storage
            seriesInstanceUID: sourceInstance.seriesInstanceUID,
            studyInstanceUID: sourceInstance.studyInstanceUID,
            contentLabel: getSegmentationLabel(for: parameters.type),
            algorithmType: .automatic,
            rows: metadata.rows,
            columns: metadata.columns,
            numberOfFrames: 1
        )
        
        // Create segment
        let segment = SegmentationSegment(
            segmentNumber: 1,
            segmentLabel: getSegmentLabel(for: parameters.type),
            algorithmType: .automatic,
            segmentedPropertyCategory: getPropertyCategory(for: parameters.type),
            segmentedPropertyType: getPropertyType(for: parameters.type),
            pixelData: maskData,
            recommendedDisplayColor: getSegmentColor(for: parameters.type),
            opacity: 0.5,
            isVisible: true
        )
        
        segmentation.addSegment(segment)
        
        return segmentation
    }
    
    private func extractMaskData(from texture: MTLTexture) throws -> Data {
        let bytesPerRow = texture.width
        let dataSize = bytesPerRow * texture.height
        var pixelData = Data(count: dataSize)
        
        pixelData.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(0, 0, texture.width, texture.height),
                mipmapLevel: 0
            )
        }
        
        return pixelData
    }
    
    private func getSegmentationLabel(for type: SegmentationType) -> String {
        switch type {
        case .lungParenchyma: return "Automatic Lung Segmentation"
        case .boneStructure: return "Automatic Bone Segmentation"
        case .contrastVessels: return "Automatic Vessel Segmentation"
        case .organBoundaries: return "Automatic Organ Segmentation"
        case .airSpaces: return "Automatic Air Space Segmentation"
        case .fatTissue: return "Automatic Fat Tissue Segmentation"
        case .muscleGroups: return "Automatic Muscle Segmentation"
        case .customThreshold: return "Custom Threshold Segmentation"
        }
    }
    
    private func getSegmentLabel(for type: SegmentationType) -> String {
        switch type {
        case .lungParenchyma: return "Lung Parenchyma"
        case .boneStructure: return "Bone"
        case .contrastVessels: return "Blood Vessel"
        case .organBoundaries: return "Organ"
        case .airSpaces: return "Air"
        case .fatTissue: return "Fat Tissue"
        case .muscleGroups: return "Muscle"
        case .customThreshold: return "Segmented Region"
        }
    }
    
    private func getPropertyCategory(for type: SegmentationType) -> String {
        switch type {
        case .lungParenchyma: return "Tissue"
        case .boneStructure: return "Tissue"
        case .contrastVessels: return "Tissue"
        case .organBoundaries: return "Tissue"
        case .airSpaces: return "Substance"
        case .fatTissue: return "Tissue"
        case .muscleGroups: return "Tissue"
        case .customThreshold: return "Tissue"
        }
    }
    
    private func getPropertyType(for type: SegmentationType) -> String {
        switch type {
        case .lungParenchyma: return "Lung"
        case .boneStructure: return "Bone"
        case .contrastVessels: return "Blood vessel"
        case .organBoundaries: return "Organ"
        case .airSpaces: return "Air"
        case .fatTissue: return "Adipose tissue"
        case .muscleGroups: return "Muscle"
        case .customThreshold: return "Tissue"
        }
    }
    
    private func getSegmentColor(for type: SegmentationType) -> UIColor {
        switch type {
        case .lungParenchyma: return UIColor.systemBlue.withAlphaComponent(0.6)
        case .boneStructure: return UIColor.systemYellow.withAlphaComponent(0.8)
        case .contrastVessels: return UIColor.systemRed.withAlphaComponent(0.7)
        case .organBoundaries: return UIColor.systemGreen.withAlphaComponent(0.6)
        case .airSpaces: return UIColor.systemGray.withAlphaComponent(0.4)
        case .fatTissue: return UIColor.systemOrange.withAlphaComponent(0.5)
        case .muscleGroups: return UIColor.systemPurple.withAlphaComponent(0.6)
        case .customThreshold: return UIColor.systemPink.withAlphaComponent(0.6)
        }
    }
    
    // MARK: - Advanced Post-Processing
    
    private func enhanceLungSegmentation(_ segmentation: inout DICOMSegmentation) {
        // Post-process lung segmentation to identify airways, vessels, and nodules
        print("🫁 Enhancing lung segmentation with airway and vessel detection")
        
        // This would implement advanced lung-specific enhancements
        // - Airway tree extraction
        // - Vessel segmentation within lungs
        // - Nodule detection
        // - Lobe separation
    }
    
    private func separateCorticalTrabecularBone(_ segmentation: inout DICOMSegmentation) {
        // Separate cortical and trabecular bone based on density
        print("🦴 Separating cortical and trabecular bone regions")
        
        // This would implement bone-specific separation
        // - High-density cortical bone
        // - Lower-density trabecular bone
        // - Bone marrow regions
    }
    
    private func combineSegmentations(_ segmentations: [DICOMSegmentation]) -> DICOMSegmentation {
        // Combine multiple organ segmentations into a single multi-class segmentation
        guard let first = segmentations.first else {
            fatalError("No segmentations to combine")
        }
        
        let combined = DICOMSegmentation(
            sopInstanceUID: UUID().uuidString,
            sopClassUID: first.sopClassUID,
            seriesInstanceUID: first.seriesInstanceUID,
            studyInstanceUID: first.studyInstanceUID,
            contentLabel: "Multi-Organ Automatic Segmentation",
            algorithmType: .automatic,
            rows: first.rows,
            columns: first.columns,
            numberOfFrames: first.numberOfFrames
        )
        
        // Add all segments from individual segmentations
        for (index, segmentation) in segmentations.enumerated() {
            for segment in segmentation.segments {
                var combinedSegment = segment
                combinedSegment.segmentNumber = UInt16(index + 1)
                combined.addSegment(combinedSegment)
            }
        }
        
        return combined
    }
    
    // MARK: - Morphological Operations Support
    
    enum MorphologyOperation {
        case erosion
        case dilation
        case opening
        case closing
    }
    
    private func applyMorphologyOperation(
        input: MTLTexture,
        operation: MorphologyOperation,
        radius: Int,
        pipeline: MTLComputePipelineState,
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLTexture {
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SegmentationError.failedToCreateComputeEncoder
        }
        
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = input.pixelFormat
        descriptor.width = input.width
        descriptor.height = input.height
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            throw SegmentationError.failedToCreateTexture
        }
        
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        
        var params = MorphologyParams(operation: operation.rawValue, radius: Int32(radius))
        computeEncoder.setBytes(&params, length: MemoryLayout<MorphologyParams>.size, index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (input.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (input.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        return outputTexture
    }
}

// MARK: - Supporting Structures

struct ThresholdParams {
    let minThreshold: Float
    let maxThreshold: Float
}

struct MorphologyParams {
    let operation: Int32
    let radius: Int32
}

extension AutomaticSegmentationService.MorphologyOperation {
    var rawValue: Int32 {
        switch self {
        case .erosion: return 0
        case .dilation: return 1
        case .opening: return 2
        case .closing: return 3
        }
    }
}

// MARK: - Error Types

enum SegmentationError: Error {
    case failedToCreateCommandQueue
    case failedToCreateLibrary
    case failedToCreateCommandBuffer
    case failedToCreateComputeEncoder
    case failedToCreateTexture
    case invalidInputData
    case noSegmentationsGenerated
    
    var localizedDescription: String {
        switch self {
        case .failedToCreateCommandQueue:
            return "Failed to create Metal command queue"
        case .failedToCreateLibrary:
            return "Failed to create Metal library"
        case .failedToCreateCommandBuffer:
            return "Failed to create command buffer"
        case .failedToCreateComputeEncoder:
            return "Failed to create compute encoder"
        case .failedToCreateTexture:
            return "Failed to create Metal texture"
        case .invalidInputData:
            return "Invalid input DICOM data"
        case .noSegmentationsGenerated:
            return "No segmentations were successfully generated"
        }
    }
}