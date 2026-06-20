import SwiftUI

public struct MenuBarLabelView: View {
    @ObservedObject var store: WatchlistStore
    @ObservedObject var scheduler: RefreshScheduler
    
    public init(store: WatchlistStore, scheduler: RefreshScheduler) {
        self.store = store
        self.scheduler = scheduler
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
            
            if let topItem = store.items.first(where: { $0.isEnabled }),
               let snapshot = store.snapshots[topItem.id] {
                
                let summary = SummaryEngine.deriveSummary(
                    snapshot: snapshot,
                    watchItem: topItem,
                    decimalPlaces: store.decimalPlaces
                )
                
                let status = scheduler.getRefreshStatus(item: topItem)
                
                Text(summary.compactText)
                    .font(.system(.body, design: .default).monospacedDigit())
                    .foregroundColor(status == "Stale" || status == "Error" ? .secondary : .primary)
                
                if status == "Refreshing" {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                } else if status == "Error" {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 10))
                } else if status == "Stale" {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))
                }
            }
        }
    }
}
