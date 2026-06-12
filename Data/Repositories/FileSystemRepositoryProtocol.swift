import Foundation

// Protocol for file-system repository used by Domain layer
public protocol FileSystemRepositoryProtocol: Sendable {
    /// Loads immediate subfolders of a given folder URL as FolderNode entities
    func loadSubfolders(of folder: URL) async throws -> [FolderNode]
    
    /// Loads all supported images in a given folder URL as ImageItem entities
    func loadImages(of folder: URL) async throws -> [ImageItem]
}
