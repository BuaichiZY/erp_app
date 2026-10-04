import SwiftUI
import CryptoKit
import ImageIO
import WebKit

enum Palette {
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let secondary = Color(uiColor: .tertiarySystemGroupedBackground)
    static let background = Color(uiColor: .systemGroupedBackground)
}
struct Panel<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { VStack(alignment: .leading, spacing: 12) { content }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.secondary.opacity(0.18))) }
}
struct Page<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 18) { if !title.isEmpty { Text(L(title)).font(.largeTitle.bold()).padding(.vertical, 8) }; content }.padding(UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18).frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 1060 : 850).frame(maxWidth: .infinity) }.background(Palette.background) }
}
struct Dot: View {
    var count = 0
    var body: some View { Group { if count > 0 { Text(count > 99 ? "99+" : String(count)).font(.caption2.bold()).foregroundStyle(.white).padding(5).background(.red, in: Capsule()) } else { Circle().fill(.red).frame(width: 8, height: 8) } } }
}
struct MenuRow: View {
    @EnvironmentObject private var app: AppState
    let icon: String, title: String
    var subtitle = ""
    var badge: Int? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title3).foregroundStyle(app.accent).frame(width: 44, height: 44).background(app.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) { Text(L(title)).font(.headline); if !subtitle.isEmpty { Text(L(subtitle)).font(.caption).foregroundStyle(.secondary) } }
                Spacer(); if let badge { Dot(count: badge) }; Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.padding(16).foregroundStyle(.primary)
        }.buttonStyle(.plain)
    }
}
struct PrimaryButton: View {
    @EnvironmentObject private var app: AppState
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View { Button(action: action) { HStack { if let icon { Image(systemName: icon) }; Text(L(title)).fontWeight(.semibold) }.frame(maxWidth: .infinity).padding(15).foregroundStyle(.white).background(app.accent.gradient, in: Capsule()) }.buttonStyle(.plain) }
}
struct EmptyState: View {
    var title = "暂无内容"
    var body: some View { VStack(spacing: 14) { Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary); Text(L(title)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(40) }
}

actor ImageStore {
    static let shared = ImageStore()
    private let memory = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<Data, Error>] = [:]
    private let directory: URL
    init() {
        memory.totalCostLimit = 24 * 1024 * 1024
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("erp-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    func image(_ url: URL, size: Int, scope: String) async throws -> UIImage {
        let digest = SHA256.hash(data: Data((scope + "|" + url.absoluteString).utf8)).map { String(format: "%02x", $0) }.joined()
        let key = "\(digest)-\(size)" as NSString
        if let saved = memory.object(forKey: key) { return saved }
        let file = directory.appendingPathComponent(digest)
        var data: Data?
        if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]), let date = values.contentModificationDate, Date().timeIntervalSince(date) < 7 * 86400 { data = try? Data(contentsOf: file) }
        if data == nil {
            let task: Task<Data, Error>
            if let running = inFlight[digest] { task = running } else {
                task = Task { let (data, response) = try await URLSession.shared.data(from: url); guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count <= 20 * 1024 * 1024 else { throw URLError(.badServerResponse) }; return data }
                inFlight[digest] = task
            }
            defer { inFlight.removeValue(forKey: digest) }
            data = try await task.value
            try data?.write(to: file, options: .atomic); trim()
        }
        guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil), let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: size, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { throw URLError(.cannotDecodeContentData) }
        let image = UIImage(cgImage: thumbnail); memory.setObject(image, forKey: key, cost: thumbnail.bytesPerRow * thumbnail.height); return image
    }
    private func trim() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []
        let ordered = files.compactMap { url -> (URL, Date, Int)? in guard let v = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { return nil }; return (url, v.contentModificationDate ?? .distantPast, v.fileSize ?? 0) }.sorted { $0.1 < $1.1 }
        var total = ordered.reduce(0) { $0 + $1.2 }
        for (url, date, size) in ordered where total > 64 * 1024 * 1024 || Date().timeIntervalSince(date) > 7 * 86400 { try? FileManager.default.removeItem(at: url); total -= size }
    }
    func clear() { memory.removeAllObjects(); for file in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] { try? FileManager.default.removeItem(at: file) } }
}

struct RemoteImage: View {
    @EnvironmentObject private var app: AppState
    let media: JSON
    var size = 1000
    var thumbnail = false
    @State private var image: UIImage?
    @State private var failed = false
    private var url: URL? {
        guard media["view"].string.isEmpty || media["view"].string == "show" else { return nil }
        let value = thumbnail && !media["thumbUrl"].string.isEmpty ? media["thumbUrl"].string : !media["url"].string.isEmpty ? media["url"].string : media["thumbUrl"].string
        guard let url = URL(string: value), url.scheme == "https" else { return nil }; return url
    }
    private var scope: String { app.me.id + "|" + app.mode }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.secondary
                if let image { Image(uiImage: image).resizable().scaledToFill().transition(.opacity) }
                else if url != nil && !failed { ProgressView() }
                else { Image(systemName: "photo").foregroundStyle(.secondary) }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.task(id: scope + (url?.absoluteString ?? "") + String(size)) {
            image = nil; failed = false; guard let url else { return }
            do {
                if !thumbnail, let preview = URL(string: media["thumbUrl"].string), preview.scheme == "https", preview != url { image = try? await ImageStore.shared.image(preview, size: 400, scope: scope) }
                let value = try await ImageStore.shared.image(url, size: size, scope: scope)
                if !Task.isCancelled { withAnimation(.easeOut(duration: 0.2)) { image = value } }
            } catch { failed = true }
        }
    }
}
struct Avatar: View {
    let user: JSON
    var size: CGFloat = 48
    var body: some View { RemoteImage(media: user["avatar"], size: Int(size * 3), thumbnail: true).frame(width: size, height: size).clipShape(Circle()) }
}
struct VerifiedBadge: View {
    @EnvironmentObject private var app: AppState
    var body: some View { Image(systemName: "checkmark.seal").font(.caption.bold()).foregroundStyle(app.accent).padding(.horizontal, 7).padding(.vertical, 4).background(app.accent.opacity(0.15), in: Capsule()).accessibilityLabel(L("已验证 VRChat 账号")) }
}

struct VerificationView: UIViewRepresentable {
    @EnvironmentObject private var app: AppState
    @Environment(\.colorScheme) private var scheme
    let action: String
    @Binding var token: String
    var reset: Int = 0
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .default()
        config.userContentController.add(context.coordinator, name: "verification")
        let view = WKWebView(frame: .zero, configuration: config); view.isOpaque = false; view.backgroundColor = .clear; view.scrollView.isScrollEnabled = false; view.customUserAgent = app.api.userAgent; view.navigationDelegate = context.coordinator
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        let key = app.config["turnstileSiteKey"].string
        let signature = "\(key)|\(action)|\(reset)|\(scheme)|\(app.localeCode)"
        guard context.coordinator.signature != signature else { return }; context.coordinator.signature = signature
        if key.isEmpty { return }
        func js(_ value: String) -> String { String(data: try! JSONEncoder().encode(value), encoding: .utf8)! }
        let html = """
        <!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><body style="margin:0;background:transparent"><div id="verify"></div>
        <script>function ready(){turnstile.render('#verify',{sitekey:\(js(key)),action:\(js(action)),theme:\(js(scheme == .dark ? "dark" : "light")),language:\(js(app.localeCode == "zh-Hans" ? "zh-cn" : app.localeCode == "zh-Hant" ? "zh-tw" : app.localeCode)),size:'flexible',callback:function(t){window.webkit.messageHandlers.verification.postMessage(t)},'expired-callback':function(){window.webkit.messageHandlers.verification.postMessage('')},'error-callback':function(){window.webkit.messageHandlers.verification.postMessage('')}})}</script>
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=ready" async defer></script></body>
        """
        Task { await app.api.seedWebCookies(); if context.coordinator.signature == signature { view.loadHTMLString(html, baseURL: APIClient.origin) } }
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) { view.stopLoading(); view.configuration.userContentController.removeScriptMessageHandler(forName: "verification") }
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: VerificationView
        var signature = ""
        init(parent: VerificationView) { self.parent = parent }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.host == "erp.sex", let value = message.body as? String, value.count < 10000 else { return }
            Task { @MainActor in await parent.app.api.syncWebCookies(); parent.token = value }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            decisionHandler(url?.scheme == "about" || (url?.scheme == "https" && ["erp.sex", "challenges.cloudflare.com"].contains(url?.host ?? "")) ? .allow : .cancel)
        }
    }
}
