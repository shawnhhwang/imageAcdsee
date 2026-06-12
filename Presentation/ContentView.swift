import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        NavigationSplitView {
            // Left Sidebar
            FolderTreeView(viewModel: viewModel)
                .frame(minWidth: 200, idealWidth: 240)
        } detail: {
            // Main Content Area
            ZStack {
                // Image Grid view
                ImageGridView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Metal Detail view overlay with fade animation
                if viewModel.isDetailActive {
                    ImageDetailView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeIn(duration: 0.18)),
                            removal: .opacity.animation(.easeOut(duration: 0.15))
                        ))
                        .zIndex(1)
                }
                
                // Loading Overlay
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                        ProgressView("載入中...")
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))
                            )
                    }
                    .zIndex(2)
                }
            }
            .navigationTitle(viewModel.selectedFolder?.lastPathComponent ?? "Project Lumina")
        }
        .frame(minWidth: 1000, minHeight: 600)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
