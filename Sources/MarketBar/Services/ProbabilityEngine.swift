import Foundation

public struct ProbabilityEngine {
    
    // Normalize probabilities of outcomes
    public static func normalize(outcomes: [OutcomeQuote]) -> [OutcomeQuote] {
        guard !outcomes.isEmpty else { return outcomes }
        
        let sum = outcomes.compactMap { $0.impliedProbability }.reduce(0.0, +)
        
        var normalized = outcomes
        if sum > 0.0 {
            for i in 0..<normalized.count {
                if let p = normalized[i].impliedProbability {
                    normalized[i].normalizedProbability = p / sum
                }
            }
        }
        return normalized
    }
    
    public struct CumulativeResult: Equatable {
        public var targetDate: Date
        public var probability: Double
        public var confidence: SummaryConfidence
        public var explanation: String
        
        public init(targetDate: Date, probability: Double, confidence: SummaryConfidence, explanation: String) {
            self.targetDate = targetDate
            self.probability = probability
            self.confidence = confidence
            self.explanation = explanation
        }
    }
    
    // Calculate cumulative probability for date buckets
    public static func calculateCumulativeProbabilities(
        outcomes: [OutcomeQuote],
        defaultYear: Int = 2026
    ) -> [CumulativeResult] {
        let parsed = outcomes.map { quote -> (quote: OutcomeQuote, parsed: ParsedOutcome) in
            let p = OutcomeParser.parse(outcomeID: quote.id, label: quote.name, defaultYear: defaultYear)
            return (quote, p)
        }
        
        let dateOutcomes = parsed.filter { $0.parsed.isDateBucket }
        guard !dateOutcomes.isEmpty else { return [] }
        
        var deadlines: Set<Date> = []
        for item in dateOutcomes {
            if let endDate = item.parsed.endDate {
                deadlines.insert(endDate)
            }
            if let startDate = item.parsed.startDate {
                // For start dates of after-ranges, they represent the day boundary (e.g. after June 30 is by June 30)
                // Let's use start date minus 1 day as the deadline for "by date"
                if item.parsed.isAfterDate {
                    if let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: startDate) {
                        deadlines.insert(dayBefore)
                    }
                } else {
                    deadlines.insert(startDate)
                }
            }
        }
        
        var results: [CumulativeResult] = []
        let calendar = Calendar.current
        
        for deadline in deadlines {
            var directSum = 0.0
            var hasDirectComponents = false
            
            for item in dateOutcomes {
                let parsed = item.parsed
                let prob = item.quote.impliedProbability ?? 0.0
                
                if !parsed.isNotByDate && !parsed.isAfterDate {
                    if let end = parsed.endDate, end <= deadline {
                        directSum += prob
                        hasDirectComponents = true
                    }
                }
            }
            
            var complementProb: Double? = nil
            var complementName = ""
            
            for item in dateOutcomes {
                let parsed = item.parsed
                let prob = item.quote.impliedProbability ?? 0.0
                
                if parsed.isNotByDate, let end = parsed.endDate, isSameDay(end, deadline) {
                    complementProb = 1.0 - prob
                    complementName = item.quote.name
                    break
                }
                
                if parsed.isAfterDate, let start = parsed.startDate {
                    // e.g. "After June 30" start is July 1 (or June 30 late).
                    // If deadline is June 30, it is the complement of "After June 30".
                    // Let's check if the start date of the "after" is the day after the deadline.
                    if let nextDay = calendar.date(byAdding: .day, value: 1, to: deadline), isSameDay(start, nextDay) || isSameDay(start, deadline) {
                        complementProb = 1.0 - prob
                        complementName = item.quote.name
                        break
                    }
                }
            }
            
            let finalProb: Double
            let confidence: SummaryConfidence
            let explanation: String
            
            if let compVal = complementProb {
                if hasDirectComponents {
                    let diff = abs(directSum - compVal)
                    if diff > 0.05 {
                        finalProb = compVal // Prefer complement as it's typically a direct single-outcome market contract
                        confidence = .low
                        explanation = "Direct sum (\(Int(round(directSum * 100)))%) and complement \(complementName) (\(Int(round(compVal * 100)))%) disagree."
                    } else {
                        finalProb = compVal
                        confidence = .high
                        explanation = "Agreed within tolerance. Direct sum: \(Int(round(directSum * 100)))%, complement: \(Int(round(compVal * 100)))%."
                    }
                } else {
                    finalProb = compVal
                    confidence = .high
                    explanation = "Derived from complement of \(complementName)."
                }
            } else {
                finalProb = directSum
                confidence = hasDirectComponents ? .high : .low
                explanation = "Sum of date buckets."
            }
            
            results.append(CumulativeResult(
                targetDate: deadline,
                probability: finalProb,
                confidence: confidence,
                explanation: explanation
            ))
        }
        
        return results.sorted { $0.targetDate < $1.targetDate }
    }
    
    private static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }
}
