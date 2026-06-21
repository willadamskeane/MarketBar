import SwiftUI

class DropdownViewModel: ObservableObject {
    @Published var activeSheet: DropdownView.ActiveSheet?
    @Published var expandedItems: Set<UUID> = []
}

public struct DropdownView: View {
    @ObservedObject var store: WatchlistStore
    @ObservedObject var scheduler: RefreshScheduler
    
    @StateObject private var viewModel = DropdownViewModel()
    
    public enum ActiveSheet: Identifiable {
        case add
        case edit(WatchItem)
        case settings
        
        public var id: String {
            switch self {
            case .add: return "add"
            case .edit(let item): return "edit-\(item.id.uuidString)"
            case .settings: return "settings"
            }
        }
    }
    
    public init(store: WatchlistStore, scheduler: RefreshScheduler) {
        self.store = store
        self.scheduler = scheduler
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("MarketBar")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    
                    Button {
                        Task {
                            await scheduler.refreshAll()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Refresh All")
                    
                    Button {
                        viewModel.activeSheet = .add
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Add Market")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // Watchlist
                if store.items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("No markets watched")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Button("Add Market") {
                            viewModel.activeSheet = .add
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .background(Color(NSColor.controlBackgroundColor))
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(store.items) { item in
                                let snapshot = store.snapshots[item.id]
                                let status = scheduler.getRefreshStatus(item: item)
                                
                                WatchItemRow(
                                    item: item,
                                    snapshot: snapshot,
                                    status: status,
                                    store: store,
                                    isExpanded: viewModel.expandedItems.contains(item.id),
                                    onToggleExpand: {
                                        if viewModel.expandedItems.contains(item.id) {
                                            viewModel.expandedItems.remove(item.id)
                                        } else {
                                            viewModel.expandedItems.insert(item.id)
                                        }
                                    },
                                    onRefresh: {
                                        Task {
                                            await scheduler.refreshItem(item)
                                        }
                                    },
                                    onEdit: {
                                        viewModel.activeSheet = .edit(item)
                                    },
                                    onRemove: {
                                        store.remove(id: item.id)
                                    }
                                )
                            }
                        }
                        .padding(12)
                    }
                    .frame(maxHeight: 450)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(Color(NSColor.controlBackgroundColor))
                }
                
                Divider()
                
                // Footer
                HStack {
                    Button {
                        viewModel.activeSheet = .settings
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Text("Quit")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .blur(radius: viewModel.activeSheet != nil ? 1.5 : 0.0)
            
            // Inline sheet overlay
            if let sheet = viewModel.activeSheet {
                Color.black.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        viewModel.activeSheet = nil
                    }
                
                VStack {
                    Spacer()
                    switch sheet {
                    case .add:
                        AddMarketView(store: store, scheduler: scheduler) {
                            viewModel.activeSheet = nil
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
                        .shadow(radius: 10)
                        .padding(10)
                    case .edit(let item):
                        EditWatchItemView(store: store, item: item) {
                            viewModel.activeSheet = nil
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
                        .shadow(radius: 10)
                        .padding(10)
                    case .settings:
                        SettingsView(store: store) {
                            viewModel.activeSheet = nil
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
                        .shadow(radius: 10)
                        .padding(10)
                    }
                    Spacer()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 320)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.activeSheet != nil)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - WatchItemRow Component

struct WatchItemRow: View {
    var item: WatchItem
    var snapshot: MarketSnapshot?
    var status: String
    @ObservedObject var store: WatchlistStore
    var isExpanded: Bool
    var onToggleExpand: () -> Void
    var onRefresh: () -> Void
    var onEdit: () -> Void
    var onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main Row Info
            Button {
                onToggleExpand()
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName.isEmpty ? (snapshot?.title ?? item.slugOrTicker) : item.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 4) {
                            Text(item.platform.displayName)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                            Text("·")
                            if let snap = snapshot {
                                Text("Updated \(formatTime(snap.fetchedAt))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Never updated")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if let snap = snapshot {
                        let summary = SummaryEngine.deriveSummary(
                            snapshot: snap,
                            watchItem: item,
                            decimalPlaces: store.decimalPlaces
                        )
                        if let prob = summary.probability {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(SummaryEngine.formatProbability(prob, decimalPlaces: store.decimalPlaces))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                if let targetDate = summary.targetDate {
                                    let prefix = summary.compactText.contains("not by") ? "not by" : "by"
                                    Text("\(prefix) \(SummaryEngine.formatDate(targetDate))")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.secondary)
                                } else if let targetValue = summary.targetValue {
                                    Text(targetValue)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Text("—")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("—")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.top, 3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded detail section
            if isExpanded {
                Divider()
                    .padding(.vertical, 2)
                
                if let snap = snapshot {
                    let summary = SummaryEngine.deriveSummary(
                        snapshot: snap,
                        watchItem: item,
                        decimalPlaces: store.decimalPlaces
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Derived Summary")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(summary.detailText)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                        if !summary.explanation.isEmpty {
                            Text(summary.explanation)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding(.bottom, 6)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Outcomes")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ForEach(snap.outcomes) { outcome in
                            let prob = outcome.impliedProbability ?? 0.0
                            let probText = SummaryEngine.formatProbability(prob, decimalPlaces: store.decimalPlaces)
                            
                            HStack {
                                Text(outcome.name)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                Spacer()
                                Text(probText)
                                    .font(.system(size: 11, design: .monospaced))
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue.opacity(0.12))
                                        .frame(width: geo.size.width * CGFloat(prob))
                                }
                            )
                        }
                    }
                    .padding(.bottom, 6)
                    
                    let cumulative = ProbabilityEngine.calculateCumulativeProbabilities(outcomes: snap.outcomes)
                    if !cumulative.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Derived Cumulative Deadlines")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            ForEach(cumulative, id: \.targetDate) { result in
                                let probText = SummaryEngine.formatProbability(result.probability, decimalPlaces: store.decimalPlaces)
                                let dateText = SummaryEngine.formatDate(result.targetDate)
                                
                                HStack {
                                    Text("By \(dateText)")
                                        .font(.system(size: 11))
                                    Spacer()
                                    Text(probText)
                                        .font(.system(size: 11, design: .monospaced))
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.green.opacity(0.12))
                                            .frame(width: geo.size.width * CGFloat(result.probability))
                                    }
                                )
                            }
                        }
                        .padding(.bottom, 6)
                    }
                } else {
                    Text("No snapshots loaded yet.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    if let source = snapshot?.sourceURL ?? item.originalURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: source) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("Open Browser", systemImage: "safari")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Spacer()
                    
                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Refresh Item")
                    
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Edit")
                    
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Remove")
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
