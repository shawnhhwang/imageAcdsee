import SwiftUI
import MetalKit
import CoreImage

// MARK: - Keyboard Capture View (failsafe for arrow key navigation)

/// A transparent, focusable NSView that lives inside ImageDetailView.
/// Its primary role: hold first-responder status so that, if the AppKit
/// local event monitor in AppDelegate ever fails to intercept an arrow key,
/// the event still reaches this view's keyDown handler and navigates photos.
/// When the monitor works correctly it consumes the event before keyDown,
/// so there is NO double-invocation.
final class KeyCaptureNSView: NSView {
    weak var viewModel: AppViewModel?
    
    private enum KeyCode {
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let upArrow: UInt16 = 126
        static let downArrow: UInt16 = 125
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Become first responder as soon as we're in a window.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        // This fires ONLY if the AppKit local event monitor did NOT consume
        // the event (i.e., the monitor failed or the app wasn't active).
        // In that case we handle arrow keys here as a direct fallback.
        Task { @MainActor [weak viewModel] in
            guard let vm = viewModel else { return }
            switch event.keyCode {
            case KeyCode.leftArrow: vm.selectPreviousImage()
            case KeyCode.rightArrow: vm.selectNextImage()
            case KeyCode.upArrow: vm.selectFirstImage()
            case KeyCode.downArrow: vm.selectLastImage()
            default:  break
            }
        }
        // For handled arrow keys, do NOT call super so the event is consumed here.
        if ![KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.upArrow, KeyCode.downArrow].contains(event.keyCode) {
            super.keyDown(with: event)
        }
    }
}

struct KeyCaptureView: NSViewRepresentable {
    @ObservedObject var viewModel: AppViewModel
    
    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.viewModel = viewModel
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.viewModel = viewModel
    }
}

// MARK: - ImageDetailView

struct ImageDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isSidebarOpen: Bool = true
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Display Area (Image Canvas + Overlays)
            ZStack {
                // Dark Backdrop
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Transparent key capture overlay — zero-size visually, but holds
                // first-responder status so arrow keys always have a handler.
                KeyCaptureView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false) // Don't block mouse events
                
                if let selectedImage = viewModel.selectedImage {
                    let key = selectedImage.url.path
                    
                    // Hardware accelerated image container
                    MetalImageView(imageURL: selectedImage.url, isZoomed: viewModel.isZoomed, viewModel: viewModel)
                        .edgesIgnoringSafeArea(.all)
                        .id("\(key)_\(viewModel.isZoomed)") // Forces redraw on change or zoom
                        .gesture(
                            TapGesture(count: 2).onEnded {
                                viewModel.toggleZoom()
                            }
                        )
                    
                    // Top Left Close Button
                    Button(action: {
                        viewModel.isDetailActive = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
                    
                    // Top Right Control Panel (Full Screen & Zoom & Sidebar Toggle)
                    HStack(spacing: 12) {
                        // Sidebar Toggle Button
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                isSidebarOpen.toggle()
                            }
                        }) {
                            Image(systemName: "sidebar.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(isSidebarOpen ? .blue : .white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Zoom Toggle Button
                        Button(action: {
                            viewModel.toggleZoom()
                        }) {
                            Image(systemName: viewModel.isZoomed ? "minus.magnifyingglass" : "plus.magnifyingglass")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Full Screen Button
                        let isFullScreen = NSApp.keyWindow?.styleMask.contains(.fullScreen) == true
                        Button(action: {
                            viewModel.toggleFullScreen()
                        }) {
                            Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(16)
                    
                    // Left & Right Navigation Arrows Overlay (middle-left and middle-right)
                    HStack {
                        let isFirst = viewModel.selectedImageIndex == 0
                        NavigationArrowButton(systemName: "chevron.left", action: {
                            viewModel.selectPreviousImage()
                        }, isDisabled: isFirst)
                        
                        Spacer()
                        
                        let isLast = viewModel.selectedImageIndex == viewModel.displayedImages.count - 1
                        NavigationArrowButton(systemName: "chevron.right", action: {
                            viewModel.selectNextImage()
                        }, isDisabled: isLast)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    
                    // EXIF / HUD Translucent Banner (Bottom)
                    if let exif = viewModel.exifMetadata[key] {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 16) {
                                Text(selectedImage.filename)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                
                                if let w = exif.width, let h = exif.height {
                                    Text("\(w) x \(h)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                // Interactive Tag Flag Button
                                Button(action: {
                                    viewModel.toggleTaggedForSelected()
                                }) {
                                    Image(systemName: exif.isTagged ? "flag.fill" : "flag")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(exif.isTagged ? .red : .white.opacity(0.45))
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(RoundedRectangle(cornerRadius: 6).fill(exif.isTagged ? Color.red.opacity(0.18) : Color.white.opacity(0.06)))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Interactive Star Rating Buttons
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= exif.rating ? "star.fill" : "star")
                                            .font(.system(size: 11))
                                            .foregroundColor(star <= exif.rating ? .orange : .white.opacity(0.2))
                                            .onTapGesture {
                                                viewModel.updateRatingForSelected(to: star)
                                            }
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                            }
                            
                            HStack(spacing: 20) {
                                if let make = exif.cameraMake, let model = exif.cameraModel {
                                    HUDField(icon: "camera", label: "\(make) \(model)")
                                }
                                
                                if let aperture = exif.aperture {
                                    HUDField(icon: "f.circle", label: String(format: "f/%.1f", aperture))
                                }
                                
                                if let iso = exif.iso {
                                    HUDField(icon: "dial.low.fill", label: "ISO \(iso)")
                                }
                                
                                if let ss = exif.shutterSpeed {
                                    let ssText = ss >= 1.0 ? String(format: "%.1fs", ss) : String(format: "1/%.0fs", 1.0 / ss)
                                    HUDField(icon: "timer", label: ssText)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Right Display Area (Sliding Info Sidebar - separated outside from the canvas)
            if isSidebarOpen, let selectedImage = viewModel.selectedImage {
                let key = selectedImage.url.path
                DetailsSidebarView(viewModel: viewModel, selectedImage: selectedImage, key: key)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .background(Color.black)
        .onAppear {
            // Re-activate the app every time the detail view opens.
            // This handles the common case where the app was launched from
            // a terminal and never properly grabbed keyboard focus.
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// Expandable details sidebar view
// Expandable details sidebar view
struct DetailsSidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    let selectedImage: ImageItem
    let key: String
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    private var fileSizeString: String {
        let sizeMB = Double(selectedImage.sizeBytes) / (1024.0 * 1024.0)
        return String(format: "%.2f MB", sizeMB)
    }
    
    private var formattedModificationDate: String {
        guard let date = selectedImage.creationDate else {
            return ""
        }
        return Self.dateFormatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerSection
            
            // Histogram
            HistogramView(bins: viewModel.activeHistogram)
            
            Divider().background(Color.white.opacity(0.08))
            
            fileInfoSection
            
            Divider().background(Color.white.opacity(0.08))
            
            cameraInfoSection
            
            Spacer()
        }
        .padding(16)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.vertical, 16)
        .padding(.trailing, 16)
    }
    
    private var headerSection: some View {
        HStack {
            Text("照片詳細資訊")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
        }
        .padding(.bottom, 2)
    }
    
    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("檔案屬性")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .padding(.bottom, 2)
            
            SidebarRow(label: "檔名", value: selectedImage.filename)
            SidebarRow(label: "路徑", value: selectedImage.url.path, isTruncated: true)
            
            if let exif = viewModel.exifMetadata[key] {
                if let w = exif.width, let h = exif.height {
                    SidebarRow(label: "解析度", value: "\(w) x \(h) 像素")
                }
            }
            
            SidebarRow(label: "檔案大小", value: fileSizeString)
            
            let dateStr = formattedModificationDate
            if !dateStr.isEmpty {
                SidebarRow(label: "修改日期", value: dateStr)
            }
        }
    }
    
    private var cameraInfoSection: some View {
        Group {
            if let exif = viewModel.exifMetadata[key] {
                VStack(alignment: .leading, spacing: 8) {
                    Text("相機參數 (EXIF)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.bottom, 2)
                    
                    if let make = exif.cameraMake, let model = exif.cameraModel {
                        SidebarRow(label: "製造相機", value: "\(make) \(model)")
                    }
                    if let aperture = exif.aperture {
                        SidebarRow(label: "光圈數值", value: String(format: "f/%.1f", aperture))
                    }
                    if let ss = exif.shutterSpeed {
                        let ssText = ss >= 1.0 ? String(format: "%.1fs", ss) : String(format: "1/%.0fs", 1.0 / ss)
                        SidebarRow(label: "曝光時間", value: ssText)
                    }
                    if let iso = exif.iso {
                        SidebarRow(label: "感光度", value: "ISO \(iso)")
                    }
                }
                
                Divider().background(Color.white.opacity(0.08))
                
                cullingSection(exif: exif)
            }
        }
    }
    
    private func cullingSection(exif: ImageMetadata) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("選片評估 (ACDSee Culling)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .padding(.bottom, 2)
            
            HStack {
                Text("星級評等")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= exif.rating ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(star <= exif.rating ? .orange : .white.opacity(0.25))
                            .onTapGesture {
                                viewModel.updateRatingForSelected(to: star)
                            }
                    }
                }
            }
            
            HStack {
                Text("選片標記")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                Button(action: {
                    viewModel.toggleTaggedForSelected()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: exif.isTagged ? "flag.fill" : "flag")
                        Text(exif.isTagged ? "已選取" : "未標記")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(exif.isTagged ? .red : .white.opacity(0.6))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(exif.isTagged ? Color.red.opacity(0.18) : Color.white.opacity(0.06)))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// Reusable sidebar details row
struct SidebarRow: View {
    let label: String
    let value: String
    var isTruncated: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(isTruncated ? 1 : nil)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
    }
}

// Real-time custom path luminance histogram view
struct HistogramView: View {
    let bins: [Float]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("曝光亮度直方圖")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
            
            ZStack {
                // Background Grid
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.02))
                    .frame(height: 70)
                
                // Grid Lines
                VStack {
                    Spacer()
                    Divider().background(Color.white.opacity(0.06))
                    Spacer()
                    Divider().background(Color.white.opacity(0.06))
                    Spacer()
                }
                .frame(height: 70)
                
                if bins.isEmpty {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    // Draw Area Path
                    GeometryReader { geo in
                        let width = geo.size.width
                        let height = geo.size.height
                        let step = width / CGFloat(bins.count - 1)
                        
                        let points: [CGPoint] = bins.indices.map { i in
                            CGPoint(x: CGFloat(i) * step, y: height - (CGFloat(bins[i]) * height * 0.92))
                        }
                        
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: height))
                            for pt in points {
                                path.addLine(to: pt)
                            }
                            path.addLine(to: CGPoint(x: width, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.35), Color.blue.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        // Draw Line Path
                        Path { path in
                            if let first = points.first {
                                path.move(to: first)
                                for pt in points.dropFirst() {
                                    path.addLine(to: pt)
                                }
                            }
                        }
                        .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                    }
                    .frame(height: 70)
                }
            }
        }
    }
}

struct HUDField: View {
    let icon: String
    let label: String
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.blue)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

struct NavigationArrowButton: View {
    let systemName: String
    let action: () -> Void
    let isDisabled: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isDisabled ? .white.opacity(0.12) : (isHovered ? .white : .white.opacity(0.55)))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isDisabled ? Color.clear : (isHovered ? Color.black.opacity(0.7) : Color.black.opacity(0.35)))
                        .overlay(
                            Circle()
                                .stroke(isHovered ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
                        )
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Metal & Core Image Accelerated Viewer

/// MTKView subclass that accepts keyboard focus so that
/// clicking on the image canvas keeps arrow-key navigation working.
final class KeyableMTKView: MTKView {
    weak var viewModel: AppViewModel?
    private var scrollAccumulatorX: CGFloat = 0.0
    
    override var acceptsFirstResponder: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began || event.phase == .mayBegin {
            scrollAccumulatorX = 0
        }
        
        // Handle horizontal scroll for previous/next navigation
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            scrollAccumulatorX += event.scrollingDeltaX
            let threshold: CGFloat = 80.0
            
            if scrollAccumulatorX > threshold {
                Task { @MainActor [weak viewModel] in
                    viewModel?.selectPreviousImage()
                }
                scrollAccumulatorX = 0
            } else if scrollAccumulatorX < -threshold {
                Task { @MainActor [weak viewModel] in
                    viewModel?.selectNextImage()
                }
                scrollAccumulatorX = 0
            }
        }
        
        if event.phase == .ended || event.phase == .cancelled || event.momentumPhase == .ended {
            scrollAccumulatorX = 0
        }
        
        super.scrollWheel(with: event)
    }
}
struct MetalImageView: NSViewRepresentable {
    let imageURL: URL
    let isZoomed: Bool
    @ObservedObject var viewModel: AppViewModel
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = KeyableMTKView()
        mtkView.viewModel = viewModel
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.delegate = context.coordinator
        
        context.coordinator.mtkView = mtkView
        context.coordinator.loadImage(from: imageURL, isZoomed: isZoomed)
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        if let keyableView = nsView as? KeyableMTKView {
            keyableView.viewModel = viewModel
        }
        context.coordinator.mtkView = nsView
        context.coordinator.loadImage(from: imageURL, isZoomed: isZoomed)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        private let context: CIContext
        private let commandQueue: MTLCommandQueue?
        private var ciImage: CIImage?
        private var loadedURL: URL?
        private var loadTask: Task<Void, Never>?
        weak var mtkView: MTKView?
        
        var isZoomed: Bool = false
        
        override init() {
            let device = MTLCreateSystemDefaultDevice()!
            self.context = CIContext(mtlDevice: device)
            self.commandQueue = device.makeCommandQueue()
            super.init()
        }
        
        func loadImage(from url: URL, isZoomed: Bool) {
            // Avoid redundant loading if same URL and zoom state, and we already have the image
            if loadedURL == url && self.isZoomed == isZoomed && ciImage != nil {
                return
            }
            
            let isNewURL = loadedURL != url
            loadedURL = url
            self.isZoomed = isZoomed
            
            // Cancel any in-progress load tasks
            loadTask?.cancel()
            
            // Temporarily clear the image only if we are loading a completely new URL,
            // to prevent flickering when toggling zoom back and forth
            if isNewURL {
                self.ciImage = nil
                self.mtkView?.setNeedsDisplay(self.mtkView?.bounds ?? .zero)
            }
            
            loadTask = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                
                let image = SecurityScopedBookmarkManager.shared.performAccessingSecurityScopedResource(at: url) { () -> CIImage? in
                    let options: [CFString: Any] = [
                        kCGImageSourceShouldCache: false
                    ]
                    
                    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
                        return nil
                    }
                    
                    // Optimizations for non-zoomed (Fit-to-screen) view:
                    // Using CGImageSourceCreateThumbnailAtIndex to extract embedded RAW preview
                    // or decode a downscaled version of large JPEGs is extremely fast and saves gigabytes of RAM.
                    if !isZoomed {
                        let maxPixelSize = 2560
                        let thumbnailOptions: [CFString: Any] = [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceShouldCacheImmediately: true
                        ]
                        
                        if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary) {
                            return CIImage(cgImage: cgImage)
                        }
                    }
                    
                    // Fallback or Zoomed mode: Load full-resolution image asynchronously
                    return CIImage(contentsOf: url)
                }
                
                if Task.isCancelled { return }
                
                Task { @MainActor in
                    self.ciImage = image
                    self.mtkView?.setNeedsDisplay(self.mtkView?.bounds ?? .zero)
                }
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            guard let ciImage = ciImage,
                  let currentDrawable = view.currentDrawable,
                  let commandQueue = commandQueue,
                  let commandBuffer = commandQueue.makeCommandBuffer() else {
                return
            }
            
            // Scaled content aspect fit calculation
            let drawableSize = view.drawableSize
            let imageSize = ciImage.extent.size
            
            let scaleX = drawableSize.width / imageSize.width
            let scaleY = drawableSize.height / imageSize.height
            let scale = isZoomed ? max(scaleX, scaleY) : min(scaleX, scaleY)
            
            let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            
            // Align center
            let offsetX = (drawableSize.width - scaledImage.extent.width) / 2
            let offsetY = (drawableSize.height - scaledImage.extent.height) / 2
            let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
            
            let destination = CIRenderDestination(
                width: Int(drawableSize.width),
                height: Int(drawableSize.height),
                pixelFormat: view.colorPixelFormat,
                commandBuffer: commandBuffer,
                mtlTextureProvider: { currentDrawable.texture }
            )
            
            do {
                _ = try context.startTask(toRender: centeredImage, to: destination)
                commandBuffer.present(currentDrawable)
                commandBuffer.commit()
            } catch {
                LoggerManager.shared.log("Metal rendering failed: \(error.localizedDescription)", level: .error)
            }
        }
    }
}
