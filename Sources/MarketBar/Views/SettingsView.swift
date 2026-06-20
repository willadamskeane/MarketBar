import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var defaultInterval = 60
    @Published var decimalPlaces = 0
    @Published var staleTimeout = 300
}

public struct SettingsView: View {
    @ObservedObject var store: WatchlistStore
    var onDismiss: () -> Void
    
    @StateObject private var viewModel = SettingsViewModel()
    
    let intervals = [
        (30, "30 seconds"),
        (60, "1 minute"),
        (120, "2 minutes"),
        (300, "5 minutes"),
        (900, "15 minutes")
    ]
    
    let precisions = [
        (0, "Whole percent (e.g. 53%)"),
        (1, "One decimal (e.g. 53.2%)"),
        (2, "Cents (e.g. 53¢)")
    ]
    
    let timeouts = [
        (120, "2 minutes"),
        (300, "5 minutes"),
        (900, "15 minutes")
    ]
    
    public init(store: WatchlistStore, onDismiss: @escaping () -> Void) {
        self.store = store
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            Text("MarketBar Settings")
                .font(.headline)
            
            Form {
                Picker("Default Interval", selection: $viewModel.defaultInterval) {
                    ForEach(intervals, id: \.0) { item in
                        Text(item.1).tag(item.0)
                    }
                }
                
                Picker("Probability Format", selection: $viewModel.decimalPlaces) {
                    ForEach(precisions, id: \.0) { item in
                        Text(item.1).tag(item.0)
                    }
                }
                
                Picker("Stale Data Warning", selection: $viewModel.staleTimeout) {
                    ForEach(timeouts, id: \.0) { item in
                        Text(item.1).tag(item.0)
                    }
                }
            }
            .formStyle(.automatic)
            .onAppear {
                viewModel.defaultInterval = store.defaultRefreshIntervalSeconds
                viewModel.decimalPlaces = store.decimalPlaces
                viewModel.staleTimeout = store.staleTimeoutSeconds
            }
            
            Spacer()
            
            HStack {
                Button("Close") {
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
        .frame(height: 210)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func save() {
        store.defaultRefreshIntervalSeconds = viewModel.defaultInterval
        store.decimalPlaces = viewModel.decimalPlaces
        store.staleTimeoutSeconds = viewModel.staleTimeout
        store.saveSettings()
        onDismiss()
    }
}
