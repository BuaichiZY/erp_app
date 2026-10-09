import Foundation
import WebKit
import Security

struct APIError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

@MainActor final class APIClient {
    static let origin = URL(string: "https://erp.sex")!
    var mode = "sfw"
    var language = "zh-CN"
    var userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1"
    private let session: URLSession
    private var memory: [String: (Date, JSON)] = [:]
    private var pending: [String: Task<JSON, Error>] = [:]
    private var epoch = 0
    init() {
        SecureCookies.restore()
        let c = URLSessionConfiguration.default
        c.httpCookieStorage = .shared
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForRequest = 25
        c.timeoutIntervalForResource = 75
        session = URLSession(configuration: c)
    }
    func invalidate() { epoch += 1; memory.removeAll() }
    func request(_ path: String, method: String = "GET", body: [String: Any]? = nil, fresh: Bool = false) async throws -> JSON {
        let key = "\(epoch)|\(mode)|\(language)|\(path)"
        let cacheable = method == "GET" && !["/auth", "/me/settings", "/me/sessions", "/me/vrc"].contains(where: { path.hasPrefix($0) })
        if cacheable && !fresh, let (date, result) = memory[key], Date().timeIntervalSince(date) < 12 { return result }
        if cacheable, let task = pending[key] { return try await task.value }
        if method != "GET" { invalidate() }
        let capturedEpoch = epoch
        let task = Task { try await self.perform(path, method: method, body: body) }
        if cacheable { pending[key] = task }
        defer { if cacheable { pending.removeValue(forKey: key) } }
        let value = try await task.value
        if cacheable && capturedEpoch == epoch { memory[key] = (Date(), value) }
        if method != "GET" { invalidate() }
        return value
    }
    private func perform(_ path: String, method: String, body: [String: Any]?) async throws -> JSON {
        if method != "GET" && csrf.isEmpty {
            var bootstrap = URLRequest(url: Self.origin.appendingPathComponent("login"))
            bootstrap.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            _ = try await session.data(for: bootstrap)
            SecureCookies.save()
        }
        guard path.hasPrefix("/"), let url = URL(string: Self.origin.absoluteString + "/api/v1" + path), url.host == Self.origin.host else { throw URLError(.badURL) }
        var req = authenticatedRequest(url: url)
        req.httpMethod = method
        if let body { req.httpBody = try JSON.body(body); req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: req)
        SecureCookies.save()
        return try decode(data, response)
    }
    var csrf: String { HTTPCookieStorage.shared.cookies(for: Self.origin.appendingPathComponent("api/v1/"))?.first(where: { $0.name == "erp_csrf" })?.value.removingPercentEncoding ?? "" }
    func authenticatedRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(language, forHTTPHeaderField: "Accept-Language")
        req.setValue(mode, forHTTPHeaderField: "X-Content-Mode")
        req.setValue(Self.origin.absoluteString, forHTTPHeaderField: "Origin")
        req.setValue(Self.origin.absoluteString + "/", forHTTPHeaderField: "Referer")
        if !csrf.isEmpty { req.setValue(csrf, forHTTPHeaderField: "X-CSRF-Token") }
        return req
    }
    private func decode(_ data: Data, _ response: URLResponse) throws -> JSON {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard data.count <= 8 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
        let value = data.isEmpty ? JSON.object([:]) : try JSONDecoder().decode(JSON.self, from: data)
        guard (200..<300).contains(status) else { throw APIError(status: status, message: value["error"]["message"].string.isEmpty ? "HTTP \(status)" : value["error"]["message"].string) }
        return value
    }
    func upload(_ data: Data, mime: String, purpose: String, matchID: String? = nil, options: [String: String]) async throws -> JSON {
        guard data.count <= 20 * 1024 * 1024 else { throw APIError(status: 413, message: L("文件不能超过 20 MB")) }
        if csrf.isEmpty { _ = try await request("/config")
            var request = URLRequest(url: Self.origin.appendingPathComponent("login")); request.setValue(userAgent, forHTTPHeaderField: "User-Agent"); _ = try await session.data(for: request)
        }
        let boundary = "ERP" + UUID().uuidString
        var fields = options; fields["purpose"] = purpose; fields["matchId"] = matchID
        var bytes = Data()
        for (name, value) in fields { bytes.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8)) }
        let ext = mime == "image/png" ? "png" : mime == "audio/mpeg" ? "mp3" : mime.hasPrefix("audio/") ? "m4a" : "jpg"
        bytes.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"attachment.\(ext)\"\r\nContent-Type: \(mime)\r\n\r\n".utf8)); bytes.append(data); bytes.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var req = authenticatedRequest(url: Self.origin.appendingPathComponent("api/v1/media")); req.httpMethod = "POST"; req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.upload(for: req, from: bytes)
        SecureCookies.save(); invalidate(); return try decode(data, response)
    }
    func syncWebCookies() async {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain == "erp.sex" || cookie.domain == ".erp.sex" { HTTPCookieStorage.shared.setCookie(cookie) }
        SecureCookies.save()
    }
    func seedWebCookies() async {
        for cookie in HTTPCookieStorage.shared.cookies ?? [] where cookie.domain == "erp.sex" || cookie.domain == ".erp.sex" { await WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie) }
    }
    func logout() async throws {
        _ = try await request("/auth/logout", method: "POST", body: [:])
        for cookie in HTTPCookieStorage.shared.cookies ?? [] where cookie.domain.contains("erp.sex") { HTTPCookieStorage.shared.deleteCookie(cookie) }
        let store = WKWebsiteDataStore.default().httpCookieStore
        for cookie in await store.allCookies() where cookie.domain.contains("erp.sex") { await store.deleteCookie(cookie) }
        SecureCookies.clear(); invalidate()
    }
    static func encode(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }
}

private enum SecureCookies {
    struct Saved: Codable { let name: String, value: String, domain: String, path: String; let expires: Date?; let secure: Bool }
    static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "sex.erp.ios.session", kSecAttrAccount as String: "cookies"] }
    static func save() {
        let values = (HTTPCookieStorage.shared.cookies ?? []).filter { $0.domain == "erp.sex" || $0.domain == ".erp.sex" }.map { Saved(name: $0.name, value: $0.value, domain: $0.domain, path: $0.path, expires: $0.expiresDate, secure: $0.isSecure) }
        guard let data = try? JSONEncoder().encode(values) else { return }
        if SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly; SecItemAdd(item as CFDictionary, nil)
        }
    }
    static func restore() {
        var q = query; q[kSecReturnData as String] = true; var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data, let saved = try? JSONDecoder().decode([Saved].self, from: data) else { return }
        for cookie in saved where cookie.expires == nil || cookie.expires! > Date() {
            var properties: [HTTPCookiePropertyKey: Any] = [.name: cookie.name, .value: cookie.value, .domain: cookie.domain, .path: cookie.path, .secure: cookie.secure ? "TRUE" : "FALSE"]
            properties[.expires] = cookie.expires
            if let value = HTTPCookie(properties: properties) { HTTPCookieStorage.shared.setCookie(value) }
        }
    }
    static func clear() { SecItemDelete(query as CFDictionary) }
}
