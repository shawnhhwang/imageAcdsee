import SwiftUI

struct FolderTreeView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header / Selector Button
            Button(action: {
                Task {
                    if let selected = await SecurityScopedBookmarkManager.shared.selectFolder() {
                        viewModel.selectFolder(selected)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("開啟資料夾")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.15))
                )
                .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider()
                .padding(.horizontal, 12)
            
            // Current Directory indicator
            if let root = viewModel.selectedFolder {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.amberFolder)
                    Text(root.lastPathComponent)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .foregroundColor(.primary.opacity(0.85))
            }
            
            // Subfolders Tree
            List {
                Section(header: Text("子資料夾").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)) {
                    if viewModel.subfolders.isEmpty {
                        Text("無子資料夾")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    } else {
                        ForEach(viewModel.subfolders) { subfolder in
                            Button(action: {
                                viewModel.selectFolder(subfolder.url)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 12))
                                        .foregroundColor(.amberFolder)
                                    Text(subfolder.name)
                                        .font(.system(size: 12, weight: .regular))
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(viewModel.selectedFolder == subfolder.url ? Color.blue.opacity(0.12) : Color.clear)
                                )
                                .foregroundColor(viewModel.selectedFolder == subfolder.url ? .blue : .primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
    }
}

// Custom color for folder icons
extension Color {
    static let amberFolder = Color(red: 0.95, green: 0.72, blue: 0.20)
}
