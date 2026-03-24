import Foundation

struct UsageData {
    var isLoggedIn: Bool
    var needsLogin: Bool
    var onUsagePage: Bool
    var sessionPercent: Int?
    var sessionReset: String?
    var weeklyPercent: Int?
    var weeklyReset: String?
    var error: String?
}
