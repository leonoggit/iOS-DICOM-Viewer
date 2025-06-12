import Foundation

/// DICOM Instance model - represents a single DICOM image/file
/// Inspired by OHIF's instance organization
class DICOMInstance {
    let metadata: DICOMMetadata
    let fileURL: URL?
    private(set) var pixelData: Data?
    private(set) var isLoaded: Bool = false
    private(set) var loadError: Error?
    
    // Frame data for multi-frame instances
    private var frameCache: [Int: Data] = [:]
    
    init(metadata: DICOMMetadata, fileURL: URL? = nil) {
        self.metadata = metadata
        self.fileURL = fileURL
    }
    
    /// Load pixel data asynchronously
    func loadPixelData() async throws {
        guard let fileURL = fileURL else {
            throw DICOMError.invalidFile
        }
        
        do {
            self.pixelData = try await DICOMParser.shared.parsePixelData(from: fileURL)
            self.isLoaded = true
            self.loadError = nil
        } catch {
            self.loadError = error
            throw error
        }
    }
    
    /// Get frame data for multi-frame instances
    func getFrameData(at frameIndex: Int) -> Data? {
        guard metadata.isMultiFrame else {
            return pixelData
        }
        
        if let cachedFrame = frameCache[frameIndex] {
            return cachedFrame
        }
        
        guard let pixelData = pixelData else { return nil }
        
        let frameSize = metadata.rows * metadata.columns * (metadata.bitsAllocated / 8)
        let offset = frameIndex * frameSize
        
        guard offset + frameSize <= pixelData.count else { return nil }
        
        let frameData = pixelData.subdata(in: offset..<(offset + frameSize))
        frameCache[frameIndex] = frameData
        
        return frameData
    }
    
    /// Get total number of frames
    var frameCount: Int {
        return metadata.numberOfFrames ?? 1
    }
    
    /// Check if this instance can be rendered
    var isRenderable: Bool {
        return isLoaded && pixelData != nil && loadError == nil
    }
    
    /// Get image dimensions
    var imageDimensions: (width: Int, height: Int) {
        return (metadata.columns, metadata.rows)
    }
    
    /// Get pixel spacing if available
    var pixelSpacing: (x: Double, y: Double)? {
        guard let spacing = metadata.pixelSpacing, spacing.count >= 2 else { return nil }
        return (spacing[0], spacing[1])
    }
    
    /// File path for compatibility with image renderer
    var filePath: String? {
        return fileURL?.path
    }
    
    /// SOP Instance UID for identification
    var sopInstanceUID: String {
        return metadata.sopInstanceUID
    }
}


// MARK: - Identifiable
extension DICOMInstance: Identifiable {
    var id: String {
        return metadata.sopInstanceUID
    }
}

// MARK: - CustomStringConvertible
extension DICOMInstance: CustomStringConvertible {
    var description: String {
        return "DICOMInstance(SOP: \(metadata.sopInstanceUID), Series: \(metadata.seriesInstanceUID), Study: \(metadata.studyInstanceUID))"
    }
}
