import Foundation

public struct ParsedOutcome: Codable, Equatable {
    public var outcomeID: String
    public var label: String
    public var startDate: Date?
    public var endDate: Date?
    public var isNotByDate: Bool
    public var isAfterDate: Bool
    public var isBeforeDate: Bool
    public var isDateBucket: Bool
    public var confidence: SummaryConfidence

    public init(
        outcomeID: String,
        label: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isNotByDate: Bool = false,
        isAfterDate: Bool = false,
        isBeforeDate: Bool = false,
        isDateBucket: Bool = false,
        confidence: SummaryConfidence = .high
    ) {
        self.outcomeID = outcomeID
        self.label = label
        self.startDate = startDate
        self.endDate = endDate
        self.isNotByDate = isNotByDate
        self.isAfterDate = isAfterDate
        self.isBeforeDate = isBeforeDate
        self.isDateBucket = isDateBucket
        self.confidence = confidence
    }
}
