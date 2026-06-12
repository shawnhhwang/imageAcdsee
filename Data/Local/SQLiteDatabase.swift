import Foundation
import SQLite3

public actor SQLiteDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    
    public init(dbPath: String) throws {
        self.dbPath = dbPath
        
        var tempDb: OpaquePointer?
        let status = sqlite3_open(dbPath, &tempDb)
        if status != SQLITE_OK {
            let errorMsg = tempDb.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw NSError(domain: "SQLiteDatabase", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to open DB: \(errorMsg)"])
        }
        self.db = tempDb
        
        // Enable WAL mode for high concurrency
        try SQLiteDatabase.executeStatic(db: tempDb, sql: "PRAGMA journal_mode=WAL;")
        // Synchronous normal for faster writes
        try SQLiteDatabase.executeStatic(db: tempDb, sql: "PRAGMA synchronous=NORMAL;")
        
        let exifTableSQL = """
        CREATE TABLE IF NOT EXISTS exif_cache (
            id TEXT PRIMARY KEY,
            url TEXT NOT NULL,
            filename TEXT NOT NULL,
            creation_date REAL,
            size_bytes INTEGER,
            width INTEGER,
            height INTEGER,
            camera_make TEXT,
            camera_model TEXT,
            iso INTEGER,
            aperture REAL,
            shutter_speed REAL,
            has_thumbnail INTEGER DEFAULT 0,
            rating INTEGER DEFAULT 0,
            is_tagged INTEGER DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_exif_url ON exif_cache(url);
        """
        try SQLiteDatabase.executeStatic(db: tempDb, sql: exifTableSQL)
        
        // Add dynamic migrations for existing schemas
        try? SQLiteDatabase.executeStatic(db: tempDb, sql: "ALTER TABLE exif_cache ADD COLUMN rating INTEGER DEFAULT 0;")
        try? SQLiteDatabase.executeStatic(db: tempDb, sql: "ALTER TABLE exif_cache ADD COLUMN is_tagged INTEGER DEFAULT 0;")
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    private static func executeStatic(db: OpaquePointer?, sql: String) throws {
        var errorMsg: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &errorMsg)
        
        if status != SQLITE_OK {
            let message = errorMsg.flatMap { String(cString: $0) } ?? "Unknown error"
            if let errorMsg = errorMsg {
                sqlite3_free(errorMsg)
            }
            throw NSError(domain: "SQLiteDatabase", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "SQL Execution Error (\(status)): \(message)"])
        }
    }
    
    public func execute(sql: String) throws {
        var errorMsg: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &errorMsg)
        
        if status != SQLITE_OK {
            let message = errorMsg.flatMap { String(cString: $0) } ?? "Unknown error"
            if let errorMsg = errorMsg {
                sqlite3_free(errorMsg)
            }
            throw NSError(domain: "SQLiteDatabase", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "SQL Execution Error (\(status)): \(message)"])
        }
    }
    
    /// Run a query with prepared statement
    /// - Parameters:
    ///   - sql: The SQL statement with placeholders
    ///   - bindings: A block that binds parameters to the statement
    ///   - rowHandler: A block that processes each row of the result
    public func query(
        sql: String,
        bindings: ((OpaquePointer) -> Void)? = nil,
        rowHandler: (OpaquePointer) -> Void
    ) throws {
        var stmt: OpaquePointer?
        let status = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        
        guard status == SQLITE_OK, let statement = stmt else {
            let errorMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw NSError(domain: "SQLiteDatabase", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Prepare Statement Error (\(status)): \(errorMsg)"])
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        // Bind parameters if any
        bindings?(statement)
        
        // Evaluate the statement
        while sqlite3_step(statement) == SQLITE_ROW {
            rowHandler(statement)
        }
    }
    
    /// Execute an update or insert with custom parameter bindings
    public func execute(sql: String, bindings: @escaping (OpaquePointer) -> Void) throws {
        var stmt: OpaquePointer?
        let status = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard status == SQLITE_OK, let statement = stmt else {
            let errorMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw NSError(domain: "SQLiteDatabase", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Prepare Statement Error (\(status)): \(errorMsg)"])
        }
        defer {
            sqlite3_finalize(statement)
        }
        bindings(statement)
        let stepStatus = sqlite3_step(statement)
        if stepStatus != SQLITE_DONE && stepStatus != SQLITE_ROW {
            let errorMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw NSError(domain: "SQLiteDatabase", code: Int(stepStatus), userInfo: [NSLocalizedDescriptionKey: "Step Error (\(stepStatus)): \(errorMsg)"])
        }
    }
}
