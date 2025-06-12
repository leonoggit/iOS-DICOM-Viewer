import Foundation
import simd
import UIKit

/// Base protocol for all ROI (Region of Interest) tools
/// Provides common functionality for medical imaging measurements and annotations
protocol ROITool: AnyObject {
    var id: UUID { get }
    var name: String { get }
    var isActive: Bool { get set }
    var isVisible: Bool { get set }
    var creationDate: Date { get }
    var modificationDate: Date { get set }
    
    /// Measurement result with units
    var measurement: Measurement<Unit>? { get }
    
    /// Statistical data for the ROI
    var statistics: ROIStatistics? { get }
    
    /// Visual properties
    var color: UIColor { get set }
    var lineWidth: Float { get set }
    var opacity: Float { get set }
    
    /// Coordinate system information
    var imageCoordinates: [simd_float2] { get set }
    var worldCoordinates: [simd_float3] { get set }
    var pixelSpacing: simd_float2 { get set }
    var sliceThickness: Float { get set }
    
    /// Tool interaction methods
    func addPoint(_ point: simd_float2, worldPoint: simd_float3)
    func removeLastPoint()
    func isComplete() -> Bool
    func contains(point: simd_float2) -> Bool
    func distanceToPoint(_ point: simd_float2) -> Float
    
    /// Calculation methods
    func calculateMeasurement() -> Measurement<Unit>?
    func calculateStatistics(pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics?
    
    /// Serialization
    func toDictionary() -> [String: Any]
    func fromDictionary(_ dict: [String: Any])
}

/// Statistical analysis results for ROI
struct ROIStatistics {
    let area: Double           // Area in mm²
    let perimeter: Double      // Perimeter in mm
    let pixelCount: Int        // Number of pixels in ROI
    let mean: Double           // Mean pixel value
    let standardDeviation: Double
    let minimum: Double        // Minimum pixel value
    let maximum: Double        // Maximum pixel value
    let median: Double         // Median pixel value
    let histogram: [Int]       // Histogram bins
    
    var displayText: String {
        return """
        Area: \(String(format: "%.2f", area)) mm²
        Perimeter: \(String(format: "%.2f", perimeter)) mm
        Pixels: \(pixelCount)
        Mean: \(String(format: "%.1f", mean)) HU
        StdDev: \(String(format: "%.1f", standardDeviation)) HU
        Min/Max: \(String(format: "%.1f", minimum))/\(String(format: "%.1f", maximum)) HU
        """
    }
}

/// Linear measurement tool for distance measurements
class LinearROITool: ROITool {
    let id = UUID()
    let name = "Linear Measurement"
    var isActive = false
    var isVisible = true
    let creationDate = Date()
    var modificationDate = Date()
    
    var color = UIColor.yellow
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
        return nil // Linear tools don't have area statistics
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
        }
    }
    
    func isComplete() -> Bool {
        return imageCoordinates.count == 2
    }
    
    func contains(point: simd_float2) -> Bool {
        return distanceToPoint(point) < 10.0 // 10 pixel tolerance
    }
    
    func distanceToPoint(_ point: simd_float2) -> Float {
        guard imageCoordinates.count == 2 else { return Float.infinity }
        
        let start = imageCoordinates[0]
        let end = imageCoordinates[1]
        
        // Distance from point to line segment
        let lineLength = distance(start, end)
        if lineLength == 0 { return distance(point, start) }
        
        let t = max(0, min(1, dot(point - start, end - start) / (lineLength * lineLength)))
        let projection = start + t * (end - start)
        
        return distance(point, projection)
    }
    
    func calculateMeasurement() -> Measurement<Unit>? {
        guard imageCoordinates.count == 2 else { return nil }
        
        let start = imageCoordinates[0]
        let end = imageCoordinates[1]
        
        // Calculate distance in image coordinates
        let imageDistance = distance(start, end)
        
        // Convert to real-world distance using pixel spacing
        let realDistance = sqrt(
            pow((end.x - start.x) * pixelSpacing.x, 2) +
            pow((end.y - start.y) * pixelSpacing.y, 2)
        )
        
        return Measurement(value: Double(realDistance), unit: UnitLength.millimeters)
    }
    
    func calculateStatistics(pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics? {
        return nil // Linear measurements don't have area statistics
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "type": "linear",
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
            color = UIColor(hex: colorHex) ?? UIColor.yellow
        }
        if let width = dict["lineWidth"] as? Float {
            lineWidth = width
        }
    }
}

/// Circular ROI tool for area measurements
class CircularROITool: ROITool {
    let id = UUID()
    let name = "Circular ROI"
    var isActive = false
    var isVisible = true
    let creationDate = Date()
    var modificationDate = Date()
    
    var color = UIColor.green
    var lineWidth: Float = 2.0
    var opacity: Float = 0.3
    
    var imageCoordinates: [simd_float2] = []
    var worldCoordinates: [simd_float3] = []
    var pixelSpacing = simd_float2(1.0, 1.0)
    var sliceThickness: Float = 1.0
    
    private var _statistics: ROIStatistics?
    
    var center: simd_float2? {
        return imageCoordinates.first
    }
    
    var radius: Float {
        guard imageCoordinates.count == 2 else { return 0 }
        return distance(imageCoordinates[0], imageCoordinates[1])
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
        guard let center = center else { return false }
        let distanceFromCenter = distance(point, center)
        return distanceFromCenter <= radius
    }
    
    func distanceToPoint(_ point: simd_float2) -> Float {
        guard let center = center else { return Float.infinity }
        let distanceFromCenter = distance(point, center)
        return abs(distanceFromCenter - radius)
    }
    
    func calculateMeasurement() -> Measurement<Unit>? {
        guard isComplete() else { return nil }
        
        // Calculate area in real-world coordinates
        let realRadius = radius * min(pixelSpacing.x, pixelSpacing.y)
        let area = Float.pi * realRadius * realRadius
        
        return Measurement(value: Double(area), unit: UnitArea.squareMillimeters)
    }
    
    func calculateStatistics(pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics? {
        guard isComplete(), let center = center else { return nil }
        
        let width = metadata.columns
        let height = metadata.rows
        let bytesPerPixel = metadata.bitsStored / 8
        
        var pixelValues: [Double] = []
        var pixelCount = 0
        
        // Extract pixels within the circular ROI
        let minX = max(0, Int(center.x - radius))
        let maxX = min(width, Int(center.x + radius))
        let minY = max(0, Int(center.y - radius))
        let maxY = min(height, Int(center.y + radius))
        
        for y in minY..<maxY {
            for x in minX..<maxX {
                let point = simd_float2(Float(x), Float(y))
                if contains(point: point) {
                    let pixelIndex = y * width + x
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
        let realRadius = Double(radius * min(pixelSpacing.x, pixelSpacing.y))
        let area = Double.pi * realRadius * realRadius
        let perimeter = 2.0 * Double.pi * realRadius
        
        // Create histogram
        let binCount = 256
        let range = maximum - minimum
        let binSize = range / Double(binCount)
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
            "type": "circular",
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
            color = UIColor(hex: colorHex) ?? UIColor.green
        }
        if let width = dict["lineWidth"] as? Float {
            lineWidth = width
        }
        if let opac = dict["opacity"] as? Float {
            opacity = opac
        }
    }
}

/// Rectangular ROI tool for area measurements
class RectangularROITool: ROITool {
    let id = UUID()
    let name = "Rectangular ROI"
    var isActive = false
    var isVisible = true
    let creationDate = Date()
    var modificationDate = Date()
    
    var color = UIColor.blue
    var lineWidth: Float = 2.0
    var opacity: Float = 0.3
    
    var imageCoordinates: [simd_float2] = []
    var worldCoordinates: [simd_float3] = []
    var pixelSpacing = simd_float2(1.0, 1.0)
    var sliceThickness: Float = 1.0
    
    private var _statistics: ROIStatistics?
    
    var topLeft: simd_float2? {
        guard imageCoordinates.count == 2 else { return nil }
        let p1 = imageCoordinates[0]
        let p2 = imageCoordinates[1]
        return simd_float2(min(p1.x, p2.x), min(p1.y, p2.y))
    }
    
    var bottomRight: simd_float2? {
        guard imageCoordinates.count == 2 else { return nil }
        let p1 = imageCoordinates[0]
        let p2 = imageCoordinates[1]
        return simd_float2(max(p1.x, p2.x), max(p1.y, p2.y))
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
        guard let topLeft = topLeft, let bottomRight = bottomRight else { return false }
        return point.x >= topLeft.x && point.x <= bottomRight.x &&
               point.y >= topLeft.y && point.y <= bottomRight.y
    }
    
    func distanceToPoint(_ point: simd_float2) -> Float {
        guard let topLeft = topLeft, let bottomRight = bottomRight else { return Float.infinity }
        
        // Distance to rectangle boundary
        let dx = max(0, max(topLeft.x - point.x, point.x - bottomRight.x))
        let dy = max(0, max(topLeft.y - point.y, point.y - bottomRight.y))
        
        return sqrt(dx * dx + dy * dy)
    }
    
    func calculateMeasurement() -> Measurement<Unit>? {
        guard let topLeft = topLeft, let bottomRight = bottomRight else { return nil }
        
        let width = (bottomRight.x - topLeft.x) * pixelSpacing.x
        let height = (bottomRight.y - topLeft.y) * pixelSpacing.y
        let area = width * height
        
        return Measurement(value: Double(area), unit: UnitArea.squareMillimeters)
    }
    
    func calculateStatistics(pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics? {
        guard let topLeft = topLeft, let bottomRight = bottomRight else { return nil }
        
        let imageWidth = metadata.columns
        let imageHeight = metadata.rows
        let bytesPerPixel = metadata.bitsStored / 8
        
        var pixelValues: [Double] = []
        var pixelCount = 0
        
        let minX = max(0, Int(topLeft.x))
        let maxX = min(imageWidth, Int(bottomRight.x))
        let minY = max(0, Int(topLeft.y))
        let maxY = min(imageHeight, Int(bottomRight.y))
        
        for y in minY..<maxY {
            for x in minX..<maxX {
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
        
        guard !pixelValues.isEmpty else { return nil }
        
        // Calculate statistics
        let mean = pixelValues.reduce(0, +) / Double(pixelValues.count)
        let variance = pixelValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(pixelValues.count)
        let standardDeviation = sqrt(variance)
        let minimum = pixelValues.min() ?? 0
        let maximum = pixelValues.max() ?? 0
        let median = pixelValues.sorted()[pixelValues.count / 2]
        
        // Calculate real-world measurements
        let width = Double((bottomRight.x - topLeft.x) * pixelSpacing.x)
        let height = Double((bottomRight.y - topLeft.y) * pixelSpacing.y)
        let area = width * height
        let perimeter = 2.0 * (width + height)
        
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
            "type": "rectangular",
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
            color = UIColor(hex: colorHex) ?? UIColor.blue
        }
        if let width = dict["lineWidth"] as? Float {
            lineWidth = width
        }
        if let opac = dict["opacity"] as? Float {
            opacity = opac
        }
    }
}

// MARK: - Helper Extensions
extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(format: "#%02X%02X%02X%02X",
                     Int(red * 255),
                     Int(green * 255),
                     Int(blue * 255),
                     Int(alpha * 255))
    }
    
    convenience init?(hex: String) {
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        
        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        
        let mask = 0x000000FF
        let r = Int(color >> 24) & mask
        let g = Int(color >> 16) & mask
        let b = Int(color >> 8) & mask
        let a = Int(color) & mask
        
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        let alpha = CGFloat(a) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Date {
    var iso8601String: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
}