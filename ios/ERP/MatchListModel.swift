import SwiftUI

@MainActor final class MatchListModel: ObservableObject {
    @Published private(set) var items: [JSON] = []
    @Published private(set) var cursor = ""
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published var query = ""
    private var generation = UUID()
    private var seenCursors: Set<String> = []
    private var fetch: ((String) async throws -> JSON)?
    private var base = ""
    func refresh(api: APIClient, state: String, authenticated: Bool, identity: String, group: String? = nil) async {
        let requestID = UUID(); generation = requestID
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = search.isEmpty ? "/matches?state=" + state + (group.map { "&group=" + APIClient.encode($0) } ?? "") : "/matches?q=" + APIClient.encode(search)
        let changed = base != endpoint
        base = endpoint; fetch = { try await api.request($0, fresh: true) }
        if changed { items = []; cursor = "" }
        error = nil; loading = true
        guard authenticated else { items = []; cursor = ""; loading = false; return }
        do {
            let response = try await api.request(endpoint, fresh: true)
            guard generation == requestID, !Task.isCancelled else { return }
            items = response["items"].array; cursor = response["nextCursor"].string; seenCursors = []; loading = false
        } catch {
            guard generation == requestID, !Task.isCancelled else { return }
            loading = false; self.error = error.localizedDescription
        }
    }
    @discardableResult func more() async -> Bool {
        guard !loading, !cursor.isEmpty, let fetch else { return false }
        let requestID = generation, requestedCursor = cursor
        loading = true; error = nil
        do {
            let response = try await fetch(base + "&cursor=" + APIClient.encode(requestedCursor))
            guard generation == requestID, !Task.isCancelled else { return false }
            for item in response["items"].array where !item.id.isEmpty {
                if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item } else { items.append(item) }
            }
            seenCursors.insert(requestedCursor)
            let next = response["nextCursor"].string
            cursor = seenCursors.contains(next) ? "" : next; loading = false; return true
        } catch {
            guard generation == requestID, !Task.isCancelled else { return false }
            loading = false; self.error = error.localizedDescription; return false
        }
    }
}
