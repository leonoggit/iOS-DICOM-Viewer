import XCTest
import simd
@testable import iOS_DICOMViewer

/// Comprehensive tests for ROI tools and measurement capabilities
/// Tests accuracy, performance, and medical compliance of measurement tools
class ROIToolsTests: XCTestCase {
    
    var roiManager: ROIManager!
    var mockDICOMInstance: DICOMInstance!
    var mockPixelData: Data!
    
    override func setUpWithError() throws {
        roiManager = ROIManager.shared
        
        // Create mock DICOM instance with test data
        mockDICOMInstance = createMockDICOMInstance()
        mockPixelData = createMockPixelData()
        
        // Configure ROI manager
        roiManager.setCurrentInstance(
            instanceUID: "test.instance.uid",
            seriesUID: "test.series.uid",
            pixelSpacing: simd_float2(0.5, 0.5), // 0.5mm pixel spacing
            sliceThickness: 2.0 // 2mm slice thickness
        )
    }
    
    override func tearDownWithError() throws {
        roiManager.deleteAllTools()
        roiManager = nil
        mockDICOMInstance = nil
        mockPixelData = nil
    }
    
    // MARK: - Linear Measurement Tests
    func testLinearMeasurementTool() throws {
        let linearTool = LinearROITool()
        linearTool.pixelSpacing = simd_float2(0.5, 0.5) // 0.5mm per pixel
        
        // Add two points 100 pixels apart horizontally
        let point1 = simd_float2(100, 100)
        let point2 = simd_float2(200, 100)
        
        linearTool.addPoint(point1, worldPoint: simd_float3(point1.x, point1.y, 0))
        linearTool.addPoint(point2, worldPoint: simd_float3(point2.x, point2.y, 0))
        
        XCTAssertTrue(linearTool.isComplete(), "Linear tool should be complete with 2 points")
        
        // Verify measurement calculation
        let measurement = linearTool.calculateMeasurement()
        XCTAssertNotNil(measurement, "Measurement should not be nil")
        
        if let measurement = measurement {
            // 100 pixels * 0.5mm/pixel = 50mm
            XCTAssertEqual(measurement.value, 50.0, accuracy: 0.1, "Linear measurement should be 50mm")
            XCTAssertEqual(measurement.unit, UnitLength.millimeters, "Unit should be millimeters")
        }
        
        // Test point containment
        let midPoint = simd_float2(150, 100)
        XCTAssertTrue(linearTool.contains(point: midPoint), "Midpoint should be contained in line")
        
        let farPoint = simd_float2(150, 150)
        XCTAssertFalse(linearTool.contains(point: farPoint), "Far point should not be contained")
    }
    
    func testLinearMeasurementDiagonal() throws {
        let linearTool = LinearROITool()
        linearTool.pixelSpacing = simd_float2(1.0, 1.0) // 1mm per pixel
        
        // Add two points forming a 3-4-5 right triangle (Pythagorean theorem)
        let point1 = simd_float2(0, 0)
        let point2 = simd_float2(3, 4)
        
        linearTool.addPoint(point1, worldPoint: simd_float3(point1.x, point1.y, 0))
        linearTool.addPoint(point2, worldPoint: simd_float3(point2.x, point2.y, 0))
        
        let measurement = linearTool.calculateMeasurement()
        XCTAssertNotNil(measurement)
        
        if let measurement = measurement {
            // sqrt(3² + 4²) = 5mm
            XCTAssertEqual(measurement.value, 5.0, accuracy: 0.01, "Diagonal measurement should be 5mm")
        }
    }
    
    // MARK: - Circular ROI Tests
    func testCircularROITool() throws {
        let circularTool = CircularROITool()
        circularTool.pixelSpacing = simd_float2(1.0, 1.0) // 1mm per pixel
        
        // Create circle with center at (50, 50) and radius 25 pixels
        let center = simd_float2(50, 50)
        let edge = simd_float2(75, 50) // 25 pixels to the right
        
        circularTool.addPoint(center, worldPoint: simd_float3(center.x, center.y, 0))
        circularTool.addPoint(edge, worldPoint: simd_float3(edge.x, edge.y, 0))
        
        XCTAssertTrue(circularTool.isComplete(), "Circular tool should be complete with 2 points")
        XCTAssertEqual(circularTool.radius, 25.0, "Radius should be 25 pixels")
        
        // Test area calculation: π * r² = π * 25² = π * 625 ≈ 1963.5 mm²
        let measurement = circularTool.calculateMeasurement()
        XCTAssertNotNil(measurement)
        
        if let measurement = measurement {
            let expectedArea = Float.pi * 25.0 * 25.0 // radius in mm
            XCTAssertEqual(measurement.value, Double(expectedArea), accuracy: 1.0, "Circular area should match calculation")
            XCTAssertEqual(measurement.unit, UnitArea.squareMillimeters, "Unit should be square millimeters")
        }
        
        // Test point containment
        XCTAssertTrue(circularTool.contains(point: center), "Center should be contained")
        XCTAssertTrue(circularTool.contains(point: simd_float2(60, 50)), "Point within radius should be contained")
        XCTAssertFalse(circularTool.contains(point: simd_float2(100, 50)), "Point outside radius should not be contained")
    }
    
    func testCircularROIStatistics() throws {
        let circularTool = CircularROITool()
        circularTool.pixelSpacing = simd_float2(1.0, 1.0)
        
        // Create small circle for testing statistics
        let center = simd_float2(10, 10)
        let edge = simd_float2(15, 10) // radius = 5 pixels
        
        circularTool.addPoint(center, worldPoint: simd_float3(center.x, center.y, 0))
        circularTool.addPoint(edge, worldPoint: simd_float3(edge.x, edge.y, 0))
        
        // Create test pixel data with known values
        let testPixelData = createTestPixelDataWithPattern()
        let testMetadata = createTestDICOMMetadata()
        
        let statistics = circularTool.calculateStatistics(pixelData: testPixelData, metadata: testMetadata)
        XCTAssertNotNil(statistics, "Statistics should be calculated")
        
        if let stats = statistics {
            XCTAssertGreaterThan(stats.pixelCount, 0, "Should have counted pixels")
            XCTAssertGreaterThan(stats.area, 0, "Area should be positive")
            XCTAssertGreaterThan(stats.perimeter, 0, "Perimeter should be positive")
            XCTAssertGreaterThanOrEqual(stats.mean, 0, "Mean should be non-negative")
            XCTAssertGreaterThanOrEqual(stats.standardDeviation, 0, "Standard deviation should be non-negative")
            XCTAssertLessThanOrEqual(stats.minimum, stats.maximum, "Minimum should be <= maximum")
        }
    }
    
    // MARK: - Rectangular ROI Tests
    func testRectangularROITool() throws {
        let rectangularTool = RectangularROITool()
        rectangularTool.pixelSpacing = simd_float2(0.5, 0.5) // 0.5mm per pixel
        
        // Create 40x30 pixel rectangle
        let topLeft = simd_float2(10, 10)
        let bottomRight = simd_float2(50, 40)
        
        rectangularTool.addPoint(topLeft, worldPoint: simd_float3(topLeft.x, topLeft.y, 0))
        rectangularTool.addPoint(bottomRight, worldPoint: simd_float3(bottomRight.x, bottomRight.y, 0))
        
        XCTAssertTrue(rectangularTool.isComplete(), "Rectangular tool should be complete")
        
        // Test area calculation: 40 * 0.5 * 30 * 0.5 = 20 * 15 = 300 mm²
        let measurement = rectangularTool.calculateMeasurement()
        XCTAssertNotNil(measurement)
        
        if let measurement = measurement {
            XCTAssertEqual(measurement.value, 300.0, accuracy: 0.1, "Rectangle area should be 300 mm²")
        }
        
        // Test point containment
        XCTAssertTrue(rectangularTool.contains(point: simd_float2(30, 25)), "Interior point should be contained")
        XCTAssertFalse(rectangularTool.contains(point: simd_float2(5, 5)), "Exterior point should not be contained")
        XCTAssertTrue(rectangularTool.contains(point: topLeft), "Corner point should be contained")
    }
    
    // MARK: - Polygon ROI Tests
    func testPolygonROITool() throws {
        let polygonTool = PolygonROITool()
        polygonTool.pixelSpacing = simd_float2(1.0, 1.0)
        
        // Create triangle: (0,0), (10,0), (5,10)
        let points = [
            simd_float2(0, 0),
            simd_float2(10, 0),
            simd_float2(5, 10)
        ]
        
        for point in points {
            polygonTool.addPoint(point, worldPoint: simd_float3(point.x, point.y, 0))
        }
        
        polygonTool.closePolygon()
        XCTAssertTrue(polygonTool.isComplete(), "Polygon should be complete when closed")
        
        // Test area calculation using shoelace formula: Area = 0.5 * |10*10 - 0*0| = 50 mm²
        let measurement = polygonTool.calculateMeasurement()
        XCTAssertNotNil(measurement)
        
        if let measurement = measurement {
            XCTAssertEqual(measurement.value, 50.0, accuracy: 1.0, "Triangle area should be approximately 50 mm²")
        }
        
        // Test point containment (triangle centroid should be inside)
        let centroid = simd_float2(5, 3.33)
        XCTAssertTrue(polygonTool.contains(point: centroid), "Centroid should be inside triangle")
        
        let outsidePoint = simd_float2(15, 15)
        XCTAssertFalse(polygonTool.contains(point: outsidePoint), "Point outside should not be contained")
    }
    
    // MARK: - Angle Measurement Tests
    func testAngleROITool() throws {
        let angleTool = AngleROITool()
        
        // Create 90-degree angle: (0,0) -> (5,0) -> (5,5)
        let point1 = simd_float2(0, 0)  // First ray point
        let vertex = simd_float2(5, 0)  // Vertex
        let point2 = simd_float2(5, 5)  // Second ray point
        
        angleTool.addPoint(point1, worldPoint: simd_float3(point1.x, point1.y, 0))
        angleTool.addPoint(vertex, worldPoint: simd_float3(vertex.x, vertex.y, 0))
        angleTool.addPoint(point2, worldPoint: simd_float3(point2.x, point2.y, 0))
        
        XCTAssertTrue(angleTool.isComplete(), "Angle tool should be complete with 3 points")
        
        let measurement = angleTool.calculateMeasurement()
        XCTAssertNotNil(measurement)
        
        if let measurement = measurement {
            XCTAssertEqual(measurement.value, 90.0, accuracy: 0.1, "Angle should be 90 degrees")
            XCTAssertEqual(measurement.unit, UnitAngle.degrees, "Unit should be degrees")
        }
    }
    
    func testAngleROITool45Degrees() throws {
        let angleTool = AngleROITool()
        
        // Create 45-degree angle
        let point1 = simd_float2(1, 0)  // Along X-axis
        let vertex = simd_float2(0, 0)  // Origin
        let point2 = simd_float2(1, 1)  // 45-degree diagonal
        
        angleTool.addPoint(point1, worldPoint: simd_float3(point1.x, point1.y, 0))
        angleTool.addPoint(vertex, worldPoint: simd_float3(vertex.x, vertex.y, 0))
        angleTool.addPoint(point2, worldPoint: simd_float3(point2.x, point2.y, 0))
        
        let measurement = angleTool.calculateMeasurement()
        XCTAssertNotNil(measurement)
        
        if let measurement = measurement {
            XCTAssertEqual(measurement.value, 45.0, accuracy: 0.1, "Angle should be 45 degrees")
        }
    }
    
    // MARK: - Elliptical ROI Tests
    func testEllipticalROITool() throws {
        let ellipticalTool = EllipticalROITool()
        ellipticalTool.pixelSpacing = simd_float2(1.0, 1.0)
        
        // Create ellipse with semi-axes 10 and 5
        let topLeft = simd_float2(40, 45)     // Center at (50, 50), semi-axes 10, 5
        let bottomRight = simd_float2(60, 55)
        
        ellipticalTool.addPoint(topLeft, worldPoint: simd_float3(topLeft.x, topLeft.y, 0))
        ellipticalTool.addPoint(bottomRight, worldPoint: simd_float3(bottomRight.x, bottomRight.y, 0))
        
        XCTAssertTrue(ellipticalTool.isComplete(), "Elliptical tool should be complete")
        
        // Test area calculation: π * a * b = π * 10 * 5 ≈ 157.08 mm²
        let measurement = ellipticalTool.calculateMeasurement()
        XCTAssertNotNil(measurement)
        
        if let measurement = measurement {
            let expectedArea = Float.pi * 10.0 * 5.0
            XCTAssertEqual(measurement.value, Double(expectedArea), accuracy: 1.0, "Ellipse area should match calculation")
        }
        
        // Test point containment
        if let center = ellipticalTool.center {
            XCTAssertTrue(ellipticalTool.contains(point: center), "Center should be contained")
        }
    }
    
    // MARK: - ROI Manager Tests
    func testROIManagerToolCreation() throws {
        // Test tool creation workflow
        roiManager.selectToolType(.linear)
        
        let point1 = simd_float2(10, 10)
        let point2 = simd_float2(20, 10)
        
        roiManager.startTool(at: point1, worldPoint: simd_float3(point1.x, point1.y, 0))
        XCTAssertTrue(roiManager.isCreating, "Should be in creating mode")
        
        roiManager.startTool(at: point2, worldPoint: simd_float3(point2.x, point2.y, 0))
        XCTAssertFalse(roiManager.isCreating, "Should finish creating after second point for linear tool")
        
        XCTAssertEqual(roiManager.activeTools.count, 1, "Should have one active tool")
        XCTAssertTrue(roiManager.activeTools.first is LinearROITool, "Should be a linear tool")
    }
    
    func testROIManagerToolSelection() throws {
        // Create multiple tools
        createTestLinearTool()
        createTestCircularTool()
        
        XCTAssertEqual(roiManager.activeTools.count, 2, "Should have two tools")
        
        // Test tool selection
        let selectionPoint = simd_float2(15, 10) // On the linear tool
        let selectedTool = roiManager.selectTool(at: selectionPoint)
        
        XCTAssertNotNil(selectedTool, "Should select a tool")
        XCTAssertTrue(selectedTool is LinearROITool, "Should select the linear tool")
    }
    
    func testROIManagerPersistence() throws {
        // Create test tools
        createTestLinearTool()
        createTestCircularTool()
        
        let initialCount = roiManager.activeTools.count
        XCTAssertGreaterThan(initialCount, 0, "Should have tools to save")
        
        // Save tools
        roiManager.saveToolsForInstance("test.instance.uid")
        
        // Clear and reload
        roiManager.deleteAllTools()
        XCTAssertEqual(roiManager.activeTools.count, 0, "Tools should be cleared")
        
        roiManager.loadToolsForInstance("test.instance.uid")
        XCTAssertEqual(roiManager.activeTools.count, initialCount, "Tools should be restored")
    }
    
    // MARK: - Measurement Accuracy Tests
    func testMeasurementAccuracyWithDifferentPixelSpacing() throws {
        let spacings: [simd_float2] = [
            simd_float2(0.1, 0.1),   // High resolution
            simd_float2(0.5, 0.5),   // Medium resolution
            simd_float2(1.0, 1.0),   // Standard resolution
            simd_float2(2.0, 2.0)    // Low resolution
        ]
        
        for spacing in spacings {
            let linearTool = LinearROITool()
            linearTool.pixelSpacing = spacing
            
            // 100 pixel distance
            linearTool.addPoint(simd_float2(0, 0), worldPoint: simd_float3(0, 0, 0))
            linearTool.addPoint(simd_float2(100, 0), worldPoint: simd_float3(100, 0, 0))
            
            let measurement = linearTool.calculateMeasurement()
            XCTAssertNotNil(measurement)
            
            if let measurement = measurement {
                let expectedDistance = 100.0 * Double(spacing.x)
                XCTAssertEqual(measurement.value, expectedDistance, accuracy: 0.01,
                             "Distance should scale with pixel spacing")
            }
        }
    }
    
    // MARK: - Performance Tests
    func testROICalculationPerformance() throws {
        measure {
            // Create and calculate measurements for multiple tools
            for _ in 0..<100 {
                let linearTool = LinearROITool()
                linearTool.pixelSpacing = simd_float2(0.5, 0.5)
                
                linearTool.addPoint(simd_float2(0, 0), worldPoint: simd_float3(0, 0, 0))
                linearTool.addPoint(simd_float2(100, 100), worldPoint: simd_float3(100, 100, 0))
                
                _ = linearTool.calculateMeasurement()
            }
        }
    }
    
    func testStatisticsCalculationPerformance() throws {
        let circularTool = CircularROITool()
        circularTool.pixelSpacing = simd_float2(1.0, 1.0)
        
        // Large circle for performance testing
        circularTool.addPoint(simd_float2(256, 256), worldPoint: simd_float3(256, 256, 0))
        circularTool.addPoint(simd_float2(356, 256), worldPoint: simd_float3(356, 256, 0))
        
        let largePixelData = createLargeTestPixelData()
        let metadata = createTestDICOMMetadata()
        
        measure {
            _ = circularTool.calculateStatistics(pixelData: largePixelData, metadata: metadata)
        }
    }
    
    // MARK: - Error Handling Tests
    func testROIToolErrorHandling() throws {
        let linearTool = LinearROITool()
        
        // Test incomplete tool
        XCTAssertFalse(linearTool.isComplete(), "Tool should not be complete with no points")
        XCTAssertNil(linearTool.calculateMeasurement(), "Measurement should be nil for incomplete tool")
        
        // Test single point
        linearTool.addPoint(simd_float2(10, 10), worldPoint: simd_float3(10, 10, 0))
        XCTAssertFalse(linearTool.isComplete(), "Tool should not be complete with one point")
        XCTAssertNil(linearTool.calculateMeasurement(), "Measurement should be nil with one point")
    }
    
    func testInvalidPixelSpacing() throws {
        let linearTool = LinearROITool()
        linearTool.pixelSpacing = simd_float2(0, 0) // Invalid spacing
        
        linearTool.addPoint(simd_float2(0, 0), worldPoint: simd_float3(0, 0, 0))
        linearTool.addPoint(simd_float2(100, 0), worldPoint: simd_float3(100, 0, 0))
        
        let measurement = linearTool.calculateMeasurement()
        XCTAssertNotNil(measurement, "Should handle invalid spacing gracefully")
        
        if let measurement = measurement {
            XCTAssertEqual(measurement.value, 0.0, "Measurement should be 0 with invalid spacing")
        }
    }
    
    // MARK: - Helper Methods
    private func createMockDICOMInstance() -> DICOMInstance {
        let metadata = DICOMMetadata()
        metadata.sopInstanceUID = "test.instance.uid"
        metadata.seriesInstanceUID = "test.series.uid"
        metadata.rows = 512
        metadata.columns = 512
        metadata.bitsStored = 16
        metadata.pixelSpacing = [0.5, 0.5]
        metadata.sliceThickness = 2.0
        
        return DICOMInstance(metadata: metadata)
    }
    
    private func createMockPixelData() -> Data {
        // Create 512x512x16-bit test data
        let size = 512 * 512 * 2
        return Data(repeating: 128, count: size)
    }
    
    private func createTestPixelDataWithPattern() -> Data {
        // Create test data with known pattern for statistics testing
        let width = 32
        let height = 32
        var data = Data(capacity: width * height * 2)
        
        for y in 0..<height {
            for x in 0..<width {
                // Create gradient pattern
                let value = UInt16((x + y) % 256 + 100) // Values 100-355
                withUnsafeBytes(of: value.littleEndian) { bytes in
                    data.append(contentsOf: bytes)
                }
            }
        }
        
        return data
    }
    
    private func createLargeTestPixelData() -> Data {
        // Create larger test data for performance testing
        let size = 512 * 512 * 2
        return Data(repeating: 150, count: size)
    }
    
    private func createTestDICOMMetadata() -> DICOMMetadata {
        let metadata = DICOMMetadata()
        metadata.rows = 32
        metadata.columns = 32
        metadata.bitsStored = 16
        metadata.bitsAllocated = 16
        metadata.pixelSpacing = [1.0, 1.0]
        return metadata
    }
    
    private func createTestLinearTool() {
        roiManager.selectToolType(.linear)
        roiManager.startTool(at: simd_float2(10, 10), worldPoint: simd_float3(10, 10, 0))
        roiManager.startTool(at: simd_float2(20, 10), worldPoint: simd_float3(20, 10, 0))
    }
    
    private func createTestCircularTool() {
        roiManager.selectToolType(.circular)
        roiManager.startTool(at: simd_float2(50, 50), worldPoint: simd_float3(50, 50, 0))
        roiManager.startTool(at: simd_float2(60, 50), worldPoint: simd_float3(60, 50, 0))
    }
}