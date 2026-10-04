import SwiftUI

struct MatchesView: View {
    @EnvironmentObject private var app: AppState
    @State private var state = "active"
    @State private var items: [JSON] = []
    @State private var cursor = ""
    var ordered: [JSON] { if state != "active" { return items }; return app.pins.compactMap { id in items.first(where: { $0.id == id }) } + items.filter { !app.pins.contains($0.id) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(L("配对")).font(.largeTitle.bold()).padding(.horizontal, 20)
            Picker(L("配对"), selection: $state) { Text(L("聊天中")).tag("active"); Text(L("已结束")).tag("ended") }.pickerStyle(.segmented).padding(.horizontal, 18)
            if !app.authenticated { PrimaryButton(title: "登录") { app.screen = .login }.padding(20); Spacer() }
            else { List {
                ForEach(ordered) { match in
                    Button { app.chatRoute = ChatRoute(id: match.id) } label: {
                        HStack(spacing: 13) {
                            Avatar(user: match["user"], size: 54)
                            VStack(alignment: .leading, spacing: 5) { HStack { if app.pins.contains(match.id) { Image(systemName: "pin.fill").font(.caption).foregroundStyle(app.accent) }; Text(match["user"]["displayName"].string).font(.headline); if match["user"]["vrcVerified"].bool { VerifiedBadge() }; Spacer(); Text(String(match["lastMessage"]["createdAt"].string.prefix(10))).font(.caption2).foregroundStyle(.secondary) }; HStack { Text(preview(match["lastMessage"])).font(.subheadline).foregroundStyle(.secondary).lineLimit(1); Spacer(); if match["unreadCount"].int > 0 { Dot(count: match["unreadCount"].int) } } }
                        }.padding(.vertical, 8).foregroundStyle(.primary)
                    }.listRowBackground(app.pins.contains(match.id) ? Palette.secondary : Palette.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if state == "active" { Button { app.togglePin(match.id) } label: { Label(L(app.pins.contains(match.id) ? "取消置顶" : "置顶"), systemImage: "pin") }.tint(.gray); Button { app.run { try await app.markRead(match); try await load() } } label: { Label(L("标为已读"), systemImage: "envelope.open") }.tint(app.accent) }
                        }
                }
                if ordered.isEmpty { EmptyState(title: "暂无配对").listRowSeparator(.hidden) }
                if !cursor.isEmpty { Button(L("加载更多")) { app.run { try await load(more: true) } } }
            }.listStyle(.insetGrouped).refreshable { do { try await load() } catch { app.message = error.localizedDescription } } }
        }.background(Palette.background).task(id: "\(state)|\(app.authenticated)|\(app.eventSerial)") { do { try await load() } catch { app.message = error.localizedDescription } }
    }
    private func preview(_ value: JSON) -> String { if value["recalled"].bool { return L("消息已撤回") }; switch value["type"].string { case "image": return L("[图片]"); case "voice": return L("[语音]"); case "vrc_link": return L("[VRChat 信息]"); case "system": return L("新的配对"); default: return value["text"].string } }
    private func load(more: Bool = false) async throws {
        guard app.authenticated else { return }
        let response = try await app.api.request("/matches?state=" + state + (more ? "&cursor=" + APIClient.encode(cursor) : ""), fresh: true)
        let list = response["items"].array
        items = more ? items + list.filter { value in !items.contains(where: { $0.id == value.id }) } : list; cursor = response["nextCursor"].string
        if state == "active" && !more { for pin in app.pins where !items.contains(where: { $0.id == pin }) { if let match = try? await app.api.request("/matches/" + APIClient.encode(pin)), match["state"].string == "active" { items.append(match) } } }
    }
}

struct ChatView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let id: String
    @State private var match: JSON = .null
    @State private var messages: [JSON] = []
    @State private var cursor = "", text = ""
    @State private var sending = false, imageSheet = false, voiceSheet = false, report = false, boundary = false, unmatch = false, block = false
    @State private var pendingText = "", pendingID = ""
    private var path: String { "/matches/" + APIClient.encode(id) }
    private var allowed: Bool { match["state"].string == "active" && match["closedReason"].string.isEmpty && (!match["boundary"]["required"].bool || match["boundary"]["myAck"].bool) && app.me["status"].string != "restricted" }
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Avatar(user: match["user"], size: 40).onTapGesture { app.profileRoute = ProfileRoute(id: match["user"].id) }
                Text(match["user"]["displayName"].string).font(.headline).lineLimit(1); Spacer()
                Button { app.run { _ = try await app.api.request(path + "/vrc-share", method: "POST", body: [:]); try await reload() } } label: { Label(L(match["vrc"]["myShared"].bool ? "已共享" : "VRC 见"), systemImage: "gamecontroller").font(.caption).padding(10).background(Palette.secondary, in: Capsule()) }.disabled(!allowed || match["vrc"]["myShared"].bool)
                Menu {
                    Button(L("查看名片")) { app.profileRoute = ProfileRoute(id: match["user"].id) }
                    Button(L("举报这段对话")) { report = true }
                    Button(L("解除配对"), role: .destructive) { unmatch = true }
                    Button(L("封锁"), role: .destructive) { block = true }
                } label: { Image(systemName: "ellipsis").rotationEffect(.degrees(90)).padding(8) }
                Button { dismiss() } label: { Image(systemName: "xmark").padding(6) }
            }.foregroundStyle(.primary).padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if !cursor.isEmpty { Button(L("加载更早的消息")) { app.run { try await loadMessages(earlier: true) } } }
                        ForEach(messages) { message in MessageBubble(message: message).id(message.id).contextMenu {
                            if canRecall(message) { Button(L("撤回这条消息？"), role: .destructive) { app.run { _ = try await app.api.request("/messages/\(APIClient.encode(message.id))/recall", method: "POST", body: [:]); try await reload() } } }
                        }
                    }.padding(12).frame(maxWidth: 850).frame(maxWidth: .infinity)
                }.background(Palette.surface, in: RoundedRectangle(cornerRadius: 20)).refreshable { do { try await reload() } catch { app.message = error.localizedDescription } }
                    .onChange(of: messages.last?.id) { newID in if let newID { withAnimation { proxy.scrollTo(newID, anchor: .bottom) } } }
            }
            if match["boundary"]["required"].bool && !match["boundary"]["myAck"].bool { Button(L("交流边界确认")) { boundary = true } }
            HStack(spacing: 12) {
                Button { imageSheet = true } label: { Image(systemName: "photo.badge.plus") }
                Button { voiceSheet = true } label: { Image(systemName: "mic") }
                TextField(L("输入消息…"), text: $text, axis: .vertical).lineLimit(1...4)
                Button { sendText() } label: { Image(systemName: "paperplane").foregroundStyle(app.accent) }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
            }.disabled(!allowed || sending).font(.title3).padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
            Text(L(allowed ? "聊天记录按网站账号权限保存" : "此配对已结束")).font(.caption).foregroundStyle(.secondary)
        }.padding(14).background(Palette.background).task { do { try await reload() } catch { app.message = error.localizedDescription } }.onChange(of: app.eventSerial) { _ in app.run { try await reload() } }
            .sheet(isPresented: $imageSheet) { ImageUploadView(purpose: "chat_image", matchID: id) { media in app.run { try await send(type: "image", media: media) } }.environmentObject(app) }
            .sheet(isPresented: $voiceSheet) { VoiceRecordView(matchID: id) { media in app.run { try await send(type: "voice", media: media) } }.environmentObject(app) }
            .sheet(isPresented: $report) { ReportView(target: "match", id: id).environmentObject(app) }
            .sheet(item: $app.profileRoute) { route in ProfileDetailView(id: route.id).environmentObject(app) }
            .sheet(isPresented: $boundary) { VStack(alignment: .leading, spacing: 20) { Text(L("交流边界确认")).font(.title.bold()); ForEach(match["boundary"]["peer"]["limits"].array, id: \.self) { value in Text(value["item"].string + " · " + value["level"].string) }; Text(L("安全词") + ": " + match["boundary"]["peer"]["safeword"].string); PrimaryButton(title: "已阅读并确认") { app.run { _ = try await app.api.request(path + "/boundary-ack", method: "POST", body: [:]); boundary = false; try await reload() } } }.padding(25) }
            .confirmationDialog(L("解除配对"), isPresented: $unmatch) { Button(L("解除配对"), role: .destructive) { app.run { _ = try await app.api.request(path, method: "DELETE"); dismiss() } } }
            .confirmationDialog(L("封锁"), isPresented: $block) { Button(L("封锁"), role: .destructive) { app.run { _ = try await app.api.request("/users/\(APIClient.encode(match["user"].id))/block", method: "POST", body: [:]); dismiss() } } }
    }
    private func reload() async throws { async let detail = app.api.request(path, fresh: true); try await loadMessages(); match = try await detail; boundary = match["boundary"]["required"].bool && !match["boundary"]["myAck"].bool }
    private func loadMessages(earlier: Bool = false) async throws {
        let result = try await app.api.request(path + "/messages?limit=50" + (earlier ? "&before=" + APIClient.encode(cursor) : ""), fresh: true)
        var all = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) }); for value in result["items"].array where !value.id.isEmpty { all[value.id] = value }
        messages = all.values.sorted { $0["createdAt"].string == $1["createdAt"].string ? $0.id < $1.id : $0["createdAt"].string < $1["createdAt"].string }
        if earlier || cursor.isEmpty { cursor = result["nextCursor"].string }
        if let last = messages.last { _ = try await app.api.request(path + "/read", method: "POST", body: ["lastMessageId": last.id]); await app.refreshCounters() }
    }
    private func sendText() {
        guard allowed, !sending else { return }; sending = true; let value = text
        if value != pendingText { pendingText = value; pendingID = UUID().uuidString }
        app.run { defer { sending = false }; _ = try await app.api.request(path + "/messages", method: "POST", body: ["type": "text", "text": value, "clientId": pendingID]); if text == value { text = "" }; pendingText = ""; pendingID = ""; try await reload() }
    }
    private func send(type: String, media: JSON) async throws { let mediaID = media.id.isEmpty ? media["media"].id : media.id; guard !mediaID.isEmpty, allowed else { return }; _ = try await app.api.request(path + "/messages", method: "POST", body: ["type": type, "mediaId": mediaID, "clientId": UUID().uuidString]); try await reload() }
    private func canRecall(_ message: JSON) -> Bool { guard message["senderId"].string == app.me.id, !message["recalled"].bool, let date = ISO8601DateFormatter().date(from: message["createdAt"].string) else { return false }; return Date().timeIntervalSince(date) <= Double(app.config["limits"]["recallWindowSec"].int == 0 ? 120 : app.config["limits"]["recallWindowSec"].int) }
}
struct MessageBubble: View {
    @EnvironmentObject private var app: AppState
    let message: JSON
    private var mine: Bool { message["senderId"].string == app.me.id }
    var body: some View {
        if message["recalled"].bool || ["system", "notice"].contains(message["type"].string) { Text(L(message["recalled"].bool ? "消息已撤回" : message["type"].string == "system" ? "你们已成功配对" : message["text"].string)).font(.caption).foregroundStyle(.secondary).padding(10).frame(maxWidth: .infinity) }
        else { HStack { if mine { Spacer(minLength: 30) }; VStack(alignment: .trailing, spacing: 6) {
            if message["type"].string == "vrc_link" { if ERPRules.isVRC(message["text"].string), let url = URL(string: message["text"].string) { Link(destination: url) { Label(L("我的 VRChat 主页"), systemImage: "gamecontroller").fontWeight(.semibold) } } else { Text(L("VRChat 链接暂不可用")) } }
            else if message["type"].string == "image" { RemoteImage(media: message["media"], size: 800).frame(width: 205, height: 190).clipShape(RoundedRectangle(cornerRadius: 14)) }
            else if message["type"].string == "voice" { AudioButton(media: message["media"]) }
            else { Text(message["text"].string).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            Text(String(message["createdAt"].string.dropFirst(11).prefix(5))).font(.caption2).opacity(0.65)
        }.padding(12).foregroundStyle(mine ? .white : .primary).background(mine ? app.accent : Palette.secondary, in: RoundedRectangle(cornerRadius: 22)).frame(maxWidth: 340, alignment: mine ? .trailing : .leading); if !mine { Spacer(minLength: 30) } } }
    }
}

struct ReportView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let target: String, id: String
    @State private var category = "other", description = "", token = ""
    @State private var confirmed = false, busy = false
    @State private var reset = 0
    let options = [("underage", "未成年用户"), ("child_avatar_nsfw", "儿童形象的成人内容"), ("unlabeled_nsfw", "未标记的成人内容"), ("real_person_nsfw", "真人成人内容"), ("non_consensual_photo", "未经同意的照片"), ("impersonation", "冒充他人"), ("harassment", "骚扰"), ("scam", "诈骗"), ("other", "其他")]
    var body: some View { NavigationStack { Form { Picker(L("举报类别"), selection: $category) { ForEach(options, id: \.0) { Text(L($0.1)).tag($0.0) } }; TextEditor(text: $description).frame(minHeight: 140); Toggle(L("我确认信息属实，举报并非恶意或报复"), isOn: $confirmed); VerificationView(action: "report", token: $token, reset: reset).frame(height: 110); PrimaryButton(title: "提交举报") { busy = true; app.run { defer { busy = false }; do { await app.api.syncWebCookies(); _ = try await app.api.request("/reports", method: "POST", body: ["targetType": target, "targetId": id, "category": category, "description": description, "lang": app.localeCode, "confirmed": true, "turnstileToken": token]); dismiss() } catch { token = ""; reset += 1; throw error } } }.disabled(busy || !confirmed || description.isEmpty || description.count > 2000 || (!app.config["turnstileSiteKey"].string.isEmpty && token.isEmpty)) }.navigationTitle(L("提交举报")).toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L("关闭")) { dismiss() } } } }
}
