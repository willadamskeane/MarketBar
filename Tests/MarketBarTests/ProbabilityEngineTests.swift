import XCTest
@testable import MarketBar

final class ProbabilityEngineTests: XCTestCase {
    
    func testBinaryYesPrice() {
        let yes = OutcomeQuote(id: "YES", name: "YES", impliedProbability: 0.64)
        let no = OutcomeQuote(id: "NO", name: "NO", impliedProbability: 0.36)
        
        let normalized = ProbabilityEngine.normalize(outcomes: [yes, no])
        XCTAssertEqual(normalized[0].normalizedProbability, 0.64)
        XCTAssertEqual(normalized[1].normalizedProbability, 0.36)
    }
    
    func testMultiOutcomeNormalization() {
        let o1 = OutcomeQuote(id: "1", name: "A", impliedProbability: 0.50)
        let o2 = OutcomeQuote(id: "2", name: "B", impliedProbability: 0.40)
        let o3 = OutcomeQuote(id: "3", name: "C", impliedProbability: 0.20)
        
        let normalized = ProbabilityEngine.normalize(outcomes: [o1, o2, o3])
        XCTAssertEqual(normalized[0].normalizedProbability!, 0.50 / 1.10, accuracy: 0.0001)
        XCTAssertEqual(normalized[1].normalizedProbability!, 0.40 / 1.10, accuracy: 0.0001)
        XCTAssertEqual(normalized[2].normalizedProbability!, 0.20 / 1.10, accuracy: 0.0001)
    }
    
    func testCumulativeDateCalculation() {
        let o1 = OutcomeQuote(id: "1", name: "June 15–June 21", impliedProbability: 0.01)
        let o2 = OutcomeQuote(id: "2", name: "June 22–June 28", impliedProbability: 0.53)
        let o3 = OutcomeQuote(id: "3", name: "Not released by June 28", impliedProbability: 0.47)
        
        let results = ProbabilityEngine.calculateCumulativeProbabilities(outcomes: [o1, o2, o3], defaultYear: 2026)
        
        XCTAssertTrue(results.count >= 2)
        
        let june28Res = results.first { result in
            let day = Calendar.current.component(.day, from: result.targetDate)
            let month = Calendar.current.component(.month, from: result.targetDate)
            return month == 6 && day == 28
        }
        
        XCTAssertNotNil(june28Res)
        XCTAssertEqual(june28Res?.probability, 0.53)
        XCTAssertEqual(june28Res?.confidence, .high)
    }
}
