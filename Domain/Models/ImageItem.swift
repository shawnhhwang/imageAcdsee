import Foundation

// Domain entity representing an image
public struct ImageItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let filename: String
    public let creationDate: Date?
    public let sizeBytes: Int64

    public init(id: UUID = UUID(), url: URL, filename: String, creationDate: Date? = nil, sizeBytes: Int64 = 0) {
        self.id = id
        self.url = url
        self.filename = filename
        self.creationDate = creationDate
        self.sizeBytes = sizeBytes
    }
}
