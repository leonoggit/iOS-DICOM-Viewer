import Foundation
import Combine
import UIKit

final class DICOMCacheManager {
    static let shared = DICOMCacheManager()

    private let memoryCache: NSCache<NSString, CachedDICOMData>
    private let diskCache: DiskCache
    private let cacheQueue = DispatchQueue(label: "dicom.cache", attributes: .concurrent)

    // Memory pressure monitoring
    private var memoryPressureObservation: NSObjectProtocol?
    private let memoryWarningPublisher = PassthroughSubject<Void, Never>()

    private init() {
        memoryCache = NSCache<NSString, CachedDICOMData>()
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 200 * 1024 * 1024 // 200MB

        diskCache = DiskCache(maxSize: 2 * 1024 * 1024 * 1024) // 2GB

        setupMemoryPressureHandling()
    }

    private func setupMemoryPressureHandling() {
        // Monitor memory pressure
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)

        source.setEventHandler { [weak self] in
            let event = source.data

            if event.contains(.warning) {
                self?.handleMemoryWarning()
            } else if event.contains(.critical) {
                self?.handleMemoryCritical()
            }
        }

        source.resume()

        // Also monitor UIApplication memory warnings
        memoryPressureObservation = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func handleMemoryWarning() {
        memoryWarningPublisher.send()

        // Reduce cache by 50%
        let currentLimit = memoryCache.totalCostLimit
        memoryCache.totalCostLimit = currentLimit / 2

        // Schedule restoration
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.memoryCache.totalCostLimit = currentLimit
        }
    }

    private func handleMemoryCritical() {
        // Clear all memory cache
        memoryCache.removeAllObjects()
    }

    func store(_ data: CachedDICOMData, for key: String) async {
        let cacheKey = key as NSString

        // Store in memory cache
        await cacheQueue.async(flags: .barrier) {
            self.memoryCache.setObject(data, forKey: cacheKey, cost: data.estimatedMemorySize)
        }

        // Store in disk cache asynchronously
        Task.detached(priority: .background) {
            await self.diskCache.store(data, for: key)
        }
    }

    func retrieve(for key: String) async -> CachedDICOMData? {
        let cacheKey = key as NSString

        // Check memory cache first
        if let cached = await cacheQueue.sync(execute: { memoryCache.object(forKey: cacheKey) }) {
            return cached
        }

        // Check disk cache
        if let diskCached = await diskCache.retrieve(for: key) {
            // Promote to memory cache
            await cacheQueue.async(flags: .barrier) {
                self.memoryCache.setObject(diskCached, forKey: cacheKey, cost: diskCached.estimatedMemorySize)
            }
            return diskCached
        }

        return nil
    }
}

// Disk cache implementation
final class DiskCache {
    private let cacheDirectory: URL
    private let maxSize: Int64
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "dicom.diskcache.io", attributes: .concurrent)

    init(maxSize: Int64) {
        self.maxSize = maxSize

        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent("DICOMCache")

        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func store(_ data: CachedDICOMData, for key: String) async {
        let fileURL = cacheDirectory.appendingPathComponent(key.data(using: .utf8)!.base64EncodedString())

        await withCheckedContinuation { continuation in
            ioQueue.async(flags: .barrier) {
                do {
                    let encoded = try JSONEncoder().encode(data)
                    try encoded.write(to: fileURL)
                    continuation.resume()
                } catch {
                    print("Failed to write to disk cache: \(error)")
                    continuation.resume()
                }
            }
        }

        // Manage cache size
        await enforceMaxSize()
    }

    func retrieve(for key: String) async -> CachedDICOMData? {
        let fileURL = cacheDirectory.appendingPathComponent(key.data(using: .utf8)!.base64EncodedString())

        return await withCheckedContinuation { continuation in
            ioQueue.async {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoded = try JSONDecoder().decode(CachedDICOMData.self, from: data)
                    continuation.resume(returning: decoded)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func enforceMaxSize() async {
        // Get all cached files with their attributes
        guard let enumerator = fileManager.enumerator(at: cacheDirectory,
                                                     includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey]) else { return }

        var fileInfos: [(url: URL, size: Int64, accessDate: Date)] = []
        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey])
                if let fileSize = resourceValues.fileSize,
                   let accessDate = resourceValues.contentAccessDate {
                    fileInfos.append((fileURL, Int64(fileSize), accessDate))
                    totalSize += Int64(fileSize)
                }
            } catch {
                continue
            }
        }

        // If under limit, nothing to do
        guard totalSize > maxSize else { return }

        // Sort by access date (LRU)
        fileInfos.sort { $0.accessDate < $1.accessDate }

        // Delete oldest files until under limit
        for fileInfo in fileInfos {
            try? fileManager.removeItem(at: fileInfo.url)
            totalSize -= fileInfo.size
            if totalSize <= maxSize { break }
        }
    }
}

struct CachedDICOMData: Codable {
    let metadata: DICOMMetadata
    let renderedImage: Data?
    let pixelData: Data?
    let windowLevel: DICOMImageRenderer.WindowLevel
    let timestamp: Date

    var estimatedMemorySize: Int {
        return (renderedImage?.count ?? 0) + (pixelData?.count ?? 0)
    }
}
