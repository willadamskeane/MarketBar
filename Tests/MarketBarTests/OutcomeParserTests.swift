import XCTest
@testable import MarketBar

final class OutcomeParserTests: XCTestCase {
    let year = 2026
    
    func testDateRange() {
        let label = "June 22–June 28"
        let p = OutcomeParser.parse(outcomeID: "1", label: label, defaultYear: year)
        XCTAssertTrue(p.isDateBucket)
        XCTAssertNotNil(p.startDate)
        XCTAssertNotNil(p.endDate)
        XCTAssertEqual(p.confidence, .high)
        
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.month, from: p.startDate!), 6)
        XCTAssertEqual(cal.component(.day, from: p.startDate!), 22)
        XCTAssertEqual(cal.component(.month, from: p.endDate!), 6)
        XCTAssertEqual(cal.component(.day, from: p.endDate!), 28)
    }
    
    func testNumericShorthandRange() {
        let label = "June 15–21"
        let p = OutcomeParser.parse(outcomeID: "2", label: label, defaultYear: year)
        XCTAssertTrue(p.isDateBucket)
        XCTAssertNotNil(p.startDate)
        XCTAssertNotNil(p.endDate)
        
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.month, from: p.startDate!), 6)
        XCTAssertEqual(cal.component(.day, from: p.startDate!), 15)
        XCTAssertEqual(cal.component(.month, from: p.endDate!), 6)
        XCTAssertEqual(cal.component(.day, from: p.endDate!), 21)
    }
    
    func testNotByDate() {
        let label = "Not released by June 28"
        let p = OutcomeParser.parse(outcomeID: "3", label: label, defaultYear: year)
        XCTAssertTrue(p.isNotByDate)
        XCTAssertNotNil(p.endDate)
        
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.month, from: p.endDate!), 6)
        XCTAssertEqual(cal.component(.day, from: p.endDate!), 28)
    }
    
    func testBeforeDate() {
        let label = "Before July 1"
        let p = OutcomeParser.parse(outcomeID: "4", label: label, defaultYear: year)
        XCTAssertTrue(p.isBeforeDate)
        XCTAssertNotNil(p.endDate)
        
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.month, from: p.endDate!), 7)
        XCTAssertEqual(cal.component(.day, from: p.endDate!), 1)
    }
    
    func testAfterDate() {
        let label = "After June 30"
        let p = OutcomeParser.parse(outcomeID: "5", label: label, defaultYear: year)
        XCTAssertTrue(p.isAfterDate)
        XCTAssertNotNil(p.startDate)
        
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.month, from: p.startDate!), 6)
        XCTAssertEqual(cal.component(.day, from: p.startDate!), 30)
    }
    
    func testQuarter() {
        let label = "Q3 2026"
        let p = OutcomeParser.parse(outcomeID: "6", label: label, defaultYear: year)
        XCTAssertTrue(p.isDateBucket)
        XCTAssertNotNil(p.startDate)
        XCTAssertNotNil(p.endDate)
        
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.month, from: p.startDate!), 7)
        XCTAssertEqual(cal.component(.day, from: p.startDate!), 1)
        XCTAssertEqual(cal.component(.month, from: p.endDate!), 9)
        XCTAssertEqual(cal.component(.day, from: p.endDate!), 30)
    }
    
    func testUnknownLabel() {
        let label = "Some ambiguous text"
        let p = OutcomeParser.parse(outcomeID: "7", label: label, defaultYear: year)
        XCTAssertFalse(p.isDateBucket)
        XCTAssertEqual(p.confidence, .low)
    }
}
