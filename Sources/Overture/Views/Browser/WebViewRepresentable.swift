import SwiftUI
import WebKit

/// Hosts the tab controller's existing web view without taking ownership of navigation.
struct WebViewRepresentable: NSViewRepresentable {
    @ObservedObject var controller: BrowserTabController

    func makeNSView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Intentionally empty. BrowserTabController is the only navigation owner, and
        // publishing or loading here can create a SwiftUI/WebKit feedback loop.
    }
}
