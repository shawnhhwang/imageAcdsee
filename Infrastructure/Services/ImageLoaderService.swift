import Foundation
import ImageIO
import AppKit

public final class ImageLoaderService: Sendable {
    public static let shared = ImageLoaderService()
    
    // Limit thumbnail generation to 4 concurrent tasks to keep CPU and disk IO responsive.
    private let thumbnailLimiter = ConcurrencyLimiter(maxConcurrency: 4)
    // Limit EXIF extraction to 4 concurrent tasks to avoid disk I/O and thread pool overload.
    private let metadataLimiter = ConcurrencyLimiter(maxConcurrency: 4)
    
    private init() {}
    
    /// Generates a thumbnail for a given image URL using ImageIO
    /// - Parameters:
    ///   - url: The image file URL
    ///   - maxPixelSize: The target pixel size (width/height) of the thumbnail
    /// - Returns: A CGImage representing the thumbnail
    public func loadThumbnail(from url: URL, maxPixelSize: Int = 256) async throws -> CGImage {
        await thumbnailLimiter.enter()
        do {
            let thumbnail = try await Task.detached(priority: .userInitiated) {
                return try SecurityScopedBookmarkManager.shared.performAccessingSecurityScopedResource(at: url) {
                    let options: [CFString: Any] = [
                        kCGImageSourceShouldCache: false,
                        kCGImageSourceShouldAllowFloat: true
                    ]
                    
                    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
                        throw NSError(domain: "ImageLoaderService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image source for \(url.path)"])
                    }
                    
                    let thumbnailOptions: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceShouldCacheImmediately: true
                    ]
                    
                    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary) else {
                        throw NSError(domain: "ImageLoaderService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to generate thumbnail at index 0 for \(url.path)"])
                    }
                    
                    return thumbnail
                }
            }.value
            await thumbnailLimiter.exit()
            return thumbnail
        } catch {
            await thumbnailLimiter.exit()
            throw error
        }
    }
    
    public func extractMetadata(from url: URL, creationDate: Date? = nil, sizeBytes: Int64 = 0) async throws -> ImageMetadata {
        await metadataLimiter.enter()
        do {
            let metadata = try await Task.detached(priority: .userInitiated) {
                return try SecurityScopedBookmarkManager.shared.performAccessingSecurityScopedResource(at: url) {
                    let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
                    
                    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
                        throw NSError(domain: "ImageLoaderService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image source for \(url.path)"])
                    }
                    
                    let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] ?? [:]
                    
                    // Get basic dimensions
                    let width = properties[kCGImagePropertyPixelWidth] as? Int
                    let height = properties[kCGImagePropertyPixelHeight] as? Int
                    
                    // Parse EXIF dictionary
                    let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
                    let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
                    
                    let cameraMake = tiff[kCGImagePropertyTIFFMake] as? String
                    let cameraModel = tiff[kCGImagePropertyTIFFModel] as? String
                    
                    let isoArray = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int]
                    let iso = isoArray?.first ?? (exif[kCGImagePropertyExifISOSpeedRatings] as? Int)
                    
                    let aperture = exif[kCGImagePropertyExifFNumber] as? Double
                    let shutterSpeed = exif[kCGImagePropertyExifExposureTime] as? Double
                    
                    let id = url.path
                    let filename = url.lastPathComponent
                    
                    return ImageMetadata(
                        id: id,
                        url: url,
                        filename: filename,
                        creationDate: creationDate,
                        sizeBytes: sizeBytes,
                        width: width,
                        height: height,
                        cameraMake: cameraMake,
                        cameraModel: cameraModel,
                        iso: iso,
                        aperture: aperture,
                        shutterSpeed: shutterSpeed,
                        hasThumbnail: true
                    )
                }
            }.value
            await metadataLimiter.exit()
            return metadata
        } catch {
            await metadataLimiter.exit()
            throw error
        }
    }
    
    /// High-performance luminance histogram calculation on a CGImage
    public func calculateLuminanceHistogram(for cgImage: CGImage) -> [Float] {
        let width = cgImage.width
        let height = cgImage.height
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return Array(repeating: 0.0, count: 256)
        }
        
        var bins = Array(repeating: 0, count: 256)
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        // Sample every 2nd pixel in both directions for maximum speed (<0.5ms)
        for y in stride(from: 0, to: height, by: 2) {
            let rowOffset = y * bytesPerRow
            for x in stride(from: 0, to: width, by: 2) {
                let pixelOffset = rowOffset + x * bytesPerPixel
                
                let r = ptr[pixelOffset]
                let g = ptr[pixelOffset + 1]
                let b = ptr[pixelOffset + 2]
                
                // Standard Luminosity Formula: Y = 0.299R + 0.587G + 0.114B
                let luminance = Int(0.299 * Float(r) + 0.587 * Float(g) + 0.114 * Float(b))
                let clamped = max(0, min(255, luminance))
                bins[clamped] += 1
            }
        }
        
        let maxBin = Float(bins.max() ?? 1)
        return bins.map { Float($0) / maxBin }
    }
}

/// Actor to limit the maximum number of concurrent asynchronous operations.
/// Safe, lightweight, and prevents thrashed cooperative thread pool in Swift concurrency.
public actor ConcurrencyLimiter: Sendable {
    private let maxConcurrency: Int
    private var activeCount = 0
    private var suspensions: [CheckedContinuation<Void, Never>] = []
    
    public init(maxConcurrency: Int) {
        self.maxConcurrency = maxConcurrency
    }
    
    public func enter() async {
        if activeCount < maxConcurrency {
            activeCount += 1
        } else {
            await withCheckedContinuation { continuation in
                suspensions.append(continuation)
            }
        }
    }
    
    public func exit() {
        if let next = suspensions.first {
            suspensions.removeFirst()
            next.resume()
        } else {
            activeCount -= 1
        }
    }
}
