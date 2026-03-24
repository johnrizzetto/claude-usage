import Foundation
import AppKit
import Combine

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var sessionPercent: Int? = nil
    @Published var sessionReset: String? = nil
    @Published var weeklyPercent: Int? = nil
    @Published var weeklyReset: String? = nil
    @Published var isLoading: Bool = true
    @Published var isLoggedIn: Bool = false
    @Published var errorMessage: String? = nil
    @Published var lastUpdatedText: String = ""

    var onUpdate: (() -> Void)?

    private var scraper: ClaudeWebScraper?
    private var refreshTimer: Timer?
    private var loginWindowController: LoginWindowController?

    init() {
        setupScraper()
        startRefreshTimer()
    }

    private func setupScraper() {
        let s = ClaudeWebScraper()
        scraper = s

        s.onData = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.handleUsageData(data)
            }
        }

        s.onNeedsLogin = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isLoading = false
                self?.isLoggedIn = false
                self?.onUpdate?()
                self?.showLoginWindow()
            }
        }

        refresh()
    }

    func refresh() {
        isLoading = true
        scraper?.loadUsagePage()
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    private func handleUsageData(_ data: UsageData) {
        isLoading = false
        isLoggedIn = data.isLoggedIn
        sessionPercent = data.sessionPercent
        sessionReset = data.sessionReset
        weeklyPercent = data.weeklyPercent
        weeklyReset = data.weeklyReset
        errorMessage = data.error

        let f = DateFormatter()
        f.timeStyle = .short
        lastUpdatedText = "Updated \(f.string(from: Date()))"

        onUpdate?()
    }

    func showLogin() {
        showLoginWindow()
    }

    private func showLoginWindow() {
        guard loginWindowController == nil else {
            loginWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let scraper = scraper else { return }

        let lw = LoginWindowController(dataStore: scraper.webView.configuration.websiteDataStore)
        loginWindowController = lw

        lw.onLoginComplete = { [weak self] in
            self?.loginWindowController = nil
            self?.refresh()
        }

        lw.showWindow(nil)
        lw.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
