import Foundation

public struct OutcomeQuote: Codable, Equatable, Identifiable {
    public var id: String // Outcome token ID, ticker, or name
    public var name: String // Outcome label (e.g. "YES", "June 22–June 28")
    public var rawPrice: Double? // Price from main endpoint, if any (0.0 to 1.0)
    public var bid: Double?
    public var ask: Double?
    public var midpoint: Double?
    public var impliedProbability: Double?
    public var normalizedProbability: Double?

    public init(
        id: String,
        name: String,
        rawPrice: Double? = nil,
        bid: Double? = nil,
        ask: Double? = nil,
        midpoint: Double? = nil,
        impliedProbability: Double? = nil,
        normalizedProbability: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.rawPrice = rawPrice
        self.bid = bid
        self.ask = ask
        self.midpoint = midpoint
        self.impliedProbability = impliedProbability
        self.normalizedProbability = normalizedProbability
    }
}
