# Project Lumina - Wiki 

歡迎來到 Project Lumina 的官方 Wiki！Project Lumina 是一款專為 macOS 設計、原生編譯、以「檔案系統為核心 (File-System Driven)」的極速影像瀏覽軟體，為專業攝影師、設計師與重視效能的使用者量身打造，提供類似 ACDSee 的零延遲、高效能影像管理體驗。

## 🌟 核心理念與特色

Project Lumina 主打 **Zero-Import Architecture (零匯入檔案架構)**，打破了 macOS 內建相簿強制匯入的繁瑣流程。

- **隨選即用**：直接綁定本地資料夾，無需等待漫長的資料庫匯入即可開始瀏覽。
- **極速盲操**：支援純鍵盤操作進行極速挑圖 (Culling)，左手按數字鍵評分，右手按方向鍵切換。
- **即時同步**：底層透過 `FSEvents` API，實時監聽目錄異動，當外部工具增刪圖片時，App 內部視圖無縫更新。
- **滑鼠手勢支援**：支援觸控板雙指左右滑動、滑鼠滾輪水平滑動進行圖片切換，完美還原原生操作手感。

## 🏗 系統架構與技術棧

專案採用 Clean Architecture 概念構建，確保各模組高度解耦與可測試性：

- **App**: 應用程式生命週期 (`ProjectLuminaApp`) 與安全性權限管理 (`SecurityScopedBookmarkManager`)。
- **Domain**: 定義核心商業模型，如 `ImageItem`、`ImageMetadata` 以及各式協定 (Protocols)。
- **Data**: 負責 SQLite 快取庫封裝、以及本機檔案系統的抽象 (`FileSystemRepository`)。
- **Presentation**: 透過 SwiftUI (網格/側邊欄) 與 Metal (`MTKView` 高效渲染引擎) 提供極致 120 FPS 渲染。
- **Infrastructure**: 底層基礎建設，涵蓋 `DirectoryMonitor`、記憶體快取、Logger 日誌等。

## ⚡ 效能與極限渲染

- **Three-Layer Caching Strategy (三層快取策略)**
  1. **記憶體 (Memory Cache)**：保留近期使用的縮圖與解析度縮減貼圖。
  2. **磁碟 (Disk Cache)**：透過 SQLite 高速讀取與寫入照片中繼資料 (EXIF、標籤、評分)，避免反覆進行磁碟 I/O。
  3. **實體檔案 (File System)**：只在需要原圖渲染時，才會動態載入高解析度原始檔。

- **Look-Ahead Prefetching Engine (預載入引擎)**
  - 利用 Swift Concurrency 在背景靜默預載入當前影像的相鄰影像 (前後各兩張)，達成切換圖片時的 **0 毫秒延遲 (Zero-Latency Rendering)**。

## 🎨 介面與功能亮點

1. **Culling Rating & Tags (選片評級系統)**
   - 使用數字鍵 `1` ~ `5` 進行評等，`0` 取消。按下 `T` 鍵切換標籤狀態。配合上方工具列能進行即時過濾篩選。
2. **Safe Trash Management (安全資源回收)**
   - 使用 `Cmd + Delete` 快速將不滿意的圖片移動至「資源回收桶」而非永久刪除，系統將即時清理相關快取並切換至下一張圖。
3. **Details Sidebar (詳情側邊欄)**
   - 側邊欄可獨立於主要顯示區之外，詳細顯示相機型號、光圈、快門、ISO、焦距等 EXIF 資訊，並具備優雅的 Glassmorphism 毛玻璃視覺設計。
4. **Luminance Histogram (亮度直方圖)**
   - 透過 Core Image 實時解析影像的 256 個灰階 Bin，並利用 Metal 加速繪製即時直方圖，協助攝影師判斷曝光狀態。

## 📚 進階開發與知識圖譜 (Knowledge Graph)

如果您是開發者，可以參考由 graphify 建立的分析報告，深入理解模組間的交互關係：
- [Graphify 報告](file:///Users/shawnwang/Documents/agy/image3/graphify-out/GRAPH_REPORT.md)
- [互動式視覺化架構圖](file:///Users/shawnwang/Documents/agy/image3/graphify-out/graph.html)
- [Wiki 知識圖譜詳細文檔](file:///Users/shawnwang/Documents/agy/image3/graphify-out/wiki/index.md)

---
*文件更新時間：2026-06-01*
