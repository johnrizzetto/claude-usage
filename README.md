# Claude Usage

A lightweight native macOS menu bar app that shows your real-time Claude session and weekly usage limits — the same data visible at `claude.ai/settings/usage`.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Live usage data** — current session % and weekly all-models % pulled directly from your Claude account
- **Pace-based color coding** — the menu bar dot projects your current usage rate to end-of-session and colors accordingly:
  - 🟢 Green — on track to use very little
  - 🟡 Yellow — moderate pace, no concern
  - 🟠 Orange — elevated, worth watching
  - 🔴 Red — on pace to hit the session limit
- **Auto-refresh** every 60 seconds
- **No dock icon** — lives entirely in the menu bar
- **Persistent auth** — sign in once, stays logged in across restarts

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools or Swift toolchain (`xcode-select --install`)
- A Claude account (Pro or Max)

## Installation

```bash
git clone https://github.com/johnrizzetto/claude-usage.git
cd claude-usage
./rebuild.sh
```

The script builds the app, creates an app bundle at `~/Applications/ClaudeUsage.app`, and launches it.

## First Launch

On first launch the app loads `claude.ai/settings/usage` in a hidden WebView. If you're not already authenticated a login window will appear — sign in once and the session is stored persistently.

## Rebuilding

After making code changes:

```bash
./rebuild.sh
```

## Project Structure

```
Sources/ClaudeUsage/
├── main.swift                  # Entry point
├── AppDelegate.swift           # App lifecycle
├── StatusBarController.swift   # NSStatusItem + popover management
├── UsagePace.swift             # Pace calculation & color logic
├── UsageViewModel.swift        # Observable state
├── ClaudeWebScraper.swift      # WKWebView-based data extraction
├── PopoverView.swift           # SwiftUI popover UI
└── LoginWindowController.swift # One-time auth window
```

## How It Works

The app runs a hidden `WKWebView` that loads `claude.ai/settings/usage` using the default persistent cookie store. After the page renders, JavaScript is injected to extract the usage percentages and reset times from the DOM. The data refreshes every 60 seconds.

Pace is calculated by projecting your current usage rate across the full 5-hour session window. If you've used 30% in the first hour, you're projected to hit ~150% — that's red. If you've used 30% in four hours, you're projected to finish around 37% — that's green.
