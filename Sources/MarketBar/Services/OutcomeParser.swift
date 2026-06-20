import Foundation

public struct OutcomeParser {
    
    // Parse individual outcome label into ParsedOutcome
    public static func parse(outcomeID: String, label: String, defaultYear: Int = 2026) -> ParsedOutcome {
        let cleanedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleanedLabel.lowercased()
        
        // 1. Quarters: "Q3 2026" or "Q4 2025"
        if let quarterMatch = parseQuarter(lower) {
            var compsStart = DateComponents()
            compsStart.year = quarterMatch.year
            compsStart.month = (quarterMatch.quarter - 1) * 3 + 1
            compsStart.day = 1
            
            var compsEnd = DateComponents()
            compsEnd.year = quarterMatch.year
            compsEnd.month = quarterMatch.quarter * 3
            compsEnd.day = quarterMatch.quarter == 1 || quarterMatch.quarter == 4 ? 31 : 30 // Q1 (Mar 31), Q2 (Jun 30), Q3 (Sep 30), Q4 (Dec 31)
            compsEnd.hour = 23
            compsEnd.minute = 59
            compsEnd.second = 59
            
            let calendar = Calendar.current
            return ParsedOutcome(
                outcomeID: outcomeID,
                label: cleanedLabel,
                startDate: calendar.date(from: compsStart),
                endDate: calendar.date(from: compsEnd),
                isDateBucket: true,
                confidence: .high
            )
        }
        
        // 2. Full Years: "2026" or "2027"
        if let yearVal = Int(lower), yearVal >= 2020 && yearVal <= 2100 {
            var compsStart = DateComponents()
            compsStart.year = yearVal
            compsStart.month = 1
            compsStart.day = 1
            
            var compsEnd = DateComponents()
            compsEnd.year = yearVal
            compsEnd.month = 12
            compsEnd.day = 31
            compsEnd.hour = 23
            compsEnd.minute = 59
            compsEnd.second = 59
            
            let calendar = Calendar.current
            return ParsedOutcome(
                outcomeID: outcomeID,
                label: cleanedLabel,
                startDate: calendar.date(from: compsStart),
                endDate: calendar.date(from: compsEnd),
                isDateBucket: true,
                confidence: .high
            )
        }
        
        // 3. Not by date: "not released by June 28" or "not by June 28"
        if lower.contains("not by") || lower.contains("not released by") {
            if let date = extractDate(from: lower, defaultYear: defaultYear) {
                return ParsedOutcome(
                    outcomeID: outcomeID,
                    label: cleanedLabel,
                    endDate: date,
                    isNotByDate: true,
                    isDateBucket: true,
                    confidence: .high
                )
            }
        }
        
        // 4. Before date: "before july 1"
        if lower.hasPrefix("before") || lower.contains(" prior to ") {
            if let date = extractDate(from: lower, defaultYear: defaultYear) {
                return ParsedOutcome(
                    outcomeID: outcomeID,
                    label: cleanedLabel,
                    endDate: date,
                    isBeforeDate: true,
                    isDateBucket: true,
                    confidence: .high
                )
            }
        }
        
        // 5. After date: "after june 30" or "in 2027 or later"
        if lower.contains("after") || lower.contains("or later") {
            if let date = extractDate(from: lower, defaultYear: defaultYear) {
                return ParsedOutcome(
                    outcomeID: outcomeID,
                    label: cleanedLabel,
                    startDate: date,
                    isAfterDate: true,
                    isDateBucket: true,
                    confidence: .high
                )
            }
        }
        
        // 6. By date: "by june 28"
        if lower.hasPrefix("by ") {
            if let date = extractDate(from: lower, defaultYear: defaultYear) {
                return ParsedOutcome(
                    outcomeID: outcomeID,
                    label: cleanedLabel,
                    endDate: date,
                    isBeforeDate: true, // "by date" is cumulative/before date
                    isDateBucket: true,
                    confidence: .high
                )
            }
        }
        
        // 7. Date range: "june 22–june 28" or "june 15–21"
        // Try splitting by common dashes
        let dashes = ["–", "—", "-"]
        for dash in dashes {
            let parts = cleanedLabel.components(separatedBy: dash)
            if parts.count == 2 {
                let firstPart = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let secondPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let start = parseDateString(firstPart, defaultYear: defaultYear) {
                    var endString = secondPart
                    
                    // If second part is just a number (e.g., "15-21"), prepends month from first part
                    let isNumericOnly = secondPart.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
                    if isNumericOnly, let monthWord = getMonthName(from: firstPart) {
                        endString = "\(monthWord) \(secondPart)"
                    }
                    
                    if let end = parseDateString(endString, defaultYear: defaultYear) {
                        return ParsedOutcome(
                            outcomeID: outcomeID,
                            label: cleanedLabel,
                            startDate: start,
                            endDate: end,
                            isDateBucket: true,
                            confidence: .high
                        )
                    }
                }
            }
        }
        
        // 8. Single Date default: "June 22" (interpreted as ending on this date or target date)
        if let singleDate = parseDateString(cleanedLabel, defaultYear: defaultYear) {
            return ParsedOutcome(
                outcomeID: outcomeID,
                label: cleanedLabel,
                endDate: singleDate,
                isDateBucket: true,
                confidence: .high
            )
        }
        
        // Fallback: low confidence
        return ParsedOutcome(
            outcomeID: outcomeID,
            label: cleanedLabel,
            confidence: .low
        )
    }
    
    // MARK: - Helpers
    
    private static func parseQuarter(_ input: String) -> (quarter: Int, year: Int)? {
        // e.g. "q3 2026"
        let pattern = "q([1-4])\\s+(\\d{4})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = input as NSString
        let results = regex.matches(in: input, options: [], range: NSRange(location: 0, length: nsString.length))
        
        guard let match = results.first, match.numberOfRanges == 3 else { return nil }
        let qStr = nsString.substring(with: match.range(at: 1))
        let yStr = nsString.substring(with: match.range(at: 2))
        
        if let q = Int(qStr), let y = Int(yStr) {
            return (q, y)
        }
        return nil
    }
    
    private static func extractDate(from input: String, defaultYear: Int) -> Date? {
        // Clean out words like "not released by", "before", "after", "or later"
        let cleaned = input
            .replacingOccurrences(of: "not released by", with: "")
            .replacingOccurrences(of: "not by", with: "")
            .replacingOccurrences(of: "before", with: "")
            .replacingOccurrences(of: "after", with: "")
            .replacingOccurrences(of: "or later", with: "")
            .replacingOccurrences(of: "by", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if there is a year at the end, e.g. "june 28 2026" or "june 28"
        return parseDateString(cleaned, defaultYear: defaultYear)
    }
    
    private static func getMonthName(from input: String) -> String? {
        let months = [
            "january", "jan", "february", "feb", "march", "mar",
            "april", "apr", "may", "june", "jun", "july", "jul",
            "august", "aug", "september", "sep", "october", "oct",
            "november", "nov", "december", "dec"
        ]
        let lower = input.lowercased()
        for month in months {
            if lower.contains(month) {
                return month
            }
        }
        return nil
    }
    
    public static func parseDateString(_ input: String, defaultYear: Int) -> Date? {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let months = [
            "january": 1, "jan": 1,
            "february": 2, "feb": 2,
            "march": 3, "mar": 3,
            "april": 4, "apr": 4,
            "may": 5,
            "june": 6, "jun": 6,
            "july": 7, "jul": 7,
            "august": 8, "aug": 8,
            "september": 9, "sep": 9,
            "october": 10, "oct": 10,
            "november": 11, "nov": 11,
            "december": 12, "dec": 12
        ]
        
        for (monthName, monthVal) in months {
            if cleaned.contains(monthName) {
                // Find all numbers in the string
                let numbers = cleaned.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .filter { !$0.isEmpty }
                    .compactMap { Int($0) }
                
                if numbers.count >= 1 {
                    let day = numbers[0]
                    var year = defaultYear
                    if numbers.count >= 2 {
                        let possibleYear = numbers[1]
                        if possibleYear >= 2020 && possibleYear <= 2100 {
                            year = possibleYear
                        } else if possibleYear >= 20 && possibleYear <= 99 {
                            year = 2000 + possibleYear
                        }
                    }
                    
                    var comps = DateComponents()
                    comps.year = year
                    comps.month = monthVal
                    comps.day = day
                    comps.hour = 23
                    comps.minute = 59
                    comps.second = 59
                    return Calendar.current.date(from: comps)
                }
            }
        }
        
        // Check if it's just a year
        if let yearVal = Int(cleaned), yearVal >= 2020 && yearVal <= 2100 {
            var comps = DateComponents()
            comps.year = yearVal
            comps.month = 12
            comps.day = 31
            comps.hour = 23
            comps.minute = 59
            comps.second = 59
            return Calendar.current.date(from: comps)
        }
        
        return nil
    }
}
