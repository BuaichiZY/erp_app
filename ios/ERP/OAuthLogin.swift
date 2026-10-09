import SwiftUI
import SafariServices
import CryptoKit
import Security

struct OAuthAuthorization: Identifiable { let url: URL; let id = UUID() }

@MainActor final class OAuthLogin: ObservableObject {
    @Published var authorization: OAuthAuthorization?
    @Published private(set) var starting = false
    @Published private(set) var status = ""
    @Published private(set) var waiting = false
    private var pending = PendingOAuthStore.load()
    private var task: Task<Void, Never>?
    private var taskID = UUID()
    private var api: APIClient?
    private var complete: ((JSON) async -> Void)?

    func configure(api: APIClient, complete: @escaping (JSON) async -> Void) {
        self.api = api; self.complete = complete
    }
    func start(token: String) async throws {
        guard !starting, !waiting, let api else { return }
        starting = true; defer { starting = false }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw URLError(.unknown) }
        func base64(_ data: Data) -> String { data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
        let secret = base64(Data(bytes)), hash = base64(Data(SHA256.hash(data: Data(secret.utf8))))
        await api.syncWebCookies()
        let result = try await api.request("/auth/oauth/x/start", method: "POST", body: ["intent": "login", "turnstileToken": token, "claimHash": hash])
        guard let url = URL(string: result["authorizeUrl"].string), url.scheme == "https", let host = url.host,
              ["erp.sex", "x.com", "twitter.com", "api.x.com", "api.twitter.com"].contains(host), url.user == nil else { throw APIError(status: 0, message: L("网站没有返回授权链接")) }
        pending = PendingOAuthStore.Pending(secret: secret, startedAt: Date(), claimed: false)
        PendingOAuthStore.save(pending)
        authorization = OAuthAuthorization(url: url)
        status = L("X 授权完成后关闭浏览器，即可返回应用登录")
        resume()
    }
    func resume() {
        guard task == nil, pending != nil, let api else { return }
        waiting = true; taskID = UUID(); let currentTask = taskID
        task = Task {
            defer { if taskID == currentTask { task = nil; waiting = pending != nil } }
            while !Task.isCancelled, taskID == currentTask, var value = pending {
                guard Date().timeIntervalSince(value.startedAt) < 600 else {
                    clear(); status = L("X 授权已超时，请重新登录"); return
                }
                do {
                    if value.claimed {
                        let user = try await api.request("/me", fresh: true)
                        guard !Task.isCancelled, taskID == currentTask else { return }
                        guard !user.id.isEmpty else { throw APIError(status: 503, message: L("正在登录…")) }
                        authorization = nil; clear(); status = ""
                        await complete?(user); return
                    }
                    let result = try await api.request("/auth/oauth/claim", method: "POST", body: ["secret": value.secret])
                    guard pending?.secret == value.secret else { return }
                    if result["status"].string == "done" {
                        value.claimed = true; pending = value; PendingOAuthStore.save(value)
                        guard !Task.isCancelled, taskID == currentTask else { return }
                        continue
                    }
                    guard !Task.isCancelled, taskID == currentTask else { return }
                } catch {
                    guard !Task.isCancelled, taskID == currentTask else { return }
                    if pending?.claimed == true && !value.claimed { continue }
                    if let failure = error as? APIError, !OAuthRules.retryable(failure.status) {
                        clear(); status = failure.localizedDescription; return
                    }
                    // Keep the pending claim on transient network and server failures.
                }
                do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
            }
        }
    }
    func pause() { taskID = UUID(); task?.cancel(); task = nil }
    func cancel() { pause(); clear(); authorization = nil; status = "" }
    private func clear() { pending = nil; waiting = false; PendingOAuthStore.save(nil) }
}

private enum PendingOAuthStore {
    struct Pending: Codable { let secret: String; let startedAt: Date; var claimed: Bool }
    static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "sex.erp.ios.oauth", kSecAttrAccount as String: "pending-claim"] }
    static func load() -> Pending? {
        var request = query; request[kSecReturnData as String] = true; var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data,
              let value = try? JSONDecoder().decode(Pending.self, from: data), Date().timeIntervalSince(value.startedAt) < 600 else { return nil }
        return value
    }
    static func save(_ value: Pending?) {
        guard let value, let data = try? JSONEncoder().encode(value) else { SecItemDelete(query as CFDictionary); return }
        if SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecItemNotFound {
            var request = query; request[kSecValueData as String] = data; request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(request as CFDictionary, nil)
        }
    }
}

struct OAuthBrowser: UIViewControllerRepresentable {
    let url: URL
    let onClose: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onClose: onClose) }
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url); controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onClose: () -> Void
        init(onClose: @escaping () -> Void) { self.onClose = onClose }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { onClose() }
    }
}
