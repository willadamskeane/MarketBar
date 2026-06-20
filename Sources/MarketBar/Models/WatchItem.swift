import Foundation

public enum SummaryMode: String, Codable, CaseIterable, Identifiable {
    case auto
    case leadingOutcome
    case cumulativeByDate
    case binaryYes
    case notByDate
    case customPinnedOutcome
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .leadingOutcome: return "Leading Outcome"
        case .cumulativeByDate: return "Cumulative By Date"
        case .binaryYes: return "Binary YES"
        case .notByDate: return "Not By Date"
        case .customPinnedOutcome: return "Pinned Outcome"
        }
    }
}

public struct WatchItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var platform: Platform
    public var originalURL: String
    public var externalID: String // For Polymarket, this is the event ID or market ID. For Kalshi, this is the ticker.
    public var slugOrTicker: String // The slug or ticker used for URL display / API fetching.
    public var displayName: String
    public var summaryMode: SummaryMode
    public var pinnedOutcomeID: String?
    public var refreshIntervalSeconds: Int
    public var isEnabled: Bool
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        platform: Platform,
        originalURL: String,
        externalID: String,
        slugOrTicker: String,
        displayName: String,
        summaryMode: SummaryMode = .auto,
        pinnedOutcomeID: String? = nil,
        refreshIntervalSeconds: Int = 60,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.platform = platform
        self.originalURL = originalURL
        self.externalID = externalID
        self.slugOrTicker = slugOrTicker
        self.displayName = displayName
        self.summaryMode = summaryMode
        self.pinnedOutcomeID = pinnedOutcomeID
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
