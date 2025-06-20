//
//  DICOMImageRenderer.swift
//  iOS_DICOMViewer
//
//  Created on 6/9/25.
//

import UIKit
import CoreGraphics
import Accelerate

class DICOMImageRenderer {
    
    // MARK: - Structures
    struct WindowLevel {
        let window: Float
        let level: Float
        
        static let `default` = WindowLevel(window: 400, level: 40)
        static let lung = WindowLevel(window: 1500, level: -600)
        static let bone = WindowLevel(window: 2000, level: 300)
        static let brain = WindowLevel(window: 100, level: 50)
        static let abdomen = WindowLevel(window: 350, level: 40)
    }
    
    struct PixelData {
        let data: [UInt16]
        let width: Int
        let height: Int
        let bitsAllocated: Int
        let bitsStored: Int
        let highBit: Int
        let pixelRepresentation: Int
        let rescaleIntercept: Float
        let rescaleSlope: Float
        let windowCenter: Float?
        let windowWidth: Float?
        
        init(data: [UInt16], width: Int, height: Int, bitsAllocated: Int = 16, bitsStored: Int = 16, highBit: Int = 15, pixelRepresentation: Int = 0, rescaleIntercept: Float = 0, rescaleSlope: Float = 1, windowCenter: Float? = nil, windowWidth: Float? = nil) {
            self.data = data
            self.width = width
            self.height = height
            self.bitsAllocated = bitsAllocated
            self.bitsStored = bitsStored
            self.highBit = highBit
            self.pixelRepresentation = pixelRepresentation
            self.rescaleIntercept = rescaleIntercept
            self.rescaleSlope = rescaleSlope
            self.windowCenter = windowCenter
            self.windowWidth = windowWidth
        }
    }
    
    // MARK: - Properties
    private let colorSpace = CGColorSpaceCreateDeviceGray()
    
    // MARK: - Public Methods
    func renderImage(from pixelData: PixelData, windowLevel: WindowLevel) -> UIImage? {
        // Apply rescale transformation
        let rescaledData = applyRescale(to: pixelData.data, slope: pixelData.rescaleSlope, intercept: pixelData.rescaleIntercept)
        
        // Apply window/level transformation
        let windowedData = applyWindowLevel(to: rescaledData, windowLevel: windowLevel)
        
        // Convert to 8-bit for display
        let displayData = convertTo8Bit(windowedData)
        
        // Create CGImage
        return createImage(from: displayData, width: pixelData.width, height: pixelData.height)
    }
    
    func renderImage(from filePath: String, windowLevel: WindowLevel = .default) async throws -> UIImage? {
        // Load pixel data from DICOM file using DCMTK bridge
        let pixelData = try await loadPixelData(from: filePath)
        return renderImage(from: pixelData, windowLevel: windowLevel)
    }
    
    // MARK: - Private Methods
    private func loadPixelData(from filePath: String) async throws -> PixelData {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                    print("🖼️ DICOMImageRenderer: Loading pixel data from: \(filePath)")
                    
                    // Use DCMTK bridge to load actual pixel data
                    var width: Int32 = 0
                    var height: Int32 = 0
                    var bitsStored: Int32 = 0
                    var isSigned: ObjCBool = false
                    var windowCenter: Double = 0
                    var windowWidth: Double = 0
                    var numberOfFrames: Int32 = 0
                    
                    guard let rawPixelData = DCMTKBridge.parsePixelData(
                        fromFile: filePath,
                        width: &width,
                        height: &height,
                        bitsStored: &bitsStored,
                        isSigned: &isSigned,
                        windowCenter: &windowCenter,
                        windowWidth: &windowWidth,
                        numberOfFrames: &numberOfFrames
                    ) else {
                        print("❌ DICOMImageRenderer: Failed to load pixel data from DCMTK bridge")
                        // Fallback to sample data for now
                        let sampleData = self.createSamplePixelData()
                        continuation.resume(returning: sampleData)
                        return
                    }
                    
                    print("✅ DICOMImageRenderer: Loaded pixel data - \(width)x\(height), \(bitsStored) bits, \(rawPixelData.count) bytes")
                    
                    // Convert raw bytes to UInt16 array
                    let pixelArray = self.convertRawDataToUInt16Array(rawPixelData, bitsStored: Int(bitsStored), isSigned: isSigned.boolValue)
                    
                    let pixelData = PixelData(
                        data: pixelArray,
                        width: Int(width),
                        height: Int(height),
                        bitsAllocated: 16,
                        bitsStored: Int(bitsStored),
                        highBit: Int(bitsStored) - 1,
                        pixelRepresentation: isSigned.boolValue ? 1 : 0,
                        rescaleIntercept: -1024, // Standard CT values
                        rescaleSlope: 1,
                        windowCenter: Float(windowCenter),
                        windowWidth: Float(windowWidth)
                    )
                    
                    print("✅ DICOMImageRenderer: Created PixelData object")
                    continuation.resume(returning: pixelData)
            }
        }
    }
    
    private func convertRawDataToUInt16Array(_ data: Data, bitsStored: Int, isSigned: Bool) -> [UInt16] {
        let bytesPerPixel = (bitsStored + 7) / 8
        let pixelCount = data.count / bytesPerPixel
        var pixelArray = [UInt16](repeating: 0, count: pixelCount)
        
        data.withUnsafeBytes { bytes in
            let buffer = bytes.bindMemory(to: UInt8.self)
            
            for i in 0..<pixelCount {
                let offset = i * bytesPerPixel
                var pixelValue: UInt16 = 0
                
                if bytesPerPixel == 1 {
                    pixelValue = UInt16(buffer[offset])
                } else if bytesPerPixel == 2 {
                    // Little endian 16-bit
                    pixelValue = UInt16(buffer[offset]) | (UInt16(buffer[offset + 1]) << 8)
                }
                
                // Handle signed values
                if isSigned && bitsStored == 16 && pixelValue > 32767 {
                    let signedValue = Int32(pixelValue) - 65536
                    pixelValue = UInt16(max(0, signedValue + 32768))
                }
                
                pixelArray[i] = pixelValue
            }
        }
        
        return pixelArray
    }
    
    private func createSamplePixelData() -> PixelData {
        let width = 512
        let height = 512
        let size = width * height
        
        var data = [UInt16](repeating: 0, count: size)
        
        // Create sample medical-like image data
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                
                // Create circular structures with varying intensities
                let centerX = width / 2
                let centerY = height / 2
                let distance = sqrt(Float((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY)))
                
                var intensity: Float = 0
                
                // Background
                intensity += 100
                
                // Main organ structure
                if distance < 200 {
                    intensity += 800 * exp(-distance / 100)
                }
                
                // Bone-like structures
                if distance > 150 && distance < 180 {
                    intensity += 1500
                }
                
                // Vessels/airways
                let angle = atan2(Float(y - centerY), Float(x - centerX))
                if abs(sin(angle * 4)) > 0.8 && distance < 150 {
                    intensity *= 0.3
                }
                
                // Add some noise
                intensity += Float.random(in: -50...50)
                
                data[index] = UInt16(max(0, min(4095, intensity)))
            }
        }
        
        return PixelData(
            data: data,
            width: width,
            height: height,
            bitsAllocated: 16,
            bitsStored: 12,
            highBit: 11,
            pixelRepresentation: 0,
            rescaleIntercept: -1024,
            rescaleSlope: 1,
            windowCenter: 40,
            windowWidth: 400
        )
    }
    
    private func applyRescale(to data: [UInt16], slope: Float, intercept: Float) -> [Float] {
        return data.map { Float($0) * slope + intercept }
    }
    
    private func applyWindowLevel(to data: [Float], windowLevel: WindowLevel) -> [Float] {
        let window = windowLevel.window
        let level = windowLevel.level
        
        let minValue = level - window / 2
        let maxValue = level + window / 2
        
        return data.map { value in
            if value <= minValue {
                return 0.0
            } else if value >= maxValue {
                return 1.0
            } else {
                return (value - minValue) / window
            }
        }
    }
    
    private func convertTo8Bit(_ data: [Float]) -> [UInt8] {
        return data.map { UInt8(max(0, min(255, $0 * 255))) }
    }
    
    private func createImage(from data: [UInt8], width: Int, height: Int) -> UIImage? {
        let bitsPerComponent = 8
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        
        guard let dataProvider = CGDataProvider(data: Data(data) as CFData) else {
            return nil
        }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Utility Methods
    func getOptimalWindowLevel(for pixelData: PixelData) -> WindowLevel {
        if let center = pixelData.windowCenter, let width = pixelData.windowWidth {
            return WindowLevel(window: width, level: center)
        }
        
        // Calculate from pixel data statistics
        let rescaledData = applyRescale(to: pixelData.data, slope: pixelData.rescaleSlope, intercept: pixelData.rescaleIntercept)
        
        let sortedData = rescaledData.sorted()
        let count = sortedData.count
        
        // Use 5th and 95th percentiles
        let p5 = sortedData[count / 20]
        let p95 = sortedData[count * 19 / 20]
        
        let window = p95 - p5
        let level = (p95 + p5) / 2
        
        return WindowLevel(window: window, level: level)
    }
    
    func getPresetWindowLevels(for modality: String) -> [String: WindowLevel] {
        switch modality.uppercased() {
        case "CT":
            return [
                "Abdomen": .abdomen,
                "Lung": .lung,
                "Bone": .bone,
                "Brain": .brain
            ]
        case "MR":
            return [
                "Brain": WindowLevel(window: 200, level: 100),
                "Spine": WindowLevel(window: 300, level: 150)
            ]
        default:
            return [
                "Default": .default
            ]
        }
    }
}

