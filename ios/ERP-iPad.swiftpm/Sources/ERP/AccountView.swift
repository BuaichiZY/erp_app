import SwiftUI
import AVFoundation
import Vision
import PhotosUI
import CoreImage.CIFilterBuiltins

struct AboutView: View {
    @EnvironmentObject private var app: AppState
    @State private var checking = false
    var body: some View {
        Page(title: "关于") {
            Text("ERP " + app.version + "-beta").font(.title2.bold())
            Panel { Text(L("这是一个开源免费的 ERP.sex 独立客户端，此 APP 本身不含有任何收益，只是为了方便大家在手机和平板上更便捷地使用网站功能。如果你是付费获得的，请退款并举报。各项服务及功能均依托于此网站。应用会保存登录 Cookie 和图片缓存，不会另外储存你的用户资料。")); Text(L("选择图片时使用系统照片选择器；仅在使用语音录制时获取麦克风权限；仅在使用二维码扫描功能时获取相机权限。")) }
            if let url = URL(string: "https://github.com/BuaichiZY/erp_app") { Link(destination: url) { Label(L("开源项目"), systemImage: "arrow.up.right") }.padding(15).frame(maxWidth: .infinity).background(Palette.surface, in: RoundedRectangle(cornerRadius: 15)) }
            Button { checking = true; app.run { await app.checkUpdate(); checking = false } } label: { HStack { Text(L(checking ? "检查中…" : "检查更新")); Spacer(); if app.updateAvailable { Dot() } }.padding(15).background(Palette.surface, in: RoundedRectangle(cornerRadius: 15)) }.disabled(checking)
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
        }.padding(24).frame(maxWidth: .infinity).background(Palette.background)
    }
}

struct ShareCardView: View {
    @EnvironmentObject private var app: AppState
    private var url: URL { URL(string: "https://erp.sex/likes?u=" + APIClient.encode(app.me.id))! }
    var body: some View {
        Page(title: "分享名片") {
            if app.authenticated {
                Panel {
                    HStack { Avatar(user: app.me, size: 72); VStack(alignment: .leading) { Text(app.me["displayName"].string).font(.title2.bold()); Text(app.me.text("tagline")).foregroundStyle(.secondary) } }
                    if let image = qr(url.absoluteString) { Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 240).frame(maxWidth: .infinity).padding() }
                    Text(url.absoluteString).font(.caption).textSelection(.enabled)
                    ShareLink(item: url) { Label(L("分享名片"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(14).foregroundStyle(.white).background(app.accent, in: Capsule()) }
                }
            } else { EmptyState(title: "请先登录") }
        }
    }
    private func qr(_ value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(value.utf8); filter.correctionLevel = "H"
        guard let output = filter.outputImage, let cg = CIContext().createCGImage(output.transformed(by: CGAffineTransform(scaleX: 10, y: 10)), from: output.extent.applying(CGAffineTransform(scaleX: 10, y: 10))) else { return nil }
        return UIImage(cgImage: cg)
    }
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
        }.task { let state = AVCaptureDevice.authorizationStatus(for: .video); allowed = state == .authorized || (state == .notDetermined && (await AVCaptureDevice.requestAccess(for: .video))); denied = !allowed }
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
        let view = UIView(); let session = AVCaptureSession(); session.sessionPreset = .high
        guard let camera = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) else { return view }
        session.addInput(input)
        let output = AVCaptureMetadataOutput(); guard session.canAddOutput(output) else { return view }; session.addOutput(output); output.setMetadataObjectsDelegate(context.coordinator, queue: .main); output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session); layer.videoGravity = .resizeAspectFill; view.layer.addSublayer(layer)
        context.coordinator.session = session; context.coordinator.layer = layer
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.layer?.frame = uiView.bounds }
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) { let session = coordinator.session; DispatchQueue.global(qos: .userInitiated).async { session?.stopRunning() } }
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var session: AVCaptureSession?, layer: AVCaptureVideoPreviewLayer?
        let detected: (String) -> Void
        private var fired = false
        init(_ detected: @escaping (String) -> Void) { self.detected = detected }
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) { guard !fired, let text = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }; fired = true; detected(text) }
    }
}
