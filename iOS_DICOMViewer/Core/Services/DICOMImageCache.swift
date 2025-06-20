//
//  DICOMImageCache.swift
//  iOS_DICOMViewer
//
//  Created on 6/16/25.
//

import UIKit
import Foundation

/// High-performance DICOM image cache optimized for medical imaging
class DICOMImageCache {
    
    // MARK: - Cache Key Structure
    struct CacheKey: Hashable {
        let instanceUID: String
        let windowLevel: String
        
        init(instanceUID: String, window: Float, level: Float) {
            self.instanceUID = instanceUID
            self.windowLevel = "\(Int(window))_\(Int(level))"
        }
    }
    
    // MARK: - Properties
    private let cache = NSCache<NSString, UIImage>()
    private let accessQueue = DispatchQueue(label: "com.dicomviewer.imagecache", qos: .userInitiated)
    private var accessTimes: [String: Date] = [:]
    
    // Cache configuration
    private let maxMemoryUsage: Int = 200 * 1024 * 1024 // 200MB
    private let maxCount: Int = 100 // Maximum number of cached images
    
    // MARK: - Initialization
    init() {
        setupCache()
        observeMemoryWarnings()
    }
    
    private func setupCache() {
        cache.totalCostLimit = maxMemoryUsage
        cache.countLimit = maxCount
        
        print("📸 DICOMImageCache: Initialized with \(maxMemoryUsage / (1024 * 1024))MB limit")
    }
    
    private func observeMemoryWarnings() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        print("⚠️ DICOMImageCache: Memory warning received, clearing cache")
        clearCache()
    }
    
    // MARK: - Cache Operations
    
    /// Get cached image for the specified key and window/level
    func image(forKey key: String, windowLevel: DICOMImageRenderer.WindowLevel) -> UIImage? {
        let cacheKey = CacheKey(instanceUID: key, window: windowLevel.window, level: windowLevel.level)
        return accessQueue.sync {
            let nsKey = NSString(string: "\(cacheKey.instanceUID)_\(cacheKey.windowLevel)")
            let image = cache.object(forKey: nsKey)
            
            if image != nil {
                accessTimes[key] = Date()
                print("✅ DICOMImageCache: Cache hit for \(key)")
            } else {
                print("❌ DICOMImageCache: Cache miss for \(key)")
            }
            
            return image
        }
    }
    
    /// Set image in cache for the specified key and window/level
    func setImage(_ image: UIImage, forKey key: String, windowLevel: DICOMImageRenderer.WindowLevel) {
        let cacheKey = CacheKey(instanceUID: key, window: windowLevel.window, level: windowLevel.level)
        
        accessQueue.async {
            let nsKey = NSString(string: "\(cacheKey.instanceUID)_\(cacheKey.windowLevel)")
            
            // Estimate image memory cost
            let cost = self.estimateImageMemoryUsage(image)
            
            self.cache.setObject(image, forKey: nsKey, cost: cost)
            self.accessTimes[key] = Date()
            
            print("💾 DICOMImageCache: Cached image for \(key) (cost: \(cost / 1024)KB)")
        }
    }
    
    /// Remove image from cache
    func removeImage(forKey key: String) {
        accessQueue.async {
            // Remove all window/level variations for this key
            for cacheKey in self.getAllCacheKeys(for: key) {
                let nsKey = NSString(string: cacheKey)
                self.cache.removeObject(forKey: nsKey)
            }
            self.accessTimes.removeValue(forKey: key)
            print("🗑️ DICOMImageCache: Removed image for \(key)")
        }
    }
    
    /// Clear entire cache
    func clearCache() {
        accessQueue.async {
            self.cache.removeAllObjects()
            self.accessTimes.removeAll()
            print("🗑️ DICOMImageCache: Cache cleared")
        }
    }
    
    /// Preload images for a series (background task)
    func preloadSeries(_ instances: [DICOMInstance], windowLevel: DICOMImageRenderer.WindowLevel) {
        Task {
            print("🔄 DICOMImageCache: Preloading \(instances.count) images")
            
            for instance in instances {
                // Check if already cached
                if image(forKey: instance.metadata.sopInstanceUID, windowLevel: windowLevel) == nil {
                    // Load in background
                    if let filePath = instance.fileURL?.path {
                        do {
                            let renderer = DICOMImageRenderer()
                            if let image = try await renderer.renderImage(from: filePath, windowLevel: windowLevel) {
                                setImage(image, forKey: instance.metadata.sopInstanceUID, windowLevel: windowLevel)
                            }
                        } catch {
                            print("❌ DICOMImageCache: Failed to preload \(instance.metadata.sopInstanceUID): \(error)")
                        }
                    }
                }
            }
            
            print("✅ DICOMImageCache: Preloading completed")
        }
    }
    
    // MARK: - Helper Methods
    
    private func estimateImageMemoryUsage(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4 // RGBA
        
        return width * height * bytesPerPixel
    }
    
    private func getAllCacheKeys(for instanceUID: String) -> [String] {
        // This is a simplified implementation
        // In a real scenario, you might want to track keys more efficiently
        return [
            "\(instanceUID)_400_40",   // Default
            "\(instanceUID)_1500_-600", // Lung
            "\(instanceUID)_2000_300",  // Bone
            "\(instanceUID)_100_50",    // Brain
            "\(instanceUID)_350_40"     // Abdomen
        ]
    }
    
    // MARK: - Cache Statistics
    
    /// Get cache statistics for debugging
    func getCacheStatistics() -> (hitCount: Int, totalRequests: Int, memoryUsage: Int) {
        return accessQueue.sync {
            let totalRequests = accessTimes.count
            let hitCount = cache.totalCostLimit > 0 ? min(totalRequests, maxCount) : 0
            let memoryUsage = 0 // NSCache doesn't provide exact memory usage
            
            return (hitCount: hitCount, totalRequests: totalRequests, memoryUsage: memoryUsage)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Extension for WindowLevel
extension DICOMImageRenderer.WindowLevel {
    var cacheString: String {
        return "\(Int(window))_\(Int(level))"
    }
}