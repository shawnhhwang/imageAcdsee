# Logging & Exif Cache

> 19 nodes · cohesion 0.15

## Key Concepts

- **ExifCacheRepository** (8 connections) — `Data/Repositories/ExifCacheRepository.swift`
- **LoggerManager** (6 connections) — `Infrastructure/Logging/LoggerManager.swift`
- **.log()** (6 connections) — `Infrastructure/Logging/LoggerManager.swift`
- **LogLevel** (6 connections) — `Infrastructure/Logging/LoggerManager.swift`
- **.setupLogFile()** (4 connections) — `Infrastructure/Logging/LoggerManager.swift`
- **String** (4 connections)
- **error** (3 connections) — `Infrastructure/Logging/LoggerManager.swift`
- **.getMetadata()** (3 connections) — `Data/Repositories/ExifCacheRepository.swift`
- **LoggerManager.swift** (2 connections) — `Infrastructure/Logging/LoggerManager.swift`
- **.init()** (2 connections) — `Infrastructure/Logging/LoggerManager.swift`
- **debug** (2 connections) — `Infrastructure/Logging/LoggerManager.swift`
- **info** (2 connections) — `Infrastructure/Logging/LoggerManager.swift`
- **ExifCacheRepository.swift** (1 connections) — `Data/Repositories/ExifCacheRepository.swift`
- **ExifCacheRepositoryProtocol** (1 connections)
- **.deinit()** (1 connections) — `Infrastructure/Logging/LoggerManager.swift`
- **.init()** (1 connections) — `Data/Repositories/ExifCacheRepository.swift`
- **.saveMetadata()** (1 connections) — `Data/Repositories/ExifCacheRepository.swift`
- **.updateRating()** (1 connections) — `Data/Repositories/ExifCacheRepository.swift`
- **.updateTagged()** (1 connections) — `Data/Repositories/ExifCacheRepository.swift`

## Relationships

- [[Models & Settings]] (3 shared connections)
- [[AppViewModel]] (1 shared connections)
- [[Settings CodingKeys]] (1 shared connections)

## Source Files

- `Data/Repositories/ExifCacheRepository.swift`
- `Infrastructure/Logging/LoggerManager.swift`

## Audit Trail

- EXTRACTED: 51 (93%)
- INFERRED: 4 (7%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*