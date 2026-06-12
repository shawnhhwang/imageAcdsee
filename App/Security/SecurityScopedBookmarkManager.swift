import Foundation
import AppKit

public final class SecurityScopedBookmarkManager: @unchecked Sendable {
    public static let shared = SecurityScopedBookmarkManager()
    
    private let bookmarksKey = "com.project.lumina.bookmarks"
    private let queue = DispatchQueue(label: "com.project.lumina.bookmarks.queue", qos: .userInitiated)
    
    private init() {}
    
    /// Request the user to select a folder using NSOpenPanel
    /// - Parameter parentWindow: Optional parent window to display panel as a sheet
    /// - Returns: The selected URL with security scope accessed
    @MainActor
    public func selectFolder(parentWindow: NSWindow? = nil) async -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.message = "請選擇要瀏覽的影像資料夾"
        openPanel.prompt = "選擇資料夾"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        
        let response: NSApplication.ModalResponse
        if let window = parentWindow {
            response = await openPanel.beginSheetModal(for: window)
        } else {
            response = openPanel.runModal()
        }
        
        guard response == .OK, let selectedURL = openPanel.url else {
            return nil
        }
        
        // Save the bookmark for future launches
        saveBookmark(for: selectedURL)
        return selectedURL
    }
    
    /// Save bookmark data for a security-scoped URL
    public func saveBookmark(for url: URL) {
        queue.async {
            guard url.startAccessingSecurityScopedResource() else {
                LoggerManager.shared.log("Failed to start accessing security scoped resource for bookmarking: \(url.path)", level: .error)
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                var currentBookmarks = UserDefaults.standard.dictionary(forKey: self.bookmarksKey) as? [String: Data] ?? [:]
                currentBookmarks[url.path] = bookmarkData
                UserDefaults.standard.set(currentBookmarks, forKey: self.bookmarksKey)
                
                LoggerManager.shared.log("Successfully saved security-scoped bookmark for path: \(url.path)", level: .info)
            } catch {
                LoggerManager.shared.log("Failed to create bookmark data for \(url.path): \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    /// Resolve and load all saved bookmarks
    /// - Returns: A list of resolved security-scoped URLs
    public func loadSavedBookmarks() -> [URL] {
        queue.sync {
            guard let bookmarksMap = UserDefaults.standard.dictionary(forKey: bookmarksKey) as? [String: Data] else {
                return []
            }
            
            var resolvedURLs: [URL] = []
            
            for (path, data) in bookmarksMap {
                do {
                    var isStale = false
                    let url = try URL(
                        resolvingBookmarkData: data,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    
                    if isStale {
                        LoggerManager.shared.log("Bookmark for path \(path) is stale, recreating...", level: .info)
                        // Recreate bookmark
                        self.saveBookmark(for: url)
                    }
                    
                    resolvedURLs.append(url)
                    LoggerManager.shared.log("Successfully resolved bookmark for path: \(url.path)", level: .info)
                } catch {
                    LoggerManager.shared.log("Failed to resolve bookmark for path \(path): \(error.localizedDescription)", level: .error)
                }
            }
            
            return resolvedURLs
        }
    }
    
    /// Perform an operation with temporary security scope access for a URL
    /// - Parameters:
    ///   - url: The security-scoped URL
    ///   - block: The operation block to perform
    /// - Returns: The result of the block
    public func performAccessingSecurityScopedResource<T>(at url: URL, block: () throws -> T) rethrows -> T {
        let isSecurityScoped = url.path.contains("/Users/") && !url.path.contains("/Library/Containers/")
        
        if isSecurityScoped {
            let accessSuccess = url.startAccessingSecurityScopedResource()
            if !accessSuccess {
                LoggerManager.shared.log("Failed to gain security scoped access to URL: \(url.path)", level: .error)
            }
            defer {
                if accessSuccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try block()
        } else {
            return try block()
        }
    }
}
