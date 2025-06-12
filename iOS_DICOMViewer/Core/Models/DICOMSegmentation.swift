import Foundation
import simd
import UIKit

/// DICOM Segmentation (SEG) data model
/// Represents segmentation objects used for organ/tissue delineation in medical imaging
struct DICOMSegmentation {
    let sopInstanceUID: String
    let sopClassUID: String
    let seriesInstanceUID: String
    let studyInstanceUID: String
    let segmentationUID: String
    
    // Segmentation metadata
    let contentLabel: String
    let contentDescription: String?
    let segmentationAlgorithmType: SegmentationAlgorithmType
    let instanceNumber: Int32
    let contentDate: Date?
    let contentTime: Date?
    
    // Referenced image information
    let referencedSeriesUID: String
    let referencedFrameOfReferenceUID: String
    
    // Segmentation data
    var segments: [SegmentationSegment]
    
    // Geometry information
    let imagePositionPatient: [Double]?
    let imageOrientationPatient: [Double]?
    let pixelSpacing: [Double]?
    let sliceThickness: Double?
    let rows: Int
    let columns: Int
    let numberOfFrames: Int
    
    // Processing metadata
    let creationDate: Date
    var modificationDate: Date
    
    enum SegmentationAlgorithmType: String, CaseIterable {
        case manual = "MANUAL"
        case semiautomatic = "SEMIAUTOMATIC"
        case automatic = "AUTOMATIC"
        
        var displayName: String {
            switch self {
            case .manual: return "Manual"
            case .semiautomatic: return "Semi-automatic"
            case .automatic: return "Automatic"
            }
        }
    }
    
    init(sopInstanceUID: String, sopClassUID: String, seriesInstanceUID: String, studyInstanceUID: String,
         contentLabel: String, algorithmType: SegmentationAlgorithmType, rows: Int, columns: Int, numberOfFrames: Int) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.seriesInstanceUID = seriesInstanceUID
        self.studyInstanceUID = studyInstanceUID
        self.segmentationUID = UUID().uuidString
        self.contentLabel = contentLabel
        self.contentDescription = nil
        self.segmentationAlgorithmType = algorithmType
        self.instanceNumber = 1
        self.contentDate = Date()
        self.contentTime = Date()
        self.referencedSeriesUID = ""
        self.referencedFrameOfReferenceUID = ""
        self.segments = []
        self.imagePositionPatient = nil
        self.imageOrientationPatient = nil
        self.pixelSpacing = nil
        self.sliceThickness = nil
        self.rows = rows
        self.columns = columns
        self.numberOfFrames = numberOfFrames
        self.creationDate = Date()
        self.modificationDate = Date()
    }
    
    mutating func addSegment(_ segment: SegmentationSegment) {
        segments.append(segment)
        modificationDate = Date()
    }
    
    mutating func removeSegment(withNumber segmentNumber: UInt16) {
        segments.removeAll { $0.segmentNumber == segmentNumber }
        modificationDate = Date()
    }
    
    func getSegment(number: UInt16) -> SegmentationSegment? {
        return segments.first { $0.segmentNumber == number }
    }
    
    var totalVoxelCount: Int {
        return segments.reduce(0) { $0 + $1.voxelCount }
    }
    
    var isEmpty: Bool {
        return segments.isEmpty || totalVoxelCount == 0
    }
}

/// Individual segment within a DICOM segmentation
struct SegmentationSegment {
    let segmentNumber: UInt16
    let segmentLabel: String
    let segmentDescription: String?
    let algorithmType: DICOMSegmentation.SegmentationAlgorithmType
    let algorithmName: String?
    
    // Visual properties
    var recommendedDisplayRGBValue: (UInt8, UInt8, UInt8)?
    var segmentedPropertyCategoryCode: SegmentedPropertyCode?
    var segmentedPropertyTypeCode: SegmentedPropertyCode?
    var anatomicRegionCode: AnatomicRegionCode?
    
    // Segmentation data
    var pixelData: Data
    let frameNumbers: [Int32] // Which frames this segment applies to
    
    // Statistics
    var voxelCount: Int
    var volume: Double? // in mm³
    var boundingBox: BoundingBox?
    
    // Processing metadata
    let creationDate: Date
    var modificationDate: Date
    var isVisible: Bool
    var opacity: Float
    
    init(segmentNumber: UInt16, segmentLabel: String, pixelData: Data, frameNumbers: [Int32]) {
        self.segmentNumber = segmentNumber
        self.segmentLabel = segmentLabel
        self.segmentDescription = nil
        self.algorithmType = .manual
        self.algorithmName = nil
        self.recommendedDisplayRGBValue = nil
        self.segmentedPropertyCategoryCode = nil
        self.segmentedPropertyTypeCode = nil
        self.anatomicRegionCode = nil
        self.pixelData = pixelData
        self.frameNumbers = frameNumbers
        self.volume = nil
        self.boundingBox = nil
        self.creationDate = Date()
        self.modificationDate = Date()
        self.isVisible = true
        self.opacity = 0.5
        
        // Calculate voxel count after all properties are initialized
        self.voxelCount = pixelData.reduce(0) { count, byte in
            count + Int(byte.nonzeroBitCount)
        }
    }
    
    private func calculateVoxelCount(from data: Data) -> Int {
        return data.reduce(0) { count, byte in
            count + Int(byte.nonzeroBitCount)
        }
    }
    
    mutating func updatePixelData(_ data: Data) {
        pixelData = data
        voxelCount = calculateVoxelCount(from: data)
        modificationDate = Date()
    }
    
    mutating func calculateVolume(pixelSpacing: [Double], sliceThickness: Double) {
        guard !pixelSpacing.isEmpty else { return }
        
        let voxelVolume = pixelSpacing[0] * pixelSpacing[1] * sliceThickness
        volume = Double(voxelCount) * voxelVolume
        modificationDate = Date()
    }
    
    mutating func calculateBoundingBox(rows: Int, columns: Int) {
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min
        var minZ = Int.max, maxZ = Int.min
        
        let frameSize = rows * columns
        
        for (frameIndex, _) in frameNumbers.enumerated() {
            let frameOffset = frameIndex * frameSize
            
            for y in 0..<rows {
                for x in 0..<columns {
                    let pixelIndex = frameOffset + y * columns + x
                    let byteIndex = pixelIndex / 8
                    let bitIndex = pixelIndex % 8
                    
                    if byteIndex < pixelData.count {
                        let byte = pixelData[byteIndex]
                        if (byte & (1 << bitIndex)) != 0 {
                            minX = min(minX, x)
                            maxX = max(maxX, x)
                            minY = min(minY, y)
                            maxY = max(maxY, y)
                            minZ = min(minZ, frameIndex)
                            maxZ = max(maxZ, frameIndex)
                        }
                    }
                }
            }
        }
        
        if minX <= maxX && minY <= maxY && minZ <= maxZ {
            boundingBox = BoundingBox(
                minX: minX, maxX: maxX,
                minY: minY, maxY: maxY,
                minZ: minZ, maxZ: maxZ
            )
        }
        
        modificationDate = Date()
    }
    
    var displayColor: UIColor {
        if let rgb = recommendedDisplayRGBValue {
            return UIColor(red: CGFloat(rgb.0) / 255.0,
                          green: CGFloat(rgb.1) / 255.0,
                          blue: CGFloat(rgb.2) / 255.0,
                          alpha: CGFloat(opacity))
        } else {
            // Generate color based on segment number
            let hue = CGFloat(segmentNumber % 12) / 12.0
            return UIColor(hue: hue, saturation: 0.8, brightness: 0.8, alpha: CGFloat(opacity))
        }
    }
}

/// Bounding box for efficient rendering
struct BoundingBox {
    let minX, maxX: Int
    let minY, maxY: Int
    let minZ, maxZ: Int
    
    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
    var depth: Int { maxZ - minZ + 1 }
    
    func intersects(with other: BoundingBox) -> Bool {
        return !(maxX < other.minX || minX > other.maxX ||
                 maxY < other.minY || minY > other.maxY ||
                 maxZ < other.minZ || minZ > other.maxZ)
    }
    
    func contains(x: Int, y: Int, z: Int) -> Bool {
        return x >= minX && x <= maxX &&
               y >= minY && y <= maxY &&
               z >= minZ && z <= maxZ
    }
}

/// Coded concept for segmented property category
struct SegmentedPropertyCode {
    let codeValue: String
    let codingSchemeDesignator: String
    let codeMeaning: String
    
    // Common property categories
    static let tissue = SegmentedPropertyCode(
        codeValue: "85756007",
        codingSchemeDesignator: "SCT",
        codeMeaning: "Tissue"
    )
    
    static let organ = SegmentedPropertyCode(
        codeValue: "410653004",
        codingSchemeDesignator: "SCT",
        codeMeaning: "Organ"
    )
    
    static let abnormalTissue = SegmentedPropertyCode(
        codeValue: "49755003",
        codingSchemeDesignator: "SCT",
        codeMeaning: "Abnormal tissue"
    )
}

/// Anatomic region codes for medical context
struct AnatomicRegionCode {
    let codeValue: String
    let codingSchemeDesignator: String
    let codeMeaning: String
    
    // Common anatomic regions
    static let brain = AnatomicRegionCode(
        codeValue: "12738006",
        codingSchemeDesignator: "SCT",
        codeMeaning: "Brain"
    )
    
    static let liver = AnatomicRegionCode(
        codeValue: "10200004",
        codingSchemeDesignator: "SCT",
        codeMeaning: "Liver"
    )
    
    static let lung = AnatomicRegionCode(
        codeValue: "39607008",
        codingSchemeDesignator: "SCT",
        codeMeaning: "Lung"
    )
    
    static let heart = AnatomicRegionCode(
        codeValue: "80891009",
        codingSchemeDesignator: "SCT",
        codeMeaning: "Heart"
    )
}

// MARK: - Extensions
extension DICOMSegmentation {
    /// Create a simplified segmentation for testing
    static func createTestSegmentation() -> DICOMSegmentation {
        var segmentation = DICOMSegmentation(
            sopInstanceUID: "test.seg.instance",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.66.4", // Segmentation Storage
            seriesInstanceUID: "test.seg.series",
            studyInstanceUID: "test.study",
            contentLabel: "Test Segmentation",
            algorithmType: .manual,
            rows: 512,
            columns: 512,
            numberOfFrames: 1
        )
        
        // Add a test segment
        let testData = Data(repeating: 0xFF, count: 512 * 512 / 8) // Binary data
        let segment = SegmentationSegment(
            segmentNumber: 1,
            segmentLabel: "Test Organ",
            pixelData: testData,
            frameNumbers: [1]
        )
        
        segmentation.addSegment(segment)
        return segmentation
    }
}

extension SegmentationSegment {
    /// Get pixel value at specific coordinates
    func getPixelValue(x: Int, y: Int, frame: Int, rows: Int, columns: Int) -> Bool {
        guard frame < frameNumbers.count else { return false }
        
        let frameSize = rows * columns
        let frameOffset = frame * frameSize
        let pixelIndex = frameOffset + y * columns + x
        let byteIndex = pixelIndex / 8
        let bitIndex = pixelIndex % 8
        
        guard byteIndex < pixelData.count else { return false }
        
        let byte = pixelData[byteIndex]
        return (byte & (1 << bitIndex)) != 0
    }
    
    /// Set pixel value at specific coordinates
    mutating func setPixelValue(x: Int, y: Int, frame: Int, rows: Int, columns: Int, value: Bool) {
        guard frame < frameNumbers.count else { return }
        
        let frameSize = rows * columns
        let frameOffset = frame * frameSize
        let pixelIndex = frameOffset + y * columns + x
        let byteIndex = pixelIndex / 8
        let bitIndex = pixelIndex % 8
        
        guard byteIndex < pixelData.count else { return }
        
        if value {
            pixelData[byteIndex] |= (1 << bitIndex)
        } else {
            pixelData[byteIndex] &= ~(1 << bitIndex)
        }
        
        modificationDate = Date()
    }
}

// MARK: - Memory Management Extensions for iOS
extension DICOMSegmentation {
    /// Memory-efficient loading for iOS
    mutating func loadSegmentDataLazy() {
        // Implementation for lazy loading of segment data on iOS
        // This helps manage memory pressure on mobile devices
        for i in 0..<segments.count {
            if segments[i].pixelData.count > 1024 * 1024 { // > 1MB
                // Consider compression or lazy loading strategies
                print("⚠️ Large segment data detected: \(segments[i].pixelData.count) bytes")
            }
        }
    }
    
    /// iOS memory pressure handling
    mutating func handleMemoryPressure() {
        // Reduce memory footprint by compressing or releasing non-visible segments
        for i in 0..<segments.count {
            if !segments[i].isVisible {
                // Could implement compression here for iOS optimization
                print("💾 Memory optimization for invisible segment: \(segments[i].segmentLabel)")
            }
        }
    }
}

// MARK: - iOS Performance Optimizations
extension SegmentationSegment {
    /// iOS-optimized pixel data access
    func getPixelDataForFrame(_ frameIndex: Int, rows: Int, columns: Int) -> Data? {
        guard frameIndex < frameNumbers.count else { return nil }
        
        let frameSize = rows * columns / 8 // Binary data is 1 bit per pixel
        let frameOffset = frameIndex * frameSize
        let endOffset = min(frameOffset + frameSize, pixelData.count)
        
        guard frameOffset < pixelData.count else { return nil }
        
        return pixelData.subdata(in: frameOffset..<endOffset)
    }
    
    /// iOS-optimized bounding box calculation with early termination
    mutating func calculateBoundingBoxOptimized(rows: Int, columns: Int) {
        // Early termination for better iOS performance
        var foundAnyPixel = false
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min
        var minZ = Int.max, maxZ = Int.min
        
        let frameSize = rows * columns
        let maxIterations = min(frameNumbers.count * frameSize, 100000) // Limit for iOS
        var iterationCount = 0
        
        for (frameIndex, _) in frameNumbers.enumerated() {
            let frameOffset = frameIndex * frameSize
            
            for y in 0..<rows {
                for x in 0..<columns {
                    iterationCount += 1
                    if iterationCount > maxIterations {
                        print("⚠️ Bounding box calculation truncated for iOS performance")
                        break
                    }
                    
                    let pixelIndex = frameOffset + y * columns + x
                    let byteIndex = pixelIndex / 8
                    let bitIndex = pixelIndex % 8
                    
                    if byteIndex < pixelData.count {
                        let byte = pixelData[byteIndex]
                        if (byte & (1 << bitIndex)) != 0 {
                            foundAnyPixel = true
                            minX = min(minX, x)
                            maxX = max(maxX, x)
                            minY = min(minY, y)
                            maxY = max(maxY, y)
                            minZ = min(minZ, frameIndex)
                            maxZ = max(maxZ, frameIndex)
                        }
                    }
                }
                if iterationCount > maxIterations { break }
            }
            if iterationCount > maxIterations { break }
        }
        
        if foundAnyPixel && minX <= maxX && minY <= maxY && minZ <= maxZ {
            boundingBox = BoundingBox(
                minX: minX, maxX: maxX,
                minY: minY, maxY: maxY,
                minZ: minZ, maxZ: maxZ
            )
        }
        
        modificationDate = Date()
    }
}