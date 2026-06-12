import Foundation
import CoreServices

/// A thread-safe, native FSEvents wrapper to monitor directory tree changes.
public final class DirectoryMonitor: @unchecked Sendable {
    private var streamRef: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.project.lumina.fsevents", qos: .default)
    
    private var continuation: AsyncStream<URL>.Continuation?
    public let events: AsyncStream<URL>
    private var monitoredURL: URL?
    
    public init() {
        var cont: AsyncStream<URL>.Continuation?
        self.events = AsyncStream { continuation in
            cont = continuation
        }
        self.continuation = cont
    }
    
    /// Starts monitoring the specified directory tree recursively
    /// - Parameter url: The directory URL to monitor
    public func startMonitoring(url: URL) {
        stopMonitoring()
        
        monitoredURL = url
        let path = url.path
        let pathsToWatch = [path] as CFArray
        
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let latency: CFTimeInterval = Double(AppSettings.shared.fileSystem.fsEventsDebounceMilliseconds) / 1000.0
        
        let callback: FSEventStreamCallback = { (
            streamRef: ConstFSEventStreamRef,
            clientCallBackInfo: UnsafeMutableRawPointer?,
            numEvents: Int,
            eventPaths: UnsafeMutableRawPointer,
            eventFlags: UnsafePointer<FSEventStreamEventFlags>,
            eventIds: UnsafePointer<FSEventStreamEventId>
        ) in
            guard let clientCallBackInfo = clientCallBackInfo else { return }
            let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            
            guard let pathsArray = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else {
                return
            }
            
            monitor.handleFSEvents(changedPaths: pathsArray)
        }
        
        // Flags: FileEvents triggers on files in addition to directories, UseCFTypes passes CFStrings/CFArrays into eventPaths
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagNoDefer
        )
        
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            LoggerManager.shared.log("Failed to create FSEventStream for path: \(path)", level: .error)
            return
        }
        
        FSEventStreamSetDispatchQueue(stream, queue)
        
        if FSEventStreamStart(stream) {
            self.streamRef = stream
            LoggerManager.shared.log("Started FSEvents directory monitoring on: \(path)", level: .info)
        } else {
            LoggerManager.shared.log("Failed to start FSEventStream for path: \(path)", level: .error)
            FSEventStreamInvalidate(stream)
        }
    }
    
    /// Stops monitoring the directory
    public func stopMonitoring() {
        guard let stream = streamRef else { return }
        
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        
        self.streamRef = nil
        LoggerManager.shared.log("Stopped FSEvents directory monitoring on: \(monitoredURL?.path ?? "unknown")", level: .info)
        monitoredURL = nil
    }
    
    private func handleFSEvents(changedPaths: [String]) {
        guard let monitoredURL = monitoredURL else { return }
        LoggerManager.shared.log("FSEvents detected changes in paths: \(changedPaths)", level: .debug)
        
        // Notify the observer
        continuation?.yield(monitoredURL)
    }
    
    deinit {
        stopMonitoring()
    }
}
