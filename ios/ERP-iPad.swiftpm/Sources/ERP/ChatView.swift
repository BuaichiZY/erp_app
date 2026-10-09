import SwiftUI

struct MatchesView: View {
    @EnvironmentObject private var app: AppState
    @State private var state = "active"
    @StateObject private var list = MatchListModel()
    @State private var view = "recent"
    var ordered: [JSON] { MatchOrdering.pinnedFirst(list.items) }
    var body: some View {
        ZStack {
            listContent.opacity(app.chatRoute == nil ? 1 : 0)
                .allowsHitTesting(app.chatRoute == nil).accessibilityHidden(app.chatRoute != nil)
            if let route = app.chatRoute {
                ChatView(id: route.id) { app.chatRoute = nil }.id(route.id)
            }
        }
    }
    private var listContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Text(L("配对")).font(.largeTitle.bold()); Spacer(); PostPills(selection: $view, choices: [("recent", "最近对话"), ("groups", "分组")], rectangular: true) }.padding(.horizontal, 20)
            if view == "recent" && list.query.isEmpty && UIDevice.current.userInterfaceIdiom != .pad { matchTabs }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(app.palette.muted)
                TextField(L("搜索聊天对象"), text: $list.query).keyboardType(.default).submitLabel(.search)
                if !list.query.isEmpty { Button { list.query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel(L("清除搜索")) }
            }.padding(12).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 12)).siteOutline(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 18)
            if view == "recent" && list.query.isEmpty && UIDevice.current.userInterfaceIdiom == .pad { matchTabs }
            if !app.authenticated { PrimaryButton(title: "登录") { app.screen = .login }.padding(20); Spacer() }
            else if view == "groups" && list.query.isEmpty { MatchGroupsView() }
            else { List {
                ForEach(ordered) { match in
                    MatchRow(match: match, reload: { await load() })
                        .listRowBackground(match["pinned"].bool ? app.palette.secondary : app.palette.surface)
                        .listRowSeparatorTint(app.palette.border)
                }
                if let error = list.error { Text(error).foregroundStyle(app.palette.muted); Button(L("重试")) { if list.cursor.isEmpty { app.run { await load() } } else { app.run { await list.more() } } } }
                if list.loading && ordered.isEmpty { LoadingSkeleton() }
                if ordered.isEmpty && !list.loading && list.error == nil { EmptyState(title: list.query.isEmpty ? "暂无配对" : "没有找到匹配的聊天").listRowSeparator(.hidden) }
                if !list.cursor.isEmpty && !list.loading { Button(L("加载更多")) { app.run { await list.more() } } }
            }.listStyle(.plain).listRowSeparatorTint(app.palette.border).scrollContentBackground(.hidden).background(app.palette.surface).clipShape(RoundedRectangle(cornerRadius: 20)).siteOutline(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 18).scrollDismissesKeyboard(.interactively).refreshable { await load() } }
        }.padding(.top, 12).frame(maxWidth: 960).frame(maxWidth: .infinity, maxHeight: .infinity).background(app.palette.background)
            .task(id: "\(state)|\(view)|\(list.query)|\(app.me.id)|\(app.authenticated)|\(app.eventSerial)") {
                if view == "groups" && list.query.isEmpty { return }
                if !list.query.isEmpty { do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return } }
                await load()
            }.onChange(of: view) { _ in list.query = "" }
    }
    private var matchTabs: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                HStack(spacing: 0) {
                    ForEach([("active", "聊天中"), ("unmatched", "已结束")], id: \.0) { value, title in
                        Button { state = value } label: {
                            Text(L(title)).font(.headline).padding(.horizontal, 16).frame(minHeight: 48)
                                .foregroundStyle(state == value ? app.palette.text : app.palette.muted)
                                .overlay(alignment: .bottom) { Rectangle().fill(state == value ? app.accent : .clear).frame(height: 2).allowsHitTesting(false) }
                        }.buttonStyle(.plain).accessibilityAddTraits(state == value ? .isSelected : [])
                    }
                    Spacer(minLength: 0)
                }.overlay(alignment: .bottom) { Rectangle().fill(app.palette.border).frame(height: 1).allowsHitTesting(false) }
            } else { PostPills(selection: $state, choices: [("active", "聊天中"), ("unmatched", "已结束")]) }
        }.padding(.horizontal, 18)
    }
    private func preview(_ value: JSON) -> String { if value["recalled"].bool { return L("消息已撤回") }; switch value["type"].string { case "image": return L("[图片]"); case "voice": return L("[语音]"); case "vrc_link": return L("[VRChat 信息]"); case "system": return L("新的配对"); default: return value["text"].string } }
    private func load() async { await list.refresh(api: app.api, state: state, authenticated: app.authenticated, identity: app.me.id) }
}

struct MatchRow: View {
    @EnvironmentObject private var app: AppState
    let match: JSON
    let reload: () async -> Void
    @State private var moving = false
    var body: some View {
        HStack(spacing: 8) {
            Button { app.chatRoute = ChatRoute(id: match.id) } label: {
                HStack(spacing: 13) {
                    Avatar(user: match["user"], size: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            if match["pinned"].bool { Image(systemName: "pin.fill").font(.caption).foregroundStyle(app.accent) }
                            Text(match["user"]["displayName"].string).font(.headline).lineLimit(1)
                            VRCIdentityBadge(user: match["user"])
                            Spacer(minLength: 4)
                            Text(String((match["lastMessage"]["createdAt"].string.isEmpty ? match["matchedAt"].string : match["lastMessage"]["createdAt"].string).prefix(10))).font(.caption2).foregroundStyle(app.palette.muted)
                        }
                        HStack { Text(preview).font(.subheadline).foregroundStyle(app.palette.muted).lineLimit(1); Spacer(); if match["unreadCount"].int > 0 { Dot(count: match["unreadCount"].int) } }
                    }
                }.padding(.vertical, 9).foregroundStyle(app.palette.text).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if match["state"].string != "unmatched" {
                Menu { actions } label: { Image(systemName: "ellipsis").frame(width: 32, height: 44) }.accessibilityLabel(L("对话选项"))
            }
        }.contextMenu { if match["state"].string != "unmatched" { actions } }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) { if match["state"].string != "unmatched" { actions } }
            .sheet(isPresented: $moving) { MatchGroupPicker(match: match, finished: reload).environmentObject(app).sitePresentation() }
    }
    @ViewBuilder private var actions: some View {
        Button { app.run { _ = try await app.api.request("/matches/" + APIClient.encode(match.id) + "/pin", method: "PUT", body: ["pinned": !match["pinned"].bool]); await reload() } } label: { Label(L(match["pinned"].bool ? "取消置顶" : "置顶"), systemImage: "pin") }.tint(.gray)
        Button { app.run { try await app.markRead(match); await reload() } } label: { Label(L("标为已读"), systemImage: "envelope.open") }.tint(app.accent)
        Button { moving = true } label: { Label(L("移到分组"), systemImage: "folder") }.tint(.indigo)
    }
    private var preview: String { let value = match["lastMessage"]; if value["recalled"].bool { return L("消息已撤回") }; switch value["type"].string { case "image": return L("[图片]"); case "voice": return L("[语音]"); case "vrc_link": return L("[VRChat 信息]"); case "system", "": return L("新的配对"); default: return value["text"].string } }
}
struct MatchGroupsView: View {
    @EnvironmentObject private var app: AppState
    @State private var snapshot: JSON = .null
    @State private var opened: Set<String> = ["default"]
    @State private var failure = ""
    @State private var editing: JSON?
    @State private var deleting: JSON?
    @State private var revision = 0
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !snapshot.exists && failure.isEmpty { LoadingSkeleton() }
                if !failure.isEmpty { Text(failure); Button(L("重试")) { app.run { await load() } } }
                if snapshot.exists {
                    section("default", "预设分组", snapshot["defaultCount"].int)
                    ForEach(snapshot["groups"].array) { group in
                        section(group.id, group["name"].string, group["count"].int, group: group)
                    }
                    section("unmatched", "已结束", snapshot["unmatchedCount"].int)
                    Button { editing = .object(["id": .string("new")]) } label: { Label(L("新增分组"), systemImage: "plus").frame(minHeight: 44) }
                }
            }.padding(.horizontal, 18)
        }.refreshable { await load() }.task(id: "\(app.me.id)|\(app.eventSerial)") { await load() }
            .sheet(item: $editing) { group in MatchGroupForm(group: group.id == "new" ? .null : group) { created in if !created.id.isEmpty { opened.insert(created.id) }; await load() }.environmentObject(app).sitePresentation() }
            .confirmationDialog(L("删除这个分组？"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) { if let group = deleting { Button(L("删除"), role: .destructive) { app.run { _ = try await app.api.request("/match-groups/" + APIClient.encode(group.id), method: "DELETE"); opened.remove(group.id); await load() } } } }
    }
    private func section(_ key: String, _ title: String, _ count: Int, group: JSON = .null) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button { withAnimation(.easeOut(duration: 0.16)) { if opened.contains(key) { opened.remove(key) } else { opened.insert(key) } } } label: {
                    HStack { Image(systemName: opened.contains(key) ? "chevron.down" : "chevron.right"); Text(L(title)).font(.headline); Spacer(); Text("\(count)").foregroundStyle(app.palette.muted) }.contentShape(Rectangle()).frame(minHeight: 48)
                }.buttonStyle(.plain)
                if group.exists { Menu { Button(L("重命名分组")) { editing = group }; Button(L("删除分组"), role: .destructive) { deleting = group } } label: { Image(systemName: "ellipsis").frame(width: 32, height: 44) }.accessibilityLabel(L("分组选项")) }
            }.padding(.horizontal, 14)
            if opened.contains(key) { SiteDivider(); MatchGroupRows(key: key, revision: revision) { await load() } }
        }.background(app.palette.surface, in: RoundedRectangle(cornerRadius: 16)).clipShape(RoundedRectangle(cornerRadius: 16)).siteOutline(RoundedRectangle(cornerRadius: 16))
    }
    private func load() async { failure = ""; do { let result = try await app.api.request("/match-groups", fresh: true); guard !Task.isCancelled else { return }; snapshot = result; revision += 1 } catch { if !Task.isCancelled { failure = error.localizedDescription } } }
}
struct MatchGroupRows: View {
    @EnvironmentObject private var app: AppState
    let key: String
    let revision: Int
    let updated: () async -> Void
    @StateObject private var list = MatchListModel()
    var body: some View {
        VStack(spacing: 0) {
            if list.loading && list.items.isEmpty { LoadingSkeleton() }
            ForEach(MatchOrdering.pinnedFirst(list.items)) { match in MatchRow(match: match) { await updated() }.padding(.horizontal, 14); SiteDivider() }
            if !list.loading && list.error == nil && list.items.isEmpty { VStack(spacing: 12) { Image(systemName: "bubble.left.and.bubble.right").font(.largeTitle).foregroundStyle(app.accent).padding(16).background(app.accent.opacity(0.1), in: Circle()); Text(L(key == "unmatched" ? "没有已结束的对话" : "这个分组还没有聊天")).font(.headline) }.frame(maxWidth: .infinity).padding(.vertical, 48) }
            if let error = list.error { Text(error).padding(); Button(L("重试")) { app.run { await load() } } }
            if !list.cursor.isEmpty { Button(L("加载更多")) { app.run { await list.more() } }.frame(minHeight: 44).disabled(list.loading) }
        }.task(id: "\(key)|\(revision)") { await load() }
    }
    private func load() async { await list.refresh(api: app.api, state: key == "unmatched" ? "unmatched" : "active", authenticated: app.authenticated, identity: app.me.id, group: key == "unmatched" ? nil : key) }
}
struct MatchGroupForm: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let group: JSON
    let saved: (JSON) async -> Void
    @State private var name = ""
    @State private var busy = false
    var body: some View {
        NavigationStack { Page(title: group.exists ? "重命名分组" : "新增分组") {
            TextField(L("分组名称"), text: $name).textFieldStyle(.roundedBorder).onChange(of: name) { value in if value.count > 30 { name = String(value.prefix(30)) } }
            PrimaryButton(title: "保存") { busy = true; app.run { defer { busy = false }; let result = try await app.api.request(group.exists ? "/match-groups/" + APIClient.encode(group.id) : "/match-groups", method: group.exists ? "PATCH" : "POST", body: ["name": name.trimmingCharacters(in: .whitespacesAndNewlines)]); await saved(result["group"].exists ? result["group"] : result); dismiss() } }.disabled(busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L("关闭")) { dismiss() }.disabled(busy) } } }.onAppear { name = group["name"].string }.interactiveDismissDisabled(busy)
    }
}
struct MatchGroupPicker: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let match: JSON
    let finished: () async -> Void
    @State private var groups: [JSON] = []
    @State private var failure = ""
    @State private var adding = false
    @State private var busy = false
    var body: some View {
        NavigationStack { Page(title: "移到分组") {
            if !failure.isEmpty { Text(failure); Button(L("重试")) { app.run { await load() } } }
            Button { move(nil) } label: { Label(L("预设分组"), systemImage: match["groupId"].string.isEmpty ? "checkmark" : "folder").frame(minHeight: 44) }
            ForEach(groups) { group in Button { move(group) } label: { Label(group["name"].string, systemImage: match["groupId"].string == group.id ? "checkmark" : "folder").frame(minHeight: 44) } }
            Button { adding = true } label: { Label(L("新增分组"), systemImage: "plus").frame(minHeight: 44) }
        }.disabled(busy).toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L("关闭")) { dismiss() }.disabled(busy) } } }
            .task { await load() }.sheet(isPresented: $adding) { MatchGroupForm(group: .null) { created in do { if !created.id.isEmpty { try await transfer(created); dismiss() }; await load() } catch { app.message = error.localizedDescription } }.environmentObject(app).sitePresentation() }
    }
    private func load() async { do { groups = try await app.api.request("/match-groups", fresh: true)["groups"].array } catch { failure = error.localizedDescription } }
    private func move(_ group: JSON?) { guard !busy else { return }; busy = true; app.run { defer { busy = false }; try await transfer(group); dismiss() } }
    private func transfer(_ group: JSON?) async throws { _ = try await app.api.request("/matches/" + APIClient.encode(match.id) + "/group", method: "PUT", body: ["groupId": group?.id as Any? ?? NSNull()]); await finished() }
}

struct ChatView: View {
    @EnvironmentObject private var app: AppState
    let id: String
    let onClose: () -> Void
    @State private var match: JSON = .null
    @State private var loadFailure: String?
    @State private var messages: [JSON] = []
    @State private var cursor = ""
    @State private var text = ""
    @State private var sending = false
    @State private var imageSheet = false
    @State private var voiceSheet = false
    @State private var report = false
    @State private var boundary = false
    @State private var unmatch = false
    @State private var block = false
    @State private var readTracker = ChatReadTracker()
    @State private var refreshing = false
    @State private var refreshAgain = false
    @State private var pendingText = ""
    @State private var pendingID = ""
    @State private var icebreaker = false
    @State private var profileRoute: ProfileRoute?
    @State private var sheetProfileRoute: ProfileRoute?
    private var path: String { "/matches/" + APIClient.encode(id) }
    private var allowed: Bool { match["state"].string == "active" && match["closedReason"].string.isEmpty && (!match["boundary"]["required"].bool || match["boundary"]["myAck"].bool) && app.me["status"].string != "restricted" }
    var body: some View {
        ZStack {
            chatContent.opacity(profileRoute == nil ? 1 : 0)
                .allowsHitTesting(profileRoute == nil).accessibilityHidden(profileRoute != nil)
            if let route = profileRoute {
                ProfileDetailView(id: route.id, onClose: { profileRoute = nil }).id(route.id)
            }
        }
    }
    private func openProfile() {
        guard !match["user"].id.isEmpty else { return }
        let route = ProfileRoute(id: match["user"].id)
        if UIDevice.current.userInterfaceIdiom == .pad { profileRoute = route }
        else { sheetProfileRoute = route }
    }
    private var chatContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button(action: onClose) { Image(systemName: "arrow.left").frame(width: 36, height: 44) }.accessibilityLabel(L("返回"))
                Button { openProfile() } label: { Avatar(user: match["user"], size: 40) }.buttonStyle(.plain).disabled(match["user"].id.isEmpty).accessibilityLabel(L("查看名片"))
                Text(match.exists ? match["user"]["displayName"].string : L("正在加载…")).font(.headline).lineLimit(1)
                VRCIdentityBadge(user: match["user"])
                Spacer(minLength: 4)
                Button { app.run { _ = try await app.api.request(path + "/vrc-share", method: "POST", body: [:]); try await reload() } } label: {
                    ViewThatFits(in: .horizontal) {
                        Label(L(match["vrc"]["myShared"].bool ? "已共享" : "VRC 见"), systemImage: "gamecontroller").fixedSize()
                        Image(systemName: "gamecontroller").frame(width: 24, height: 24)
                    }.font(.caption).padding(10).background(app.palette.secondary, in: Capsule())
                }.accessibilityLabel(L(match["vrc"]["myShared"].bool ? "已共享" : "VRC 见")).disabled(!allowed || match["vrc"]["myShared"].bool)
                Menu {
                    Button(L("查看名片")) { openProfile() }
                    Button(L("举报这段对话")) { report = true }
                    Button(L("解除配对"), role: .destructive) { unmatch = true }
                    Button(L("封锁"), role: .destructive) { block = true }
                } label: { Image(systemName: "ellipsis").rotationEffect(.degrees(90)).padding(8) }
            }.foregroundStyle(app.palette.text).padding(12).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 20)).siteOutline(RoundedRectangle(cornerRadius: 20))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if !cursor.isEmpty { Button(L("加载更早的消息")) { app.run { try await loadMessages(earlier: true) } } }
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            if let date = ERPDate.parse(message["createdAt"].string), index == 0 || !ERPDate.sameDay(message["createdAt"].string, messages[index - 1]["createdAt"].string) {
                                Text(date, format: .dateTime.year().month().day()).font(.caption).foregroundStyle(app.palette.muted).padding(.vertical, 12)
                            }
                            MessageBubble(message: message).id(message.id).contextMenu {
                            if canRecall(message) { Button(L("撤回这条消息？"), role: .destructive) { app.run { _ = try await app.api.request("/messages/\(APIClient.encode(message.id))/recall", method: "POST", body: [:]); try await reload() } } }
                        }
                        }
                    }.padding(12).frame(maxWidth: 850).frame(maxWidth: .infinity)
                }.background(app.palette.surface, in: RoundedRectangle(cornerRadius: 20)).siteOutline(RoundedRectangle(cornerRadius: 20)).refreshable { do { try await reload() } catch { loadFailure = error.localizedDescription } }
                    .onChange(of: messages.last?.id) { newID in if let newID { withAnimation { proxy.scrollTo(newID, anchor: .bottom) } } }
            }
            if match["boundary"]["required"].bool && !match["boundary"]["myAck"].bool { Button(L("交流边界确认")) { boundary = true } }
            Button(L("✧ 破冰")) { icebreaker = true }.disabled(!allowed).buttonStyle(.bordered)
            HStack(spacing: 12) {
                Button { imageSheet = true } label: { Image(systemName: "photo.badge.plus").frame(width: 36, height: 44) }.accessibilityLabel(L("发送图片"))
                Button { voiceSheet = true } label: { Image(systemName: "mic").frame(width: 36, height: 44) }.accessibilityLabel(L("录制语音"))
                TextField(L("输入消息…"), text: $text, axis: .vertical).lineLimit(1...4).keyboardType(.default)
                Button { sendText() } label: { Image(systemName: "paperplane").foregroundStyle(app.accent) }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
            }.disabled(!allowed || sending).font(.title3).padding(14).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 20)).siteOutline(RoundedRectangle(cornerRadius: 20))
            Text(L(!match.exists ? "正在加载…" : allowed ? "聊天记录按网站账号权限保存" : "此配对已结束")).font(.caption).foregroundStyle(app.palette.muted)
        }.padding(18).frame(maxWidth: 820).frame(maxWidth: .infinity).background(app.palette.background).task { do { try await reload() } catch { app.message = error.localizedDescription } }.onChange(of: app.eventSerial) { _ in app.run { try await reload() } }
            .sheet(isPresented: $imageSheet) { ImageUploadView(purpose: "chat_image", matchID: id) { media in app.run { try await send(type: "image", media: media) } }.environmentObject(app).sitePresentation() }
            .sheet(isPresented: $voiceSheet) { VoiceRecordView(matchID: id) { media in app.run { try await send(type: "voice", media: media) } }.environmentObject(app).sitePresentation() }
            .sheet(isPresented: $report) { ReportView(target: "match", id: id).environmentObject(app).sitePresentation() }
            .sheet(isPresented: $icebreaker) { IcebreakerView(matchID: id, peerName: match["user"]["displayName"].string, canAct: allowed) { text = $0 }.environmentObject(app).sitePresentation() }
            .alert(L("提示"), isPresented: Binding(get: { loadFailure != nil }, set: { if !$0 { loadFailure = nil } })) { Button(L("重试")) { app.run { do { try await reload() } catch { loadFailure = error.localizedDescription } } }; Button(L("关闭"), role: .cancel) { loadFailure = nil } } message: { Text(loadFailure ?? "") }
            .sheet(item: $sheetProfileRoute) { route in ProfileDetailView(id: route.id).environmentObject(app).sitePresentation() }
            .sheet(isPresented: $boundary) { VStack(alignment: .leading, spacing: 20) { Text(L("交流边界确认")).font(.title.bold()); ForEach(match["boundary"]["peer"]["limits"].array, id: \.self) { value in Text(value["item"].string + " · " + value["level"].string) }; Text(L("安全词") + ": " + match["boundary"]["peer"]["safeword"].string); PrimaryButton(title: "已阅读并确认") { app.run { _ = try await app.api.request(path + "/boundary-ack", method: "POST", body: [:]); boundary = false; try await reload() } } }.padding(25) }
            .confirmationDialog(L("解除配对"), isPresented: $unmatch) { Button(L("解除配对"), role: .destructive) { app.run { _ = try await app.api.request(path, method: "DELETE"); onClose() } } }
            .confirmationDialog(L("封锁"), isPresented: $block) { Button(L("封锁"), role: .destructive) { app.run { _ = try await app.api.request("/users/\(APIClient.encode(match["user"].id))/block", method: "POST", body: [:]); onClose() } } }
    }
    private func reload() async throws {
        if refreshing { refreshAgain = true; return }
        refreshing = true
        defer { refreshing = false; if refreshAgain { refreshAgain = false; app.run { try await reload() } } }
        let response = try await app.api.request(path, fresh: true)
        guard !Task.isCancelled else { return }
        match = ChatPayload.detail(response)
        boundary = match["boundary"]["required"].bool && !match["boundary"]["myAck"].bool
        try await loadMessages()
    }
    private func loadMessages(earlier: Bool = false) async throws {
        let result = try await app.api.request(path + "/messages?limit=50" + (earlier ? "&before=" + APIClient.encode(cursor) : ""), fresh: true)
        var all = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) }); for value in result["items"].array where !value.id.isEmpty { all[value.id] = value }
        messages = all.values.sorted { $0["createdAt"].string == $1["createdAt"].string ? $0.id < $1.id : $0["createdAt"].string < $1["createdAt"].string }
        if earlier || cursor.isEmpty { cursor = result["nextCursor"].string }
        if let last = messages.last, readTracker.begin(last.id) {
            do { _ = try await app.api.request(path + "/read", method: "POST", body: ["lastMessageId": last.id]); readTracker.finish(last.id, succeeded: true); await app.refreshCounters() }
            catch { readTracker.finish(last.id, succeeded: false); throw error }
        }
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
        if message["recalled"].bool || ["system", "notice"].contains(message["type"].string) { Text(L(message["recalled"].bool ? "消息已撤回" : message["type"].string == "system" ? "你们已成功配对" : message["text"].string)).font(.caption).foregroundStyle(app.palette.muted).padding(10).frame(maxWidth: .infinity) }
        else { HStack { if mine { Spacer(minLength: 30) }; VStack(alignment: .trailing, spacing: 6) {
            if message["type"].string == "vrc_link" { if ERPRules.isVRC(message["text"].string), let url = URL(string: message["text"].string) { Link(destination: url) { Label(L("我的 VRChat 主页"), systemImage: "gamecontroller").fontWeight(.semibold) } } else { Text(L("VRChat 链接暂不可用")) } }
            else if message["type"].string == "image" { RemoteImage(media: message["media"], size: 800).frame(width: 205, height: 190).clipShape(RoundedRectangle(cornerRadius: 14)) }
            else if message["type"].string == "voice" { AudioButton(media: message["media"]) }
            else { Text(message["text"].string).textSelection(.enabled) }
            Group { if let date = ERPDate.parse(message["createdAt"].string) { Text(date, format: .dateTime.hour().minute()) } else { Text(String(message["createdAt"].string.dropFirst(11).prefix(5))) } }.font(.caption2).opacity(0.65)
        }.padding(12).foregroundStyle(mine ? .white : app.palette.text).background(mine ? app.accent : app.palette.secondary, in: RoundedRectangle(cornerRadius: 22)).frame(maxWidth: 340, alignment: mine ? .trailing : .leading); if !mine { Spacer(minLength: 30) } } }
    }
}

struct ReportView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let target: String, id: String
    @State private var category = "other"
    @State private var description = ""
    @State private var token = ""
    @State private var confirmed = false
    @State private var busy = false
    @State private var reset = 0
    let options = [("underage", "未成年用户"), ("child_avatar_nsfw", "儿童形象的成人内容"), ("unlabeled_nsfw", "未标记的成人内容"), ("real_person_nsfw", "真人成人内容"), ("non_consensual_photo", "未经同意的照片"), ("impersonation", "冒充他人"), ("harassment", "骚扰"), ("scam", "诈骗"), ("other", "其他")]
    var body: some View { NavigationStack { Form { Picker(L("举报类别"), selection: $category) { ForEach(options, id: \.0) { Text(L($0.1)).tag($0.0) } }; TextEditor(text: $description).frame(minHeight: 140); Toggle(L("我确认信息属实，举报并非恶意或报复"), isOn: $confirmed); VerificationView(action: "report", token: $token, reset: reset).frame(height: 110); PrimaryButton(title: "提交举报") { busy = true; app.run { defer { busy = false }; do { await app.api.syncWebCookies(); _ = try await app.api.request("/reports", method: "POST", body: ["targetType": target, "targetId": id, "category": category, "description": description, "lang": app.localeCode, "confirmed": true, "turnstileToken": token]); dismiss() } catch { token = ""; reset += 1; throw error } } }.disabled(busy || !confirmed || description.isEmpty || description.count > 2000 || (!app.config["turnstileSiteKey"].string.isEmpty && token.isEmpty)) }.navigationTitle(L("提交举报")).toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L("关闭")) { dismiss() } } } }
}
}
