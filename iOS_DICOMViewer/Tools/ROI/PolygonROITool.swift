import Foundation
import simd
import UIKit

/// Polygon ROI tool for freeform area measurements
/// Supports complex irregular shapes commonly used in medical imaging
class PolygonROITool: ROITool {
    let id = UUID()
    let name = "Polygon ROI"
    var isActive = false
    var isVisible = true
    let creationDate = Date()
    var modificationDate = Date()
    
    var color = UIColor.magenta
    var lineWidth: Float = 2.0
    var opacity: Float = 0.3
    
    var imageCoordinates: [simd_float2] = []
    var worldCoordinates: [simd_float3] = []
    var pixelSpacing = simd_float2(1.0, 1.0)
    var sliceThickness: Float = 1.0
    
    private var _statistics: ROIStatistics?
    private var isClosed = false
    
    var measurement: Measurement<Unit>? {
        return calculateMeasurement()
    }
    
    var statistics: ROIStatistics? {
        return _statistics
    }
    
    func addPoint(_ point: simd_float2, worldPoint: simd_float3) {
        if !isClosed {
            imageCoordinates.append(point)
            worldCoordinates.append(worldPoint)
            modificationDate = Date()
        }
    }
    
    func removeLastPoint() {
        if !imageCoordinates.isEmpty && !isClosed {
            imageCoordinates.removeLast()
            worldCoordinates.removeLast()
            modificationDate = Date()
            _statistics = nil
        }
    }
    
    func closePolygon() {
        if imageCoordinates.count >= 3 {
            isClosed = true
            modificationDate = Date()
        }
    }
    
    func isComplete() -> Bool {
        return isClosed && imageCoordinates.count >= 3
    }
    
    func contains(point: simd_float2) -> Bool {
        guard isComplete() else { return false }
        return isPointInPolygon(point: point, polygon: imageCoordinates)
    }
    
    func distanceToPoint(_ point: simd_float2) -> Float {
        guard !imageCoordinates.isEmpty else { return Float.infinity }
        
        var minDistance = Float.infinity
        
        // Check distance to each edge
        for i in 0..<imageCoordinates.count {
            let start = imageCoordinates[i]
            let end = imageCoordinates[(i + 1) % imageCoordinates.count]
            
            let distance = distanceFromPointToLineSegment(point: point, start: start, end: end)
            minDistance = min(minDistance, distance)
        }
        
        return minDistance
    }
    
    func calculateMeasurement() -> Measurement<Unit>? {
        guard isComplete() else { return nil }
        
        // Calculate area using shoelace formula
        var area: Float = 0.0
        
        for i in 0..<imageCoordinates.count {
            let current = imageCoordinates[i]
            let next = imageCoordinates[(i + 1) % imageCoordinates.count]
            
            area += (current.x * pixelSpacing.x) * (next.y * pixelSpacing.y) - 
                    (next.x * pixelSpacing.x) * (current.y * pixelSpacing.y)
        }
        
        area = abs(area) / 2.0
        
        return Measurement(value: Double(area), unit: UnitArea.squareMillimeters)
    }
    
    func calculateStatistics(pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics? {
        guard isComplete() else { return nil }
        
        let imageWidth = metadata.columns
        let imageHeight = metadata.rows
        let bytesPerPixel = metadata.bitsStored / 8
        
        var pixelValues: [Double] = []
        var pixelCount = 0
        
        // Find bounding box
        let minX = max(0, Int(imageCoordinates.map { $0.x }.min() ?? 0))
        let maxX = min(imageWidth, Int(imageCoordinates.map { $0.x }.max() ?? Float(imageWidth)))
        let minY = max(0, Int(imageCoordinates.map { $0.y }.min() ?? 0))
        let maxY = min(imageHeight, Int(imageCoordinates.map { $0.y }.max() ?? Float(imageHeight)))
        
        // Extract pixels within the polygon
        for y in minY..<maxY {
            for x in minX..<maxX {
                let point = simd_float2(Float(x), Float(y))
                if contains(point: point) {
                    let pixelIndex = y * imageWidth + x
                    let byteIndex = pixelIndex * bytesPerPixel
                    
                    if byteIndex + bytesPerPixel <= pixelData.count {
                        let pixelValue: Double
                        
                        if bytesPerPixel == 2 {
                            let value = pixelData.withUnsafeBytes { bytes in
                                bytes.load(fromByteOffset: byteIndex, as: UInt16.self)
                            }
                            pixelValue = Double(value)
                        } else {
                            let value = pixelData[byteIndex]
                            pixelValue = Double(value)
                        }
                        
                        pixelValues.append(pixelValue)
                        pixelCount += 1
                    }
                }
            }
        }
        
        guard !pixelValues.isEmpty else { return nil }
        
        // Calculate statistics
        let mean = pixelValues.reduce(0, +) / Double(pixelValues.count)
        let variance = pixelValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(pixelValues.count)
        let standardDeviation = sqrt(variance)
        let minimum = pixelValues.min() ?? 0
        let maximum = pixelValues.max() ?? 0
        let median = pixelValues.sorted()[pixelValues.count / 2]
        
        // Calculate real-world measurements
        let area = Double(calculatePolygonArea())
        let perimeter = Double(calculatePolygonPerimeter())
        
        // Create histogram
        let binCount = 256
        let range = maximum - minimum
        let binSize = max(1.0, range / Double(binCount))
        var histogram = Array(repeating: 0, count: binCount)
        
        for value in pixelValues {
            let binIndex = min(binCount - 1, max(0, Int((value - minimum) / binSize)))
            histogram[binIndex] += 1
        }
        
        let stats = ROIStatistics(
            area: area,
            perimeter: perimeter,
            pixelCount: pixelCount,
            mean: mean,
            standardDeviation: standardDeviation,
            minimum: minimum,
            maximum: maximum,
            median: median,
            histogram: histogram
        )
        
        _statistics = stats
        return stats
    }
    
    private func calculatePolygonArea() -> Float {
        guard isComplete() else { return 0 }
        
        var area: Float = 0.0
        
        for i in 0..<imageCoordinates.count {
            let current = imageCoordinates[i]
            let next = imageCoordinates[(i + 1) % imageCoordinates.count]
            
            area += (current.x * pixelSpacing.x) * (next.y * pixelSpacing.y) - 
                    (next.x * pixelSpacing.x) * (current.y * pixelSpacing.y)
        }
        
        return abs(area) / 2.0
    }
    
    private func calculatePolygonPerimeter() -> Float {
        guard imageCoordinates.count >= 2 else { return 0 }
        
        var perimeter: Float = 0.0
        
        for i in 0..<imageCoordinates.count {
            let current = imageCoordinates[i]
            let next = imageCoordinates[(i + 1) % imageCoordinates.count]
            
            let dx = (next.x - current.x) * pixelSpacing.x
            let dy = (next.y - current.y) * pixelSpacing.y
            let distance = sqrt(dx * dx + dy * dy)
            
            perimeter += distance
        }
        
        return perimeter
    }
    
    private func isPointInPolygon(point: simd_float2, polygon: [simd_float2]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        var inside = false
        var j = polygon.count - 1
        
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            
            if ((pi.y > point.y) != (pj.y > point.y)) &&
               (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) {
                inside = !inside
            }
            j = i
        }
        
        return inside
    }
    
    private func distanceFromPointToLineSegment(point: simd_float2, start: simd_float2, end: simd_float2) -> Float {
        let segmentLength = distance(start, end)
        if segmentLength == 0 { return distance(point, start) }
        
        let t = max(0, min(1, dot(point - start, end - start) / (segmentLength * segmentLength)))
        let projection = start + t * (end - start)
        
        return distance(point, projection)
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "type": "polygon",
            "imageCoordinates": imageCoordinates.map { [$0.x, $0.y] },
            "worldCoordinates": worldCoordinates.map { [$0.x, $0.y, $0.z] },
            "pixelSpacing": [pixelSpacing.x, pixelSpacing.y],
            "sliceThickness": sliceThickness,
            "color": color.hexString,
            "lineWidth": lineWidth,
            "opacity": opacity,
            "isClosed": isClosed,
            "creationDate": creationDate.iso8601String,
            "modificationDate": modificationDate.iso8601String
        ]
    }
    
    func fromDictionary(_ dict: [String: Any]) {
        if let coords = dict["imageCoordinates"] as? [[Float]] {
            imageCoordinates = coords.map { simd_float2($0[0], $0[1]) }
        }
        if let coords = dict["worldCoordinates"] as? [[Float]] {
            worldCoordinates = coords.map { simd_float3($0[0], $0[1], $0[2]) }
        }
        if let spacing = dict["pixelSpacing"] as? [Float] {
            pixelSpacing = simd_float2(spacing[0], spacing[1])
        }
        if let thickness = dict["sliceThickness"] as? Float {
            sliceThickness = thickness
        }
        if let colorHex = dict["color"] as? String {
            color = UIColor(hex: colorHex) ?? UIColor.magenta
        }
        if let width = dict["lineWidth"] as? Float {
            lineWidth = width
        }
        if let opac = dict["opacity"] as? Float {
            opacity = opac
        }
        if let closed = dict["isClosed"] as? Bool {
            isClosed = closed
        }
    }
}

/// Angle measurement tool for angular measurements
class AngleROITool: ROITool {
    let id = UUID()
    let name = "Angle Measurement"
    var isActive = false
    var isVisible = true
    let creationDate = Date()
    var modificationDate = Date()
    
    var color = UIColor.orange
    var lineWidth: Float = 2.0
    var opacity: Float = 1.0
    
    var imageCoordinates: [simd_float2] = []
    var worldCoordinates: [simd_float3] = []
    var pixelSpacing = simd_float2(1.0, 1.0)
    var sliceThickness: Float = 1.0
    
    var measurement: Measurement<Unit>? {
        return calculateMeasurement()
    }
    
    var statistics: ROIStatistics? {
        return nil // Angle tools don't have area statistics
    }
    
    func addPoint(_ point: simd_float2, worldPoint: simd_float3) {
        if imageCoordinates.count < 3 {
            imageCoordinates.append(point)
            worldCoordinates.append(worldPoint)
            modificationDate = Date()
        }
    }
    
    func removeLastPoint() {
        if !imageCoordinates.isEmpty {
            imageCoordinates.removeLast()
            worldCoordinates.removeLast()
            modificationDate = Date()
        }
    }
    
    func isComplete() -> Bool {
        return imageCoordinates.count == 3
    }
    
    func contains(point: simd_float2) -> Bool {
        return distanceToPoint(point) < 10.0 // 10 pixel tolerance
    }
    
    func distanceToPoint(_ point: simd_float2) -> Float {
        guard imageCoordinates.count >= 2 else { return Float.infinity }
        
        var minDistance = Float.infinity
        
        // Check distance to each line segment
        for i in 0..<imageCoordinates.count - 1 {
            let start = imageCoordinates[i]
            let end = imageCoordinates[i + 1]
            
            let lineLength = distance(start, end)
            if lineLength == 0 { 
                minDistance = min(minDistance, distance(point, start))
                continue 
            }
            
            let t = max(0, min(1, dot(point - start, end - start) / (lineLength * lineLength)))
            let projection = start + t * (end - start)
            
            minDistance = min(minDistance, distance(point, projection))
        }
        
        return minDistance
    }
    
    func calculateMeasurement() -> Measurement<Unit>? {
        guard imageCoordinates.count == 3 else { return nil }
        
        let p1 = imageCoordinates[0]  // First point
        let vertex = imageCoordinates[1]  // Vertex (center point)
        let p2 = imageCoordinates[2]  // Third point
        
        // Calculate vectors from vertex to other points
        let v1 = p1 - vertex
        let v2 = p2 - vertex
        
        // Calculate angle using dot product
        let dotProduct = dot(v1, v2)
        let magnitude1 = length(v1)
        let magnitude2 = length(v2)
        
        if magnitude1 == 0 || magnitude2 == 0 {
            return nil
        }
        
        let cosAngle = dotProduct / (magnitude1 * magnitude2)
        let angleRadians = acos(max(-1.0, min(1.0, cosAngle))) // Clamp to avoid numerical errors
        let angleDegrees = angleRadians * 180.0 / Float.pi
        
        return Measurement(value: Double(angleDegrees), unit: UnitAngle.degrees)
    }
    
    func calculateStatistics(pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics? {
        return nil // Angle measurements don't have area statistics
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "type": "angle",
            "imageCoordinates": imageCoordinates.map { [$0.x, $0.y] },
            "worldCoordinates": worldCoordinates.map { [$0.x, $0.y, $0.z] },
            "pixelSpacing": [pixelSpacing.x, pixelSpacing.y],
            "sliceThickness": sliceThickness,
            "color": color.hexString,
            "lineWidth": lineWidth,
            "creationDate": creationDate.iso8601String,
            "modificationDate": modificationDate.iso8601String
        ]
    }
    
    func fromDictionary(_ dict: [String: Any]) {
        if let coords = dict["imageCoordinates"] as? [[Float]] {
            imageCoordinates = coords.map { simd_float2($0[0], $0[1]) }
        }
        if let coords = dict["worldCoordinates"] as? [[Float]] {
            worldCoordinates = coords.map { simd_float3($0[0], $0[1], $0[2]) }
        }
        if let spacing = dict["pixelSpacing"] as? [Float] {
            pixelSpacing = simd_float2(spacing[0], spacing[1])
        }
        if let thickness = dict["sliceThickness"] as? Float {
            sliceThickness = thickness
        }
        if let colorHex = dict["color"] as? String {
            color = UIColor(hex: colorHex) ?? UIColor.orange
        }
        if let width = dict["lineWidth"] as? Float {
            lineWidth = width
        }
    }
}

/// Elliptical ROI tool for oval area measurements
class EllipticalROITool: ROITool {
    let id = UUID()
    let name = "Elliptical ROI"
    var isActive = false
    var isVisible = true
    let creationDate = Date()
    var modificationDate = Date()
    
    var color = UIColor.cyan
    var lineWidth: Float = 2.0
    var opacity: Float = 0.3
    
    var imageCoordinates: [simd_float2] = []
    var worldCoordinates: [simd_float3] = []
    var pixelSpacing = simd_float2(1.0, 1.0)
    var sliceThickness: Float = 1.0
    
    private var _statistics: ROIStatistics?
    
    var center: simd_float2? {
        guard imageCoordinates.count == 2 else { return nil }
        return (imageCoordinates[0] + imageCoordinates[1]) / 2.0
    }
    
    var semiAxes: simd_float2? {
        guard imageCoordinates.count == 2 else { return nil }
        let diff = abs(imageCoordinates[1] - imageCoordinates[0]) / 2.0
        return simd_float2(diff.x, diff.y)
    }
    
    var measurement: Measurement<Unit>? {
        return calculateMeasurement()
    }
    
    var statistics: ROIStatistics? {
        return _statistics
    }
    
    func addPoint(_ point: simd_float2, worldPoint: simd_float3) {
        if imageCoordinates.count < 2 {
            imageCoordinates.append(point)
            worldCoordinates.append(worldPoint)
            modificationDate = Date()
        }
    }
    
    func removeLastPoint() {
        if !imageCoordinates.isEmpty {
            imageCoordinates.removeLast()
            worldCoordinates.removeLast()
            modificationDate = Date()
            _statistics = nil
        }
    }
    
    func isComplete() -> Bool {
        return imageCoordinates.count == 2
    }
    
    func contains(point: simd_float2) -> Bool {
        guard let center = center, let semiAxes = semiAxes else { return false }
        
        let dx = (point.x - center.x) / semiAxes.x
        let dy = (point.y - center.y) / semiAxes.y
        
        return (dx * dx + dy * dy) <= 1.0
    }
    
    func distanceToPoint(_ point: simd_float2) -> Float {
        guard let center = center, let semiAxes = semiAxes else { return Float.infinity }
        
        // Approximate distance to ellipse boundary
        let dx = (point.x - center.x) / semiAxes.x
        let dy = (point.y - center.y) / semiAxes.y
        let distanceFromCenter = sqrt(dx * dx + dy * dy)
        
        return abs(distanceFromCenter - 1.0) * min(semiAxes.x, semiAxes.y)
    }
    
    func calculateMeasurement() -> Measurement<Unit>? {
        guard let semiAxes = semiAxes else { return nil }
        
        // Calculate area of ellipse: π * a * b
        let a = semiAxes.x * pixelSpacing.x
        let b = semiAxes.y * pixelSpacing.y
        let area = Float.pi * a * b
        
        return Measurement(value: Double(area), unit: UnitArea.squareMillimeters)
    }
    
    func calculateStatistics(pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics? {
        guard let center = center, let semiAxes = semiAxes else { return nil }
        
        let imageWidth = metadata.columns
        let imageHeight = metadata.rows
        let bytesPerPixel = metadata.bitsStored / 8
        
        var pixelValues: [Double] = []
        var pixelCount = 0
        
        // Find bounding box
        let minX = max(0, Int(center.x - semiAxes.x))
        let maxX = min(imageWidth, Int(center.x + semiAxes.x))
        let minY = max(0, Int(center.y - semiAxes.y))
        let maxY = min(imageHeight, Int(center.y + semiAxes.y))
        
        for y in minY..<maxY {
            for x in minX..<maxX {
                let point = simd_float2(Float(x), Float(y))
                if contains(point: point) {
                    let pixelIndex = y * imageWidth + x
                    let byteIndex = pixelIndex * bytesPerPixel
                    
                    if byteIndex + bytesPerPixel <= pixelData.count {
                        let pixelValue: Double
                        
                        if bytesPerPixel == 2 {
                            let value = pixelData.withUnsafeBytes { bytes in
                                bytes.load(fromByteOffset: byteIndex, as: UInt16.self)
                            }
                            pixelValue = Double(value)
                        } else {
                            let value = pixelData[byteIndex]
                            pixelValue = Double(value)
                        }
                        
                        pixelValues.append(pixelValue)
                        pixelCount += 1
                    }
                }
            }
        }
        
        guard !pixelValues.isEmpty else { return nil }
        
        // Calculate statistics
        let mean = pixelValues.reduce(0, +) / Double(pixelValues.count)
        let variance = pixelValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(pixelValues.count)
        let standardDeviation = sqrt(variance)
        let minimum = pixelValues.min() ?? 0
        let maximum = pixelValues.max() ?? 0
        let median = pixelValues.sorted()[pixelValues.count / 2]
        
        // Calculate real-world measurements
        let a = Double(semiAxes.x * pixelSpacing.x)
        let b = Double(semiAxes.y * pixelSpacing.y)
        let area = Double.pi * a * b
        
        // Approximate perimeter using Ramanujan's formula
        let h = pow((a - b) / (a + b), 2)
        let perimeter = Double.pi * (a + b) * (1 + (3 * h) / (10 + sqrt(4 - 3 * h)))
        
        // Create histogram
        let binCount = 256
        let range = maximum - minimum
        let binSize = max(1.0, range / Double(binCount))
        var histogram = Array(repeating: 0, count: binCount)
        
        for value in pixelValues {
            let binIndex = min(binCount - 1, max(0, Int((value - minimum) / binSize)))
            histogram[binIndex] += 1
        }
        
        let stats = ROIStatistics(
            area: area,
            perimeter: perimeter,
            pixelCount: pixelCount,
            mean: mean,
            standardDeviation: standardDeviation,
            minimum: minimum,
            maximum: maximum,
            median: median,
            histogram: histogram
        )
        
        _statistics = stats
        return stats
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "type": "elliptical",
            "imageCoordinates": imageCoordinates.map { [$0.x, $0.y] },
            "worldCoordinates": worldCoordinates.map { [$0.x, $0.y, $0.z] },
            "pixelSpacing": [pixelSpacing.x, pixelSpacing.y],
            "sliceThickness": sliceThickness,
            "color": color.hexString,
            "lineWidth": lineWidth,
            "opacity": opacity,
            "creationDate": creationDate.iso8601String,
            "modificationDate": modificationDate.iso8601String
        ]
    }
    
    func fromDictionary(_ dict: [String: Any]) {
        if let coords = dict["imageCoordinates"] as? [[Float]] {
            imageCoordinates = coords.map { simd_float2($0[0], $0[1]) }
        }
        if let coords = dict["worldCoordinates"] as? [[Float]] {
            worldCoordinates = coords.map { simd_float3($0[0], $0[1], $0[2]) }
        }
        if let spacing = dict["pixelSpacing"] as? [Float] {
            pixelSpacing = simd_float2(spacing[0], spacing[1])
        }
        if let thickness = dict["sliceThickness"] as? Float {
            sliceThickness = thickness
        }
        if let colorHex = dict["color"] as? String {
            color = UIColor(hex: colorHex) ?? UIColor.cyan
        }
        if let width = dict["lineWidth"] as? Float {
            lineWidth = width
        }
        if let opac = dict["opacity"] as? Float {
            opacity = opac
        }
    }
}