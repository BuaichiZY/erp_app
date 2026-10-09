import SwiftUI
import CryptoKit
import ImageIO
import WebKit

struct Palette {
    let pop: Bool
    private func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    var surface: Color { adaptive(0xffffff, pop ? 0x271a47 : 0x181b22) }
    var secondary: Color { adaptive(pop ? 0xfff3c4 : 0xeef0f4, pop ? 0x34245d : 0x22262e) }
    var background: Color { adaptive(pop ? 0xffeb7a : 0xf5f6f9, pop ? 0x1b1233 : 0x101217) }
    var text: Color { adaptive(pop ? 0x141415 : 0x20232a, pop ? 0xfefeff : 0xf5f5f7) }
    var muted: Color { adaptive(pop ? 0x4d4d4d : 0x737986, pop ? 0xcfc4ec : 0x9ba0ad) }
    var selection: Color { pop ? adaptive(0x141414, 0xff3e9a) : surface }
    var selectionText: Color { pop ? .white : text }
    var energy: Color { Color(hex: pop ? 0x7fe3fa : 0xffc83d) }
    var border: Color { adaptive(pop ? 0x141414 : 0xdfe2e7, pop ? 0x0b0618 : 0x30333c) }
}

/// The website's Pop style uses a hard outline and an unblurred, short offset shadow.
private struct SiteOutline<S: Shape>: ViewModifier {
    @EnvironmentObject private var app: AppState
    let shape: S
    let shadow: Bool
    let normalBorder: Bool
    func body(content: Content) -> some View {
        content.overlay { shape.stroke(app.palette.pop || normalBorder ? app.palette.border : .clear, lineWidth: app.palette.pop ? 2.5 : 1).allowsHitTesting(false) }
            .background { if app.palette.pop && shadow { shape.fill(app.palette.border).offset(x: 3, y: 3).allowsHitTesting(false) } }
    }
}
private struct SitePresentation: ViewModifier {
    @EnvironmentObject private var app: AppState
    func body(content: Content) -> some View { content.foregroundStyle(app.palette.text).presentationBackground(app.palette.background).preferredColorScheme(app.preferredScheme) }
}
extension View {
    func sitePresentation() -> some View { modifier(SitePresentation()) }
    func siteOutline<S: Shape>(_ shape: S, shadow: Bool = true, normalBorder: Bool = true) -> some View { modifier(SiteOutline(shape: shape, shadow: shadow, normalBorder: normalBorder)) }
}

struct SiteDivider: View {
    @EnvironmentObject private var app: AppState
    var body: some View { Rectangle().fill(app.palette.border).frame(height: 1).accessibilityHidden(true) }
}

struct Panel<Content: View>: View {
    @EnvironmentObject private var app: AppState
    @ViewBuilder let content: Content
    var body: some View { VStack(alignment: .leading, spacing: 12) { content }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 20)).siteOutline(RoundedRectangle(cornerRadius: 20)) }
}
struct Page<Content: View>: View {
    @EnvironmentObject private var app: AppState
    let title: String
    var maximumWidth: CGFloat? = nil
    @ViewBuilder let content: Content
    var body: some View {
        GeometryReader { geometry in
            let layout = LayoutMetrics(width: geometry.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !title.isEmpty { Text(L(title)).font(.largeTitle.bold()).padding(.vertical, 8) }
                    content
                }
                .environment(\.pageLayout, layout)
                .padding(layout.pagePadding)
                .frame(maxWidth: maximumWidth.map { min($0, layout.pageWidth) } ?? layout.pageWidth)
                .frame(maxWidth: .infinity)
            }.background(app.palette.background)
        }
    }
}
private struct PageLayoutKey: EnvironmentKey {
    static let defaultValue = LayoutMetrics(width: 390)
}
extension EnvironmentValues {
    var pageLayout: LayoutMetrics {
        get { self[PageLayoutKey.self] }
        set { self[PageLayoutKey.self] = newValue }
    }
}

/// Equal columns fitted to the actual content area, including narrow iPad sheets.
struct ResponsiveGrid<Content: View>: View {
    @Environment(\.pageLayout) private var layout
    let minimum: CGFloat
    var spacing: CGFloat = 16
    var compactMinimum: CGFloat? = nil
    @ViewBuilder let content: Content
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: spacing, alignment: .top), count: layout.gridColumns(minimum: layout.contentWidth < 600 ? compactMinimum ?? minimum : minimum, spacing: spacing)), spacing: spacing) {
            content
        }
    }
}
struct Dot: View {
    var count = 0
    @ScaledMetric(relativeTo: .caption2) private var diameter: CGFloat = 22
    var body: some View {
        Group {
            if count > 0 {
                Text(count > 99 ? "99+" : String(count))
                    .font(.caption2.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .frame(minWidth: diameter, minHeight: diameter)
                    .background(.red, in: Capsule())
            } else {
                Circle().fill(.red).frame(width: 8, height: 8)
            }
        }.fixedSize()
    }
}
struct WrappingLayout: Layout {
    var spacing: CGFloat = 8
    private func frames(width: CGFloat, subviews: Subviews) -> ([CGRect], CGFloat) {
        var frames: [CGRect] = [], x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let ideal = view.sizeThatFits(.unspecified)
            let size = view.sizeThatFits(ProposedViewSize(width: min(width, ideal.width), height: nil))
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return (frames, y + rowHeight)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(1, proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width + spacing })
        return CGSize(width: width, height: frames(width: width, subviews: subviews).1)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews).0) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
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
                Image(systemName: icon).font(.title3).foregroundStyle(app.palette.pop ? app.palette.muted : app.accent).frame(width: app.palette.pop ? 28 : 44, height: 44).background(app.accent.opacity(app.palette.pop ? 0 : 0.16), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) { Text(L(title)).font(.headline); if !subtitle.isEmpty { Text(L(subtitle)).font(.caption).foregroundStyle(app.palette.muted) } }
                Spacer(); if let badge { Dot(count: badge) }; Image(systemName: "chevron.right").foregroundStyle(app.palette.muted)
            }.padding(16).foregroundStyle(app.palette.text)
        }.buttonStyle(.plain)
    }
}
struct PrimaryButton: View {
    @EnvironmentObject private var app: AppState
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View { Button(action: action) { HStack { if let icon { Image(systemName: icon) }; Text(L(title)).fontWeight(.semibold) }.frame(maxWidth: .infinity).padding(15).foregroundStyle(.white).background(app.accent, in: RoundedRectangle(cornerRadius: app.palette.pop ? 14 : 28)).siteOutline(RoundedRectangle(cornerRadius: app.palette.pop ? 14 : 28), normalBorder: false) }.buttonStyle(.plain) }
}
struct EmptyState: View {
    @EnvironmentObject private var app: AppState
    var title = "暂无内容"
    var body: some View { VStack(spacing: 14) { Image(systemName: "tray").font(.largeTitle).foregroundStyle(app.palette.muted); Text(L(title)).foregroundStyle(app.palette.muted) }.frame(maxWidth: .infinity).padding(40) }
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
    var fit = false
    @State private var image: UIImage?
    @State private var failed = false
    @State private var requestID = UUID()
    private var url: URL? { MediaVisibility.imageURL(media, thumbnail: thumbnail) }
    private var scope: String { app.me.id + "|" + app.mode }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                app.palette.secondary
                if let image { Image(uiImage: image).resizable().aspectRatio(contentMode: fit ? .fit : .fill).transition(.opacity) }
                else if url != nil && !failed { ProgressView() }
                else { Image(systemName: "photo").foregroundStyle(app.palette.muted) }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .contentShape(Rectangle())
        }.task(id: scope + (url?.absoluteString ?? "") + String(size)) {
            let generation = UUID(); requestID = generation
            image = nil; failed = false; guard let url else { return }
            do {
                if media["view"].string != "blur", !thumbnail, let preview = URL(string: media["thumbUrl"].string), preview.scheme == "https", preview != url { let value = try? await ImageStore.shared.image(preview, size: 400, scope: scope); if !Task.isCancelled && requestID == generation { image = value } }
                let value = try await ImageStore.shared.image(url, size: size, scope: scope)
                if !Task.isCancelled && requestID == generation { withAnimation(.easeOut(duration: 0.2)) { image = value } }
            } catch { if !Task.isCancelled && requestID == generation { failed = true } }
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
struct VRCIdentityBadge: View {
    let user: JSON
    var compact = true
    var showPrefix = false
    var body: some View {
        if VRCTrust.verified(user) {
            let key = VRCTrust.key(user)
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                if !compact { Text((showPrefix && !key.isEmpty ? "VRC · " : "") + L(VRCTrust.label(key))) }
            }.font(.caption.bold()).padding(.horizontal, 6).padding(.vertical, 4)
                .foregroundStyle(VRCTrust.darkForeground(key) ? Color(hex: 0x111827) : .white)
                .background(Color(hex: VRCTrust.background(key)), in: Capsule())
                .fixedSize().accessibilityLabel(L(VRCTrust.label(key)))
        }
    }
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

/// Faceted gemstone, matching the site's permanent-energy symbol.
struct GemShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        var path = Path()
        path.move(to: point(0.22, 0.12)); path.addLine(to: point(0.78, 0.12))
        path.addLine(to: point(0.98, 0.4)); path.addLine(to: point(0.5, 0.95))
        path.addLine(to: point(0.02, 0.4)); path.closeSubpath()
        path.move(to: point(0.02, 0.4)); path.addLine(to: point(0.98, 0.4))
        path.move(to: point(0.22, 0.12)); path.addLine(to: point(0.35, 0.4)); path.addLine(to: point(0.5, 0.95))
        path.move(to: point(0.78, 0.12)); path.addLine(to: point(0.65, 0.4)); path.addLine(to: point(0.5, 0.95))
        path.move(to: point(0.35, 0.4)); path.addLine(to: point(0.5, 0.12)); path.addLine(to: point(0.65, 0.4))
        return path
    }
}
struct EnergyGem: View {
    @EnvironmentObject private var app: AppState
    var body: some View { GemShape().stroke(app.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)).frame(width: 18, height: 18).accessibilityHidden(true) }
}

/// Exclusive recognition sends exactly one action for a tap or a long press.
struct SecretActionButton<Content: View>: View {
    let action: () -> Void
    var secretAction: (() -> Void)? = nil
    @ViewBuilder let content: Content
    var body: some View {
        content.contentShape(Rectangle())
            .gesture(LongPressGesture(minimumDuration: 0.5).exclusively(before: TapGesture()).onEnded { result in
                switch result { case .first: (secretAction ?? action)(); case .second: action() }
            })
            .accessibilityAddTraits(.isButton).accessibilityAction { action() }
            .accessibilityAction(named: Text(L("悄悄喜欢"))) { (secretAction ?? action)() }
    }
}
struct LoadingSkeleton: View {
    @EnvironmentObject private var app: AppState
    var cards = false
    @State private var pulse = false
    var body: some View {
        Group {
            if cards {
                ResponsiveGrid(minimum: 190, compactMinimum: 130) { ForEach(0..<6, id: \.self) { _ in RoundedRectangle(cornerRadius: 18).fill(app.palette.secondary).frame(height: 230) } }
            } else {
                VStack(spacing: 18) { ForEach(0..<3, id: \.self) { _ in HStack { Circle().fill(app.palette.secondary).frame(width: 48, height: 48); VStack(alignment: .leading, spacing: 12) { RoundedRectangle(cornerRadius: 5).fill(app.palette.secondary).frame(width: 150, height: 14); RoundedRectangle(cornerRadius: 5).fill(app.palette.secondary).frame(height: 10) }; Spacer() } } }.padding(16)
            }
        }.opacity(pulse ? 0.45 : 1).animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse).onAppear { pulse = true }.accessibilityLabel(L("正在加载…"))
    }
}
