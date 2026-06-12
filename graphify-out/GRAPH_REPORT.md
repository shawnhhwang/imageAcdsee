# Graph Report - .  (2026-06-12)

## Corpus Check
- Corpus is ~10,710 words - fits in a single context window. You may not need a graph.

## Summary
- 222 nodes · 295 edges · 28 communities (12 shown, 16 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]

## God Nodes (most connected - your core abstractions)
1. `AppViewModel` - 23 edges
2. `CodingKeys` - 21 edges
3. `ImageMetadata` - 9 edges
4. `ExifCacheRepository` - 8 edges
5. `Coordinator` - 8 edges
6. `SecurityScopedBookmarkManager` - 7 edges
7. `DirectoryMonitor` - 7 edges
8. `SQLiteDatabase` - 7 edges
9. `FolderNode` - 7 edges
10. `ImageItem` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Zero-Import Architecture` --rationale_for--> `SecurityScopedBookmarkManager`  [INFERRED]
  SPEC.md → App/Security/SecurityScopedBookmarkManager.swift
- `Three-Layer Caching` --conceptually_related_to--> `ExifCacheRepository`  [INFERRED]
  wiki.md → Data/Repositories/ExifCacheRepository.swift
- `Zero-Import Architecture` --conceptually_related_to--> `FileSystemRepository`  [INFERRED]
  wiki.md → Data/Repositories/FileSystemRepository.swift
- `Project Lumina API/System Specification` --references--> `FolderNode`  [EXTRACTED]
  SPEC.md → Domain/Models/FolderNode.swift
- `Project Lumina API/System Specification` --references--> `ImageItem`  [EXTRACTED]
  SPEC.md → Domain/Models/ImageItem.swift

## Hyperedges (group relationships)
- **Domain Model Entities** — foldernode_foldernode, imageitem_imageitem, imagemetadata_imagemetadata [INFERRED 0.95]
- **Fast Keyboard Culling Workflow** — appviewmodel_appviewmodel, imagedetailview_imagedetailview, imagegridview_imagegridview, readme_acdsee_culling_shortcuts [INFERRED 0.95]

## Communities (28 total, 16 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.07
Nodes (21): MTKView, MTKViewDelegate, NSView, NSViewRepresentable, View, Color, FolderTreeView, Coordinator (+13 more)

### Community 1 - "Community 1"
Cohesion: 0.19
Nodes (3): ObservableObject, AppViewModel, KeyCode

### Community 2 - "Community 2"
Cohesion: 0.1
Nodes (9): App, AppDelegate, ProjectLuminaApp, CacheEntry, MemoryCache, FileSystemRepositoryProtocol, NSApplicationDelegate, NSObject (+1 more)

### Community 3 - "Community 3"
Cohesion: 0.1
Nodes (20): CodingKey, CodingKeys, appConfiguration, diskCacheLimitGigabytes, enableRealtimeFSEvents, environment, fileSystem, fsEventsDebounceMilliseconds (+12 more)

### Community 4 - "Community 4"
Cohesion: 0.12
Nodes (8): Equatable, ExifCacheRepositoryProtocol, Hashable, Identifiable, FolderNode, ImageItem, ImageMetadata, ExifCacheRepository

### Community 5 - "Community 5"
Cohesion: 0.28
Nodes (10): Codable, AppConfiguration, AppSettings, FileSystemSettings, LoggingSettings, RenderingSettings, ThumbnailSizeSettings, ExifCacheRepositoryProtocol (+2 more)

### Community 6 - "Community 6"
Cohesion: 0.17
Nodes (13): AppDelegate, ProjectLuminaApp, ExifCacheRepository, FileSystemRepository, ImageMetadata, DirectoryMonitor, ImageLoaderService, AppViewModel (+5 more)

### Community 7 - "Community 7"
Cohesion: 0.31
Nodes (6): LoggerManager, LogLevel, debug, error, info, String

### Community 12 - "Community 12"
Cohesion: 0.47
Nodes (6): FileSystemRepositoryProtocol, FolderNode, ImageItem, Roo Code Initial Prompt, Project Lumina API/System Specification, AI Micro-Task Split List

### Community 13 - "Community 13"
Cohesion: 0.5
Nodes (3): ContentView, ContentView_Previews, PreviewProvider

### Community 14 - "Community 14"
Cohesion: 0.67
Nodes (3): FolderTreeView, SecurityScopedBookmarkManager, Zero-Import Architecture

## Knowledge Gaps
- **43 isolated node(s):** `environment`, `maxMemoryCacheMegabytes`, `diskCacheLimitGigabytes`, `supportedExtensions`, `enableRealtimeFSEvents` (+38 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ImageMetadata` connect `Community 4` to `Community 8`, `Community 1`, `Community 5`?**
  _High betweenness centrality (0.255) - this node is a cross-community bridge._
- **Why does `Coordinator` connect `Community 0` to `Community 2`?**
  _High betweenness centrality (0.249) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `ImageMetadata` (e.g. with `.extractMetadata()` and `.getMetadata()`) actually correct?**
  _`ImageMetadata` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `environment`, `maxMemoryCacheMegabytes`, `diskCacheLimitGigabytes` to the rest of the system?**
  _43 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._