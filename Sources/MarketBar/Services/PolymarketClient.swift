import Foundation

fileprivate struct PolymarketMarket: Codable {
    var id: String
    var question: String
    var active: Bool
    var closed: Bool
    var outcomes: [String]
    var clobTokenIds: [String]
    var outcomePrices: [String]?
    var groupItemTitle: String?
    
    enum CodingKeys: String, CodingKey {
        case id, question, active, closed, outcomes, clobTokenIds, outcomePrices, groupItemTitle
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        question = try container.decode(String.self, forKey: .question)
        active = try container.decode(Bool.self, forKey: .active)
        closed = try container.decode(Bool.self, forKey: .closed)
        groupItemTitle = try? container.decode(String.self, forKey: .groupItemTitle)
        
        // Decode outcomes (can be array or stringified JSON array)
        if let directOutcomes = try? container.decode([String].self, forKey: .outcomes) {
            outcomes = directOutcomes
        } else if let stringOutcomes = try? container.decode(String.self, forKey: .outcomes),
                  let data = stringOutcomes.data(using: .utf8) {
            outcomes = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        } else {
            outcomes = []
        }
        
        // Decode clobTokenIds (can be array or stringified JSON array)
        if let directTokens = try? container.decode([String].self, forKey: .clobTokenIds) {
            clobTokenIds = directTokens
        } else if let stringTokens = try? container.decode(String.self, forKey: .clobTokenIds),
                  let data = stringTokens.data(using: .utf8) {
            clobTokenIds = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        } else {
            clobTokenIds = []
        }
        
        // Decode outcomePrices (can be array or stringified JSON array)
        if let directPrices = try? container.decode([String].self, forKey: .outcomePrices) {
            outcomePrices = directPrices
        } else if let stringPrices = try? container.decode(String.self, forKey: .outcomePrices),
                  let data = stringPrices.data(using: .utf8) {
            outcomePrices = try? JSONDecoder().decode([String].self, from: data)
        } else {
            outcomePrices = nil
        }
    }
}

public struct PolymarketClient {
    private static let session = URLSession.shared
    
    public static func fetchEventSnapshot(watchItemID: UUID, slug: String, originalURL: String) async -> MarketSnapshot {
        let eventURLString = "https://gamma-api.polymarket.com/events/slug/\(slug)"
        guard let eventURL = URL(string: eventURLString) else {
            return MarketSnapshot(
                watchItemID: watchItemID,
                platform: .polymarket,
                title: slug,
                status: .unknown,
                error: SnapshotError(message: "Invalid event URL: \(eventURLString)")
            )
        }
        
        do {
            var request = URLRequest(url: eventURL)
            request.timeoutInterval = 10.0
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return MarketSnapshot(
                    watchItemID: watchItemID,
                    platform: .polymarket,
                    title: slug,
                    status: .unknown,
                    error: SnapshotError(message: "Polymarket event API returned non-200 status code.")
                )
            }
            
            struct PolymarketEvent: Codable {
                var title: String
                var active: Bool
                var closed: Bool
                var markets: [PolymarketMarket]
            }
            
            let event = try JSONDecoder().decode(PolymarketEvent.self, from: data)
            
            let marketStatus: MarketStatus = event.closed ? .closed : (event.active ? .active : .unknown)
            
            var outcomeQuotes: [OutcomeQuote] = []
            
            let isMultiMarket = event.markets.count > 1
            
            for market in event.markets {
                let isBinary = market.outcomes.count == 2 &&
                    market.outcomes[0].lowercased() == "yes" &&
                    market.outcomes[1].lowercased() == "no"
                
                if isMultiMarket && isBinary {
                    // For multi-market binary questions, we only keep the "Yes" outcome and rename it to the bucket title
                    let outcomeName = market.outcomes[0]
                    let displayName = (market.groupItemTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? market.question : market.groupItemTitle!
                    
                    let tokenId = !market.clobTokenIds.isEmpty ? market.clobTokenIds[0] : outcomeName
                    
                    var rawPrice: Double? = nil
                    if let prices = market.outcomePrices, !prices.isEmpty {
                        rawPrice = Double(prices[0])
                    }
                    
                    var midpointPrice: Double? = nil
                    if !market.clobTokenIds.isEmpty {
                        midpointPrice = await fetchClobMidpoint(token_id: market.clobTokenIds[0])
                    }
                    
                    let price = midpointPrice ?? rawPrice
                    
                    let quote = OutcomeQuote(
                        id: tokenId,
                        name: displayName,
                        rawPrice: rawPrice,
                        midpoint: midpointPrice,
                        impliedProbability: price
                    )
                    outcomeQuotes.append(quote)
                } else {
                    // Otherwise keep all outcomes as-is
                    for (index, outcomeName) in market.outcomes.enumerated() {
                        let tokenId = index < market.clobTokenIds.count ? market.clobTokenIds[index] : outcomeName
                        
                        var rawPrice: Double? = nil
                        if let prices = market.outcomePrices, index < prices.count {
                            rawPrice = Double(prices[index])
                        }
                        
                        var midpointPrice: Double? = nil
                        if index < market.clobTokenIds.count {
                            let token = market.clobTokenIds[index]
                            midpointPrice = await fetchClobMidpoint(token_id: token)
                        }
                        
                        let price = midpointPrice ?? rawPrice
                        
                        let quote = OutcomeQuote(
                            id: tokenId,
                            name: outcomeName,
                            rawPrice: rawPrice,
                            midpoint: midpointPrice,
                            impliedProbability: price
                        )
                        outcomeQuotes.append(quote)
                    }
                }
            }
            
            return MarketSnapshot(
                watchItemID: watchItemID,
                platform: .polymarket,
                title: event.title,
                status: marketStatus,
                outcomes: outcomeQuotes,
                fetchedAt: Date(),
                sourceURL: originalURL
            )
            
        } catch {
            return MarketSnapshot(
                watchItemID: watchItemID,
                platform: .polymarket,
                title: slug,
                status: .unknown,
                error: SnapshotError(message: error.localizedDescription)
            )
        }
    }
    
    private static func fetchClobMidpoint(token_id: String) async -> Double? {
        let urlString = "https://clob.polymarket.com/midpoint?token_id=\(token_id)"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3.0
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            struct ClobResponse: Codable {
                var mid: String?
            }
            
            let clobRes = try JSONDecoder().decode(ClobResponse.self, from: data)
            if let midStr = clobRes.mid, let midVal = Double(midStr) {
                return midVal
            }
            return nil
        } catch {
            return nil
        }
    }
}
