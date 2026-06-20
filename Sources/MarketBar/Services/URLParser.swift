import Foundation

public struct ParsedURLResult: Equatable {
    public var platform: Platform
    public var slugOrTicker: String
    public var externalID: String
    public var displayName: String
}

public enum URLParserError: Error, LocalizedError, Equatable {
    case invalidURLOrTicker
    case unsupportedPlatform
    
    public var errorDescription: String? {
        switch self {
        case .invalidURLOrTicker:
            return "Invalid URL or ticker format."
        case .unsupportedPlatform:
            return "Unsupported platform. Only Polymarket and Kalshi are supported."
        }
    }
}

public struct URLParser {
    public static func parse(_ input: String) throws -> ParsedURLResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw URLParserError.invalidURLOrTicker
        }
        
        // Check if it's a URL
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
                throw URLParserError.invalidURLOrTicker
            }
            
            if host.contains("polymarket.com") {
                // Polymarket URL format: https://polymarket.com/event/<slug> or https://polymarket.com/market/<slug>
                let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
                guard pathComponents.count >= 2 else {
                    throw URLParserError.invalidURLOrTicker
                }
                
                let type = pathComponents[0].lowercased()
                let slug = pathComponents[1]
                
                // Remove query parameters if any (handled by URL pathComponents mostly, but query may stick if URL is weird)
                let cleanSlug = slug.components(separatedBy: "?").first ?? slug
                
                guard type == "event" || type == "market" else {
                    throw URLParserError.invalidURLOrTicker
                }
                
                let titleGuess = cleanSlug
                    .replacingOccurrences(of: "-", with: " ")
                    .capitalized
                
                return ParsedURLResult(
                    platform: .polymarket,
                    slugOrTicker: cleanSlug,
                    externalID: cleanSlug,
                    displayName: titleGuess
                )
            } else if host.contains("kalshi.com") {
                // Kalshi URL format: https://kalshi.com/markets/<ticker> or https://kalshi.com/markets/<series>/<ticker>
                let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
                guard pathComponents.count >= 2, pathComponents[0].lowercased() == "markets" else {
                    throw URLParserError.invalidURLOrTicker
                }
                
                let ticker = pathComponents.last!
                let cleanTicker = ticker.components(separatedBy: "?").first ?? ticker
                
                return ParsedURLResult(
                    platform: .kalshi,
                    slugOrTicker: cleanTicker.uppercased(),
                    externalID: cleanTicker.uppercased(),
                    displayName: cleanTicker.uppercased()
                )
            } else {
                throw URLParserError.unsupportedPlatform
            }
        } else {
            // Treat as raw ticker
            if trimmed.contains("/") || trimmed.contains("\\") {
                throw URLParserError.invalidURLOrTicker
            }
            
            return ParsedURLResult(
                platform: .kalshi,
                slugOrTicker: trimmed.uppercased(),
                externalID: trimmed.uppercased(),
                displayName: trimmed.uppercased()
            )
        }
    }
}
