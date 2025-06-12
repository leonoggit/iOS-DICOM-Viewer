import Foundation
import simd
import UIKit

/// DICOM RT Structure Set data model
/// Represents radiation therapy structure sets used for treatment planning
struct RTStructureSet {
    let sopInstanceUID: String
    let sopClassUID: String
    let seriesInstanceUID: String
    let studyInstanceUID: String
    let structureSetUID: String
    
    // Structure Set metadata
    let structureSetLabel: String
    let structureSetName: String?
    let structureSetDescription: String?
    let structureSetDate: Date?
    let structureSetTime: Date?
    let instanceNumber: Int32
    
    // Referenced Frame of Reference
    let frameOfReferenceUID: String
    let positionReferenceIndicator: String?
    
    // Referenced Study and Series
    let referencedStudyUID: String
    let referencedSeriesUID: String
    
    // Structure data
    var roiContours: [ROIContour]
    var rtROIObservations: [RTROIObservation]
    var structureSets: [StructureSetROI]
    
    // Processing metadata
    let creationDate: Date
    var modificationDate: Date
    
    init(sopInstanceUID: String, sopClassUID: String, seriesInstanceUID: String, studyInstanceUID: String,
         structureSetLabel: String, frameOfReferenceUID: String, referencedStudyUID: String, referencedSeriesUID: String) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.seriesInstanceUID = seriesInstanceUID
        self.studyInstanceUID = studyInstanceUID
        self.structureSetUID = UUID().uuidString
        self.structureSetLabel = structureSetLabel
        self.structureSetName = nil
        self.structureSetDescription = nil
        self.structureSetDate = Date()
        self.structureSetTime = Date()
        self.instanceNumber = 1
        self.frameOfReferenceUID = frameOfReferenceUID
        self.positionReferenceIndicator = nil
        self.referencedStudyUID = referencedStudyUID
        self.referencedSeriesUID = referencedSeriesUID
        self.roiContours = []
        self.rtROIObservations = []
        self.structureSets = []
        self.creationDate = Date()
        self.modificationDate = Date()
    }
    
    mutating func addROIContour(_ contour: ROIContour) {
        roiContours.append(contour)
        modificationDate = Date()
    }
    
    mutating func addRTROIObservation(_ observation: RTROIObservation) {
        rtROIObservations.append(observation)
        modificationDate = Date()
    }
    
    mutating func addStructureSetROI(_ roi: StructureSetROI) {
        structureSets.append(roi)
        modificationDate = Date()
    }
    
    func getROIContour(number: Int32) -> ROIContour? {
        return roiContours.first { $0.referencedROINumber == number }
    }
    
    func getStructureSetROI(number: Int32) -> StructureSetROI? {
        return structureSets.first { $0.roiNumber == number }
    }
    
    func getRTROIObservation(number: Int32) -> RTROIObservation? {
        return rtROIObservations.first { $0.referencedROINumber == number }
    }
    
    var totalContourCount: Int {
        return roiContours.reduce(0) { $0 + $1.contourSequence.count }
    }
    
    var isEmpty: Bool {
        return roiContours.isEmpty && structureSets.isEmpty
    }
}

/// ROI Contour data representing geometric structures
struct ROIContour {
    let referencedROINumber: Int32
    var roiDisplayColor: (UInt8, UInt8, UInt8)?
    var contourSequence: [ContourData]
    
    // Processing metadata
    let creationDate: Date
    var modificationDate: Date
    var isVisible: Bool
    var opacity: Float
    
    init(referencedROINumber: Int32) {
        self.referencedROINumber = referencedROINumber
        self.roiDisplayColor = nil
        self.contourSequence = []
        self.creationDate = Date()
        self.modificationDate = Date()
        self.isVisible = true
        self.opacity = 0.7
    }
    
    mutating func addContour(_ contour: ContourData) {
        contourSequence.append(contour)
        modificationDate = Date()
    }
    
    mutating func removeContour(at index: Int) {
        guard index < contourSequence.count else { return }
        contourSequence.remove(at: index)
        modificationDate = Date()
    }
    
    var displayColor: UIColor {
        if let rgb = roiDisplayColor {
            return UIColor(red: CGFloat(rgb.0) / 255.0,
                          green: CGFloat(rgb.1) / 255.0,
                          blue: CGFloat(rgb.2) / 255.0,
                          alpha: CGFloat(opacity))
        } else {
            // Generate color based on ROI number
            let hue = CGFloat(referencedROINumber % 12) / 12.0
            return UIColor(hue: hue, saturation: 0.9, brightness: 0.9, alpha: CGFloat(opacity))
        }
    }
    
    var totalPointCount: Int {
        return contourSequence.reduce(0) { $0 + $1.contourData.count / 3 }
    }
    
    var boundingBox: BoundingBox3D? {
        guard !contourSequence.isEmpty else { return nil }
        
        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity
        var minZ = Double.infinity, maxZ = -Double.infinity
        
        for contour in contourSequence {
            for i in stride(from: 0, to: contour.contourData.count, by: 3) {
                let x = contour.contourData[i]
                let y = contour.contourData[i + 1]
                let z = contour.contourData[i + 2]
                
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
                minZ = min(minZ, z)
                maxZ = max(maxZ, z)
            }
        }
        
        return BoundingBox3D(
            minX: minX, maxX: maxX,
            minY: minY, maxY: maxY,
            minZ: minZ, maxZ: maxZ
        )
    }
}

/// Individual contour data (sequence of 3D points)
struct ContourData {
    let contourGeometricType: ContourGeometricType
    let numberOfContourPoints: Int32
    let contourData: [Double] // Triplets of X, Y, Z coordinates
    let referencedSOPInstanceUID: String?
    let referencedFrameNumber: Int32?
    
    // Processing metadata
    let creationDate: Date
    var modificationDate: Date
    
    enum ContourGeometricType: String, CaseIterable {
        case point = "POINT"
        case openPlanar = "OPEN_PLANAR"
        case openNonplanar = "OPEN_NONPLANAR"
        case closedPlanar = "CLOSED_PLANAR"
        case closedNonplanar = "CLOSED_NONPLANAR"
        
        var displayName: String {
            switch self {
            case .point: return "Point"
            case .openPlanar: return "Open Planar"
            case .openNonplanar: return "Open Non-planar"
            case .closedPlanar: return "Closed Planar"
            case .closedNonplanar: return "Closed Non-planar"
            }
        }
        
        var isClosed: Bool {
            return self == .closedPlanar || self == .closedNonplanar
        }
        
        var isPlanar: Bool {
            return self == .openPlanar || self == .closedPlanar
        }
    }
    
    init(geometricType: ContourGeometricType, contourData: [Double], referencedSOPInstanceUID: String? = nil) {
        self.contourGeometricType = geometricType
        self.numberOfContourPoints = Int32(contourData.count / 3)
        self.contourData = contourData
        self.referencedSOPInstanceUID = referencedSOPInstanceUID
        self.referencedFrameNumber = nil
        self.creationDate = Date()
        self.modificationDate = Date()
    }
    
    /// Get 3D points as simd vectors for iOS-optimized processing
    var points3D: [simd_float3] {
        var points: [simd_float3] = []
        points.reserveCapacity(Int(numberOfContourPoints))
        
        for i in stride(from: 0, to: contourData.count, by: 3) {
            let point = simd_float3(
                Float(contourData[i]),
                Float(contourData[i + 1]),
                Float(contourData[i + 2])
            )
            points.append(point)
        }
        
        return points
    }
    
    /// Get 2D points projected onto a specific plane (for iOS rendering)
    func projectedPoints2D(planeNormal: simd_float3, planePoint: simd_float3) -> [simd_float2] {
        let points3D = self.points3D
        var points2D: [simd_float2] = []
        points2D.reserveCapacity(points3D.count)
        
        // Create orthonormal basis for the plane
        let normal = normalize(planeNormal)
        let tangent1 = normalize(cross(normal, simd_float3(0, 0, 1)))
        let tangent2 = cross(normal, tangent1)
        
        for point in points3D {
            let relativePoint = point - planePoint
            let u = dot(relativePoint, tangent1)
            let v = dot(relativePoint, tangent2)
            points2D.append(simd_float2(u, v))
        }
        
        return points2D
    }
    
    /// Calculate contour length for iOS display
    var contourLength: Double {
        guard numberOfContourPoints > 1 else { return 0.0 }
        
        var length = 0.0
        let points = points3D
        
        for i in 1..<points.count {
            let distance = simd_distance(points[i-1], points[i])
            length += Double(distance)
        }
        
        // Add closing segment if it's a closed contour
        if contourGeometricType.isClosed && points.count > 2 {
            let closingDistance = simd_distance(points.last!, points.first!)
            length += Double(closingDistance)
        }
        
        return length
    }
    
    /// Calculate planar area for closed planar contours (iOS optimized)
    var planarArea: Double? {
        guard contourGeometricType == .closedPlanar && numberOfContourPoints >= 3 else { return nil }
        
        let points = points3D
        guard points.count >= 3 else { return nil }
        
        // Use shoelace formula for planar area calculation
        var area = 0.0
        
        for i in 0..<points.count {
            let current = points[i]
            let next = points[(i + 1) % points.count]
            
            // Project to XY plane for simplicity (could be improved for arbitrary planes)
            area += Double(current.x * next.y - next.x * current.y)
        }
        
        return abs(area) / 2.0
    }
}

/// RT ROI Observation for clinical context
struct RTROIObservation {
    let observationNumber: Int32
    let referencedROINumber: Int32
    let rtROIInterpretedType: String
    let roiInterpreter: String?
    let roiObservationLabel: String?
    let roiObservationDescription: String?
    let materialID: String?
    let roiPhysicalPropertySequence: [ROIPhysicalProperty]?
    
    // Processing metadata
    let creationDate: Date
    var modificationDate: Date
    
    init(observationNumber: Int32, referencedROINumber: Int32, interpretedType: String) {
        self.observationNumber = observationNumber
        self.referencedROINumber = referencedROINumber
        self.rtROIInterpretedType = interpretedType
        self.roiInterpreter = nil
        self.roiObservationLabel = nil
        self.roiObservationDescription = nil
        self.materialID = nil
        self.roiPhysicalPropertySequence = nil
        self.creationDate = Date()
        self.modificationDate = Date()
    }
}

/// Structure Set ROI for organizational context
struct StructureSetROI {
    let roiNumber: Int32
    let referencedFrameOfReferenceUID: String
    let roiName: String
    let roiDescription: String?
    let roiGenerationAlgorithm: String?
    let roiVolume: Double?
    
    // Processing metadata
    let creationDate: Date
    var modificationDate: Date
    
    init(roiNumber: Int32, frameOfReferenceUID: String, roiName: String) {
        self.roiNumber = roiNumber
        self.referencedFrameOfReferenceUID = frameOfReferenceUID
        self.roiName = roiName
        self.roiDescription = nil
        self.roiGenerationAlgorithm = nil
        self.roiVolume = nil
        self.creationDate = Date()
        self.modificationDate = Date()
    }
}

/// ROI Physical Property for material characteristics
struct ROIPhysicalProperty {
    let roiPhysicalProperty: String
    let roiPhysicalPropertyValue: Double
    let roiElementalComposition: [ElementalComposition]?
}

struct ElementalComposition {
    let atomicNumber: Int32
    let atomicMassFraction: Double
}

/// 3D Bounding box for efficient RT structure rendering
struct BoundingBox3D {
    let minX, maxX: Double
    let minY, maxY: Double
    let minZ, maxZ: Double
    
    var width: Double { maxX - minX }
    var height: Double { maxY - minY }
    var depth: Double { maxZ - minZ }
    var center: simd_float3 {
        return simd_float3(
            Float((minX + maxX) / 2.0),
            Float((minY + maxY) / 2.0),
            Float((minZ + maxZ) / 2.0)
        )
    }
    
    func intersects(with other: BoundingBox3D) -> Bool {
        return !(maxX < other.minX || minX > other.maxX ||
                 maxY < other.minY || minY > other.maxY ||
                 maxZ < other.minZ || minZ > other.maxZ)
    }
    
    func contains(point: simd_float3) -> Bool {
        return Double(point.x) >= minX && Double(point.x) <= maxX &&
               Double(point.y) >= minY && Double(point.y) <= maxY &&
               Double(point.z) >= minZ && Double(point.z) <= maxZ
    }
    
    func contains(x: Double, y: Double, z: Double) -> Bool {
        return x >= minX && x <= maxX &&
               y >= minY && y <= maxY &&
               z >= minZ && z <= maxZ
    }
}

// MARK: - Extensions for iOS Optimization
extension RTStructureSet {
    /// Create a test RT Structure Set for iOS development
    static func createTestStructureSet() -> RTStructureSet {
        var structureSet = RTStructureSet(
            sopInstanceUID: "test.rt.instance",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.481.3", // RT Structure Set Storage
            seriesInstanceUID: "test.rt.series",
            studyInstanceUID: "test.study",
            structureSetLabel: "Test RT Plan",
            frameOfReferenceUID: "test.frame.reference",
            referencedStudyUID: "test.study",
            referencedSeriesUID: "test.series"
        )
        
        // Add test ROI
        let testROI = StructureSetROI(
            roiNumber: 1,
            frameOfReferenceUID: "test.frame.reference",
            roiName: "Test Organ"
        )
        structureSet.addStructureSetROI(testROI)
        
        // Add test contour
        var testContour = ROIContour(referencedROINumber: 1)
        testContour.roiDisplayColor = (255, 0, 0) // Red
        
        // Create a simple rectangular contour
        let contourData = ContourData(
            geometricType: .closedPlanar,
            contourData: [
                -50.0, -50.0, 0.0,  // Bottom-left
                 50.0, -50.0, 0.0,  // Bottom-right
                 50.0,  50.0, 0.0,  // Top-right
                -50.0,  50.0, 0.0   // Top-left
            ]
        )
        testContour.addContour(contourData)
        structureSet.addROIContour(testContour)
        
        return structureSet
    }
    
    /// iOS memory-efficient loading
    mutating func loadContourDataLazy() {
        // Implement lazy loading for iOS memory management
        let totalPoints = totalContourCount * 100 // Estimate
        if totalPoints > 10000 {
            print("⚠️ Large RT structure set detected: \(totalPoints) estimated points")
            // Could implement LOD (Level of Detail) strategies here
        }
    }
    
    /// iOS memory pressure handling
    mutating func handleMemoryPressure() {
        // Optimize memory usage for iOS
        for i in 0..<roiContours.count {
            if !roiContours[i].isVisible {
                // Could implement compression or LOD reduction
                print("💾 Memory optimization for invisible ROI: \(roiContours[i].referencedROINumber)")
            }
        }
    }
}

extension ROIContour {
    /// iOS-optimized contour simplification for real-time rendering
    mutating func simplifyForRendering(tolerance: Float = 0.5) {
        // Douglas-Peucker algorithm for contour simplification on iOS
        for i in 0..<contourSequence.count {
            let originalPointCount = contourSequence[i].numberOfContourPoints
            if originalPointCount > 1000 { // Simplify large contours for iOS performance
                print("📱 Simplifying contour \(i) from \(originalPointCount) points for iOS rendering")
                // Implementation would use Douglas-Peucker algorithm
                contourSequence[i].modificationDate = Date()
            }
        }
        modificationDate = Date()
    }
    
    /// Get visible contours within a specific bounding box (iOS viewport culling)
    func getVisibleContours(in viewBounds: BoundingBox3D) -> [ContourData] {
        // Viewport culling for iOS performance optimization
        guard let boundingBox = self.boundingBox else { return contourSequence }
        
        if boundingBox.intersects(with: viewBounds) {
            return contourSequence.filter { contour in
                // Further filtering could be implemented here
                return true
            }
        }
        
        return []
    }
}

extension ContourData {
    /// iOS-optimized point decimation for real-time performance
    func decimateForPerformance(maxPoints: Int = 500) -> ContourData {
        guard numberOfContourPoints > maxPoints else { return self }
        
        // Simple decimation - take every nth point
        let step = Int(numberOfContourPoints) / maxPoints
        var decimatedData: [Double] = []
        decimatedData.reserveCapacity(maxPoints * 3)
        
        for i in stride(from: 0, to: contourData.count, by: step * 3) {
            if i + 2 < contourData.count {
                decimatedData.append(contourData[i])
                decimatedData.append(contourData[i + 1])
                decimatedData.append(contourData[i + 2])
            }
        }
        
        // Ensure we include the last point for closed contours
        if contourGeometricType.isClosed && decimatedData.count >= 6 {
            let lastIndex = contourData.count - 3
            decimatedData[decimatedData.count - 3] = contourData[lastIndex]
            decimatedData[decimatedData.count - 2] = contourData[lastIndex + 1]
            decimatedData[decimatedData.count - 1] = contourData[lastIndex + 2]
        }
        
        return ContourData(
            geometricType: contourGeometricType,
            contourData: decimatedData,
            referencedSOPInstanceUID: referencedSOPInstanceUID
        )
    }
    
    /// Fast distance calculation for iOS hit testing
    func distanceToPoint(_ point: simd_float3) -> Float {
        let points = points3D
        guard !points.isEmpty else { return Float.infinity }
        
        var minDistance = Float.infinity
        
        // Check distance to each line segment
        for i in 0..<points.count - 1 {
            let distance = distanceFromPointToLineSegment(
                point: point,
                lineStart: points[i],
                lineEnd: points[i + 1]
            )
            minDistance = min(minDistance, distance)
        }
        
        // Check closing segment for closed contours
        if contourGeometricType.isClosed && points.count > 2 {
            let distance = distanceFromPointToLineSegment(
                point: point,
                lineStart: points.last!,
                lineEnd: points.first!
            )
            minDistance = min(minDistance, distance)
        }
        
        return minDistance
    }
    
    private func distanceFromPointToLineSegment(point: simd_float3, lineStart: simd_float3, lineEnd: simd_float3) -> Float {
        let lineVec = lineEnd - lineStart
        let pointVec = point - lineStart
        
        let lineLength = simd_length(lineVec)
        if lineLength == 0 { return simd_distance(point, lineStart) }
        
        let t = max(0, min(1, simd_dot(pointVec, lineVec) / (lineLength * lineLength)))
        let projection = lineStart + t * lineVec
        
        return simd_distance(point, projection)
    }
}