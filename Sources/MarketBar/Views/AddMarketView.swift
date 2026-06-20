import SwiftUI

class AddMarketViewModel: ObservableObject {
    @Published var input = ""
    @Published var parsedResult: ParsedURLResult?
    @Published var errorMessage: String?
    @Published var customDisplayName = ""
    @Published var selectedSummaryMode: SummaryMode = .auto
}

public struct AddMarketView: View {
    @ObservedObject var store: WatchlistStore
    @ObservedObject var scheduler: RefreshScheduler
    var onDismiss: () -> Void
    
    @StateObject private var viewModel = AddMarketViewModel()
    @FocusState private var isInputFocused: Bool
    
    public init(store: WatchlistStore, scheduler: RefreshScheduler, onDismiss: @escaping () -> Void) {
        self.store = store
        self.scheduler = scheduler
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            Text("Add Market Watcher")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Paste Polymarket/Kalshi URL or Ticker")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("https://polymarket.com/event/...", text: $viewModel.input)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                        .onSubmit {
                            verify()
                        }
                    
                    Button("Verify") {
                        verify()
                    }
                    .disabled(viewModel.input.isEmpty)
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let result = viewModel.parsedResult {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    
                    Text("Detected Market Details")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                        GridRow {
                            Text("Platform:")
                                .fontWeight(.semibold)
                            Text(result.platform.displayName)
                        }
                        GridRow {
                            Text("Identifier:")
                                .fontWeight(.semibold)
                            Text(result.slugOrTicker)
                        }
                    }
                    .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Display Name Override")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(result.displayName, text: $viewModel.customDisplayName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Summary Mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.selectedSummaryMode) {
                            ForEach(SummaryMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
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
                .disabled(viewModel.parsedResult == nil)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: viewModel.parsedResult == nil ? 180 : 380)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
                isInputFocused = true
            }
        }
    }
    
    private func verify() {
        viewModel.errorMessage = nil
        viewModel.parsedResult = nil
        
        do {
            let result = try URLParser.parse(viewModel.input)
            viewModel.parsedResult = result
            viewModel.customDisplayName = result.displayName
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
    
    private func save() {
        guard let result = viewModel.parsedResult else { return }
        
        var urlResult = result
        if !viewModel.customDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            urlResult.displayName = viewModel.customDisplayName
        }
        
        let item = store.add(urlResult: urlResult, originalURL: viewModel.input)
        var updatedItem = item
        updatedItem.summaryMode = viewModel.selectedSummaryMode
        store.update(item: updatedItem)
        
        Task {
            await scheduler.refreshItem(updatedItem)
        }
        
        onDismiss()
    }
}
