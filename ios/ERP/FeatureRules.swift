import Foundation

/// The server's omitted sort defaults to a member-only feed; hot is available to all signed-in users.
enum BrowseRules {
    static func sorts(_ me: JSON) -> [String] {
        var seen: Set<String> = ["hot"]
        return ["hot"] + me["browse"]["sorts"].array.map(\.string).filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    static func selected(_ value: String, me: JSON) -> String { sorts(me).contains(value) ? value : "hot" }
    static func label(_ value: String) -> String { ["hot": "热门", "new": "最新", "active": "活跃"][value] ?? "推荐" }
}

enum OAuthRules {
    static func retryable(_ status: Int) -> Bool { status == 0 || status == 429 || status >= 500 }
}

enum MatchSearch {
    static func normalize(_ value: String) -> String {
        value.precomposedStringWithCompatibilityMapping.lowercased(with: Locale(identifier: "en_US_POSIX"))
    }
    static func matches(_ user: JSON, query: String) -> Bool {
        let needle = normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        return needle.isEmpty || normalize(user["displayName"].string).contains(needle) || normalize(user["username"].string).contains(needle)
    }
}

enum VRCTrust {
    static func verified(_ user: JSON) -> Bool {
        user["badges"]["vrcVerified"].exists ? user["badges"]["vrcVerified"].bool : user["vrcVerified"].bool
    }
    static func key(_ user: JSON) -> String { user["badges"]["vrcTrust"].string.isEmpty ? user["vrcTrust"].string : user["badges"]["vrcTrust"].string }
    static func label(_ key: String) -> String {
        ["visitor": "访客", "new_user": "新玩家", "user": "玩家", "known_user": "长期玩家", "trusted_user": "资深玩家", "nuisance": "受限玩家"][key] ?? "已验证 VRChat 账号"
    }
    static func background(_ key: String) -> UInt32 {
        ["visitor": 0xcccccc, "new_user": 0x1778ff, "user": 0x2bcf5c, "known_user": 0xff7b42, "trusted_user": 0x8143e6, "nuisance": 0x782f2f][key] ?? 0x8245e7
    }
    static func darkForeground(_ key: String) -> Bool { ["visitor", "user", "known_user"].contains(key) }
}

enum IcebreakerRules {
    static func hours(_ values: [Int]) -> String {
        let sorted = Array(Set(values.filter { (0..<24).contains($0) })).sorted()
        var ranges: [(Int, Int)] = []
        var index = 0
        while index < sorted.count {
            let start = sorted[index]
            var end = start
            while index + 1 < sorted.count && sorted[index + 1] == end + 1 { index += 1; end = sorted[index] }
            ranges.append((start, end + 1))
            index += 1
        }
        if ranges.count > 1, ranges.first?.0 == 0, ranges.last?.1 == 24 {
            let first = ranges.removeFirst()
            ranges[ranges.count - 1].1 = first.1
        }
        return ranges.map { "\($0.0)–\($0.1)" }.joined(separator: ", ")
    }
    static func complete(_ questions: [JSON], answers: [String: Set<String>]) -> Bool {
        !questions.isEmpty && questions.allSatisfy { question in
            let selected = answers[question.id] ?? []
            let valid = Set(question["options"].array.map(\.id))
            return !question.id.isEmpty && !selected.isEmpty && selected.isSubset(of: valid) && (question["type"].string != "single" || selected.count == 1)
        }
    }
}

enum NotificationRoute {
    case likes, chat(String), profile(String), post(String), vrc, membership, editProfile, settings, matches, none
    static func resolve(_ item: JSON) -> NotificationRoute {
        let type = item["type"].string, data = item["data"]
        if !data["matchId"].string.isEmpty { return .chat(data["matchId"].string) }
        if ["superlike", "like_received", "received_like", "new_like", "like"].contains(type) { return .likes }
        if type.hasPrefix("vrc") { return .vrc }
        if type == "tier_changed" { return .membership }
        if !data["postId"].string.isEmpty && data["action"].string != "deleted" { return .post(data["postId"].string) }
        let profile = !data["profileId"].string.isEmpty ? data["profileId"].string : data["userId"].string
        if !profile.isEmpty { return .profile(profile) }
        if type == "match" { return .matches }
        if ["profile_moderated", "media_moderated"].contains(type) { return .editProfile }
        if type == "login_method_shutdown" { return .settings }
        return .none
    }
}

/// Notification copy is nested under data in the current API; older payloads used top-level copy.
struct NotificationPresentation {
    let title: String
    let message: String
    let symbol: String
    let date: Date?
    init(_ item: JSON) {
        let data = item["data"], type = item["type"].string
        let titles = ["match": "你有新的配对！", "unmatch": "配对已结束", "superlike": "有人超级喜欢你", "like": "有人喜欢你", "like_received": "有人喜欢你", "vrc_bound": "VRChat 账号已绑定", "vrc_unbound": "VRChat 账号已解绑", "vrc_rebind": "VRChat 账号绑定已更新", "announcement": "网站公告", "guestbook_new": "你有新的留言", "guestbook_reply": "你的留言有新回复", "post_comment": "你的动态有新评论", "comment_reply": "你的评论有新回复", "tier_changed": "会员状态已更新"]
        title = !data.text("title").isEmpty ? data.text("title") : !item.text("title").isEmpty ? item.text("title") : titles[type] ?? (type.contains("post") ? "动态通知" : type.contains("sanction") ? "账号状态通知" : "网站通知")
        message = [data.text("message"), data.text("body"), item.text("body"), item.text("message")].first { !$0.isEmpty } ?? ""
        symbol = type == "match" || type.contains("like") ? "heart" : type.hasPrefix("vrc") ? "gamecontroller" : type == "announcement" ? "megaphone" : type.contains("post") || type.contains("guestbook") || type.contains("comment") ? "bubble.left" : "bell"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        date = formatter.date(from: item["createdAt"].string) ?? ISO8601DateFormatter().date(from: item["createdAt"].string)
    }
}

/// Only visible media is used by the swipe card and quick preview, with one shared selection.
enum DiscoveryMedia {
    static func photos(_ user: JSON) -> [JSON] {
        var seen = Set<JSON>()
        let photos = ([user["cover"]] + user["photos"].array).filter { media in
            guard media.exists, media["view"].string.isEmpty || media["view"].string == "show" else { return false }
            return seen.insert(media).inserted
        }
        return photos.isEmpty ? [user["avatar"]] : photos
    }
}

/// Both direct and wrapped match detail responses are returned by supported server versions.
enum ChatPayload {
    static func detail(_ response: JSON) -> JSON { response["match"].exists ? response["match"] : response }
}

enum ERPDate {
    static func parse(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
    static func sameDay(_ first: String, _ second: String, calendar: Calendar = .current) -> Bool {
        guard let a = parse(first), let b = parse(second) else { return false }
        return calendar.isDate(a, inSameDayAs: b)
    }
}

/// Content style comes from the site's per-mode appearance; brightness is a separate preference.
struct ThemeRules {
    let pop: Bool
    let modeDark: Bool
    let accent: UInt32
    init(mode: String, config: JSON) {
        let appearance = config["appearance"][mode]
        let preset = appearance["preset"].string
        pop = (preset.isEmpty ? (mode == "nsfw" ? "pop" : "clean") : preset) == "pop"
        let scheme = appearance["scheme"].string
        modeDark = (scheme.isEmpty ? (mode == "nsfw" ? "dark" : "light") : scheme) == "dark"
        let raw = appearance["accent"].string
        accent = raw.count == 7 && raw.first == "#" ? UInt32(raw.dropFirst(), radix: 16) ?? (mode == "nsfw" ? 0xff3e9a : 0xff5a4e) : (mode == "nsfw" ? 0xff3e9a : 0xff5a4e)
    }
    func dark(preference: String, systemDark: Bool) -> Bool {
        switch preference {
        case "light": return false
        case "dark": return true
        case "system": return systemDark
        default: return modeDark
        }
    }
}

/// Read acknowledgements must not feed a realtime refresh back into another acknowledgement.
struct ChatReadTracker {
    private(set) var acknowledged = ""
    private var pending = ""
    mutating func begin(_ messageID: String) -> Bool {
        guard !messageID.isEmpty, messageID != acknowledged, pending.isEmpty else { return false }
        pending = messageID; return true
    }
    mutating func finish(_ messageID: String, succeeded: Bool) {
        guard pending == messageID else { return }
        if succeeded { acknowledged = messageID }
        pending = ""
    }
}
enum RealtimeRules {
    static func refreshesContent(_ type: String) -> Bool {
        ["message.", "match.", "post.", "profile.", "guestbook.", "media."].contains { type.hasPrefix($0) }
    }
}

/// Official web renderer: clamp(containerWidth / 6, 40, 80) pixels per second.
enum DanmakuTiming {
    static func speed(containerWidth: Double) -> Double { min(80, max(40, containerWidth / 6)) }
    static func duration(containerWidth: Double, messageWidth: Double) -> Double {
        max(1, containerWidth + messageWidth) / speed(containerWidth: containerWidth)
    }
}

// Each category uses the documented single-category API and its own cursor.
enum PostCategoryRules {
    static func merge(_ batches: [[JSON]], existing: [JSON], sort: String) -> [JSON] {
        var result = existing, seen = Set(existing.map(\.id))
        let count = batches.map(\.count).max() ?? 0
        for index in 0..<count {
            for batch in batches where index < batch.count {
                let item = batch[index]
                if !item.id.isEmpty, seen.insert(item.id).inserted { result.append(item) }
            }
        }
        if sort == "new" { result.sort { $0["createdAt"].string > $1["createdAt"].string } }
        return result
    }
}

/// A blurred response must never fall back to an unrestricted thumbnail.
enum MediaVisibility {
    static func imageURL(_ media: JSON, thumbnail: Bool = false) -> URL? {
        let view = media["view"].string
        let raw: String
        if view == "blur" { raw = media["blurUrl"].string }
        else if view.isEmpty || view == "show" { raw = thumbnail && !media["thumbUrl"].string.isEmpty ? media["thumbUrl"].string : !media["url"].string.isEmpty ? media["url"].string : media["thumbUrl"].string }
        else { return nil }
        guard let url = URL(string: raw), url.scheme == "https" else { return nil }; return url
    }
}
enum MatchOrdering {
    static func pinnedFirst(_ items: [JSON]) -> [JSON] {
        items.enumerated().sorted { a, b in a.element["pinned"].bool == b.element["pinned"].bool ? a.offset < b.offset : a.element["pinned"].bool }.map(\.element)
    }
}
