import SwiftUI
import WebKit

enum Screen: String, Identifiable {
    case login, notifications, energy, settings, about, scan, share, editProfile, vrc, invite, membership, content, privacy, account, language, appearance, blocks, sanctions, sessions, password, notificationSettings
    var id: String { rawValue }
}
struct ProfileRoute: Identifiable { let id: String }
struct ChatRoute: Identifiable { let id: String }
struct MatchResult: Identifiable { let user: JSON; let matchID: String; var id: String { user.id } }

@MainActor final class AppState: ObservableObject {
    let api = APIClient()
    @Published var me: JSON = .null
    @Published var config: JSON = .null
    @Published var counters: JSON = .null
    @Published var energy: JSON = .null
    @Published var tab = 0
    @Published var screen: Screen?
    @Published var profileRoute: ProfileRoute?
    @Published var chatRoute: ChatRoute?
    @Published var matched: MatchResult?
    @Published var message: String?
    @Published var mode = UserDefaults.standard.string(forKey: "contentMode") ?? "sfw"
    @Published var appearance = UserDefaults.standard.string(forKey: "appearance") ?? "auto"
    @Published var language = UserDefaults.standard.string(forKey: "language") ?? "auto"
    @Published var update: JSON = .null
    @Published var firstRun = !UserDefaults.standard.bool(forKey: "introduced")
    @Published var eventSerial = 0
    @Published var pins: [String] = []
    var socket: URLSessionWebSocketTask?
    private var realtimeTask: Task<Void, Never>?
    var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.0" }
    var authenticated: Bool { !me.id.isEmpty }
    var updateAvailable: Bool { update.exists }
    var localeCode: String { LanguageSupport.resolve(language, preferred: Locale.preferredLanguages) }
    var accent: Color { mode == "nsfw" ? Color(hex: 0xff5793) : Color(hex: 0xff594f) }
    func prepare() async {
        let web = WKWebView(); if let ua = try? await web.evaluateJavaScript("navigator.userAgent") as? String { api.userAgent = ua }
        await reloadSession(); await checkUpdate()
    }
    func configure() {
        api.mode = mode; api.language = localeCode == "zh-Hant" ? "zh-TW" : localeCode == "zh-Hans" ? "zh-CN" : localeCode
        Localizer.shared.language = localeCode
    }
    func run(_ action: @escaping () async throws -> Void) { Task { do { try await action() } catch is CancellationError {} catch { self.message = error.localizedDescription } } }
    func reloadSession() async {
        configure()
        do { config = try await api.request("/config", fresh: true) } catch { message = error.localizedDescription }
        do { me = try await api.request("/me", fresh: true); loadPins(); await refreshCounters(); connectRealtime() }
        catch let error as APIError where error.status == 401 { me = .null; disconnectRealtime() }
        catch { message = error.localizedDescription }
    }
    func refreshCounters() async {
        guard authenticated else { return }
        async let count = try? api.request("/me/counters", fresh: true)
        async let amount = try? api.request("/me/energy", fresh: true)
        if let count = await count { counters = count }; if let amount = await amount { energy = amount }
    }
    func requireLogin() -> Bool { if authenticated { return true }; screen = .login; return false }
    func setMode(_ value: String) { mode = value; UserDefaults.standard.set(value, forKey: "contentMode"); configure(); api.invalidate(); eventSerial += 1; run { await self.refreshCounters() } }
    func setAppearance(_ value: String) { appearance = value; UserDefaults.standard.set(value, forKey: "appearance"); if authenticated { run { _ = try await self.api.request("/me/settings", method: "PATCH", body: ["colorScheme": value]) } } }
    func setLanguage(_ value: String) { language = value; UserDefaults.standard.set(value, forKey: "language"); configure(); api.invalidate(); eventSerial += 1 }
    func finishIntroduction() { UserDefaults.standard.set(true, forKey: "introduced"); firstRun = false }
    func togglePin(_ id: String) {
        if let index = pins.firstIndex(of: id) { pins.remove(at: index) } else { pins.append(id) }
        UserDefaults.standard.set(pins, forKey: "pins." + me.id)
    }
    private func loadPins() { pins = UserDefaults.standard.stringArray(forKey: "pins." + me.id) ?? [] }
    func markRead(_ match: JSON) async throws {
        var last = match["lastMessage"]["id"].string
        if last.isEmpty { last = try await api.request("/matches/\(APIClient.encode(match.id))/messages?limit=1")["items"].array.first?.id ?? "" }
        if !last.isEmpty { _ = try await api.request("/matches/\(APIClient.encode(match.id))/read", method: "POST", body: ["lastMessageId": last]); await refreshCounters() }
    }
    func swipe(_ user: JSON, _ action: String) async throws {
        guard requireLogin() else { throw CancellationError() }
        let result = try await api.request("/swipes", method: "POST", body: ["targetId": user.id, "action": action])
        if result["matched"].bool { matched = MatchResult(user: user, matchID: result["match"].id) }
        await refreshCounters()
    }
    func checkUpdate() async {
        // Android APKs are never advertised as installable iOS updates.
        guard let url = URL(string: "https://api.github.com/repos/BuaichiZY/erp_app/releases?per_page=20") else { return }
        do {
            var req = URLRequest(url: url); req.setValue("ERP-iOS", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let releases = try JSONDecoder().decode(JSON.self, from: data).array
            update = releases.first { release in !release["draft"].bool && ERPRules.newer(release["tag_name"].string, than: version) && release["assets"].array.contains { $0["name"].string.lowercased().hasSuffix(".ipa") } } ?? .null
        } catch { /* A background update check must not interrupt the current page. */ }
    }
    func connectRealtime() {
        guard authenticated, realtimeTask == nil else { return }
        realtimeTask = Task { var retry: UInt64 = 1
            while !Task.isCancelled && self.authenticated {
                var request = self.api.authenticatedRequest(url: URL(string: "wss://erp.sex/api/v1/ws")!)
                if let cookies = HTTPCookieStorage.shared.cookies(for: APIClient.origin.appendingPathComponent("api/v1/ws")) { request.setValue(HTTPCookie.requestHeaderFields(with: cookies)["Cookie"], forHTTPHeaderField: "Cookie") }
                let socket = URLSession.shared.webSocketTask(with: request); self.socket = socket; socket.resume()
                do {
                    try await socket.send(.string("{\"type\":\"visibility\",\"data\":{\"visible\":true}}"))
                    while !Task.isCancelled {
                        let packet = try await socket.receive(); let data: Data
                        switch packet { case .string(let text): data = Data(text.utf8); case .data(let bytes): data = bytes; @unknown default: continue }
                        let json = try JSONDecoder().decode(JSON.self, from: data)
                        if json["type"].string == "ping" { try await socket.send(.string("{\"type\":\"pong\",\"data\":{}}")); continue }
                        self.api.invalidate(); self.eventSerial += 1; await self.refreshCounters(); retry = 1
                    }
                } catch { socket.cancel(with: .goingAway, reason: nil) }
                if !Task.isCancelled { try? await Task.sleep(nanoseconds: min(retry, 30) * 1_000_000_000); retry *= 2 }
            }
        }
    }
    func disconnectRealtime() { realtimeTask?.cancel(); realtimeTask = nil; socket?.cancel(with: .goingAway, reason: nil); socket = nil }
}

extension Color { init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) } }

enum LanguageSupport {
    static func resolve(_ setting: String, preferred: [String]) -> String {
        if setting != "auto" { return setting }
        let value = preferred.first?.lowercased() ?? "en"
        if value.hasPrefix("zh") { return value.contains("hant") || value.contains("tw") || value.contains("hk") || value.contains("mo") ? "zh-Hant" : "zh-Hans" }
        if value.hasPrefix("ja") { return "ja" }; if value.hasPrefix("ko") { return "ko" }; return "en"
    }
}
@MainActor final class Localizer {
    static let shared = Localizer()
    var language = "zh-Hans"
    private var dictionaries: [String: [String: String]] = [:]
    func text(_ source: String) -> String {
        if language == "zh-Hans" { return source }
        let file = ["zh-Hant": "ui_zh_hant", "ja": "ui_ja", "ko": "ui_ko", "en": "ui_en"][language] ?? "ui_en"
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        if dictionaries[file] == nil, let url = bundle.url(forResource: file, withExtension: "json"), let bytes = try? Data(contentsOf: url) { dictionaries[file] = try? JSONDecoder().decode([String: String].self, from: bytes) }
        return dictionaries[file]?[source] ?? source
    }
}
@MainActor func L(_ source: String) -> String { Localizer.shared.text(source) }
