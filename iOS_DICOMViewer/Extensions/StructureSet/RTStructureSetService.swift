//
//  RTStructureSetService.swift
//  iOS_DICOMViewer
//
//  RT Structure Set support for radiotherapy planning
//  Handles DICOM RT Structure Set files and ROI visualization
//

import Foundation
import UIKit
import simd

final class RTStructureSetService: DICOMServiceProtocol {
    let identifier = "RTStructureSetService"
    
    private let metadataStore: DICOMMetadataStore
    private var structureSets: [String: RTStructureSet] = [:]
    
    init(metadataStore: DICOMMetadataStore) {
        self.metadataStore = metadataStore
    }
    
    func initialize() async throws {
        // Initialize RT structure set handling
    }
    
    func shutdown() async {
        // Cleanup
    }
    
    func loadRTStructureSet(from url: URL) async throws -> RTStructureSet {
        // Parse RT Structure Set
        let parser = DICOMParser.shared
        guard await parser.detectFileType(url) == .rtStructureSet else {
            throw DICOMError.unsupportedFormat(format: "Expected RT Structure Set file")
        }
        
        // Parse structure set data
        let structureData = try await parseRTStructureData(from: url)
        
        let structureSet = RTStructureSet(
            structureSetUID: structureData.uid,
            structures: structureData.structures
        )
        
        structureSets[structureSet.structureSetUID] = structureSet
        
        return structureSet
    }
    
    func createStructureOverlay(for instance: DICOMInstance,
                               structureSet: RTStructureSet) -> CALayer? {
        
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(x: 0, y: 0,
                                   width: instance.metadata.columns,
                                   height: instance.metadata.rows)
        
        // Find contours for this slice
        for structure in structureSet.structures {
            if let contour = structure.findContour(for: instance) {
                let contourLayer = createContourLayer(contour, color: structure.color)
                overlayLayer.addSublayer(contourLayer)
            }
        }
        
        return overlayLayer
    }
    
    private func createContourLayer(_ contour: RTContour, color: UIColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        
        let path = UIBezierPath()
        if let first = contour.points.first {
            path.move(to: CGPoint(x: first.x, y: first.y))
            
            for point in contour.points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            
            path.close()
        }
        
        layer.path = path.cgPath
        layer.strokeColor = color.cgColor
        layer.fillColor = color.withAlphaComponent(0.2).cgColor
        layer.lineWidth = 2.0
        
        return layer
    }
    
    // MARK: - Private Methods
    
    private func parseRTStructureData(from url: URL) async throws -> RTStructureData {
        // This would parse DICOM RT Structure Set specific tags and data
        // For now, return placeholder data
        return RTStructureData(
            uid: UUID().uuidString,
            structures: []
        )
    }
}

// MARK: - Supporting Types

struct RTStructureData {
    let uid: String
    let structures: [RTStructure]
}

// RT Structure Set models
struct RTStructureSet {
    let structureSetUID: String
    let structures: [RTStructure]
}

struct RTStructure {
    let roiNumber: Int
    let roiName: String
    let color: UIColor
    let contours: [RTContour]
    
    func findContour(for instance: DICOMInstance) -> RTContour? {
        // Find contour that matches the instance's image position
        guard let imagePosition = instance.metadata.imagePositionPatient,
              imagePosition.count >= 3 else {
            return nil
        }
        
        let instanceZ = imagePosition[2]
        
        return contours.first { contour in
            abs(contour.referencedZ - instanceZ) < 0.5 // 0.5mm tolerance
        }
    }
}

struct RTContour {
    let points: [simd_float3]
    let referencedSOPInstanceUID: String?
    let referencedZ: Double
}

// Extensions for file type detection
extension DICOMFileType {
    static var rtStructureSet: DICOMFileType { .structureSet }
}
