#!/bin/bash
set -e

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy all source files
mkdir -p "$TEMP_DIR/Sources"
cp Sources/MarketBar/Models/*.swift "$TEMP_DIR/Sources/"
cp Sources/MarketBar/Services/URLParser.swift "$TEMP_DIR/Sources/"
cp Sources/MarketBar/Services/OutcomeParser.swift "$TEMP_DIR/Sources/"
cp Sources/MarketBar/Services/ProbabilityEngine.swift "$TEMP_DIR/Sources/"
cp Sources/MarketBar/Services/SummaryEngine.swift "$TEMP_DIR/Sources/"

# Copy all test files, stripping XCTest imports and prepending import Foundation
mkdir -p "$TEMP_DIR/Tests"
for f in Tests/MarketBarTests/*Tests.swift; do
    basename=$(basename "$f")
    echo "import Foundation" > "$TEMP_DIR/Tests/$basename"
    sed -e 's/import XCTest//g' -e 's/@testable import MarketBar//g' "$f" >> "$TEMP_DIR/Tests/$basename"
done

# Create mock XCTest classes and the main entry point
cat << 'EOF' > "$TEMP_DIR/Tests/MockXCTest.swift"
import Foundation

open class XCTestCase {
    public init() {}
}

public func XCTAssertEqual<T: Equatable>(_ expr1: T, _ expr2: T, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    if expr1 != expr2 {
        print("❌ Assertion Failed: \"\(expr1)\" is not equal to \"\(expr2)\" - \(msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTAssertEqual<T: FloatingPoint>(_ expr1: T, _ expr2: T, accuracy: T, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    if abs(expr1 - expr2) > accuracy {
        print("❌ Assertion Failed: \"\(expr1)\" is not within \(accuracy) of \"\(expr2)\" - \(msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTAssertNotNil(_ expr: Any?, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    if expr == nil {
        print("❌ Assertion Failed: expression is nil - \(msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTAssertNil(_ expr: Any?, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    if expr != nil {
        print("❌ Assertion Failed: expression is not nil - \(msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTAssertTrue(_ expr: Bool, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    if !expr {
        print("❌ Assertion Failed: expression is false - \(msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTAssertFalse(_ expr: Bool, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
    if expr {
        print("❌ Assertion Failed: expression is true - \(msg) at \(file):\(line)")
        exit(1)
    }
}

public func XCTAssertThrowsError<T>(_ expr: @autoclosure () throws -> T, _ msg: String = "", file: StaticString = #file, line: UInt = #line, _ errorHandler: (Error) -> Void = { _ in }) {
    do {
        _ = try expr()
        print("❌ Assertion Failed: Did not throw error - \(msg) at \(file):\(line)")
        exit(1)
    } catch {
        errorHandler(error)
    }
}

@main
struct TestRunner {
    static func main() {
        print("🚀 Running MarketBar Custom Test Suite...")
        
        do {
            let parserTests = URLParserTests()
            try parserTests.testPolymarketEventURL()
            try parserTests.testPolymarketEventURLWithQueryParams()
            try parserTests.testPolymarketMarketURL()
            try parserTests.testKalshiURL()
            try parserTests.testKalshiTickerInput()
            parserTests.testInvalidURL()
            print("  ✅ URLParserTests passed.")
        } catch {
            print("  ❌ URLParserTests failed with error: \(error)")
            exit(1)
        }
        
        let outcomeTests = OutcomeParserTests()
        outcomeTests.testDateRange()
        outcomeTests.testNumericShorthandRange()
        outcomeTests.testNotByDate()
        outcomeTests.testBeforeDate()
        outcomeTests.testAfterDate()
        outcomeTests.testQuarter()
        outcomeTests.testUnknownLabel()
        print("  ✅ OutcomeParserTests passed.")
        
        let probTests = ProbabilityEngineTests()
        probTests.testBinaryYesPrice()
        probTests.testMultiOutcomeNormalization()
        probTests.testCumulativeDateCalculation()
        print("  ✅ ProbabilityEngineTests passed.")
        
        let summaryTests = SummaryEngineTests()
        summaryTests.testBinaryYesSummary()
        summaryTests.testLeadingOutcomeSummary()
        summaryTests.testCumulativeDateSummary()
        print("  ✅ SummaryEngineTests passed.")
        
        print("🎉 All tests passed successfully!")
    }
}
EOF

# Compile
swiftc "$TEMP_DIR/Sources/"*.swift "$TEMP_DIR/Tests/"*.swift -o "$TEMP_DIR/test_runner"

# Run
"$TEMP_DIR/test_runner"
