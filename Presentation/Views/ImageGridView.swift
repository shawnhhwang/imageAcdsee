import SwiftUI

struct ImageGridView: View {
    @ObservedObject var viewModel: AppViewModel
    
    // Grid configuration
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 14)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Premium Filter Bar (ACDSee style)
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text("選片篩選器:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary.opacity(0.75))
                }
                
                // Star Rating Filter buttons
                HStack(spacing: 4) {
                    FilterButton(label: "全部", isSelected: viewModel.filterRating == 0) {
                        viewModel.filterRating = 0
                        viewModel.updateDisplayedImages()
                    }
                    
                    ForEach(1...5, id: \.self) { stars in
                        FilterButton(icon: "star.fill", label: "\(stars)+", isSelected: viewModel.filterRating == stars, selectedColor: .orange) {
                            viewModel.filterRating = stars
                            viewModel.updateDisplayedImages()
                        }
                    }
                }
                
                Divider()
                    .frame(height: 12)
                
                // Tagged Filter button
                FilterButton(icon: "flag.fill", label: "僅顯示標記 (T)", isSelected: viewModel.filterTaggedOnly, selectedColor: .red) {
                    viewModel.filterTaggedOnly.toggle()
                    viewModel.updateDisplayedImages()
                }
                
                Spacer()
                
                // Total Count HUD
                Text("共 \(viewModel.displayedImages.count) / \(viewModel.images.count) 張影像")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(4)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                VStack {
                    Spacer()
                    Rectangle().fill(Color(NSColor.gridColor).opacity(0.35)).frame(height: 1)
                }
            )
            
            ScrollView {
                if viewModel.displayedImages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text(viewModel.selectedFolder == nil ? "請在左側欄選取或開啟影像資料夾" : "此篩選條件下沒有任何支援的影像")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(0..<viewModel.displayedImages.count, id: \.self) { index in
                            let item = viewModel.displayedImages[index]
                            let key = item.url.path
                            let isSelected = viewModel.selectedImageIndex == index
                            
                            VStack(alignment: .leading, spacing: 6) {
                                // Thumbnail Frame
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2.5)
                                        )
                                        .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.1), radius: isSelected ? 8 : 2, x: 0, y: 1)
                                    
                                    if let cgImage = viewModel.thumbnails[key] {
                                        Image(nsImage: NSImage(cgImage: cgImage, size: .zero))
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 130)
                                            .clipped()
                                            .cornerRadius(6)
                                            .padding(isSelected ? 3 : 1)
                                            .transition(.opacity.animation(.easeIn(duration: 0.15)))
                                    } else {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    
                                    // Dimension HUD Overlay (top right)
                                    if let exif = viewModel.exifMetadata[key], let w = exif.width, let h = exif.height {
                                        Text("\(w)x\(h)")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.vertical, 2)
                                            .padding(.horizontal, 4)
                                            .background(Color.black.opacity(0.6))
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                            .padding(6)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    }
                                    
                                    // Tag Flag Overlay (top-left)
                                    if let exif = viewModel.exifMetadata[key], exif.isTagged {
                                        Image(systemName: "flag.fill")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(4)
                                            .background(Circle().fill(Color.red))
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                    
                                    // Star Rating Overlay (bottom-left)
                                    if let exif = viewModel.exifMetadata[key], exif.rating > 0 {
                                        HStack(spacing: 1) {
                                            ForEach(0..<exif.rating, id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 4)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(4)
                                        .padding(6)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                    }
                                }
                                .frame(height: 135)
                                .onTapGesture {
                                    viewModel.selectedImageIndex = index
                                }
                                .simultaneousGesture(TapGesture(count: 2).onEnded {
                                    viewModel.selectedImageIndex = index
                                    viewModel.isDetailActive = true
                                })
                                
                                // Image Label / Filename
                                Text(item.filename)
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundColor(isSelected ? .blue : .primary.opacity(0.85))
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(NSColor.underPageBackgroundColor))
        }
    }
}

// Reusable premium filter button view
struct FilterButton: View {
    var icon: String? = nil
    var label: String
    var isSelected: Bool
    var selectedColor: Color = .blue
    var action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                }
                Text(label)
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? selectedColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? selectedColor.opacity(0.3) : (isHovered ? Color.primary.opacity(0.1) : Color.clear), lineWidth: 1)
            )
            .foregroundColor(isSelected ? selectedColor : .primary.opacity(0.7))
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
