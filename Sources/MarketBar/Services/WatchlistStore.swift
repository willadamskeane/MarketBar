import Foundation
import Combine

public final class WatchlistStore: ObservableObject {
    @Published public var items: [WatchItem] = []
    @Published public var snapshots: [UUID: MarketSnapshot] = [:]
    
    // Global Settings
    @Published public var defaultRefreshIntervalSeconds: Int = 60
    @Published public var decimalPlaces: Int = 0 // 0 for whole %, 1 for 1 decimal, 2 for cents
    @Published public var staleTimeoutSeconds: Int = 300 // 5 minutes
    
    private let fileManager = FileManager.default
    
    private var applicationSupportDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("MarketBar")
        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: nil)
        return appSupport
    }
    
    private var watchlistFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("watchlist.json")
    }
    
    private var snapshotsFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("snapshots.json")
    }
    
    private var settingsFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("settings.json")
    }
    
    public init() {
        loadSettings()
        loadWatchlist()
        loadSnapshots()
    }
    
    // MARK: - Persistence Logic
    
    public func saveWatchlist() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: watchlistFileURL, options: .atomic)
        } catch {
            print("Failed to save watchlist: \(error)")
        }
    }
    
    public func loadWatchlist() {
        guard fileManager.fileExists(atPath: watchlistFileURL.path) else {
            items = []
            return
        }
        do {
            let data = try Data(contentsOf: watchlistFileURL)
            items = try JSONDecoder().decode([WatchItem].self, from: data)
            items.sort { $0.sortOrder < $1.sortOrder }
        } catch {
            print("Failed to load watchlist: \(error)")
            items = []
        }
    }
    
    public func saveSnapshots() {
        do {
            let data = try JSONEncoder().encode(snapshots)
            try data.write(to: snapshotsFileURL, options: .atomic)
        } catch {
            print("Failed to save snapshots: \(error)")
        }
    }
    
    public func loadSnapshots() {
        guard fileManager.fileExists(atPath: snapshotsFileURL.path) else {
            snapshots = [:]
            return
        }
        do {
            let data = try Data(contentsOf: snapshotsFileURL)
            snapshots = try JSONDecoder().decode([UUID: MarketSnapshot].self, from: data)
        } catch {
            print("Failed to load snapshots: \(error)")
            snapshots = [:]
        }
    }
    
    public func saveSettings() {
        struct Settings: Codable {
            var defaultRefreshIntervalSeconds: Int
            var decimalPlaces: Int
            var staleTimeoutSeconds: Int
        }
        let settings = Settings(
            defaultRefreshIntervalSeconds: defaultRefreshIntervalSeconds,
            decimalPlaces: decimalPlaces,
            staleTimeoutSeconds: staleTimeoutSeconds
        )
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsFileURL, options: .atomic)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    public func loadSettings() {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return }
        do {
            struct Settings: Codable {
                var defaultRefreshIntervalSeconds: Int
                var decimalPlaces: Int
                var staleTimeoutSeconds: Int
            }
            let data = try Data(contentsOf: settingsFileURL)
            let settings = try JSONDecoder().decode(Settings.self, from: data)
            self.defaultRefreshIntervalSeconds = settings.defaultRefreshIntervalSeconds
            self.decimalPlaces = settings.decimalPlaces
            self.staleTimeoutSeconds = settings.staleTimeoutSeconds
        } catch {
            print("Failed to load settings: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    @discardableResult
    public func add(urlResult: ParsedURLResult, originalURL: String) -> WatchItem {
        let maxSortOrder = items.map(\.sortOrder).max() ?? -1
        let newItem = WatchItem(
            platform: urlResult.platform,
            originalURL: originalURL,
            externalID: urlResult.externalID,
            slugOrTicker: urlResult.slugOrTicker,
            displayName: urlResult.displayName,
            refreshIntervalSeconds: defaultRefreshIntervalSeconds,
            sortOrder: maxSortOrder + 1
        )
        items.append(newItem)
        saveWatchlist()
        return newItem
    }
    
    public func remove(id: UUID) {
        items.removeAll { $0.id == id }
        snapshots.removeValue(forKey: id)
        saveWatchlist()
        saveSnapshots()
    }
    
    public func update(item: WatchItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveWatchlist()
        }
    }
    
    public func updateSnapshot(itemID: UUID, snapshot: MarketSnapshot) {
        snapshots[itemID] = snapshot
        saveSnapshots()
    }
}
