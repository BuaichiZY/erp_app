import SwiftUI
import AVFoundation
import Vision
import PhotosUI
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

struct AboutView: View {
    @EnvironmentObject private var app: AppState
    @State private var checking = false
    var body: some View {
        Page(title: "关于") {
            Text("ERP " + app.version + "-beta").font(.title2.bold())
            Panel { Text(L("这是一个开源免费的 ERP.sex 独立客户端，此 APP 本身不含有任何收益，只是为了方便大家在手机和平板上更便捷地使用网站功能。如果你是付费获得的，请退款并举报。各项服务及功能均依托于此网站。应用会保存登录 Cookie 和图片缓存，不会另外储存你的用户资料。")); Text(L("选择图片时使用系统照片选择器；仅在使用语音录制时获取麦克风权限；仅在使用二维码扫描功能时获取相机权限。")) }
            if let url = URL(string: "https://github.com/BuaichiZY/erp_app") { Link(destination: url) { Label(L("开源项目"), systemImage: "arrow.up.right") }.padding(15).frame(maxWidth: .infinity).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 15)) }
            Button { checking = true; app.run { await app.checkUpdate(); checking = false } } label: {
                Text(L(checking ? "检查中…" : "检查更新"))
                    .frame(maxWidth: .infinity, alignment: .center).padding(15)
                    .overlay(alignment: .trailing) { if app.updateAvailable { Dot().padding(.trailing, 15) } }
                    .background(app.palette.surface, in: RoundedRectangle(cornerRadius: 15))
            }.disabled(checking)
            if app.updateAvailable {
                Panel { Text(L("当前有新版本发布")).font(.headline); Text(app.update["body"].string); if let url = URL(string: app.update["html_url"].string), url.scheme == "https" { Link(L("立即更新"), destination: url) } }
            }
        }
    }
}

struct IntroductionView: View {
    @EnvironmentObject private var app: AppState
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "heart.square.fill").font(.system(size: 80)).foregroundStyle(app.accent)
            Text("ERP").font(.largeTitle.bold())
            ScrollView { VStack(alignment: .leading, spacing: 14) {
                Text(L("这是一个开源免费的 ERP.sex 独立客户端，此 APP 本身不含有任何收益，只是为了方便大家在手机和平板上更便捷地使用网站功能。如果你是付费获得的，请退款并举报。各项服务及功能均依托于此网站。应用会保存登录 Cookie 和图片缓存，不会另外储存你的用户资料。"))
                Text(L("选择图片时使用系统照片选择器；仅在使用语音录制时获取麦克风权限；仅在使用二维码扫描功能时获取相机权限。"))
            }.frame(maxWidth: 560, alignment: .leading) }.frame(maxHeight: 310)
            PrimaryButton(title: "我知道啦") { app.finishIntroduction() }.frame(maxWidth: 560)
            Spacer()
        }.padding(24).frame(maxWidth: .infinity).background(app.palette.background)
    }
}

struct ShareCardView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.openURL) private var openURL
    @State private var profile: JSON = .null
    @State private var presets: JSON = .object([:])
    @State private var format = "og"
    @State private var rendered: UIImage?
    @State private var status = ""
    @State private var exporting = false
    @State private var sharing = false
    @State private var confirmPreview = false
    @State private var busy = false
    private let fields = [("tagline", "一句话简介"), ("intents", "来意"), ("tags", "标签"), ("platform", "平台"), ("speech", "说话方式"), ("langs", "语言"), ("time", "当地时间"), ("avatar", "素体"), ("shine", "闪亮标签"), ("vrc", "VRChat 名称"), ("qr", "二维码")]
    private var preset: JSON { presets[format] }
    private var member: Bool { app.me["membership"]["rank"].int > 0 }
    private var url: URL { URL(string: "https://erp.sex/s/" + APIClient.encode(app.me.id) + (preset["invite"].bool && !app.me["inviteCode"].string.isEmpty ? "?invite=" + APIClient.encode(app.me["inviteCode"].string) : ""))! }
    private var photos: [JSON] {
        var seen: Set<String> = []
        return ([profile["cover"]] + profile["photos"].array + [profile["avatar"]]).filter { !$0.id.isEmpty && seen.insert($0.id).inserted && ($0["kind"].string.isEmpty || $0["kind"].string == "image") && ($0["rating"].string.isEmpty || $0["rating"].string == "general") && $0["reviewState"].string != "rejected" && ($0["view"].string.isEmpty || $0["view"].string == "show") }
    }
    var body: some View {
        Page(title: "分享卡片") {
            if profile.exists {
                ScrollView(.horizontal, showsIndicators: false) { PostPills(selection: $format, choices: [("og", "X・链接预览 1.91:1"), ("1x1", "IG 贴文 1:1"), ("4x5", "IG 直式 4:5"), ("9x16", "限时动态 9:16")], rectangular: true) }
                if let rendered { Image(uiImage: rendered).resizable().scaledToFit().frame(maxHeight: 460).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 16)) }
                else { ProgressView().frame(maxWidth: .infinity, minHeight: 100) }
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(app.palette.muted) }
                Panel {
                    picker("风格", "style", [("poster", "海报"), ("card", "资料卡"), ("type", "大字"), ("night", "夜色"), ("minimal", "极简")])
                    picker("配色", "palette", [("red", "网站红"), ("ink", "墨黑"), ("sea", "海蓝"), ("mint", "薄荷"), ("milk", "奶茶")])
                    Text(L("照片")).font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(photos) { photo in Button { update("photoId", .string(photo.id)) } label: { RemoteImage(media: photo, size: 240).frame(width: 70, height: 70).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedPhoto == photo.id ? app.accent : .clear, lineWidth: 3)) }.buttonStyle(.plain).accessibilityLabel(L("选择照片") + " \((photos.firstIndex(of: photo) ?? 0) + 1)") } } }
                    MultiChoices(title: "卡片上放的资料", options: fields, selected: Binding(get: { Set(preset["fields"].array.map(\.string)) }, set: { update("fields", .array($0.sorted().map(JSON.string))) }))
                    TextField(L("加一句话"), text: Binding(get: { preset["text"].string }, set: { update("text", .string(String($0.prefix(60)))) })).textFieldStyle(.roundedBorder)
                    Toggle(L("网站标识"), isOn: Binding(get: { !member || preset["brand"].bool }, set: { update("brand", .bool($0)) })).disabled(!member)
                    Toggle(L("链接带上我的邀请码"), isOn: Binding(get: { preset["invite"].bool }, set: { update("invite", .bool($0)) }))
                    Button(L("保存分享配置")) { busy = true; app.run { defer { busy = false }; _ = try await app.api.request("/me/share-cards/" + format, method: "PUT", body: preset.object.mapValues(\.foundation)); app.message = L("已保存") } }.disabled(busy)
                }
                Panel {
                    ResponsiveGrid(minimum: 130, compactMinimum: 130) {
                        Button { exporting = true } label: { Label(L("下载图片"), systemImage: "arrow.down.to.line").frame(minHeight: 44) }
                        Button { sharing = true } label: { Label(L("分享"), systemImage: "square.and.arrow.up").frame(minHeight: 44) }
                        Button { UIPasteboard.general.image = rendered; app.message = L("已复制图片") } label: { Label(L("复制图片"), systemImage: "doc.on.doc").frame(minHeight: 44) }
                        Button { UIPasteboard.general.url = url; app.message = L("已复制链接") } label: { Label(L("复制链接"), systemImage: "link").frame(minHeight: 44) }
                        Button { var c = URLComponents(string: "https://x.com/intent/tweet")!; c.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]; if let target = c.url { openURL(target) } } label: { Text(L("发到 X")).frame(minHeight: 44) }
                        if format == "og" { Button(L("设为链接预览图")) { confirmPreview = true }.frame(minHeight: 44) }
                    }.disabled(rendered == nil || busy)
                    Text(url.absoluteString).font(.caption).textSelection(.enabled)
                }
            } else { Text(status.isEmpty ? L("正在加载…") : status); Button(L("重试")) { app.run { await load() } } }
        }.task { await load() }
            .task(id: JSON.array([.string(format), preset, .string(app.mode)])) { await render() }
            .fileExporter(isPresented: $exporting, document: PNGDocument(bytes: rendered?.pngData() ?? Data()), contentType: .png, defaultFilename: "ERP-\(format)") { result in if case .failure(let error) = result { app.message = error.localizedDescription } }
            .sheet(isPresented: $sharing) { if let rendered { NativeShareSheet(items: [rendered, url]) } }
            .confirmationDialog(L("将这张卡片设为名片链接的预览图？"), isPresented: $confirmPreview) { Button(L("设为链接预览图")) { guard let bytes = rendered?.pngData() else { return }; busy = true; app.run { defer { busy = false }; let result = try await app.api.upload(bytes, mime: "image/png", purpose: "share_image", options: ["rating": "general", "realPerson": "false", "original": "false"]); let item = result["media"].exists ? result["media"] : result; guard !item.id.isEmpty else { throw APIError(status: 0, message: L("上传未返回可用的附件")) }; _ = try await app.api.request("/me/profile", method: "PATCH", body: ["shareImageId": item.id]); await app.reloadSession(); app.message = L("已保存") } } }
    }
    private var selectedPhoto: String { photos.contains(where: { $0.id == preset["photoId"].string }) ? preset["photoId"].string : photos.first?.id ?? "" }
    private func update(_ key: String, _ value: JSON) { rendered = nil; presets = presets.replacing(at: [format, key], with: value) }
    private func picker(_ title: String, _ key: String, _ choices: [(String, String)]) -> some View { Picker(L(title), selection: Binding(get: { preset[key].string }, set: { update(key, .string($0)) })) { ForEach(choices, id: \.0) { Text(L($0.1)).tag($0.0) } }.pickerStyle(.menu) }
    private func load() async {
        do {
            let user = try await app.api.request("/profiles/" + APIClient.encode(app.me.id), fresh: true).profile
            let saved = try await app.api.request("/me/share-cards", fresh: true)
            var values: [String: JSON] = [:]
            for f in ["og", "1x1", "4x5", "9x16"] {
                let defaults: [String: JSON] = ["style": .string(f == "og" ? "card" : "poster"), "palette": .string("red"), "fields": .array(["tagline", "intents", "tags", "platform", "speech", "langs", "shine", "qr"].map(JSON.string)), "brand": .bool(true), "invite": .bool(true), "text": .string(""), "photoId": .null]
                values[f] = .object(defaults.merging(saved["presets"][f].object) { _, new in new })
            }
            try Task.checkCancellation(); presets = .object(values); profile = user; status = ""; await render()
        } catch { if !Task.isCancelled { status = error.localizedDescription } }
    }
    private func render() async {
        guard profile.exists, preset.exists else { return }; rendered = nil
        let snapshot = preset, capturedFormat = format, capturedPhoto = selectedPhoto, capturedURL = url
        do {
            var photoImage: UIImage?
            if let item = photos.first(where: { $0.id == capturedPhoto }), let source = URL(string: item["url"].string.isEmpty ? item["thumbUrl"].string : item["url"].string), source.scheme == "https" {
                photoImage = try await ImageStore.shared.image(source, size: 1600, scope: app.me.id + "|" + app.mode)
            }
            try Task.checkCancellation()
            let output = ShareCardRenderer.render(format: capturedFormat, config: snapshot, profile: profile, photo: photoImage, url: capturedURL, branded: !member || snapshot["brand"].bool)
            guard snapshot == preset, capturedFormat == format else { return }; rendered = output; status = "\(Int(output.size.width)) × \(Int(output.size.height))"
        } catch { if !Task.isCancelled { status = error.localizedDescription } }
    }
}

struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    let bytes: Data
    init(bytes: Data) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws { bytes = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: bytes) }
}
struct NativeShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

@MainActor enum ShareCardRenderer {
    static func render(format: String, config: JSON, profile: JSON, photo: UIImage?, url: URL, branded: Bool) -> UIImage {
        let size: CGSize = format == "1x1" ? CGSize(width: 1080, height: 1080) : format == "4x5" ? CGSize(width: 1080, height: 1350) : format == "9x16" ? CGSize(width: 1080, height: 1920) : CGSize(width: 1200, height: 630)
        let accent = UIColor(Color(hex: ["red": 0xff5a4e, "ink": 0x17181c, "sea": 0x2f6bf0, "mint": 0x0e9f76, "milk": 0x8b5e3c][config["palette"].string] ?? 0xff5a4e))
        let paper = UIColor(Color(hex: ["ink": 0xf6f6f7, "sea": 0xf5f8fd, "mint": 0xf4faf7, "milk": 0xfbf7f2][config["palette"].string] ?? 0xfaf7f5))
        let style = config["style"].string, wide = size.width > size.height * 1.3
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let ctx = renderer.cgContext, w = size.width, h = size.height
            paper.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            func image(_ rect: CGRect) { ctx.saveGState(); ctx.clip(to: rect); if let photo { let scale = max(rect.width / photo.size.width, rect.height / photo.size.height); let target = CGSize(width: photo.size.width * scale, height: photo.size.height * scale); photo.draw(in: CGRect(x: rect.midX - target.width / 2, y: rect.minY - (target.height - rect.height) * 0.4, width: target.width, height: target.height)) } else { accent.setFill(); ctx.fill(rect) }; ctx.restoreGState() }
            var x: CGFloat = 64, y: CGFloat = 80, usable = w - 128
            let light = ["card", "type", "minimal"].contains(style)
            if style == "card" { if wide { image(CGRect(x: 0, y: 0, width: w * 0.42, height: h)); x = w * 0.46; y = branded ? 106 : 64; usable = w - x - 58 } else { image(CGRect(x: 0, y: 0, width: w, height: h * 0.55)); y = h * 0.59 } }
            else if style == "type" { if wide { image(CGRect(x: w * 0.54, y: 0, width: w * 0.46, height: h)); usable = w * 0.48; y = branded ? 120 : 76 } else { image(CGRect(x: 0, y: 0, width: w, height: h * 0.46)); y = h * 0.52 } }
            else if style == "minimal" { if wide { image(CGRect(x: w * 0.58, y: 40, width: w * 0.42 - 40, height: h - 80)); usable = w * 0.48; y = branded ? 120 : 76 } else { image(CGRect(x: 42, y: 42, width: w - 84, height: h * 0.47 - 42)); y = h * 0.53 } }
            else {
                image(CGRect(origin: .zero, size: size))
                if style == "night" { UIColor.black.withAlphaComponent(0.45).setFill(); ctx.fill(CGRect(origin: .zero, size: size)) }
                let colors = [UIColor.black.withAlphaComponent(wide ? 0.85 : 0).cgColor, UIColor.black.withAlphaComponent(wide ? 0 : 0.85).cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) { ctx.drawLinearGradient(gradient, start: wide ? .zero : CGPoint(x: 0, y: h * 0.22), end: wide ? CGPoint(x: w * 0.9, y: 0) : CGPoint(x: 0, y: h), options: []) }
                x = wide ? 64 : 72; y = h * (wide ? 0.29 : 0.53); usable = wide ? w * 0.67 : w - 144
            }
            let foreground: UIColor = light ? .black : .white, muted = light ? UIColor.darkGray : UIColor.white.withAlphaComponent(0.9)
            func text(_ value: String, _ rect: CGRect, _ fontSize: CGFloat, _ color: UIColor, _ bold: Bool = false) { let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail; (value as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: [.font: UIFont.systemFont(ofSize: fontSize, weight: bold ? .bold : .regular), .foregroundColor: color, .paragraphStyle: paragraph], context: nil) }
            if branded { text("♥  erp.sex", CGRect(x: x, y: light ? max(25, y - 65) : 30, width: usable, height: 40), 25, light ? accent : .white, true) }
            let fields = Set(config["fields"].array.map(\.string)), reserve: CGFloat = fields.contains("qr") ? (wide ? 176 : 235) : 110
            func line(_ value: String, size: CGFloat, bold: Bool = false, rows: Int = 2, color: UIColor? = nil) { guard !value.isEmpty else { return }; let height = min(CGFloat(rows) * size * 1.22, max(0, h - reserve - y)); guard height >= size else { return }; text(value, CGRect(x: x, y: y, width: usable, height: height), size, color ?? foreground, bold); y += height + 14 }
            line(profile["displayName"].string.isEmpty ? "ERP" : profile["displayName"].string, size: wide ? 54 : 72, bold: true)
            if fields.contains("shine") { let value = profile["shine"]; if value["likes"].int > 0 { line("★ " + L("喜欢前") + " \(value["likes"].int)%", size: 23, rows: 1, color: accent) } }
            if fields.contains("tagline") { line(profile.text("tagline"), size: wide ? 26 : 32, color: muted) }
            line(config["text"].string, size: wide ? 25 : 31)
            var chips: [String] = []
            if fields.contains("intents") { chips += profile["intents"].array.map { DiscoveryFacts.label($0.string) } }
            if fields.contains("tags") { chips += profile["tags"].array.prefix(8).map { $0["name"].text } }
            line(chips.joined(separator: " · "), size: wide ? 19 : 24)
            var facts: [String] = []
            if fields.contains("platform") { facts.append(DiscoveryFacts.values(profile["vrc"]["platforms"].array)) }
            if fields.contains("speech") { facts.append(DiscoveryFacts.values(profile["vrc"]["speech"].array)) }
            if fields.contains("langs") { facts += profile["languages"].array.map { $0["code"].string.uppercased() } }
            if fields.contains("time") { facts.append(profile["timezone"].string) }
            if fields.contains("avatar") { facts += profile["bases"].array.map { $0["name"].text } }
            if fields.contains("vrc") { facts.append(profile["vrcAccount"]["displayName"].string) }
            line(facts.filter { !$0.isEmpty }.joined(separator: " · "), size: wide ? 17 : 23, color: muted)
            text(L("扫码看我的名片"), CGRect(x: x, y: h - (wide ? 70 : 100), width: usable - reserve, height: 36), wide ? 17 : 24, muted)
            if branded { text("erp.sex", CGRect(x: x, y: h - (wide ? 45 : 65), width: usable - reserve, height: 30), wide ? 15 : 21, muted) }
            if fields.contains("qr"), let qr = qrCode(url.absoluteString) { let edge: CGFloat = wide ? 128 : 166; let rect = CGRect(x: w - edge - 38, y: h - edge - 38, width: edge, height: edge); UIColor.white.setFill(); ctx.fill(rect.insetBy(dx: -8, dy: -8)); ctx.interpolationQuality = .none; qr.draw(in: rect) }
        }
    }
    private static func qrCode(_ value: String) -> UIImage? { let filter = CIFilter.qrCodeGenerator(); filter.message = Data(value.utf8); filter.correctionLevel = "M"; guard let image = filter.outputImage, let cg = CIContext().createCGImage(image, from: image.extent) else { return nil }; return UIImage(cgImage: cg) }
}

struct QRScannerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var allowed = false
    @State private var denied = false
    @State private var album: PhotosPickerItem?
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                if allowed { CameraPreview { text in accept(text) }.ignoresSafeArea() }
                else { Text(L(denied ? "请在系统设置中允许相机权限" : "正在打开相机…")).foregroundStyle(.white) }
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.85), lineWidth: 3).frame(width: min(geo.size.width * 0.72, 360), height: min(geo.size.width * 0.72, 360))
                        .overlay { ScanLine().padding(10) }
                    Text(L("将分享名片的二维码放入取景框")).foregroundStyle(.white).padding(.top, 24)
                    Spacer()
                    HStack {
                        PhotosPicker(selection: $album, matching: .images) { Label(L("相册选择"), systemImage: "photo") }
                        Spacer()
                        Button { dismiss() } label: { Label(L("关闭"), systemImage: "xmark") }
                    }.font(.headline).foregroundStyle(.white).padding(28).background(.black.opacity(0.68))
                }
            }
        }.task {
            let state = AVCaptureDevice.authorizationStatus(for: .video)
            if state == .authorized { allowed = true }
            else if state == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
            else { allowed = false }
            denied = !allowed
        }
            .onChange(of: album) { item in app.run { guard let bytes = try await item?.loadTransferable(type: Data.self), let image = UIImage(data: bytes), let cg = image.cgImage else { throw APIError(status: 0, message: L("图片无法读取")) }; let request = VNDetectBarcodesRequest(); request.symbologies = [.qr]; try VNImageRequestHandler(cgImage: cg).perform([request]); if let text = request.results?.first?.payloadStringValue { accept(text) } else { app.message = L("未找到二维码") } } }
    }
    private func accept(_ raw: String) { guard let id = ERPRules.profileID(raw) else { app.message = L("不是有效的 ERP 名片二维码"); return }; dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { app.profileRoute = ProfileRoute(id: id) } }
}
private struct ScanLine: View {
    @State private var offset: CGFloat = -110
    var body: some View {
        GeometryReader { geometry in
            Rectangle().fill(LinearGradient(colors: [.clear, .cyan, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 2).offset(y: offset + geometry.size.height / 2)
                .onAppear { withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) { offset = 110 } }
        }.clipped()
    }
}
private struct CameraPreview: UIViewRepresentable {
    let detected: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(detected) }
    func makeUIView(context: Context) -> UIView {
        let view = PreviewCanvas(); let session = AVCaptureSession(); session.sessionPreset = .high
        guard let camera = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { return view }
        session.addInput(input)
        let output = AVCaptureMetadataOutput(); guard session.canAddOutput(output) else { return view }; session.addOutput(output); output.setMetadataObjectsDelegate(context.coordinator, queue: .main); output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session); layer.videoGravity = .resizeAspectFill; view.previewLayer = layer; view.layer.addSublayer(layer)
        context.coordinator.session = session; context.coordinator.layer = layer
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) { uiView.setNeedsLayout() }
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) { let session = coordinator.session; DispatchQueue.global(qos: .userInitiated).async { session?.stopRunning() } }
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var session: AVCaptureSession?, layer: AVCaptureVideoPreviewLayer?
        let detected: (String) -> Void
        private var fired = false
        init(_ detected: @escaping (String) -> Void) { self.detected = detected }
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) { guard !fired, let text = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }; fired = true; detected(text) }
    }
    final class PreviewCanvas: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        override func layoutSubviews() { super.layoutSubviews(); previewLayer?.frame = bounds }
    }
}
