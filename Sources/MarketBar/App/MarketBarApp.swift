import SwiftUI

@main
struct MarketBarApp: App {
    @StateObject private var store: WatchlistStore
    @StateObject private var scheduler: RefreshScheduler
    
    init() {
        let storeInstance = WatchlistStore()
        _store = StateObject(wrappedValue: storeInstance)
        _scheduler = StateObject(wrappedValue: RefreshScheduler(store: storeInstance))
    }
    
    var body: some Scene {
        MenuBarExtra {
            DropdownView(store: store, scheduler: scheduler)
        } label: {
            MenuBarLabelView(store: store, scheduler: scheduler)
        }
        .menuBarExtraStyle(.window)
    }
}
