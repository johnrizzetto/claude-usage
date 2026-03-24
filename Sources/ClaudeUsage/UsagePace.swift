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

/// Parses "Fri 2:59 PM", "Mon 10:30 AM" → minutes remaining from now
func parseWeeklyMinutesRemaining(_ text: String) -> Int? {
    let dayNumbers = ["Sun": 1, "Mon": 2, "Tue": 3, "Wed": 4, "Thu": 5, "Fri": 6, "Sat": 7]

    guard let regex = try? NSRegularExpression(pattern: #"(Sun|Mon|Tue|Wed|Thu|Fri|Sat)\s+(\d{1,2}):(\d{2})\s*(AM|PM)"#),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let dayRange  = Range(match.range(at: 1), in: text),
          let hourRange = Range(match.range(at: 2), in: text),
          let minRange  = Range(match.range(at: 3), in: text),
          let ampmRange = Range(match.range(at: 4), in: text) else { return nil }

    let dayStr = String(text[dayRange])
    let ampm   = String(text[ampmRange])
    guard var hour   = Int(text[hourRange]),
          let minute = Int(text[minRange]),
          let targetWeekday = dayNumbers[dayStr] else { return nil }

    if ampm == "PM" && hour != 12 { hour += 12 }
    if ampm == "AM" && hour == 12 { hour = 0 }

    let cal = Calendar.current
    let now = Date()
    let nowWeekday = cal.component(.weekday, from: now)
    let nowHour    = cal.component(.hour,    from: now)
    let nowMinute  = cal.component(.minute,  from: now)

    var daysUntil = targetWeekday - nowWeekday
    if daysUntil < 0 { daysUntil += 7 }
    // Same day — if target time already passed, it's next week
    if daysUntil == 0 && (nowHour * 60 + nowMinute) >= (hour * 60 + minute) {
        daysUntil = 7
    }

    let minutesRemaining = daysUntil * 24 * 60 + (hour * 60 + minute) - (nowHour * 60 + nowMinute)
    return minutesRemaining > 0 ? minutesRemaining : nil
}

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

/// Projects weekly usage to end-of-week and maps to a pace tier.
/// Weekly window is 7 days (10,080 min).
func calculateWeeklyPace(weeklyPercent: Int, weeklyReset: String?) -> UsagePace {
    if weeklyPercent >= 85 { return .critical }

    let totalMinutes = 7.0 * 24 * 60 // 10,080 min

    guard let resetText = weeklyReset,
          let minutesLeft = parseWeeklyMinutesRemaining(resetText),
          minutesLeft > 0 else {
        if weeklyPercent >= 60 { return .warning }
        if weeklyPercent >= 35 { return .okay }
        return .great
    }

    let remaining  = Double(minutesLeft)
    let elapsed    = max(totalMinutes - remaining, 1.0)
    let ratePerMin = Double(weeklyPercent) / elapsed
    let projected  = Double(weeklyPercent) + ratePerMin * remaining

    switch projected {
    case ..<60:   return .great
    case 60..<80: return .okay
    case 80..<95: return .warning
    default:      return .critical
    }
}

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
