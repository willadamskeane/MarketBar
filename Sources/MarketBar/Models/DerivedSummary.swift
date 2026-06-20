import Foundation

public enum SummaryConfidence: String, Codable, Equatable {
    case high
    case low
}

public struct DerivedSummary: Codable, Equatable {
    public var title: String
    public var compactText: String
    public var detailText: String
    public var probability: Double? // Value between 0.0 and 1.0
    public var targetDate: Date?
    public var targetValue: String?
    public var confidence: SummaryConfidence
    public var explanation: String

    public init(
        title: String,
        compactText: String,
        detailText: String,
        probability: Double? = nil,
        targetDate: Date? = nil,
        targetValue: String? = nil,
        confidence: SummaryConfidence = .high,
        explanation: String = ""
    ) {
        self.title = title
        self.compactText = compactText
        self.detailText = detailText
        self.probability = probability
        self.targetDate = targetDate
        self.targetValue = targetValue
        self.confidence = confidence
        self.explanation = explanation
    }
}
