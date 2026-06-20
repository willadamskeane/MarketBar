import Foundation

public enum Platform: String, Codable, CaseIterable, Identifiable {
    case polymarket
    case kalshi
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .polymarket: return "Polymarket"
        case .kalshi: return "Kalshi"
        }
    }
}
