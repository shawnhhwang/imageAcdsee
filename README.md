# Project Lumina - Mac 原生極速影像瀏覽與快速選片器

Project Lumina 是一款專為 macOS 設計、以「檔案系統為核心 (File-System Driven)」的極速影像瀏覽與專業挑選（Culling）工具。其靈感源自經典的 ACDSee，旨在解決傳統相簿軟體強制「匯入」的緩慢等待，提供零延遲、高效能且安全的本地影像操作體驗。

## 🏗️ 系統架構 (Clean Architecture)
* **`App`**：應用程式生命週期管理、權限控制（Security-Scoped Bookmarks）。
* **`Domain`**：核心業務模型與介面定義（ImageItem, FolderNode）。
* **`Data`**：資料夾讀寫（FileSystemRepository）、EXIF 本地快取（GRDB SQLite）。
* **`Presentation`**：SwiftUI 原生極速網格、詳細資訊 HUD 與自訂視圖。
* **`Infrastructure`**：FSEvents 資料夾變更監聽、GPU 影像解碼（ImageIO & Metal）、系統級高靈敏度鍵盤攔截器。

---

## ⌨️ 專業挑圖快捷鍵對照表 (ACDSee Culling Shortcuts)

為了實現無滑鼠的極速盲操選片，Project Lumina 整合了系統級的快速鍵處理。以下是支援的核心快捷鍵：

| 快捷鍵 | 對應功能 | 設計用途 |
| :--- | :--- | :--- |
| **`左 / 右方向鍵`** | 上一張 / 下一張 | 快速瀏覽相鄰影像 |
| **`上 / 下方向鍵`** | 跳至第一張 / 最後一張 | 快速跳轉至首尾照片 |
| **`1` - `5` 鍵** | 設定星級評等 (1-5 星) | 將照片歸類星等 |
| **`0` 鍵** | 清除星級評等 | 取消當前照片的星等 |
| **`T` 鍵** | 切換已標記 / 未標記 (Tag) | 快速勾選要保留的照片 |
| **`Cmd + Delete`** | 安全刪除照片（移至垃圾桶） | 挑片時快速汰換不良照片 |
| **`空白鍵 (Space)`** | 進入 / 退出高解析度詳細檢視 | 快速放大看清細節 |
| **`ESC 鍵`** | 退出詳細檢視 | 返回多圖網格畫面 |
| **`Z` 鍵 / 雙擊滑鼠** | 切換照片適應視窗 / 滿版放大 | 100% 滿版像素對焦檢查 |
| **`F` 鍵 / `Enter`** | 切換 macOS 原生全螢幕 | 沉浸式無干擾挑圖體驗 |

