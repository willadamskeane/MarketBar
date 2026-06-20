import Foundation
import Combine

public final class RefreshScheduler: ObservableObject {
    private var store: WatchlistStore
    private var timer: Timer?
    
    @Published private var isRefreshingMap: [UUID: Bool] = [:]
    
    public init(store: WatchlistStore) {
        self.store = store
        startTimer()
    }
    
    public func isRefreshing(itemID: UUID) -> Bool {
        return isRefreshingMap[itemID] ?? false
    }
    
    public func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkAndRefreshItems()
            }
        }
    }
    
    public func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @MainActor
    private func checkAndRefreshItems() async {
        let now = Date()
        for item in store.items {
            guard item.isEnabled else { continue }
            
            let snapshot = store.snapshots[item.id]
            let lastFetched = snapshot?.fetchedAt ?? Date.distantPast
            let elapsed = now.timeIntervalSince(lastFetched)
            
            if elapsed >= Double(item.refreshIntervalSeconds) {
                await refreshItem(item)
            }
        }
    }
    
    @MainActor
    public func refreshItem(_ item: WatchItem) async {
        guard !isRefreshing(itemID: item.id) else { return }
        
        isRefreshingMap[item.id] = true
        
        let snapshot: MarketSnapshot
        switch item.platform {
        case .polymarket:
            snapshot = await PolymarketClient.fetchEventSnapshot(
                watchItemID: item.id,
                slug: item.slugOrTicker,
                originalURL: item.originalURL
            )
        case .kalshi:
            snapshot = await KalshiClient.fetchMarketSnapshot(
                watchItemID: item.id,
                ticker: item.slugOrTicker,
                originalURL: item.originalURL
            )
        }
        
        store.updateSnapshot(itemID: item.id, snapshot: snapshot)
        isRefreshingMap[item.id] = false
    }
    
    @MainActor
    public func refreshAll() async {
        for item in store.items {
            await refreshItem(item)
        }
    }
    
    public func getRefreshStatus(item: WatchItem) -> String {
        if isRefreshing(itemID: item.id) {
            return "Refreshing"
        }
        guard let snapshot = store.snapshots[item.id] else {
            return "Refreshing"
        }
        if snapshot.error != nil {
            return "Error"
        }
        if snapshot.status == .resolved {
            return "Resolved"
        }
        if snapshot.status == .closed {
            return "Closed"
        }
        
        let elapsed = Date().timeIntervalSince(snapshot.fetchedAt)
        if elapsed > Double(store.staleTimeoutSeconds) {
            return "Stale"
        }
        return "Fresh"
    }
}
