import Foundation

public protocol ExifCacheRepositoryProtocol: Sendable {
    /// Retrieve EXIF metadata from local database cache
    func getMetadata(for id: String) async throws -> ImageMetadata?
    
    /// Save or update EXIF metadata in the local database cache
    func saveMetadata(_ metadata: ImageMetadata) async throws
    
    /// Update rating for an image in the cache
    func updateRating(for id: String, rating: Int) async throws
    
    /// Update tagged status for an image in the cache
    func updateTagged(for id: String, isTagged: Bool) async throws
}
