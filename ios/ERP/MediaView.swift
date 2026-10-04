import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct ImageUploadView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let purpose: String
    var matchID: String? = nil
    let accepted: (JSON) -> Void
    @State private var selected: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var rating = "", kind = "sexual"
    @State private var realPerson = false, original = false, confirmed = false, adult = false, busy = false
    private var originalAllowed: Bool { app.me["features"]["original_upload"]["enabled"].bool }
    private var ready: Bool { image != nil && !rating.isEmpty && confirmed && (!realPerson || rating == "general") && (rating != "r18" || adult) && !busy }
    var body: some View {
        NavigationStack {
            Page(title: "传送图片") {
                PhotosPicker(selection: $selected, matching: .images) {
                    ZStack { RoundedRectangle(cornerRadius: 18).fill(Palette.secondary); RoundedRectangle(cornerRadius: 18).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5])).foregroundStyle(.secondary.opacity(0.35)); if let image { Image(uiImage: image).resizable().scaledToFit().padding(8) } else { VStack(spacing: 15) { Image(systemName: "photo.badge.plus").font(.largeTitle); Text(L("选择图片")).font(.headline); Text("JPEG / PNG / WebP / GIF").font(.caption) }.foregroundStyle(.secondary) } }.frame(height: 230)
                }.disabled(busy)
                Label(L("上传时会清除图片中继资料。"), systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                Toggle(L("这是真人照片"), isOn: $realPerson).onChange(of: realPerson) { on in if on { rating = "general" } }
                Text(L("真人照片只能标为全年龄，NSFW 内容只能是 VRC 截图。")).font(.caption).foregroundStyle(.secondary)
                Text(L("内容分级 *")).font(.headline)
                HStack(spacing: 8) {
                    ForEach([("general", "全年龄", "日常照、合照"), ("suggestive", "擦边", "泳装、内衣、暗示姿势"), ("r18", "R18", "裸露、性行为")], id: \.0) { option in
                        Button { rating = option.0 } label: { VStack(spacing: 7) { Text(L(option.1)).font(.headline); Text(L(option.2)).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).frame(height: 85).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(rating == option.0 ? app.accent : .secondary.opacity(0.25), lineWidth: 2)) }.buttonStyle(.plain).disabled(realPerson && option.0 != "general")
                    }
                }
                if rating == "r18" { Picker(L("R18 内容类型"), selection: $kind) { Text(L("成人内容")).tag("sexual"); Text(L("血腥内容")).tag("gore") }.pickerStyle(.segmented); Toggle(L("我确认内容为成年人"), isOn: $adult) }
                Toggle(L("传送原图"), isOn: $original).disabled(!originalAllowed)
                Text(L("传送原图为会员功能，预设会压缩图片。")).font(.caption).foregroundStyle(.secondary)
                Toggle(L("我确认内容非儿童色情且非真人 NSFW，否则会导致账号限制或者封号"), isOn: $confirmed).font(.subheadline)
                PrimaryButton(title: busy ? "正在上传…" : "上传并发送") { upload() }.disabled(!ready)
            }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark") }.disabled(busy) } }
                .onChange(of: selected) { item in app.run { guard let bytes = try await item?.loadTransferable(type: Data.self), bytes.count <= 20 * 1024 * 1024, let decoded = UIImage(data: bytes) else { throw APIError(status: 0, message: L("图片无法读取")) }; image = decoded } }
        }.interactiveDismissDisabled(busy)
    }
    private func upload() {
        guard ready, let image else { return }; busy = true
        app.run { defer { busy = false }
            let maxEdge: CGFloat = original ? 4096 : 1600; let factor = min(1, maxEdge / max(image.size.width, image.size.height)); let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let flattened = UIGraphicsImageRenderer(size: size, format: format).image { ctx in UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size)); image.draw(in: CGRect(origin: .zero, size: size)) }
            guard let data = flattened.jpegData(compressionQuality: original ? 0.92 : 0.85) else { throw URLError(.cannotEncodeContentData) }
            var options = ["rating": rating, "realPerson": String(realPerson), "original": String(original && originalAllowed)]
            if rating == "r18" { options["r18Kind"] = kind; options["adultConfirm"] = String(adult) }
            let media = try await app.api.upload(data, mime: "image/jpeg", purpose: purpose, matchID: matchID, options: options)
            accepted(media); dismiss()
        }
    }
}

@MainActor final class VoiceRecorder: NSObject, ObservableObject {
    @Published var recording = false
    @Published var duration: TimeInterval = 0
    @Published var file: URL?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    func start() async throws {
        let allowed = await withCheckedContinuation { continuation in AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) } }
        guard allowed else { throw APIError(status: 0, message: L("麦克风权限未开启")) }
        let session = AVAudioSession.sharedInstance(); try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker]); try session.setActive(true)
        clear(); let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue]); recorder?.record(forDuration: 120); recording = true; file = url
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in Task { @MainActor in guard let self else { return }; self.duration = self.recorder?.currentTime ?? 0; if self.duration >= 119.8 { self.stop() } } }
    }
    func stop() { duration = recorder?.currentTime ?? duration; recorder?.stop(); timer?.invalidate(); timer = nil; recording = false; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    func clear() { recorder?.stop(); timer?.invalidate(); if let file { try? FileManager.default.removeItem(at: file) }; file = nil; duration = 0; recording = false; recorder = nil }
}
struct VoiceRecordView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let matchID: String
    let accepted: (JSON) -> Void
    @StateObject private var recorder = VoiceRecorder()
    @State private var busy = false
    @State private var importing = false
    var body: some View { VStack(spacing: 25) {
        Text(L("录制语音")).font(.title.bold())
        Text(String(format: "%02d:%02d", Int(recorder.duration) / 60, Int(recorder.duration) % 60)).font(.system(size: 44, design: .monospaced))
        Button { if recorder.recording { recorder.stop() } else { app.run { try await recorder.start() } } } label: { Image(systemName: recorder.recording ? "stop.fill" : "mic.fill").font(.largeTitle).foregroundStyle(.white).frame(width: 85, height: 85).background(app.accent, in: Circle()) }.disabled(busy)
        Text(L("语音长度须为 1 秒至 2 分钟")).font(.caption).foregroundStyle(.secondary)
        PrimaryButton(title: "上传并发送") { guard let url = recorder.file, !recorder.recording else { return }; upload(url) }.disabled(recorder.file == nil || recorder.recording || recorder.duration < 1 || busy)
        Button(L("选择已有音频")) { importing = true }.disabled(busy)
        Button(L("关闭")) { dismiss() }.disabled(busy)
    }.padding(25).onDisappear { recorder.clear() }.fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in app.run { let url = try result.get(); upload(url) } }.interactiveDismissDisabled(busy) }
    private func upload(_ url: URL) { busy = true; app.run { defer { busy = false }; let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; let asset = AVURLAsset(url: url); let duration = try await asset.load(.duration).seconds; guard duration >= 1, duration <= 121 else { throw APIError(status: 0, message: L("语音长度须为 1 秒至 2 分钟")) }; let input = try Data(contentsOf: url); let mime = url.pathExtension.lowercased() == "mp3" ? "audio/mpeg" : "audio/mp4"; let media = try await app.api.upload(input, mime: mime, purpose: "chat_voice", matchID: matchID, options: ["rating": "general"]); accepted(media); dismiss() } }
}
