import SwiftUI

class EditWatchItemViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var summaryMode: SummaryMode = .auto
    @Published var refreshIntervalSeconds = 60
    @Published var pinnedOutcomeID: String = ""
    @Published var isEnabled = true
}

public struct EditWatchItemView: View {
    @ObservedObject var store: WatchlistStore
    var item: WatchItem
    var onDismiss: () -> Void
    
    @StateObject private var viewModel = EditWatchItemViewModel()
    @FocusState private var isNameFocused: Bool
    
    let intervals = [
        (30, "30 seconds"),
        (60, "1 minute"),
        (120, "2 minutes"),
        (300, "5 minutes"),
        (900, "15 minutes")
    ]
    
    public init(store: WatchlistStore, item: WatchItem, onDismiss: @escaping () -> Void) {
        self.store = store
        self.item = item
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            Text("Edit Market Watcher")
                .font(.headline)
            
            Form {
                TextField("Display Name", text: $viewModel.displayName)
                    .focused($isNameFocused)
                
                Picker("Summary Mode", selection: $viewModel.summaryMode) {
                    ForEach(SummaryMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                
                if viewModel.summaryMode == .customPinnedOutcome {
                    if let snapshot = store.snapshots[item.id], !snapshot.outcomes.isEmpty {
                        Picker("Pinned Outcome", selection: $viewModel.pinnedOutcomeID) {
                            Text("Select Outcome").tag("")
                            ForEach(snapshot.outcomes) { outcome in
                                Text(outcome.name).tag(outcome.id)
                            }
                        }
                    } else {
                        TextField("Pinned Outcome Name/ID", text: $viewModel.pinnedOutcomeID)
                    }
                }
                
                Picker("Refresh Interval", selection: $viewModel.refreshIntervalSeconds) {
                    ForEach(intervals, id: \.0) { interval in
                        Text(interval.1).tag(interval.0)
                    }
                }
                
                Toggle("Enabled", isOn: $viewModel.isEnabled)
            }
            .formStyle(.automatic)
            .onAppear {
                viewModel.displayName = item.displayName
                viewModel.summaryMode = item.summaryMode
                viewModel.refreshIntervalSeconds = item.refreshIntervalSeconds
                viewModel.pinnedOutcomeID = item.pinnedOutcomeID ?? ""
                viewModel.isEnabled = item.isEnabled
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.activate(ignoringOtherApps: true)
                    isNameFocused = true
                }
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: viewModel.summaryMode == .customPinnedOutcome ? 320 : 270)
    }
    
    private func save() {
        var updated = item
        updated.displayName = viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.displayName : viewModel.displayName
        updated.summaryMode = viewModel.summaryMode
        updated.pinnedOutcomeID = viewModel.pinnedOutcomeID.isEmpty ? nil : viewModel.pinnedOutcomeID
        updated.refreshIntervalSeconds = viewModel.refreshIntervalSeconds
        updated.isEnabled = viewModel.isEnabled
        updated.updatedAt = Date()
        
        store.update(item: updated)
        onDismiss()
    }
}
