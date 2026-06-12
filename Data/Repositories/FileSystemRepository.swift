import Foundation

public final class FileSystemRepository: FileSystemRepositoryProtocol {
    public init() {}
    
    public func loadSubfolders(of folder: URL) async throws -> [FolderNode] {
        return await Task.detached(priority: .userInitiated) {
            return SecurityScopedBookmarkManager.shared.performAccessingSecurityScopedResource(at: folder) {
                let fileManager = FileManager.default
                let keys: [URLResourceKey] = [.isDirectoryKey, .localizedNameKey]
                
                guard let enumerator = fileManager.enumerator(
                    at: folder,
                    includingPropertiesForKeys: keys,
                    options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
                ) else {
                    LoggerManager.shared.log("Failed to create directory enumerator for subfolders at: \(folder.path)", level: .error)
                    return []
                }
                
                var subfolders: [FolderNode] = []
                
                for case let fileURL as URL in enumerator {
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                          let isDirectory = resourceValues.isDirectory,
                          isDirectory else {
                        continue
                    }
                    
                    let name = resourceValues.localizedName ?? fileURL.lastPathComponent
                    let node = FolderNode(url: fileURL, name: name)
                    subfolders.append(node)
                }
                
                // Sort subfolders by name alphabetically
                return subfolders.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
        }.value
    }
    
    public func loadImages(of folder: URL) async throws -> [ImageItem] {
        return await Task.detached(priority: .userInitiated) {
            return SecurityScopedBookmarkManager.shared.performAccessingSecurityScopedResource(at: folder) {
                let fileManager = FileManager.default
                let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
                
                guard let contents = try? fileManager.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: keys,
                    options: .skipsHiddenFiles
                ) else {
                    LoggerManager.shared.log("Failed to list directory contents for images at: \(folder.path)", level: .error)
                    return []
                }
                
                let supportedExtensions = Set(
                    AppSettings.shared.fileSystem.supportedExtensions.map { $0.lowercased() }
                )
                
                var images: [ImageItem] = []
                
                for fileURL in contents {
                    let ext = ".\(fileURL.pathExtension.lowercased())"
                    guard supportedExtensions.contains(ext) else {
                        continue
                    }
                    
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)) else {
                        continue
                    }
                    
                    // Filter out folders that happen to have image-like extensions (rare but safe check)
                    if let isDirectory = resourceValues.isDirectory, isDirectory {
                        continue
                    }
                    
                    let creationDate = resourceValues.contentModificationDate
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    let filename = fileURL.lastPathComponent
                    
                    let item = ImageItem(
                        url: fileURL,
                        filename: filename,
                        creationDate: creationDate,
                        sizeBytes: fileSize
                    )
                    images.append(item)
                }
                
                // Sort images: latest modified or alphabetical
                return images.sorted {
                    if let d1 = $0.creationDate, let d2 = $1.creationDate {
                        return d1 > d2 // Show latest modified first
                    }
                    return $0.filename.localizedStandardCompare($1.filename) == .orderedAscending
                }
            }
        }.value
    }
}
