# MarketBar 📈

MarketBar is a native macOS menu bar app that lets you monitor Polymarket and Kalshi prediction markets passively. Paste a market or event URL, and MarketBar will display a compact, real-time probability summary directly in your status bar.

---

## Features

- **Native macOS App**: Built with Swift 6 and SwiftUI, running efficiently in the background.
- **Custom Interactive Dropdown**: Styled with a native floating popover including outcome progress bars and cumulative timelines.
- **Derived Cumulative Date Engine**: Automatically parses date range buckets (e.g. `"June 22–June 28"`, `"Not released by June 28"`) and derives the probability of a resolution by specific deadlines.
- **Multiple Summary Modes**: Choose how each watch item represents its status in the menu bar:
  - `Auto` (automatically switches between date-bucket cumulative and binary YES)
  - `Binary YES` (percentage for the YES contract)
  - `Leading Outcome` (highest probability outcome)
  - `Cumulative By Date` (probability by a target date)
  - `Not By Date` (probability after a target date)
  - `Custom Pinned Outcome` (pins a specific contract)
- **Local Caching & Settings**: Persists your watchlist and settings locally in JSON files under Application Support.
- **Micro-Indicators**: Visual feedback in the status bar (refreshing state, warning indicator for stale data, or error status).

---

## Supported Platforms & URL Formats

### 1. Polymarket
- **Event URL**: `https://polymarket.com/event/when-will-gpt-5pt6-be-released`
- **Market URL**: `https://polymarket.com/market/will-gpt-5pt6-be-released-before-july`
- *Data Source*: Fetches metadata from Gamma API and real-time bid/ask midpoint prices from the public CLOB API.

### 2. Kalshi
- **Market URL**: `https://kalshi.com/markets/KXHIGHNY-24JAN01-T60`
- **Manually entered ticker**: `KXHIGHNY-24JAN01-T60` or `FED-26DEC-T4.5`
- *Data Source*: Fetches market metadata and yes/no bids from the public Trade API v2.

---

## Build and Run Instructions

Since the app lives exclusively in the menu bar, it is configured with `LSUIElement = true` in its `Info.plist` so that it runs in the background without showing up in the Dock.

### 1. Build the App Bundle
Run the packaging script to compile and assemble the `MarketBar.app` bundle in the project root:
```bash
./build_app.sh
```

### 2. Run the App
Launch the app from the terminal or double-click `MarketBar.app` in Finder:
```bash
open MarketBar.app
```

---

## Running Unit Tests

To verify that the URL parser, outcome parser, probability engines, and summary engines are working correctly, run:
```bash
./run_tests.sh
```
This runs the full suite of unit tests, compiling the source files alongside a custom test harness to bypass native Command Line Tools framework linkage bugs.

---

## Known Limitations & Caveats

- **Read-Only**: MarketBar is purely a watcher app. It does not support trading, order placement, wallet integration, or portfolio logging.
- **Rate Limits & API Policy**: Uses public, unauthenticated APIs. If Polymarket or Kalshi API endpoints undergo schema changes or impose strict rate limits, data fetching may degrade or show stale warnings.
- **Date Parser Heuristics**: Outcome parsing uses regular expression heuristics to extract calendar dates and quarters. Highly custom/ambiguous outcome labels may resolve with lower confidence.

---

## Disclaimer

**No-Trading Disclaimer**: This software is provided for informational and passive monitoring purposes only. It is not financial or investment advice. The author is not responsible for any trading losses or decisions made based on the data displayed in this application.
