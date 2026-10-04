import SwiftUI

struct MyView: View {
    @EnvironmentObject private var app: AppState
    var body: some View {
        Page(title: "") {
            if app.authenticated {
                Panel {
                    HStack(spacing: 18) { Avatar(user: app.me, size: 92); VStack(alignment: .leading, spacing: 6) { Text(app.me["displayName"].string).font(.title.bold()); Text(app.me.text("tagline")).foregroundStyle(.secondary); if app.me["vrcVerified"].bool { VerifiedBadge() } }; Spacer() }
                    HStack { Button(L("查看名片")) { app.profileRoute = ProfileRoute(id: app.me.id) }; Spacer(); Button(L("编辑名片")) { app.screen = .editProfile }; Spacer(); Button(L("分享名片")) { app.screen = .share } }
                }
                Panel {
                    MenuRow(icon: "person.crop.circle", title: "VRC 账号", subtitle: "VRChat 绑定与状态") { app.screen = .vrc }
                    Divider()
                    MenuRow(icon: "eye", title: "访客", subtitle: "谁看过你的名片", badge: app.counters["newVisitors"].int > 0 ? app.counters["newVisitors"].int : nil) { app.tab = 1 }
                    Divider()
                    MenuRow(icon: "qrcode", title: "分享名片", subtitle: "二维码与链接") { app.screen = .share }
                }
                Panel {
                    MenuRow(icon: "gearshape", title: "设置") { app.screen = .settings }
                    Divider()
                    MenuRow(icon: "crown", title: "会员") { app.screen = .membership }
                    Divider()
                    MenuRow(icon: "gift", title: "邀请朋友") { app.screen = .invite }
                    Divider()
                    MenuRow(icon: "info.circle", title: "关于", badge: app.updateAvailable ? 0 : nil) { app.screen = .about }
                }
                Button(L("退出登录"), role: .destructive) { app.run { try await app.api.logout(); app.me = .null; app.counters = .null; app.disconnectRealtime(); await ImageStore.shared.clear(); app.tab = 0 } }.frame(maxWidth: .infinity).padding()
            } else { EmptyState(title: "请先登录"); PrimaryButton(title: "登录") { app.screen = .login } }
        }.refreshable { await app.reloadSession() }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    private let sections: [[(Screen, String, String, String)]] = [
        [(.account, "person.badge.key", "账号与安全", "电子邮件、密码、登录方式、两步验证"), (.content, "eye", "内容与风格", "看到什么、怎么显示"), (.privacy, "lock", "隐私", "隐身、暂停资料、避开熟人"), (.notificationSettings, "bell", "通知", "推播与电子邮件")],
        [(.vrc, "gamecontroller", "VRChat 绑定", "验证及在线状态"), (.membership, "crown", "会员", "会员权益"), (.energy, "bolt", "能量", "补充与永久能量"), (.invite, "gift", "邀请朋友", "获得永久能量")],
        [(.language, "globe", "语言", "自动检测、简体中文、繁體中文、日本語、English、한국어"), (.blocks, "hand.raised", "封锁名单", "你封锁的人"), (.sanctions, "scale.3d", "账号状态", "警告、限制与申诉")]
    ]
    var body: some View {
        Page(title: "设置") {
            ForEach(sections.indices, id: \.self) { section in
                VStack(spacing: 0) {
                    ForEach(sections[section].indices, id: \.self) { index in
                        let entry = sections[section][index]
                        MenuRow(icon: entry.1, title: entry.2, subtitle: entry.3) { app.screen = entry.0 }
                        if index + 1 < sections[section].count { Divider().padding(.leading, 70) }
                    }
                }.background(Palette.surface, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.secondary.opacity(0.18)))
            }
        }
    }
}

struct SettingsDetailView: View {
    @EnvironmentObject private var app: AppState
    let screen: Screen
    @State private var data: JSON = .null
    @State private var password = ""
    @State private var newPassword = ""
    @State private var redeem = ""
    @State private var guestbookScope = "everyone"
    private var title: String { [Screen.energy: "能量", .invite: "邀请朋友", .membership: "会员", .content: "内容与风格", .privacy: "隐私", .account: "账号与安全", .language: "语言", .appearance: "主题与外观", .blocks: "封锁名单", .sanctions: "账号状态", .sessions: "登录设备", .password: "修改密码", .notificationSettings: "通知偏好"][screen] ?? "设置" }
    var body: some View {
        Page(title: title) {
            switch screen {
            case .language:
                choices([("auto", "自动检测"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("ja", "日本語"), ("en", "English"), ("ko", "한국어")], selected: app.language) { app.setLanguage($0) }
            case .appearance:
                choices([("auto", "跟随模式风格"), ("light", "浅色"), ("dark", "深色"), ("system", "跟随系统设置")], selected: app.appearance) { app.setAppearance($0) }
            case .content:
                MenuRow(icon: "heart", title: "内容模式") { app.screen = nil }
                MenuRow(icon: "circle.lefthalf.filled", title: "主题与外观") { app.screen = .appearance }
                ForEach([("suggestiveView", "擦边"), ("r18View", "R18"), ("r18gView", "血腥内容")], id: \.0) { entry in
                    Panel { Text(L(entry.1)).font(.headline); choices([("hide", "隐藏"), ("blur", "模糊"), ("show", "显示")], selected: app.me["settings"][entry.0].string) { value in setting(entry.0, value) } }
                }
            case .privacy:
                ForEach([("stealth", "隐身"), ("paused", "暂停资料"), ("publicDiscover", "公开探索"), ("hideVisits", "隐藏访客记录"), ("showMatchCount", "显示配对人数"), ("showMutualMatches", "显示共同配对"), ("guestbook", "留言板")], id: \.0) { item in
                    Toggle(L(item.1), isOn: Binding(get: { app.me["settings"][item.0].bool }, set: { setting(item.0, $0) }))
                }
                Panel { Text(L("谁可以留言")).font(.headline); choices([("everyone", "所有人"), ("verified", "已验证用户"), ("matches", "仅配对对象")], selected: app.me["settings"]["guestbookScope"].string) { setting("guestbookScope", $0) } }
            case .notificationSettings:
                ForEach([("guestbook", "留言"), ("visitorBadge", "访客提醒"), ("pushMatch", "新配对"), ("pushMessage", "新消息")], id: \.0) { item in
                    Toggle(L(item.1), isOn: Binding(get: { app.me["settings"]["notify"][item.0].bool }, set: { value in app.run { _ = try await app.api.request("/me/settings", method: "PATCH", body: ["notify": [item.0: value]]); app.me = try await app.api.request("/me", fresh: true) } }))
                }
            case .account:
                MenuRow(icon: "lock", title: "修改密码") { app.screen = .password }
                MenuRow(icon: "iphone", title: "登录设备") { app.screen = .sessions }
                Text(app.me["email"].string).foregroundStyle(.secondary)
                Text(L("两步验证等账号安全设置请在官网完成。"))
            case .password:
                SecureField(L("当前密码"), text: $password).textFieldStyle(.roundedBorder)
                SecureField(L("新密码"), text: $newPassword).textFieldStyle(.roundedBorder)
                PrimaryButton(title: "修改密码") { app.run { _ = try await app.api.request("/me/password", method: "POST", body: ["currentPassword": password, "newPassword": newPassword]); password = ""; newPassword = ""; app.message = L("已保存") } }.disabled(password.isEmpty || newPassword.count < 8)
            case .sessions:
                ForEach(data["items"].array) { session in Panel { Text(session["device"].string.isEmpty ? session["userAgent"].string : session["device"].string); Text(session["lastActiveAt"].string).font(.caption); if !session["current"].bool { Button(L("退出此设备")) { app.run { _ = try await app.api.request("/me/sessions/" + APIClient.encode(session.id), method: "DELETE"); await load() } } } }
                }
            case .energy:
                Panel { Label(L("补充能量") + " \(data["regen"].int)/\(data["regenMax"].int)", systemImage: "bolt.fill"); Text(L("永久能量") + " \(data["permanent"].int)"); Text(data["nextRegenAt"].string).foregroundStyle(.secondary) }
            case .membership:
                Panel { Text(data["tierName"].string.isEmpty ? L("当前会员状态") : data["tierName"].string).font(.title2.bold()); Text(data["expiresAt"].string) }
                TextField(L("兑换码"), text: $redeem).textFieldStyle(.roundedBorder)
                PrimaryButton(title: "兑换") { app.run { _ = try await app.api.request("/me/redeem", method: "POST", body: ["code": redeem]); await load() } }.disabled(redeem.isEmpty)
                Button(L("同步 Patreon 会员")) { app.run { _ = try await app.api.request("/me/patreon/sync", method: "POST", body: [:]); await load() } }
            case .invite:
                let value = data["url"].string.isEmpty ? data["inviteUrl"].string : data["url"].string
                Text(value).textSelection(.enabled)
                if let url = URL(string: value), url.scheme == "https" { ShareLink(item: url) { Label(L("分享邀请"), systemImage: "square.and.arrow.up") } }
            case .blocks:
                ForEach(data["items"].array) { item in Panel { HStack { Avatar(user: item["user"], size: 44); Text(item["user"]["displayName"].string); Spacer(); Button(L("取消封锁")) { app.run { _ = try await app.api.request("/users/" + APIClient.encode(item["user"].id) + "/block", method: "DELETE"); await load() } } } } }
            case .sanctions:
                ForEach(data["items"].array) { item in Panel { Text(item["reason"].string); Text(item["createdAt"].string).font(.caption) } }
                if data["items"].array.isEmpty { EmptyState(title: "暂无记录") }
            default: EmptyState()
            }
        }.task(id: screen) { await load() }
    }
    private func choices(_ options: [(String, String)], selected: String, select: @escaping (String) -> Void) -> some View {
        ForEach(options, id: \.0) { option in Button { select(option.0) } label: { Text(L(option.1)).frame(maxWidth: .infinity).padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(selected == option.0 ? app.accent : .secondary.opacity(0.15), lineWidth: selected == option.0 ? 2 : 1)) }.buttonStyle(.plain) }
    }
    private func setting(_ key: String, _ value: Any) { app.run { _ = try await app.api.request("/me/settings", method: "PATCH", body: [key: value]); app.me = try await app.api.request("/me", fresh: true) } }
    private func load() async {
        let endpoint: [Screen: String] = [.energy: "/me/energy", .invite: "/me/invite", .membership: "/me/membership", .blocks: "/me/blocks", .sanctions: "/me/sanctions", .sessions: "/me/sessions"]
        if let path = endpoint[screen] { do { data = try await app.api.request(path, fresh: true) } catch { app.message = error.localizedDescription } }
    }
}

struct NotificationsView: View {
    @EnvironmentObject private var app: AppState
    @State private var items: [JSON] = []
    @State private var cursor = ""
    var body: some View {
        Page(title: "通知") {
            Button(L("全部标为已读")) { app.run { _ = try await app.api.request("/notifications/read", method: "POST", body: ["all": true]); try await load(); await app.refreshCounters() } }.frame(maxWidth: .infinity).padding(14).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
            VStack(spacing: 0) { ForEach(items) { item in Button { open(item) } label: { HStack(spacing: 12) { Image(systemName: item["type"].string == "match" ? "heart" : "bell").foregroundStyle(app.accent).frame(width: 32); VStack(alignment: .leading, spacing: 4) { Text(item["title"].string).font(.headline); Text(item["body"].string).font(.subheadline).foregroundStyle(.secondary); Text(item["createdAt"].string).font(.caption2).foregroundStyle(.secondary) }; Spacer(); if !item["read"].bool { Dot() } }.padding(15).foregroundStyle(.primary) }.buttonStyle(.plain); Divider() } }.background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
            if items.isEmpty { EmptyState() }
            if !cursor.isEmpty { Button(L("加载更多")) { app.run { try await load(more: true) } } }
        }.refreshable { do { try await load() } catch { app.message = error.localizedDescription } }.task { do { try await load() } catch { app.message = error.localizedDescription } }
    }
    private func load(more: Bool = false) async throws { let result = try await app.api.request("/notifications" + (more ? "?cursor=" + APIClient.encode(cursor) : ""), fresh: !more); items = more ? items + result["items"].array : result["items"].array; cursor = result["nextCursor"].string }
    private func open(_ item: JSON) { app.run { if !item["read"].bool { _ = try await app.api.request("/notifications/read", method: "POST", body: ["ids": [item.id]]); await app.refreshCounters() }; if !item["data"]["matchId"].string.isEmpty { app.screen = nil; app.chatRoute = ChatRoute(id: item["data"]["matchId"].string) } else if !item["data"]["userId"].string.isEmpty { app.screen = nil; app.profileRoute = ProfileRoute(id: item["data"]["userId"].string) } else { try await load() } } }
}
