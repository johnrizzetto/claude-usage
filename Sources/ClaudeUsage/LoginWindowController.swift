import AppKit
import WebKit

@MainActor
final class LoginWindowController: NSWindowController, WKNavigationDelegate {
    var onLoginComplete: (() -> Void)?
    private let loginWebView: WKWebView

    init(dataStore: WKWebsiteDataStore) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 520, height: 680), configuration: config)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in to Claude"
        window.center()
        window.contentView = wv
        window.minSize = NSSize(width: 400, height: 500)

        self.loginWebView = wv
        super.init(window: window)

        wv.navigationDelegate = self
        wv.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
    }

    required init?(coder: NSCoder) { fatalError() }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url?.absoluteString else { return }

        // Detect successful login: we're on claude.ai but not on login/auth pages
        let isLoggedIn = url.contains("claude.ai")
            && !url.contains("/login")
            && !url.contains("/auth")
            && !url.contains("signin")
            && !url.contains("sign_in")

        if isLoggedIn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.window?.close()
                self?.onLoginComplete?()
            }
        }
    }
}
