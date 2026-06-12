import Foundation

// Domain entity representing a folder node
public struct FolderNode: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public var children: [FolderNode]?

    public init(id: UUID = UUID(), url: URL, name: String, children: [FolderNode]? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.children = children
    }
}
