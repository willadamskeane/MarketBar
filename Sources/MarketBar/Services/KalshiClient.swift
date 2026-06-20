import Foundation

public struct KalshiClient {
    private static let session = URLSession.shared
    
    public static func fetchMarketSnapshot(watchItemID: UUID, ticker: String, originalURL: String) async -> MarketSnapshot {
        let urlString = "https://external-api.kalshi.com/trade-api/v2/markets/\(ticker)"
        guard let url = URL(string: urlString) else {
            return MarketSnapshot(
                watchItemID: watchItemID,
                platform: .kalshi,
                title: ticker,
                status: .unknown,
                error: SnapshotError(message: "Invalid Kalshi market URL/ticker: \(urlString)")
            )
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return MarketSnapshot(
                    watchItemID: watchItemID,
                    platform: .kalshi,
                    title: ticker,
                    status: .unknown,
                    error: SnapshotError(message: "Kalshi market API returned non-200 status code.")
                )
            }
            
            struct KalshiMarketContainer: Codable {
                var market: KalshiMarket
            }
            
            struct KalshiMarket: Codable {
                var ticker: String
                var title: String
                var status: String
                var yes_bid: Int?
                var yes_ask: Int?
                var no_bid: Int?
                var no_ask: Int?
                var last_price: Int?
            }
            
            let container = try JSONDecoder().decode(KalshiMarketContainer.self, from: data)
            let market = container.market
            
            let marketStatus: MarketStatus
            switch market.status.lowercased() {
            case "active":
                marketStatus = .active
            case "closed":
                marketStatus = .closed
            case "determined", "finalized":
                marketStatus = .resolved
            default:
                marketStatus = .unknown
            }
            
            var yesBidPrice: Double? = nil
            if let bid = market.yes_bid { yesBidPrice = Double(bid) / 100.0 }
            var yesAskPrice: Double? = nil
            if let ask = market.yes_ask { yesAskPrice = Double(ask) / 100.0 }
            var yesLastPrice: Double? = nil
            if let last = market.last_price { yesLastPrice = Double(last) / 100.0 }
            
            var yesMidpoint: Double? = nil
            if let bid = yesBidPrice, let ask = yesAskPrice {
                yesMidpoint = (bid + ask) / 2.0
            }
            let yesImplied = yesMidpoint ?? yesLastPrice
            
            var noBidPrice: Double? = nil
            if let bid = market.no_bid { noBidPrice = Double(bid) / 100.0 }
            var noAskPrice: Double? = nil
            if let ask = market.no_ask { noAskPrice = Double(ask) / 100.0 }
            
            var noMidpoint: Double? = nil
            if let bid = noBidPrice, let ask = noAskPrice {
                noMidpoint = (bid + ask) / 2.0
            }
            let noImplied = noMidpoint ?? (yesImplied != nil ? (1.0 - yesImplied!) : nil)
            
            let yesQuote = OutcomeQuote(
                id: "YES",
                name: "YES",
                rawPrice: yesLastPrice,
                bid: yesBidPrice,
                ask: yesAskPrice,
                midpoint: yesMidpoint,
                impliedProbability: yesImplied
            )
            
            let noQuote = OutcomeQuote(
                id: "NO",
                name: "NO",
                rawPrice: yesLastPrice != nil ? (1.0 - yesLastPrice!) : nil,
                bid: noBidPrice,
                ask: noAskPrice,
                midpoint: noMidpoint,
                impliedProbability: noImplied
            )
            
            return MarketSnapshot(
                watchItemID: watchItemID,
                platform: .kalshi,
                title: market.title,
                status: marketStatus,
                outcomes: [yesQuote, noQuote],
                fetchedAt: Date(),
                sourceURL: originalURL
            )
            
        } catch {
            return MarketSnapshot(
                watchItemID: watchItemID,
                platform: .kalshi,
                title: ticker,
                status: .unknown,
                error: SnapshotError(message: error.localizedDescription)
            )
        }
    }
}
