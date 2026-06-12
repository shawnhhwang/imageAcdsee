import Foundation
import os

public enum LogLevel: String, Sendable {
    case debug
    case info
    case error
}

public final class LoggerManager: @unchecked Sendable {
    public static let shared = LoggerManager()
    
    private let logger: Logger
    private let configuredLogLevel: LogLevel
    private let logToDisk: Bool
    private var logFileURL: URL?
    private var fileHandle: FileHandle?
    private let logQueue = DispatchQueue(label: "com.project.lumina.logger", qos: .background)
    
    private init() {
        let settings = AppSettings.shared.logging
        let subsystem = settings.subsystem
        self.logger = Logger(subsystem: subsystem, category: "App")
        
        switch settings.logLevel.lowercased() {
        case "debug":
            self.configuredLogLevel = .debug
        case "error":
            self.configuredLogLevel = .error
        default:
            self.configuredLogLevel = .info
        }
        
        self.logToDisk = settings.logToDisk
        
        if logToDisk {
            setupLogFile()
        }
    }
    
    private func setupLogFile() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let logDir = appSupport.appendingPathComponent("ProjectLumina/Logs", isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
            let fileURL = logDir.appendingPathComponent("app.log")
            if !fileManager.fileExists(atPath: fileURL.path) {
                fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
            }
            self.logFileURL = fileURL
            
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                self.fileHandle = handle
                _ = try? handle.seekToEnd()
            }
            
            log("Log file initialized at: \(fileURL.path)", level: .info)
        } catch {
            logger.error("Failed to create log directory: \(error.localizedDescription)")
        }
    }
    
    public func log(_ message: String, level: LogLevel = .info) {
        // Filter based on log level configuration
        switch (configuredLogLevel, level) {
        case (.info, .debug):
            return // Skip debug logs if configured for info
        case (.error, .debug), (.error, .info):
            return // Skip debug and info logs if configured for error
        default:
            break
        }
        
        // Write to OSLog
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
        
        // Write to disk if enabled
        if logToDisk, let handle = fileHandle {
            logQueue.async {
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let logLine = "[\(timestamp)] [\(level.rawValue.uppercased())] \(message)\n"
                if let data = logLine.data(using: .utf8) {
                    _ = try? handle.write(contentsOf: data)
                }
            }
        }
    }
    
    deinit {
        _ = try? fileHandle?.close()
    }
}
