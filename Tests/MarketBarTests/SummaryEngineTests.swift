import XCTest
@testable import MarketBar

final class SummaryEngineTests: XCTestCase {
    let watchItemID = UUID()
    
    func testBinaryYesSummary() {
        let watchItem = WatchItem(
            id: watchItemID,
            platform: .kalshi,
            originalURL: "KXHIGHNY-24JAN01-T60",
            externalID: "KXHIGHNY-24JAN01-T60",
            slugOrTicker: "KXHIGHNY-24JAN01-T60",
            displayName: "NYC Temp 90°",
            summaryMode: .binaryYes
        )
        
        let yesQuote = OutcomeQuote(id: "YES", name: "YES", impliedProbability: 0.72)
        let noQuote = OutcomeQuote(id: "NO", name: "NO", impliedProbability: 0.28)
        
        let snapshot = MarketSnapshot(
            watchItemID: watchItemID,
            platform: .kalshi,
            title: "Will NYC Temp hit 90°?",
            outcomes: [yesQuote, noQuote]
        )
        
        let summary = SummaryEngine.deriveSummary(snapshot: snapshot, watchItem: watchItem)
        XCTAssertEqual(summary.compactText, "NYC Temp 90°: 72%")
        XCTAssertEqual(summary.probability, 0.72)
    }
    
    func testLeadingOutcomeSummary() {
        let watchItem = WatchItem(
            id: watchItemID,
            platform: .polymarket,
            originalURL: "https://polymarket.com/event/some-slug",
            externalID: "some-slug",
            slugOrTicker: "some-slug",
            displayName: "Next Fed Cut",
            summaryMode: .leadingOutcome
        )
        
        let o1 = OutcomeQuote(id: "1", name: "September", impliedProbability: 0.71)
        let o2 = OutcomeQuote(id: "2", name: "November", impliedProbability: 0.20)
        let o3 = OutcomeQuote(id: "3", name: "No Cut", impliedProbability: 0.09)
        
        let snapshot = MarketSnapshot(
            watchItemID: watchItemID,
            platform: .polymarket,
            title: "When is the next Fed Rate cut?",
            outcomes: [o1, o2, o3]
        )
        
        let summary = SummaryEngine.deriveSummary(snapshot: snapshot, watchItem: watchItem)
        XCTAssertEqual(summary.compactText, "Next Fed Cut (September): 71%")
        XCTAssertEqual(summary.probability, 0.71)
    }
    
    func testCumulativeDateSummary() {
        let watchItem = WatchItem(
            id: watchItemID,
            platform: .polymarket,
            originalURL: "https://polymarket.com/event/when-will-gpt-5pt6-be-released",
            externalID: "when-will-gpt-5pt6-be-released",
            slugOrTicker: "when-will-gpt-5pt6-be-released",
            displayName: "GPT-5.6",
            summaryMode: .cumulativeByDate
        )
        
        let o1 = OutcomeQuote(id: "1", name: "June 15–June 21", impliedProbability: 0.01)
        let o2 = OutcomeQuote(id: "2", name: "June 22–June 28", impliedProbability: 0.53)
        let o3 = OutcomeQuote(id: "3", name: "Not released by June 28", impliedProbability: 0.47)
        
        let snapshot = MarketSnapshot(
            watchItemID: watchItemID,
            platform: .polymarket,
            title: "When will GPT-5.6 be released?",
            outcomes: [o1, o2, o3]
        )
        
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 20
        let currentDate = Calendar.current.date(from: comps)!
        
        let summary = SummaryEngine.deriveSummary(
            snapshot: snapshot,
            watchItem: watchItem,
            decimalPlaces: 0,
            currentDate: currentDate
        )
        
        XCTAssertEqual(summary.compactText, "GPT-5.6: 53% by Jun 28")
        XCTAssertEqual(summary.probability, 0.53)
    }
}
