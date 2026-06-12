import Foundation
import SQLite3

public final class ExifCacheRepository: ExifCacheRepositoryProtocol {
    private let database: SQLiteDatabase
    
    public init(database: SQLiteDatabase) {
        self.database = database
    }
    
    public func getMetadata(for id: String) async throws -> ImageMetadata? {
        let sql = """
        SELECT url, filename, creation_date, size_bytes, width, height, camera_make, camera_model, iso, aperture, shutter_speed, has_thumbnail, rating, is_tagged
        FROM exif_cache WHERE id = ?;
        """
        
        var result: ImageMetadata? = nil
        
        try await database.query(sql: sql, bindings: { stmt in
            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        }, rowHandler: { stmt in
            guard let urlString = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                  let url = URL(string: urlString),
                  let filename = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }) else {
                return
            }
            
            let width = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
            let height = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 5))
            let cameraMake = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let cameraModel = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            let iso = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 8))
            let aperture = sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 9)
            let shutterSpeed = sqlite3_column_type(stmt, 10) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 10)
            let hasThumbnail = sqlite3_column_int(stmt, 11) != 0
            
            // New culling fields
            let rating = Int(sqlite3_column_int(stmt, 12))
            let isTagged = sqlite3_column_int(stmt, 13) != 0
            
            result = ImageMetadata(
                id: id,
                url: url,
                filename: filename,
                width: width,
                height: height,
                cameraMake: cameraMake,
                cameraModel: cameraModel,
                iso: iso,
                aperture: aperture,
                shutterSpeed: shutterSpeed,
                hasThumbnail: hasThumbnail,
                rating: rating,
                isTagged: isTagged
            )
        })
        
        return result
    }
    
    public func saveMetadata(_ metadata: ImageMetadata) async throws {
        let sql = """
        INSERT OR REPLACE INTO exif_cache (id, url, filename, creation_date, size_bytes, width, height, camera_make, camera_model, iso, aperture, shutter_speed, has_thumbnail, rating, is_tagged)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        let actualTimeInterval = metadata.creationDate?.timeIntervalSince1970 ?? 0
        let fileSize = metadata.sizeBytes
        
        try await database.execute(sql: sql) { stmt in
            // 1. id
            sqlite3_bind_text(stmt, 1, (metadata.id as NSString).utf8String, -1, nil)
            // 2. url
            sqlite3_bind_text(stmt, 2, (metadata.url.absoluteString as NSString).utf8String, -1, nil)
            // 3. filename
            sqlite3_bind_text(stmt, 3, (metadata.filename as NSString).utf8String, -1, nil)
            
            // 4. creation_date
            sqlite3_bind_double(stmt, 4, actualTimeInterval)
            
            // 5. size_bytes
            sqlite3_bind_int64(stmt, 5, Int64(fileSize))
            
            // 6. width
            if let w = metadata.width {
                sqlite3_bind_int(stmt, 6, Int32(w))
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            
            // 7. height
            if let h = metadata.height {
                sqlite3_bind_int(stmt, 7, Int32(h))
            } else {
                sqlite3_bind_null(stmt, 7)
            }
            
            // 8. camera_make
            if let make = metadata.cameraMake {
                sqlite3_bind_text(stmt, 8, (make as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 8)
            }
            
            // 9. camera_model
            if let model = metadata.cameraModel {
                sqlite3_bind_text(stmt, 9, (model as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 9)
            }
            
            // 10. iso
            if let iso = metadata.iso {
                sqlite3_bind_int(stmt, 10, Int32(iso))
            } else {
                sqlite3_bind_null(stmt, 10)
            }
            
            // 11. aperture
            if let ap = metadata.aperture {
                sqlite3_bind_double(stmt, 11, ap)
            } else {
                sqlite3_bind_null(stmt, 11)
            }
            
            // 12. shutter_speed
            if let ss = metadata.shutterSpeed {
                sqlite3_bind_double(stmt, 12, ss)
            } else {
                sqlite3_bind_null(stmt, 12)
            }
            
            // 13. has_thumbnail
            sqlite3_bind_int(stmt, 13, metadata.hasThumbnail ? 1 : 0)
            
            // 14. rating
            sqlite3_bind_int(stmt, 14, Int32(metadata.rating))
            
            // 15. is_tagged
            sqlite3_bind_int(stmt, 15, metadata.isTagged ? 1 : 0)
        }
    }
    
    public func updateRating(for id: String, rating: Int) async throws {
        let sql = "UPDATE exif_cache SET rating = ? WHERE id = ?;"
        try await database.execute(sql: sql) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(rating))
            sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, nil)
        }
    }
    
    public func updateTagged(for id: String, isTagged: Bool) async throws {
        let sql = "UPDATE exif_cache SET is_tagged = ? WHERE id = ?;"
        try await database.execute(sql: sql) { stmt in
            sqlite3_bind_int(stmt, 1, isTagged ? 1 : 0)
            sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, nil)
        }
    }
}
