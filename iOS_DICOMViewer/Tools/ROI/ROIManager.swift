import Foundation
import simd
import UIKit

/// ROI Manager for handling all measurement and annotation tools
/// Provides centralized management for ROI creation, editing, and persistence
class ROIManager: ObservableObject {
    
    static let shared = ROIManager()
    
    // MARK: - Properties
    @Published var activeTools: [ROITool] = []
    @Published var selectedTool: ROITool?
    @Published var currentToolType: ROIToolType = .linear
    @Published var isInEditMode = false
    
    private var pixelSpacing = simd_float2(1.0, 1.0)
    private var sliceThickness: Float = 1.0
    private var currentInstanceUID: String?
    private var seriesUID: String?
    
    // Tool creation state
    private var isCreatingTool = false
    private var pendingTool: ROITool?
    
    // Compliance manager for audit logging
    private let complianceManager = ClinicalComplianceManager.shared
    
    // MARK: - Tool Types
    enum ROIToolType: String, CaseIterable {
        case linear = "linear"
        case circular = "circular"
        case rectangular = "rectangular"
        case polygon = "polygon"
        case angle = "angle"
        case elliptical = "elliptical"
        
        var displayName: String {
            switch self {
            case .linear: return "Linear Measurement"
            case .circular: return "Circular ROI"
            case .rectangular: return "Rectangular ROI"
            case .polygon: return "Polygon ROI"
            case .angle: return "Angle Measurement"
            case .elliptical: return "Elliptical ROI"
            }
        }
        
        var icon: String {
            switch self {
            case .linear: return "ruler"
            case .circular: return "circle"
            case .rectangular: return "rectangle"
            case .polygon: return "pentagon"
            case .angle: return "angle"
            case .elliptical: return "ellipsis"
            }
        }
        
        func createTool() -> ROITool {
            switch self {
            case .linear: return LinearROITool()
            case .circular: return CircularROITool()
            case .rectangular: return RectangularROITool()
            case .polygon: return PolygonROITool()
            case .angle: return AngleROITool()
            case .elliptical: return EllipticalROITool()
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupDefaultColors()
    }
    
    private func setupDefaultColors() {
        // Set up default color scheme for different tool types
    }
    
    // MARK: - Tool Management
    func setCurrentInstance(instanceUID: String, seriesUID: String, pixelSpacing: simd_float2, sliceThickness: Float) {
        self.currentInstanceUID = instanceUID
        self.seriesUID = seriesUID
        self.pixelSpacing = pixelSpacing
        self.sliceThickness = sliceThickness
        
        // Load existing tools for this instance
        loadToolsForInstance(instanceUID)
    }
    
    func selectToolType(_ toolType: ROIToolType) {
        currentToolType = toolType
        finishCurrentTool()
    }
    
    func startTool(at point: simd_float2, worldPoint: simd_float3) {
        if isCreatingTool, let tool = pendingTool {
            // Continue with existing tool
            tool.addPoint(point, worldPoint: worldPoint)
            
            if tool.isComplete() {
                finishCurrentTool()
            }
        } else {
            // Start new tool
            startNewTool(at: point, worldPoint: worldPoint)
        }
    }
    
    private func startNewTool(at point: simd_float2, worldPoint: simd_float3) {
        let newTool = currentToolType.createTool()
        newTool.pixelSpacing = pixelSpacing
        newTool.sliceThickness = sliceThickness
        newTool.isActive = true
        newTool.addPoint(point, worldPoint: worldPoint)
        
        pendingTool = newTool
        isCreatingTool = true
        
        // For single-click tools like polygon, don't finish immediately
        if newTool.isComplete() && currentToolType != .polygon {
            finishCurrentTool()
        }
        
        complianceManager.logUserAction("ROI tool creation started", details: [
            "toolType": currentToolType.rawValue,
            "instanceUID": currentInstanceUID ?? "unknown"
        ])
    }
    
    func finishCurrentTool() {
        guard let tool = pendingTool else { return }
        
        if tool.isComplete() {
            tool.isActive = false
            activeTools.append(tool)
            
            complianceManager.logUserAction("ROI tool completed", details: [
                "toolType": currentToolType.rawValue,
                "toolID": tool.id.uuidString,
                "measurement": tool.measurement?.description ?? "N/A"
            ])
            
            print("✅ ROI tool completed: \(tool.measurement?.description ?? "No measurement")")
        }
        
        pendingTool = nil
        isCreatingTool = false
    }
    
    func cancelCurrentTool() {
        pendingTool = nil
        isCreatingTool = false
    }
    
    func deleteLastPoint() {
        pendingTool?.removeLastPoint()
    }
    
    func closePolygon() {
        if let polygonTool = pendingTool as? PolygonROITool {
            polygonTool.closePolygon()
            if polygonTool.isComplete() {
                finishCurrentTool()
            }
        }
    }
    
    // MARK: - Tool Selection and Editing
    func selectTool(at point: simd_float2) -> ROITool? {
        // Find the closest tool to the touch point
        var closestTool: ROITool?
        var minDistance = Float.infinity
        
        for tool in activeTools {
            if tool.isVisible {
                let distance = tool.distanceToPoint(point)
                if distance < minDistance && distance < 20.0 { // 20 pixel tolerance
                    minDistance = distance
                    closestTool = tool
                }
            }
        }
        
        selectedTool = closestTool
        return closestTool
    }
    
    func deleteTool(_ tool: ROITool) {
        activeTools.removeAll { $0.id == tool.id }
        if selectedTool?.id == tool.id {
            selectedTool = nil
        }
        
        complianceManager.logUserAction("ROI tool deleted", details: [
            "toolID": tool.id.uuidString,
            "toolType": tool.name
        ])
    }
    
    func deleteAllTools() {
        let toolCount = activeTools.count
        activeTools.removeAll()
        selectedTool = nil
        
        complianceManager.logUserAction("All ROI tools deleted", details: [
            "toolCount": toolCount
        ])
    }
    
    func duplicateTool(_ tool: ROITool) {
        // Create a copy of the tool with offset position
        let newTool = currentToolType.createTool()
        
        // Copy properties
        newTool.pixelSpacing = tool.pixelSpacing
        newTool.sliceThickness = tool.sliceThickness
        newTool.color = tool.color
        newTool.lineWidth = tool.lineWidth
        newTool.opacity = tool.opacity
        
        // Offset coordinates by 20 pixels
        let offset = simd_float2(20, 20)
        for (index, coord) in tool.imageCoordinates.enumerated() {
            let offsetCoord = coord + offset
            let worldCoord = tool.worldCoordinates[safe: index] ?? simd_float3(0, 0, 0)
            newTool.addPoint(offsetCoord, worldPoint: worldCoord)
        }
        
        activeTools.append(newTool)
    }
    
    // MARK: - Statistics and Analysis
    func calculateStatistics(for tool: ROITool, pixelData: Data, metadata: DICOMMetadata) -> ROIStatistics? {
        return tool.calculateStatistics(pixelData: pixelData, metadata: metadata)
    }
    
    func generateReport() -> ROIReport {
        let report = ROIReport(
            seriesUID: seriesUID ?? "Unknown",
            instanceUID: currentInstanceUID ?? "Unknown",
            tools: activeTools,
            generationDate: Date()
        )
        
        complianceManager.logUserAction("ROI report generated", details: [
            "toolCount": activeTools.count,
            "seriesUID": seriesUID ?? "unknown"
        ])
        
        return report
    }
    
    // MARK: - Persistence
    func saveToolsForInstance(_ instanceUID: String) {
        let toolData = activeTools.map { $0.toDictionary() }
        
        UserDefaults.standard.set(toolData, forKey: "ROITools_\(instanceUID)")
        UserDefaults.standard.synchronize()
        
        complianceManager.logUserAction("ROI tools saved", details: [
            "instanceUID": instanceUID,
            "toolCount": activeTools.count
        ])
    }
    
    func loadToolsForInstance(_ instanceUID: String) {
        guard let toolData = UserDefaults.standard.array(forKey: "ROITools_\(instanceUID)") as? [[String: Any]] else {
            activeTools.removeAll()
            return
        }
        
        var loadedTools: [ROITool] = []
        
        for data in toolData {
            if let toolType = data["type"] as? String,
               let roiToolType = ROIToolType(rawValue: toolType) {
                
                let tool = roiToolType.createTool()
                tool.fromDictionary(data)
                loadedTools.append(tool)
            }
        }
        
        activeTools = loadedTools
        
        print("📋 Loaded \(loadedTools.count) ROI tools for instance \(instanceUID)")
    }
    
    func exportTools() -> Data? {
        let toolData = activeTools.map { $0.toDictionary() }
        
        let exportData = [
            "version": "1.0",
            "exportDate": Date().iso8601String,
            "seriesUID": seriesUID ?? "unknown",
            "instanceUID": currentInstanceUID ?? "unknown",
            "tools": toolData
        ] as [String: Any]
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    func importTools(from data: Data) -> Bool {
        do {
            guard let importData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let toolsData = importData["tools"] as? [[String: Any]] else {
                return false
            }
            
            var importedTools: [ROITool] = []
            
            for data in toolsData {
                if let toolType = data["type"] as? String,
                   let roiToolType = ROIToolType(rawValue: toolType) {
                    
                    let tool = roiToolType.createTool()
                    tool.fromDictionary(data)
                    importedTools.append(tool)
                }
            }
            
            activeTools.append(contentsOf: importedTools)
            
            complianceManager.logUserAction("ROI tools imported", details: [
                "importedCount": importedTools.count
            ])
            
            return true
        } catch {
            print("❌ Failed to import ROI tools: \(error)")
            return false
        }
    }
    
    // MARK: - Tool Visibility and Appearance
    func setToolsVisible(_ visible: Bool) {
        for tool in activeTools {
            tool.isVisible = visible
        }
    }
    
    func setToolColor(_ color: UIColor, for tool: ROITool) {
        tool.color = color
        tool.modificationDate = Date()
    }
    
    func setToolLineWidth(_ width: Float, for tool: ROITool) {
        tool.lineWidth = width
        tool.modificationDate = Date()
    }
    
    func setToolOpacity(_ opacity: Float, for tool: ROITool) {
        tool.opacity = opacity
        tool.modificationDate = Date()
    }
    
    // MARK: - Public Interface
    var hasActiveTools: Bool {
        return !activeTools.isEmpty
    }
    
    var isCreating: Bool {
        return isCreatingTool
    }
    
    var pendingToolDescription: String? {
        guard let tool = pendingTool else { return nil }
        return tool.measurement?.description
    }
    
    func getToolsForCurrentInstance() -> [ROITool] {
        return activeTools
    }
}

// MARK: - ROI Report
struct ROIReport {
    let seriesUID: String
    let instanceUID: String
    let tools: [ROITool]
    let generationDate: Date
    
    var measurements: [String] {
        return tools.compactMap { tool in
            guard let measurement = tool.measurement else { return nil }
            return "\(tool.name): \(measurement.description)"
        }
    }
    
    var statistics: [ROIStatistics] {
        return tools.compactMap { $0.statistics }
    }
    
    var summaryText: String {
        var summary = "ROI Analysis Report\n"
        summary += "Generated: \(DateFormatter.localizedString(from: generationDate, dateStyle: .medium, timeStyle: .short))\n"
        summary += "Series: \(seriesUID)\n"
        summary += "Instance: \(instanceUID)\n\n"
        
        summary += "Measurements (\(tools.count) total):\n"
        for (index, tool) in tools.enumerated() {
            summary += "\(index + 1). \(tool.name)\n"
            if let measurement = tool.measurement {
                summary += "   \(measurement.description)\n"
            }
            if let stats = tool.statistics {
                summary += "   \(stats.displayText)\n"
            }
            summary += "\n"
        }
        
        return summary
    }
}

// MARK: - Helper Extensions
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension ClinicalComplianceManager {
    func logUserAction(_ action: String, details: [String: Any]) {
        // Implementation would go here for audit logging
        print("🔍 Audit: \(action) - \(details)")
    }
}