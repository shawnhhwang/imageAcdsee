import Foundation

public struct ImageMetadata: Equatable, Hashable, Sendable {
    public let id: String
    public let url: URL
    public let filename: String
    public let creationDate: Date?
    public let sizeBytes: Int64
    public let width: Int?
    public let height: Int?
    public let cameraMake: String?
    public let cameraModel: String?
    public let iso: Int?
    public let aperture: Double?
    public let shutterSpeed: Double?
    public var hasThumbnail: Bool
    public var rating: Int
    public var isTagged: Bool
    
    public init(
        id: String,
        url: URL,
        filename: String,
        creationDate: Date? = nil,
        sizeBytes: Int64 = 0,
        width: Int? = nil,
        height: Int? = nil,
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        iso: Int? = nil,
        aperture: Double? = nil,
        shutterSpeed: Double? = nil,
        hasThumbnail: Bool = false,
        rating: Int = 0,
        isTagged: Bool = false
    ) {
        self.id = id
        self.url = url
        self.filename = filename
        self.creationDate = creationDate
        self.sizeBytes = sizeBytes
        self.width = width
        self.height = height
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.iso = iso
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.hasThumbnail = hasThumbnail
        self.rating = rating
        self.isTagged = isTagged
    }
}
