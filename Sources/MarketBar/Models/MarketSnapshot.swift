import Foundation

public enum MarketStatus: String, Codable, Equatable {
    case active
    case closed
    case resolved
    case unknown
}

public struct SnapshotError: Codable, Equatable {
    public var message: String
    
    public init(message: String) {
        self.message = message
    }
}

public struct MarketSnapshot: Codable, Equatable {
    public var watchItemID: UUID
    public var platform: Platform
    public var title: String
    public var status: MarketStatus
    public var outcomes: [OutcomeQuote]
    public var fetchedAt: Date
    public var sourceURL: String?
    public var error: SnapshotError?

    public init(
        watchItemID: UUID,
        platform: Platform,
        title: String,
        status: MarketStatus = .active,
        outcomes: [OutcomeQuote] = [],
        fetchedAt: Date = Date(),
        sourceURL: String? = nil,
        error: SnapshotError? = nil
    ) {
        self.watchItemID = watchItemID
        self.platform = platform
        self.title = title
        self.status = status
        self.outcomes = outcomes
        self.fetchedAt = fetchedAt
        self.sourceURL = sourceURL
        self.error = error
    }
}
