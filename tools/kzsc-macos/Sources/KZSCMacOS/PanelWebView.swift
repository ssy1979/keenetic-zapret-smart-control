import SwiftUI
import WebKit

struct PanelWebView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        return view
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
