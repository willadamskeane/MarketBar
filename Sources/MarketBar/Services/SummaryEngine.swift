import Foundation

public struct SummaryEngine {
    
    public static func deriveSummary(
        snapshot: MarketSnapshot,
        watchItem: WatchItem,
        decimalPlaces: Int = 0,
        currentDate: Date = Date()
    ) -> DerivedSummary {
        
        let displayName = watchItem.displayName.isEmpty ? snapshot.title : watchItem.displayName
        
        // 1. Error state handling
        if let error = snapshot.error {
            return DerivedSummary(
                title: displayName,
                compactText: "Error",
                detailText: error.message,
                confidence: .low,
                explanation: "Fetch error: \(error.message)"
            )
        }
        
        // 2. Closed/Resolved handling
        if snapshot.status == .resolved {
            return DerivedSummary(
                title: displayName,
                compactText: "Resolved",
                detailText: "This market has resolved.",
                confidence: .high,
                explanation: "Market resolved"
            )
        }
        
        // Ensure we have outcomes
        guard !snapshot.outcomes.isEmpty else {
            return DerivedSummary(
                title: displayName,
                compactText: "—",
                detailText: "No outcomes available.",
                confidence: .low,
                explanation: "Empty outcome list"
            )
        }
        
        // Determine mode to use
        var mode = watchItem.summaryMode
        if mode == .auto {
            // Auto detect: check if there are date buckets
            let cumulative = ProbabilityEngine.calculateCumulativeProbabilities(outcomes: snapshot.outcomes)
            if !cumulative.isEmpty {
                mode = .cumulativeByDate
            } else if snapshot.outcomes.count == 2 {
                // If it is binary YES/NO
                let hasYesNo = snapshot.outcomes.contains { $0.name.uppercased() == "YES" } &&
                               snapshot.outcomes.contains { $0.name.uppercased() == "NO" }
                if hasYesNo {
                    mode = .binaryYes
                } else {
                    mode = .leadingOutcome
                }
            } else {
                mode = .leadingOutcome
            }
        }
        
        // 3. Mode implementations
        switch mode {
        case .binaryYes:
            // Find YES outcome
            if let yesOutcome = snapshot.outcomes.first(where: { $0.name.uppercased() == "YES" }),
               let prob = yesOutcome.impliedProbability {
                let probText = formatProbability(prob, decimalPlaces: decimalPlaces)
                return DerivedSummary(
                    title: displayName,
                    compactText: "\(displayName): \(probText)",
                    detailText: "YES probability: \(probText)",
                    probability: prob,
                    confidence: .high,
                    explanation: "YES outcome probability"
                )
            }
            // Fallback to leading outcome if no YES found
            return deriveLeadingOutcomeSummary(snapshot: snapshot, displayName: displayName, decimalPlaces: decimalPlaces)
            
        case .cumulativeByDate:
            let cumulative = ProbabilityEngine.calculateCumulativeProbabilities(outcomes: snapshot.outcomes)
            guard !cumulative.isEmpty else {
                return deriveLeadingOutcomeSummary(snapshot: snapshot, displayName: displayName, decimalPlaces: decimalPlaces)
            }
            
            let selectedResult = selectBestCumulativeResult(cumulative: cumulative, snapshot: snapshot, currentDate: currentDate)
            
            if let selected = selectedResult {
                let probText = formatProbability(selected.probability, decimalPlaces: decimalPlaces)
                let dateText = formatDate(selected.targetDate)
                return DerivedSummary(
                    title: displayName,
                    compactText: "\(displayName): \(probText) by \(dateText)",
                    detailText: "Cumulative probability by \(dateText): \(probText)",
                    probability: selected.probability,
                    targetDate: selected.targetDate,
                    confidence: selected.confidence,
                    explanation: selected.explanation
                )
            }
            
            return deriveLeadingOutcomeSummary(snapshot: snapshot, displayName: displayName, decimalPlaces: decimalPlaces)
            
        case .notByDate:
            let cumulative = ProbabilityEngine.calculateCumulativeProbabilities(outcomes: snapshot.outcomes)
            guard !cumulative.isEmpty else {
                return deriveLeadingOutcomeSummary(snapshot: snapshot, displayName: displayName, decimalPlaces: decimalPlaces)
            }
            
            let selectedResult = selectBestCumulativeResult(cumulative: cumulative, snapshot: snapshot, currentDate: currentDate)
            
            if let selected = selectedResult {
                let notProb = 1.0 - selected.probability
                let probText = formatProbability(notProb, decimalPlaces: decimalPlaces)
                let dateText = formatDate(selected.targetDate)
                return DerivedSummary(
                    title: displayName,
                    compactText: "\(displayName) not by \(dateText): \(probText)",
                    detailText: "Probability after \(dateText): \(probText)",
                    probability: notProb,
                    targetDate: selected.targetDate,
                    confidence: selected.confidence,
                    explanation: "Derived as complement (1 - P(by \(dateText)))"
                )
            }
            return deriveLeadingOutcomeSummary(snapshot: snapshot, displayName: displayName, decimalPlaces: decimalPlaces)
            
        case .customPinnedOutcome:
            if let pinnedID = watchItem.pinnedOutcomeID,
               let pinnedOutcome = snapshot.outcomes.first(where: { $0.id == pinnedID || $0.name == pinnedID }),
               let prob = pinnedOutcome.impliedProbability {
                let probText = formatProbability(prob, decimalPlaces: decimalPlaces)
                return DerivedSummary(
                    title: displayName,
                    compactText: "\(displayName) (\(pinnedOutcome.name)): \(probText)",
                    detailText: "\(pinnedOutcome.name) probability: \(probText)",
                    probability: prob,
                    confidence: .high,
                    explanation: "Pinned outcome: \(pinnedOutcome.name)"
                )
            }
            return deriveLeadingOutcomeSummary(snapshot: snapshot, displayName: displayName, decimalPlaces: decimalPlaces)
            
        case .leadingOutcome, .auto:
            return deriveLeadingOutcomeSummary(snapshot: snapshot, displayName: displayName, decimalPlaces: decimalPlaces)
        }
    }
    
    private static func selectBestCumulativeResult(
        cumulative: [ProbabilityEngine.CumulativeResult],
        snapshot: MarketSnapshot,
        currentDate: Date
    ) -> ProbabilityEngine.CumulativeResult? {
        guard !cumulative.isEmpty else { return nil }
        
        var targetDeadline: Date? = nil
        let parsedOutcomes = snapshot.outcomes.map { quote -> (quote: OutcomeQuote, parsed: ParsedOutcome) in
            let p = OutcomeParser.parse(outcomeID: quote.id, label: quote.name)
            return (quote, p)
        }
        
        let dateRanges = parsedOutcomes.filter { !$0.parsed.isNotByDate && !$0.parsed.isAfterDate && $0.parsed.isDateBucket }
        if let leadingRange = dateRanges.max(by: { ($0.quote.impliedProbability ?? 0.0) < ($1.quote.impliedProbability ?? 0.0) }),
           let leadProb = leadingRange.quote.impliedProbability,
           leadProb > 0.10,
           let end = leadingRange.parsed.endDate {
            targetDeadline = end
        }
        
        if let target = targetDeadline,
           let matched = cumulative.first(where: { Calendar.current.isDate($0.targetDate, inSameDayAs: target) }) {
            return matched
        }
        
        for result in cumulative {
            if result.targetDate >= currentDate {
                return result
            }
        }
        
        return cumulative.first
    }
    
    private static func deriveLeadingOutcomeSummary(
        snapshot: MarketSnapshot,
        displayName: String,
        decimalPlaces: Int
    ) -> DerivedSummary {
        var leading: OutcomeQuote? = nil
        for outcome in snapshot.outcomes {
            if let prob = outcome.impliedProbability {
                if leading == nil || prob > (leading?.impliedProbability ?? -1.0) {
                    leading = outcome
                }
            }
        }
        
        if let lead = leading, let prob = lead.impliedProbability {
            let probText = formatProbability(prob, decimalPlaces: decimalPlaces)
            return DerivedSummary(
                title: displayName,
                compactText: "\(displayName) (\(lead.name)): \(probText)",
                detailText: "Leading outcome: \(lead.name) at \(probText)",
                probability: prob,
                confidence: .high,
                explanation: "Highest implied probability outcome"
            )
        }
        
        return DerivedSummary(
            title: displayName,
            compactText: "\(displayName): —",
            detailText: "No active outcome price found.",
            confidence: .low,
            explanation: "No outcome has implied probability"
        )
    }
    
    public static func formatProbability(_ p: Double, decimalPlaces: Int) -> String {
        if p < 0.005 && p > 0.0 {
            return "<1%"
        }
        if p > 0.995 && p < 1.0 {
            return ">99%"
        }
        
        switch decimalPlaces {
        case 0:
            let pct = Int(round(p * 100))
            return "\(pct)%"
        case 1:
            let pct = round(p * 1000) / 10.0
            return String(format: "%.1f%%", pct)
        case 2:
            let cents = Int(round(p * 100))
            return "\(cents)¢"
        default:
            let pct = Int(round(p * 100))
            return "\(pct)%"
        }
    }
    
    public static func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}
