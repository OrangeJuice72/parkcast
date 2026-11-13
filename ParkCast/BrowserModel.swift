import Combine
import Foundation
import WebKit
import SwiftUI

@MainActor
final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published var address = ""
    @Published private(set) var title = "Browser"
    @Published private(set) var progress = 0.0
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published var issue: String?
    private var observations: [NSKeyValueObservation] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        observations.append(webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
            let value = view.estimatedProgress
            Task { @MainActor in self?.progress = value }
        })
        observations.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
            let value = view.canGoBack
            Task { @MainActor in self?.canGoBack = value }
        })
        observations.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
            let value = view.canGoForward
            Task { @MainActor in self?.canGoForward = value }
        })
    }

    func open(_ address: String) {
        do {
            let url = try WebAddress.parse(address)
            self.address = url.absoluteString
            issue = nil
            webView.load(URLRequest(url: url))
        } catch { issue = error.localizedDescription }
    }

    func pause() { webView.pauseAllMediaPlayback { } }

    func clearWebsiteData() async {
        webView.stopLoading()
        pause()
        await webView.configuration.websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        webView.loadHTMLString("<html><body style='background:#101315;color:#ddd;font:18px -apple-system;padding:32px'>Website data cleared. Open a service to sign in again.</body></html>", baseURL: nil)
        address = ""
        title = "Browser"
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url, ["https", "http"].contains(url.scheme ?? "") {
            address = url.absoluteString
            title = webView.title ?? url.host ?? "Browser"
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        issue = "The website stopped responding. Tap Reload to reopen it."
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let scheme = url.scheme?.lowercased() ?? ""
        if ["https", "about", "blob"].contains(scheme) { decisionHandler(.allow); return }
        decisionHandler(.cancel)
        if navigationAction.targetFrame?.isMainFrame != false {
            issue = scheme == "http"
                ? "This page uses unencrypted HTTP. Open an HTTPS address instead."
                : "This link needs another app. You can open the current page in Safari from the toolbar."
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url, url.scheme == "https" {
            webView.load(navigationAction.request)
        }
        return nil
    }

    private func report(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        issue = error.localizedDescription
    }
}

@MainActor
struct BrowserSurface: UIViewRepresentable {
    let model: BrowserModel
    func makeUIView(context: Context) -> WKWebView { model.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
