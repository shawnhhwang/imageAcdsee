# Project Lumina - Mac 原生極速影像瀏覽器 API/系統規格書

## 1. 專案概述 (Overview)
Project Lumina 是一款專為 macOS 設計、原生編譯、以「檔案系統為核心 (File-System Driven)」的極速影像瀏覽軟體。旨在解決系統內建相簿強制匯入的問題，提供類似 ACDSee 的零延遲、高效能影像管理體驗。

## 2. 使用者案例 (User Stories)
* **專業攝影師/設計師**：透過純鍵盤操作進行極速盲操挑圖 (Culling)，無需等待圖片匯入即可預覽 RAW 檔。
* **資料夾管理者**：在 App 內瀏覽圖片時，能即時反映 Finder 中的檔案變動（新增、刪除、移動），無需手動重新整理。
* **注重隱私的使用者**：所有影像解析、快取處理與元數據 (EXIF) 讀取皆在裝置本地 (On-Device) 處理，無資料外洩風險。

## 3. 功能規範與系統架構 (Functional Specifications)

### 3.1 零匯入檔案架構 (Zero-Import Architecture)
* **實體路徑綁定**：使用 macOS `Security-Scoped Bookmarks` 取得資料夾持久性存取權限。
* **即時檔案監控**：透過 `FSEvents` API，背景監聽目錄樹異動，動態更新 UI 與本地 SQLite 快取，確保「資料一致性」。

### 3.2 極限渲染與快取機制 (Performance & Caching)
* **三層快取策略**：
  1. 記憶體快取 (Memory Cache, `NSCache`)：存放當前與預先載入的縮圖。
  2. 磁碟快取 (Disk Cache)：透過 SQLite 儲存 EXIF 數據與中等解析度縮圖。
  3. 實體檔案 (File System)：高解析度大圖/RAW 檔。
* **Metal API 渲染**：利用 Core Image 與 Metal 進行影像縮放硬體加速，維持 ProMotion 螢幕下的 120 FPS 流暢度。

### 3.3 系統架構定義 (Folder Structure - Clean Architecture)
```text
ProjectLumina/
├── App/                  # 生命週期 (App.swift, AppDelegate), 權限管理
├── Domain/               # 核心模型 (ImageItem, FolderNode), Protocols
├── Data/                 # 實作層 (FileSystemRepository, GRDB SQLite Provider)
├── Presentation/         # SwiftUI 視圖與 ViewModels (Main, Sidebar, Grid)
└── Infrastructure/       # FSEvents 監聽器, OSLog 日誌封裝, 效能監控

### 3.4 星級與標籤系統 (Culling Ratings & Tags)
* **評分與標記**：為照片新增 0-5 星評等（數字鍵 `1` - `5` 進行評等，`0` 取消）與標籤 flag（`T` 鍵切換標記）。
* **快取整合**：星級與標籤資訊必須持久化儲存在快取資料庫（SQLite），並設計快照機制以實現毫秒級無延遲載入。
* **網格過濾**：主畫面頂端需支援即時篩選（如：僅顯示星級大於 3 的照片，或僅顯示已標記的照片）。

### 3.5 安全性檔案操作 (Safe Culling & File Management)
* **資源回收桶整合**：在詳細檢視或網格選取照片時，按下 `Cmd + Delete` 快速鍵，會將實體影像檔案安全地移動至 macOS 的「資源回收桶」（Trash），而非直接抹除，保障資料安全。
* **自動垃圾清理與同步**：當檔案移動至垃圾桶後，底層資料庫快取將自動同步刪除對應快取紀錄，網格畫面即時重新載入並自動選取下一張照片。

### 3.6 預載入與快取強化 (Look-Ahead Prefetching Engine)
* **雙向背景快取**：當使用者停留在第 `N` 張照片時，預載入引擎會自動在背景啟動 Actor，非同步加載 `N-2`, `N-1`, `N+1`, `N+2` 共四張鄰近圖片的 Exif 資訊與紋理快取。
* **無縫切換**：當按下左右方向鍵切換照片時，可無痛達成接近 0 毫秒的零卡頓渲染。

### 3.7 影像分析與邊欄 HUD (Image Analysis & Details Sidebar)
* **亮度直方圖 (Luminance Histogram)**：利用 Core Image 與背景線程計算影像像素亮度分佈，即時產生 256 個灰階 Bin 的統計數值，並於詳細檢視視圖的角落繪製流暢的半透明直方圖曲線。
* **右側資訊邊欄 (Right Details HUD)**：設計可摺疊式的右側 HUD 面板，完整呈現 EXIF 與檔案核心資訊（包含光圈、快門、ISO、焦距、相機型號、檔案體積大小、建立日期與完整實體檔案路徑）。