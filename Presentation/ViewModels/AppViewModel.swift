import Foundation
import SwiftUI
import CoreGraphics
import AppKit

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var selectedFolder: URL?
    @Published public var subfolders: [FolderNode] = []
    @Published public var images: [ImageItem] = []
    @Published public var displayedImages: [ImageItem] = []
    
    @Published public var filterRating: Int = 0
    @Published public var filterTaggedOnly: Bool = false
    
    @Published public var selectedImageIndex: Int?
    @Published public var isDetailActive: Bool = false
    
    @Published public var thumbnails: [String: CGImage] = [:]
    @Published public var exifMetadata: [String: ImageMetadata] = [:]
    @Published public var isLoading: Bool = false
    @Published public var isZoomed: Bool = false
    @Published public var activeHistogram: [Float] = []
    
    private let fileSystemRepo = FileSystemRepository()
    private let directoryMonitor = DirectoryMonitor()
    
    private var db: SQLiteDatabase?
    private var exifRepo: ExifCacheRepository?
    private var keyboardObserver: Any?
    private var loadGeneration = 0
    
    public init() {
        setupDatabase()
        setupDirectoryMonitor()
        loadInitialBookmarks()
        setupKeyboardNotificationObserver()
    }
    
    private func setupDatabase() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let dbDir = appSupport.appendingPathComponent("ProjectLumina", isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            let dbURL = dbDir.appendingPathComponent("metadata_cache.db")
            let database = try SQLiteDatabase(dbPath: dbURL.path)
            self.db = database
            self.exifRepo = ExifCacheRepository(database: database)
            LoggerManager.shared.log("SQLite Database initialized at \(dbURL.path)", level: .info)
        } catch {
            LoggerManager.shared.log("Failed to setup SQLite database: \(error.localizedDescription)", level: .error)
        }
    }
    
    private func setupDirectoryMonitor() {
        Task {
            for await _ in directoryMonitor.events {
                LoggerManager.shared.log("Directory change detected by monitor, reloading contents...", level: .info)
                self.refreshFolderContents()
            }
        }
    }
    
    private func loadInitialBookmarks() {
        let bookmarks = SecurityScopedBookmarkManager.shared.loadSavedBookmarks()
        if let first = bookmarks.first {
            selectFolder(first)
        }
    }
    
    public func selectFolder(_ url: URL) {
        selectedFolder = url
        SecurityScopedBookmarkManager.shared.saveBookmark(for: url)
        
        // Start watching the directory
        directoryMonitor.startMonitoring(url: url)
        
        // Load initial contents
        refreshFolderContents()
    }
    
    public func refreshFolderContents() {
        guard let url = selectedFolder else { return }
        isLoading = true
        loadGeneration += 1
        let currentGen = loadGeneration
        
        Task {
            do {
                let folders = try await fileSystemRepo.loadSubfolders(of: url)
                let loadedImages = try await fileSystemRepo.loadImages(of: url)
                
                self.subfolders = folders
                self.images = loadedImages
                self.updateDisplayedImages()
                self.isLoading = false
                
                // Clear selection if index is out of bounds
                if let index = selectedImageIndex, index >= self.displayedImages.count {
                    selectedImageIndex = nil
                }
                
                // Begin background loading of thumbnails and EXIF metadata
                loadThumbnailsAndMetadata(for: loadedImages, generation: currentGen)
            } catch {
                LoggerManager.shared.log("Failed to load folder contents: \(error.localizedDescription)", level: .error)
                self.isLoading = false
            }
        }
    }
    
    public func updateDisplayedImages() {
        displayedImages = images.filter { item in
            let key = item.url.path
            let metadata = exifMetadata[key]
            
            if filterRating > 0 {
                let rating = metadata?.rating ?? 0
                if rating < filterRating {
                    return false
                }
            }
            
            if filterTaggedOnly {
                let isTagged = metadata?.isTagged ?? false
                if !isTagged {
                    return false
                }
            }
            
            return true
        }
        
        // Keep selection in bounds
        if let index = selectedImageIndex {
            if index >= displayedImages.count {
                selectedImageIndex = displayedImages.isEmpty ? nil : displayedImages.count - 1
            }
        }
    }
    
    private func loadThumbnailsAndMetadata(for items: [ImageItem], generation: Int) {
        // 1. Batch load cached EXIF metadata from SQLite database in a single background task
        Task {
            if let repo = exifRepo {
                var loadedMetadata: [String: ImageMetadata] = [:]
                for item in items {
                    if Task.isCancelled || self.loadGeneration != generation { return }
                    let key = item.url.path
                    if self.exifMetadata[key] == nil {
                        if let cachedExif = try? await repo.getMetadata(for: key) {
                            loadedMetadata[key] = cachedExif
                        }
                    }
                }
                
                if Task.isCancelled || self.loadGeneration != generation { return }
                
                if !loadedMetadata.isEmpty {
                    // Update in a single batch on the main actor
                    for (key, metadata) in loadedMetadata {
                        self.exifMetadata[key] = metadata
                    }
                    self.updateDisplayedImages()
                }
            }
            
            let localRepo = self.exifRepo
            
            // 2. Process items using a TaskGroup for fully managed parallel execution
            await withTaskGroup(of: Void.self) { group in
                for item in items {
                    let key = item.url.path
                    let filename = item.filename
                    let url = item.url
                    
                    // A. Process Thumbnail
                    if self.thumbnails[key] == nil {
                        group.addTask {
                            if Task.isCancelled { return }
                            let isOldGeneration = await MainActor.run { self.loadGeneration != generation }
                            if isOldGeneration { return }
                            
                            if let cachedImage = await MemoryCache.shared.get(forKey: key) {
                                await MainActor.run {
                                    if self.loadGeneration == generation {
                                        self.thumbnails[key] = cachedImage
                                    }
                                }
                                return
                            }
                            
                            do {
                                let thumbnailSize = AppSettings.shared.rendering.thumbnailSize.width
                                let thumbnail = try await ImageLoaderService.shared.loadThumbnail(from: url, maxPixelSize: thumbnailSize)
                                await MemoryCache.shared.set(thumbnail, forKey: key)
                                
                                await MainActor.run {
                                    if self.loadGeneration == generation {
                                        self.thumbnails[key] = thumbnail
                                    }
                                }
                            } catch {
                                LoggerManager.shared.log("Failed to load thumbnail for \(filename): \(error.localizedDescription)", level: .debug)
                            }
                        }
                    }
                    
                    // B. Process non-cached EXIF Metadata (requires ImageIO parsing)
                    if self.exifMetadata[key] == nil {
                        group.addTask {
                            if Task.isCancelled { return }
                            let isOldGeneration = await MainActor.run { self.loadGeneration != generation }
                            if isOldGeneration { return }
                            
                            do {
                                let exif = try await ImageLoaderService.shared.extractMetadata(
                                    from: url,
                                    creationDate: item.creationDate,
                                    sizeBytes: item.sizeBytes
                                )
                                
                                await MainActor.run {
                                    if self.loadGeneration == generation {
                                        self.exifMetadata[key] = exif
                                        // Only trigger main-thread filtering and layout update if a filter is active!
                                        if self.filterRating > 0 || self.filterTaggedOnly {
                                            self.updateDisplayedImages()
                                        }
                                    }
                                }
                                
                                if let repo = localRepo {
                                    try? await repo.saveMetadata(exif)
                                }
                            } catch {
                                LoggerManager.shared.log("Failed to extract EXIF for \(filename): \(error.localizedDescription)", level: .debug)
                            }
                        }
                    }
                }
            }
        }
    }
    
    public var selectedImage: ImageItem? {
        guard let index = selectedImageIndex, index >= 0, index < displayedImages.count else {
            return nil
        }
        return displayedImages[index]
    }
    
    public func selectNextImage() {
        guard !displayedImages.isEmpty else { return }
        if let current = selectedImageIndex {
            if current < displayedImages.count - 1 {
                selectedImageIndex = current + 1
            }
        } else {
            selectedImageIndex = 0
        }
        if isDetailActive { calculateHistogramForSelected() }
        prefetchAdjacentImages()
    }
    
    public func selectPreviousImage() {
        guard !displayedImages.isEmpty else { return }
        if let current = selectedImageIndex {
            if current > 0 {
                selectedImageIndex = current - 1
            }
        } else {
            selectedImageIndex = 0
        }
        if isDetailActive { calculateHistogramForSelected() }
        prefetchAdjacentImages()
    }
    
    public func selectFirstImage() {
        guard !displayedImages.isEmpty else { return }
        selectedImageIndex = 0
        if isDetailActive { calculateHistogramForSelected() }
        prefetchAdjacentImages()
    }
    
    public func selectLastImage() {
        guard !displayedImages.isEmpty else { return }
        selectedImageIndex = displayedImages.count - 1
        if isDetailActive { calculateHistogramForSelected() }
        prefetchAdjacentImages()
    }
    
    public func toggleZoom() {
        isZoomed.toggle()
    }
    
    public func toggleFullScreen() {
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
    }
    
    public func calculateHistogramForSelected() {
        guard let image = selectedImage else {
            self.activeHistogram = []
            return
        }
        let key = image.url.path
        
        if let thumbnail = thumbnails[key] {
            Task.detached(priority: .userInitiated) {
                let histogram = ImageLoaderService.shared.calculateLuminanceHistogram(for: thumbnail)
                await MainActor.run {
                    self.activeHistogram = histogram
                }
            }
        } else {
            // Fallback: If thumbnail isn't loaded yet, try to load it quickly in background
            Task {
                do {
                    let thumbnailSize = AppSettings.shared.rendering.thumbnailSize.width
                    let thumbnail = try await ImageLoaderService.shared.loadThumbnail(from: image.url, maxPixelSize: thumbnailSize)
                    let histogram = ImageLoaderService.shared.calculateLuminanceHistogram(for: thumbnail)
                    self.activeHistogram = histogram
                } catch {
                    self.activeHistogram = []
                }
            }
        }
    }
    
    /// Look-ahead prefetching of adjacent images for seamless ACDSee-style culling
    public func prefetchAdjacentImages() {
        guard let currentIndex = selectedImageIndex, !displayedImages.isEmpty else { return }
        
        let prefetchWindow = 3 // Prefetch 3 ahead and 3 behind
        var indicesToPrefetch: [Int] = []
        
        for offset in 1...prefetchWindow {
            let nextIndex = currentIndex + offset
            let prevIndex = currentIndex - offset
            
            if nextIndex < displayedImages.count {
                indicesToPrefetch.append(nextIndex)
            }
            if prevIndex >= 0 {
                indicesToPrefetch.append(prevIndex)
            }
        }
        
        // Map to ImageItems and run light background preloading
        let items = indicesToPrefetch.map { displayedImages[$0] }
        loadThumbnailsAndMetadata(for: items, generation: loadGeneration)
    }
    
    // Culling Actions
    public func updateRatingForSelected(to rating: Int) {
        guard let index = selectedImageIndex, index >= 0, index < displayedImages.count else { return }
        let item = displayedImages[index]
        let key = item.url.path
        
        var metadata = exifMetadata[key] ?? ImageMetadata(id: key, url: item.url, filename: item.filename)
        metadata.rating = rating
        exifMetadata[key] = metadata
        
        Task {
            try? await exifRepo?.updateRating(for: key, rating: rating)
        }
        
        if filterRating > 0 {
            updateDisplayedImages()
        }
        
        LoggerManager.shared.log("Updated rating for \(item.filename) to \(rating) stars", level: .info)
    }
    
    public func toggleTaggedForSelected() {
        guard let index = selectedImageIndex, index >= 0, index < displayedImages.count else { return }
        let item = displayedImages[index]
        let key = item.url.path
        
        var metadata = exifMetadata[key] ?? ImageMetadata(id: key, url: item.url, filename: item.filename)
        metadata.isTagged.toggle()
        let newTagged = metadata.isTagged
        exifMetadata[key] = metadata
        
        Task {
            try? await exifRepo?.updateTagged(for: key, isTagged: newTagged)
        }
        
        if filterTaggedOnly {
            updateDisplayedImages()
        }
        
        LoggerManager.shared.log("Toggled tagged for \(item.filename) to \(newTagged)", level: .info)
    }
    
    public func deleteSelectedImage() {
        guard let index = selectedImageIndex, index >= 0, index < displayedImages.count else { return }
        let item = displayedImages[index]
        let fileURL = item.url
        
        LoggerManager.shared.log("Trashing file: \(fileURL.path)", level: .info)
        
        var nextSelectIndex: Int? = nil
        if displayedImages.count > 1 {
            if index < displayedImages.count - 1 {
                nextSelectIndex = index
            } else {
                nextSelectIndex = index - 1
            }
        }
        
        NSWorkspace.shared.recycle([fileURL])
        
        if let imgIndex = images.firstIndex(where: { $0.url == fileURL }) {
            images.remove(at: imgIndex)
        }
        
        selectedImageIndex = nextSelectIndex
        updateDisplayedImages()
        if isDetailActive { calculateHistogramForSelected() }
        
        LoggerManager.shared.log("Successfully trashed \(item.filename)", level: .info)
    }
    
    private func setupKeyboardNotificationObserver() {
        keyboardObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("didReceiveKeyboardEvent"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, let event = notification.userInfo?["event"] as? NSEvent else { return }
            Task { @MainActor in
                self.handleKeyboardEvent(event)
            }
        }
    }
    
    private enum KeyCode {
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let upArrow: UInt16 = 126
        static let downArrow: UInt16 = 125
        static let space: UInt16 = 49
        static let escape: UInt16 = 53
        static let fKey: UInt16 = 3
        static let enter: UInt16 = 36
        static let zKey: UInt16 = 6
        static let key1: UInt16 = 18
        static let key2: UInt16 = 19
        static let key3: UInt16 = 20
        static let key4: UInt16 = 21
        static let key5: UInt16 = 23
        static let key0: UInt16 = 29
        static let tKey: UInt16 = 17
        static let delete: UInt16 = 51
    }
    
    private func handleKeyboardEvent(_ event: NSEvent) {
        switch event.keyCode {
        case KeyCode.leftArrow:
            selectPreviousImage()
        case KeyCode.rightArrow:
            selectNextImage()
        case KeyCode.upArrow:
            selectFirstImage()
        case KeyCode.downArrow:
            selectLastImage()
        case KeyCode.space:
            isDetailActive.toggle()
        case KeyCode.escape:
            if isDetailActive {
                isDetailActive = false
            }
        case KeyCode.fKey, KeyCode.enter:
            toggleFullScreen()
        case KeyCode.zKey:
            toggleZoom()
        case KeyCode.key1:
            updateRatingForSelected(to: 1)
        case KeyCode.key2:
            updateRatingForSelected(to: 2)
        case KeyCode.key3:
            updateRatingForSelected(to: 3)
        case KeyCode.key4:
            updateRatingForSelected(to: 4)
        case KeyCode.key5:
            updateRatingForSelected(to: 5)
        case KeyCode.key0:
            updateRatingForSelected(to: 0)
        case KeyCode.tKey:
            toggleTaggedForSelected()
        case KeyCode.delete:
            deleteSelectedImage()
        default:
            break
        }
    }
}
