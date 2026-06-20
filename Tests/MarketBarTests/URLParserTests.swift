import XCTest
@testable import MarketBar

final class URLParserTests: XCTestCase {
    func testPolymarketEventURL() throws {
        let url = "https://polymarket.com/event/when-will-gpt-5pt6-be-released"
        let result = try URLParser.parse(url)
        XCTAssertEqual(result.platform, .polymarket)
        XCTAssertEqual(result.slugOrTicker, "when-will-gpt-5pt6-be-released")
        XCTAssertEqual(result.externalID, "when-will-gpt-5pt6-be-released")
        XCTAssertEqual(result.displayName, "When Will Gpt 5Pt6 Be Released")
    }
    
    func testPolymarketEventURLWithQueryParams() throws {
        let url = "https://polymarket.com/event/when-will-gpt-5pt6-be-released?someParam=value&other=123"
        let result = try URLParser.parse(url)
        XCTAssertEqual(result.platform, .polymarket)
        XCTAssertEqual(result.slugOrTicker, "when-will-gpt-5pt6-be-released")
    }
    
    func testPolymarketMarketURL() throws {
        let url = "https://polymarket.com/market/will-gpt-5pt6-be-released-before-july"
        let result = try URLParser.parse(url)
        XCTAssertEqual(result.platform, .polymarket)
        XCTAssertEqual(result.slugOrTicker, "will-gpt-5pt6-be-released-before-july")
    }
    
    func testKalshiURL() throws {
        let url = "https://kalshi.com/markets/KXHIGHNY-24JAN01-T60"
        let result = try URLParser.parse(url)
        XCTAssertEqual(result.platform, .kalshi)
        XCTAssertEqual(result.slugOrTicker, "KXHIGHNY-24JAN01-T60")
        XCTAssertEqual(result.externalID, "KXHIGHNY-24JAN01-T60")
    }
    
    func testKalshiTickerInput() throws {
        let ticker = "KXHIGHNY-24JAN01-T60"
        let result = try URLParser.parse(ticker)
        XCTAssertEqual(result.platform, .kalshi)
        XCTAssertEqual(result.slugOrTicker, "KXHIGHNY-24JAN01-T60")
    }
    
    func testInvalidURL() {
        let invalid = "https://example.com/event/slug"
        XCTAssertThrowsError(try URLParser.parse(invalid)) { error in
            XCTAssertEqual(error as? URLParserError, .unsupportedPlatform)
        }
    }
}
