import AppKit
import SwiftUI

// MARK: - Pace enum

enum UsagePace {
    case great    // Green  — on track to use very little
    case okay     // Yellow — moderate, no concern
    case warning  // Orange — elevated, worth watching
    case critical // Red    — on pace to hit the limit

    var nsColor: NSColor {
        switch self {
        case .great:    return .systemGreen
        case .okay:     return NSColor(red: 0.95, green: 0.78, blue: 0.0, alpha: 1)
        case .warning:  return .systemOrange
        case .critical: return .systemRed
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .great:    return Color(red: 0.2, green: 0.78, blue: 0.35)
        case .okay:     return Color(red: 0.95, green: 0.78, blue: 0.0)
        case .warning:  return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .critical: return Color(red: 0.92, green: 0.25, blue: 0.25)
        }
    }

    var label: String {
        switch self {
        case .great:    return "Low usage"
        case .okay:     return "On pace"
        case .warning:  return "Elevated"
        case .critical: return "High usage"
        }
    }
}

// MARK: - Parser

/// Parses "2 hr 22 min", "45 min", "1 hr" → total minutes
func parseMinutesRemaining(_ text: String) -> Int? {
    var total = 0
    var found = false

    if let m = try? NSRegularExpression(pattern: #"(\d+)\s*hr"#)
        .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
       let r = Range(m.range(at: 1), in: text),
       let n = Int(text[r]) {
        total += n * 60
        found = true
    }

    if let m = try? NSRegularExpression(pattern: #"(\d+)\s*min"#)
        .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
       let r = Range(m.range(at: 1), in: text),
       let n = Int(text[r]) {
        total += n
        found = true
    }

    return found ? total : nil
}

// MARK: - Pace calculation

/// Projects session usage to end-of-window and maps to a pace tier.
/// Claude Pro sessions reset every 5 hours (300 min).
func calculatePace(sessionPercent: Int, sessionReset: String?) -> UsagePace {
    let totalMinutes = 300.0 // 5-hour session window

    // Hard ceiling — always critical if already very high
    if sessionPercent >= 85 { return .critical }

    guard let resetText = sessionReset,
          let minutesLeft = parseMinutesRemaining(resetText),
          minutesLeft > 0 else {
        // No time data — simple thresholds
        if sessionPercent >= 60 { return .warning }
        if sessionPercent >= 35 { return .okay }
        return .great
    }

    let remaining = Double(minutesLeft)
    let elapsed = max(totalMinutes - remaining, 1.0)
    let ratePerMin = Double(sessionPercent) / elapsed
    let projected = Double(sessionPercent) + ratePerMin * remaining

    switch projected {
    case ..<60:   return .great
    case 60..<80: return .okay
    case 80..<95: return .warning
    default:      return .critical
    }
}
