import WebKit
import Foundation

@MainActor
final class ClaudeWebScraper: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    var onData: ((UsageData) -> Void)?
    var onNeedsLogin: (() -> Void)?

    private var extractionAttempts = 0
    private var extractionTimer: Timer?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // persistent cookies
        webView = WKWebView(frame: CGRect(x: -2000, y: -2000, width: 1280, height: 800), configuration: config)
        super.init()
        webView.navigationDelegate = self
    }

    func loadUsagePage() {
        extractionAttempts = 0
        extractionTimer?.invalidate()
        let url = URL(string: "https://claude.ai/settings/usage")!
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        extractionAttempts = 0
        scheduleExtraction(delay: 2.0)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onData?(UsageData(
            isLoggedIn: false, needsLogin: false, onUsagePage: false,
            error: "Navigation failed: \(error.localizedDescription)"
        ))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onData?(UsageData(
            isLoggedIn: false, needsLogin: false, onUsagePage: false,
            error: "Load failed: \(error.localizedDescription)"
        ))
    }

    private func scheduleExtraction(delay: TimeInterval) {
        extractionTimer?.invalidate()
        extractionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.extractData()
            }
        }
    }

    private func extractData() {
        let js = #"""
        (function() {
          const result = {
            isLoggedIn: true,
            needsLogin: false,
            onUsagePage: false,
            sessionPercent: null,
            sessionReset: null,
            weeklyPercent: null,
            weeklyReset: null,
            rawText: null,
            error: null
          };

          try {
            const url = window.location.href;
            result.onUsagePage = url.includes('/settings/usage');
            result.needsLogin = url.includes('/login') || url.includes('/auth') || url.includes('signin') || url.includes('sign_in');
            result.isLoggedIn = !result.needsLogin && url.includes('claude.ai');

            if (result.needsLogin) {
              return JSON.stringify(result);
            }

            if (!result.onUsagePage) {
              result.error = 'Not on usage page: ' + url;
              return JSON.stringify(result);
            }

            const bodyText = document.body ? document.body.innerText : '';
            result.rawText = bodyText.substring(0, 1000);

            // Extract "X% used" patterns
            const percentMatches = [...bodyText.matchAll(/(\d+)%\s*used/g)];
            if (percentMatches.length > 0) result.sessionPercent = parseInt(percentMatches[0][1]);
            if (percentMatches.length > 1) result.weeklyPercent = parseInt(percentMatches[1][1]);

            // "Resets in X hr Y min" for session
            const sessionResetMatch = bodyText.match(/Resets in ([^\n]+)/);
            if (sessionResetMatch) result.sessionReset = sessionResetMatch[1].trim();

            // "Resets Fri 2:59 PM" for weekly (not "Resets in")
            const weeklyResetMatch = bodyText.match(/Resets (?!in )([^\n]+)/);
            if (weeklyResetMatch) result.weeklyReset = weeklyResetMatch[1].trim();

            // Fallback: progressbar aria values
            const progressBars = document.querySelectorAll('[role="progressbar"]');
            if (progressBars.length > 0) {
              const v0 = progressBars[0].getAttribute('aria-valuenow');
              if (v0 && result.sessionPercent === null) {
                const n = parseFloat(v0);
                if (!isNaN(n)) result.sessionPercent = Math.round(n);
              }
            }
            if (progressBars.length > 1) {
              const v1 = progressBars[1].getAttribute('aria-valuenow');
              if (v1 && result.weeklyPercent === null) {
                const n = parseFloat(v1);
                if (!isNaN(n)) result.weeklyPercent = Math.round(n);
              }
            }

            // Fallback: inline width styles (progress fill elements)
            if (result.sessionPercent === null || result.weeklyPercent === null) {
              const allEls = [...document.querySelectorAll('[style]')];
              const widths = allEls.map(el => {
                const s = el.getAttribute('style') || '';
                const m = s.match(/width:\s*(\d+\.?\d*)%/);
                return m ? parseFloat(m[1]) : null;
              }).filter(w => w !== null && w > 0 && w <= 100);
              if (widths.length > 0 && result.sessionPercent === null) result.sessionPercent = Math.round(widths[0]);
              if (widths.length > 1 && result.weeklyPercent === null) result.weeklyPercent = Math.round(widths[1]);
            }

          } catch(e) {
            result.error = 'JS error: ' + e.message;
          }

          return JSON.stringify(result);
        })()
        """#

        webView.evaluateJavaScript(js) { [weak self] result, error in
            Task { @MainActor [weak self] in
                self?.handleJSResult(result: result, error: error)
            }
        }
    }

    private func handleJSResult(result: Any?, error: Error?) {
        if let error = error {
            extractionAttempts += 1
            if extractionAttempts < 6 {
                scheduleExtraction(delay: 2.0)
            } else {
                onData?(UsageData(
                    isLoggedIn: false, needsLogin: false, onUsagePage: false,
                    error: "JS error: \(error.localizedDescription)"
                ))
            }
            return
        }

        guard let jsonString = result as? String,
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            extractionAttempts += 1
            if extractionAttempts < 6 {
                scheduleExtraction(delay: 2.0)
            }
            return
        }

        let needsLogin = (json["needsLogin"] as? Bool) ?? false
        let isLoggedIn = (json["isLoggedIn"] as? Bool) ?? false
        let onUsagePage = (json["onUsagePage"] as? Bool) ?? false
        let sessionPercent = json["sessionPercent"] as? Int
        let sessionReset = json["sessionReset"] as? String
        let weeklyPercent = json["weeklyPercent"] as? Int
        let weeklyReset = json["weeklyReset"] as? String
        let jsError = json["error"] as? String

        if needsLogin {
            onNeedsLogin?()
            return
        }

        // If on usage page but no data yet, retry up to 6 times
        if onUsagePage && sessionPercent == nil && weeklyPercent == nil && extractionAttempts < 6 {
            extractionAttempts += 1
            scheduleExtraction(delay: 2.0)
            return
        }

        onData?(UsageData(
            isLoggedIn: isLoggedIn,
            needsLogin: needsLogin,
            onUsagePage: onUsagePage,
            sessionPercent: sessionPercent,
            sessionReset: sessionReset,
            weeklyPercent: weeklyPercent,
            weeklyReset: weeklyReset,
            error: jsError
        ))
    }
}
