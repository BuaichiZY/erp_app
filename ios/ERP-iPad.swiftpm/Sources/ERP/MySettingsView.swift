import SwiftUI
import CryptoKit
import Security

struct MyView: View {
    @EnvironmentObject private var app: AppState
    @State private var passCount: Int?
    @State private var resettingPasses = false
    @State private var confirmReset = false
    @State private var preview = false
    var body: some View {
        Group {
        if preview { ProfileDetailView(id: app.me.id, onClose: { preview = false }) }
        else { Page(title: "") {
            if app.authenticated {
                MyProfileHero(preview: { preview = true })
                Panel {
                    Button { app.screen = .energy } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "bolt.fill").font(.title2).foregroundStyle(app.palette.energy)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L("能量")).font(.headline)
                                Text(L("补充能量") + " \(app.energy["regen"].int)/\(app.energy["regenMax"].int) · " + L("永久能量") + " \(app.energy["permanent"].int)").font(.subheadline).foregroundStyle(app.palette.muted)
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundStyle(app.palette.muted)
                        }.frame(maxWidth: .infinity, minHeight: 54).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(app.palette.text)
                }
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Image(systemName: "forward.end").font(.title3).frame(width: 28).foregroundStyle(app.palette.muted)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("跳过的人")).font(.headline)
                            Text(passCount.map { L("目前") + " \($0) " + L("人") } ?? L("正在加载…")).font(.subheadline).foregroundStyle(app.palette.muted)
                        }
                        Spacer(minLength: 8)
                        Button { confirmReset = true } label: { Label(L("重新看看") + (passCount.map { " \($0) " + L("人") } ?? ""), systemImage: "arrow.uturn.backward").font(.subheadline).padding(12).background(app.palette.secondary, in: RoundedRectangle(cornerRadius: 12)).siteOutline(RoundedRectangle(cornerRadius: 12), normalBorder: false) }.buttonStyle(.plain).disabled((passCount ?? 0) == 0 || resettingPasses)
                    }.padding(20)
                    SiteDivider()
                    MyHubRow(icon: "shoeprints.fill", title: "访客", badge: app.counters["newVisitors"].int > 0 ? app.counters["newVisitors"].int : nil) { app.likesKind = "visitors"; app.tab = 1 }
                    SiteDivider()
                    MyHubRow(icon: "bell", title: "通知", badge: app.counters["unreadNotifications"].int > 0 ? app.counters["unreadNotifications"].int : nil) { app.screen = .notifications }
                    SiteDivider()
                    MyHubRow(icon: "gamecontroller", title: "VRChat 绑定与隐私") { app.screen = .vrc }
                    SiteDivider()
                    MyHubRow(icon: "crown", title: "会员") { app.screen = .membership }
                    SiteDivider()
                    MyHubRow(icon: "gift", title: "邀请朋友") { app.screen = .invite }
                    SiteDivider()
                    MyHubRow(icon: "gearshape", title: "设置") { app.screen = .settings }
                    SiteDivider()
                    MyHubRow(icon: "info.circle", title: "关于", badge: app.updateAvailable ? 0 : nil) { app.screen = .about }
                }.background(app.palette.surface).clipShape(RoundedRectangle(cornerRadius: 20)).siteOutline(RoundedRectangle(cornerRadius: 20))
                Button(L("退出登录"), role: .destructive) { app.run { try await app.api.logout(); app.me = .null; app.counters = .null; app.disconnectRealtime(); await ImageStore.shared.clear(); app.tab = 0 } }.frame(maxWidth: .infinity).padding()
            } else { EmptyState(title: "请先登录"); PrimaryButton(title: "登录") { app.screen = .login } }
        } }
        }.refreshable { await app.reloadSession(); await loadPasses() }
            .task(id: app.me.id) { await loadPasses() }
            .alert(L("让跳过的人重新出现在探索中？"), isPresented: $confirmReset) {
                Button(L("取消"), role: .cancel) {}
                Button(L("重新看看")) { resettingPasses = true; app.run { defer { resettingPasses = false }; _ = try await app.api.request("/me/passes", method: "DELETE"); passCount = 0 } }
            }
    }
    private func loadPasses() async {
        guard app.authenticated else { passCount = nil; return }
        do { let result = try await app.api.request("/me/passes", fresh: true); if !Task.isCancelled { passCount = max(0, result["count"].int) } }
        catch { if !Task.isCancelled { app.message = error.localizedDescription } }
    }
}

private struct MyHubRow: View {
    @EnvironmentObject private var app: AppState
    let icon: String, title: String
    var badge: Int? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title3).frame(width: 28).foregroundStyle(app.palette.muted)
                Text(L(title)).font(.headline)
                Spacer()
                if let badge { Dot(count: badge) }
                Image(systemName: "chevron.right").foregroundStyle(app.palette.muted)
            }.padding(.horizontal, 20).frame(minHeight: 70).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(app.palette.text)
    }
}

private struct MyProfileHero: View {
    let preview: () -> Void
    @EnvironmentObject private var app: AppState
    @Environment(\.pageLayout) private var layout
    private var completeness: Double { Double(max(0, min(100, app.me["profileCompleteness"].int))) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if app.me["cover"].exists { RemoteImage(media: app.me["cover"], size: 1200).frame(height: layout.contentWidth < 600 ? 150 : 210).clipped() }
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    Avatar(user: app.me, size: layout.contentWidth < 600 ? 96 : 128)
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .padding(.top, app.me["cover"].exists ? (layout.contentWidth >= 600 ? -64 : -40) : 0)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(app.me["displayName"].string).font(.title2.bold())
                        if !app.me.text("tagline").isEmpty { Text(app.me.text("tagline")).foregroundStyle(app.palette.muted) }
                        VRCIdentityBadge(user: app.me, compact: false, showPrefix: true)
                    }; Spacer(minLength: 0)
                }
                HStack { Text(L("资料完整度")).font(.subheadline.bold()); Spacer(); Text("\(Int(completeness))%").foregroundStyle(app.accent).fontWeight(.bold) }
                ProgressView(value: completeness, total: 100).tint(app.accent)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { actions }
                    VStack(spacing: 10) { actions }
                }
            }.padding(18)
        }.background(app.palette.surface).clipShape(RoundedRectangle(cornerRadius: 20)).siteOutline(RoundedRectangle(cornerRadius: 20))
    }
    @ViewBuilder private var actions: some View {
        PrimaryButton(title: "编辑名片", icon: "pencil") { app.screen = .editProfile }
        Button(action: preview) { Label(L("预览名片"), systemImage: "eye").font(.subheadline.bold()).fixedSize().padding(14).frame(maxWidth: .infinity).background(app.palette.secondary, in: RoundedRectangle(cornerRadius: 14)).siteOutline(RoundedRectangle(cornerRadius: 14), normalBorder: false) }.buttonStyle(.plain)
        Button { app.screen = .share } label: { Label(L("分享"), systemImage: "square.and.arrow.up").font(.subheadline.bold()).fixedSize().padding(14).frame(maxWidth: .infinity).background(app.palette.secondary, in: RoundedRectangle(cornerRadius: 14)).siteOutline(RoundedRectangle(cornerRadius: 14), normalBorder: false) }.buttonStyle(.plain)
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
            VStack(spacing: 0) {
                let entries = sections.flatMap { $0 }
                ForEach(entries.indices, id: \.self) { index in
                    let entry = entries[index]
                    MenuRow(icon: entry.1, title: entry.2, subtitle: entry.3) { app.screen = entry.0 }
                    if index + 1 < entries.count { SiteDivider() }
                }
            }.background(app.palette.surface, in: RoundedRectangle(cornerRadius: 18)).siteOutline(RoundedRectangle(cornerRadius: 18))

        }
    }
}

struct SettingsDetailView: View {
    @EnvironmentObject private var app: AppState
    let screen: Screen
    @State private var data: JSON = .null
    @State private var ledger: [JSON] = []
    @State private var ledgerCursor = ""
    @State private var cursor = ""
    @State private var avoid: [JSON] = []
    @State private var avoidQuery = ""
    @State private var password = ""
    @State private var newPassword = ""
    @State private var redeem = ""
    @State private var loading = false
    @State private var failure = ""
    @State private var removal: JSON?
    @State private var appeal: JSON?
    @State private var appealText = ""
    private var title: String { [Screen.energy: "能量", .invite: "邀请朋友", .membership: "会员", .content: "内容与风格", .privacy: "隐私", .account: "账号与安全", .language: "语言", .appearance: "主题与外观", .blocks: "封锁名单", .sanctions: "账号状态", .sessions: "登录设备", .password: "修改密码", .notificationSettings: "通知偏好"][screen] ?? "设置" }
    var body: some View {
        Page(title: title) {
            if loading && !data.exists { ProgressView().frame(maxWidth: .infinity) }
            if !failure.isEmpty { Text(failure).foregroundStyle(app.palette.muted); Button(L("重试")) { app.run { await load() } } }
            content
        }.task(id: screen) { await load() }.refreshable { await load() }
            .confirmationDialog(L(screen == .sessions ? "让此设备退出登录？" : "解除封锁？"), isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } })) {
                Button(L("确认"), role: .destructive) { if let item = removal { app.run { _ = try await app.api.request(screen == .sessions ? "/me/sessions/" + APIClient.encode(item.id) : "/users/" + APIClient.encode(item["user"].exists ? item["user"].id : item.id) + "/block", method: "DELETE"); await load() }; removal = nil } }
            }
            .sheet(item: $appeal) { item in
                VStack(spacing: 20) { Text(L("提交申诉")).font(.title2.bold()); TextField(L("申诉说明"), text: $appealText, axis: .vertical).lineLimit(6...12).textFieldStyle(.roundedBorder); PrimaryButton(title: "提交") { app.run { _ = try await app.api.request("/appeals", method: "POST", body: ["sanctionId": item.id, "text": String(appealText.prefix(3000))]); appeal = nil; appealText = ""; await load() } }.disabled(appealText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding(24).environmentObject(app).sitePresentation()
            }
    }
    @ViewBuilder private var content: some View {
        switch screen {
        case .language: choices([("auto", "自动检测"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("ja", "日本語"), ("en", "English"), ("ko", "한국어")], selected: app.language) { app.setLanguage($0) }
        case .appearance: choices([("auto", "跟随模式风格"), ("light", "浅色"), ("dark", "深色"), ("system", "跟随系统设置")], selected: app.appearance) { app.setAppearance($0) }
        case .content:
            Panel { Text(L("内容模式")).font(.headline); choices([("sfw", "SFW"), ("mixed", "混合"), ("nsfw", "仅 NSFW")], selected: app.mode) { app.setMode($0) } }
            MenuRow(icon: "circle.lefthalf.filled", title: "主题与外观") { app.screen = .appearance }
            ForEach([("suggestiveView", "擦边"), ("r18View", "R18"), ("r18gView", "血腥内容")], id: \.0) { key, label in Panel {
                Text(L(label)).font(.headline)
                if key != "suggestiveView", app.me["r18ConsentAt"].string.isEmpty { Text(L("请先在官方网站完成成人内容规则确认。")); Link(L("前往官网"), destination: APIClient.origin.appendingPathComponent("settings/content")) }
                else { choices([("hide", "隐藏"), ("blur", "模糊"), ("show", "显示")], selected: app.me["settings"][key].string) { setting(key, $0) } }
            } }
        case .privacy: privacy
        case .notificationSettings: notifications
        case .account: AccountSecurityControls()
        case .password:
            SecureField(L("当前密码"), text: $password).textFieldStyle(.roundedBorder)
            SecureField(L("新密码"), text: $newPassword).textFieldStyle(.roundedBorder)
            PrimaryButton(title: "修改密码") { app.run { _ = try await app.api.request("/me/password", method: "POST", body: ["currentPassword": password, "newPassword": newPassword]); password = ""; newPassword = ""; app.message = L("已保存") } }.disabled(password.isEmpty || newPassword.count < 8)
        case .sessions:
            ForEach(data.records) { session in Panel {
                HStack { Text(session["device"].string.isEmpty ? session["userAgent"].string : session["device"].string).font(.headline); Spacer(); if session["current"].bool { Text(L("当前设备")).foregroundStyle(app.accent) } }
                date(session["lastSeenAt"].string.isEmpty ? session["lastActiveAt"].string : session["lastSeenAt"].string)
                if !session["current"].bool { Button(L("退出此设备"), role: .destructive) { removal = session } }
            } }
            if data.exists && data.records.isEmpty { EmptyState(title: "暂无记录") }
        case .energy: energy
        case .membership:
            let membership = data["membership"].exists ? data["membership"] : data
            Panel { Text(membership["tierName"].string.isEmpty ? L("当前会员状态") : membership["tierName"].string).font(.title2.bold()); date(membership["expiresAt"].string); if !data["features"].object.isEmpty { ForEach(data["features"].object.keys.sorted(), id: \.self) { key in HStack { Text(L(featureTitle(key))); Spacer(); Image(systemName: data["features"][key]["enabled"].bool ? "checkmark.circle" : "minus.circle") } } } }
            TextField(L("兑换码"), text: $redeem).textFieldStyle(.roundedBorder)
            PrimaryButton(title: "兑换") { app.run { _ = try await app.api.request("/me/redeem", method: "POST", body: ["code": redeem.trimmingCharacters(in: .whitespacesAndNewlines)]); redeem = ""; await load(); await app.reloadSession() } }.disabled(redeem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(L("同步 Patreon 会员")) { app.run { _ = try await app.api.request("/me/patreon/sync", method: "POST", body: [:]); await load(); await app.reloadSession() } }
        case .invite:
            Panel { Text(L("邀请好友注册，获得永久能量。")).foregroundStyle(app.palette.muted)
                let raw = data["url"].string.isEmpty ? data["inviteUrl"].string.isEmpty ? data["code"].string.isEmpty ? "" : "https://erp.sex/register?invite=" + APIClient.encode(data["code"].string) : data["inviteUrl"].string : data["url"].string
                Text(raw).textSelection(.enabled)
                if let url = URL(string: raw), url.scheme == "https" { ShareLink(item: url) { Label(L("分享邀请"), systemImage: "square.and.arrow.up") }; Button(L("复制链接")) { UIPasteboard.general.url = url; app.message = L("已复制链接") } }
                if data["count"].exists { Text(L("邀请人数") + " \(data["count"].int)") }
            }
        case .blocks:
            ForEach(data.records) { item in let user = item["user"].exists ? item["user"] : item
                Panel { HStack { Avatar(user: user, size: 44); Text(user["displayName"].string); Spacer(); Button(L("解除封锁")) { removal = item } } }
            }
            if data.exists && data.records.isEmpty { EmptyState(title: "暂无封锁的用户") }
            if !cursor.isEmpty { Button(L("加载更多")) { app.run { await load(more: true) } }.disabled(loading) }
        case .sanctions:
            ForEach(data.records) { item in Panel { Text(L(item["kind"].string)).font(.headline); Text(item["reason"].text); date(item["startsAt"].string); date(item["endsAt"].string); if item["appeal"].exists { Text(L(item["appeal"]["status"].string)); Text(item["appeal"]["note"].text) } else if item["kind"].string != "warning" { Button(L("提交申诉")) { appealText = ""; appeal = item } } } }
            if data.exists && data.records.isEmpty { EmptyState(title: "暂无警告或限制") }
        default: EmptyState()
        }
    }
    private var privacy: some View {
        VStack(spacing: 16) {
            Panel {
                Text(L("资料可见性")).font(.headline)
                ForEach([("stealth", "隐身模式"), ("paused", "暂停展示名片"), ("publicDiscover", "公开探索名片"), ("hideVisits", "隐藏访问足迹"), ("showMatchCount", "显示配对人数"), ("showMutualMatches", "显示共同配对")], id: \.0) { key, label in
                    Toggle(L(label), isOn: Binding(get: { app.me["settings"][key].exists ? app.me["settings"][key].bool : key == "publicDiscover" }, set: { setting(key, $0) })).disabled(key == "hideVisits" && !app.me["features"]["hide_visits"]["enabled"].bool)
                }
            }
            Panel { Text(L("留言板")).font(.headline); Toggle(L("开放留言板"), isOn: Binding(get: { app.me["settings"]["guestbook"].exists ? app.me["settings"]["guestbook"].bool : true }, set: { setting("guestbook", $0) })); choices([("everyone", "所有人"), ("verified", "已验证用户"), ("matches", "仅配对对象")], selected: app.me["settings"]["guestbookScope"].string.isEmpty ? "verified" : app.me["settings"]["guestbookScope"].string) { setting("guestbookScope", $0) } }
            Panel {
                Text(L("避开熟人")).font(.headline)
                TextField(L("VRChat 用户 ID 或 ERP 名片链接"), text: $avoidQuery).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                Button(L("添加")) { app.run { let value = avoidQuery.trimmingCharacters(in: .whitespacesAndNewlines); var body: [String: Any] = ["vrcUser": value]; if let id = ERPRules.profileID(value) { body = ["userId": id] }; _ = try await app.api.request("/me/avoid", method: "POST", body: body); avoidQuery = ""; await load() } }.disabled(avoidQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ForEach(avoid) { item in HStack { Text(item["label"].string.isEmpty ? item["vrcUserId"].string.isEmpty ? item["userId"].string : item["vrcUserId"].string : item["label"].string); Spacer(); Button(L("移除")) { app.run { _ = try await app.api.request("/me/avoid/" + APIClient.encode(item.id), method: "DELETE"); await load() } } } }
            }
        }
    }
    private var notifications: some View {
        VStack(spacing: 16) {
            Panel { Text(L("应用通知")).font(.headline)
                ForEach([("guestbook", "留言板通知"), ("visitorBadge", "显示访客提示"), ("pushMatch", "新配对通知"), ("pushMessage", "新消息通知")], id: \.0) { key, label in
                    Toggle(L(label), isOn: Binding(get: { let value = app.me["settings"]["notify"][key]; return value.exists ? value.bool : key == "guestbook" }, set: { value in notify([key: value]) }))
                }
                Text(L("通知与聊天在应用打开时更新。")).font(.caption).foregroundStyle(app.palette.muted)
            }
            Panel { Text(L("邮件通知")).font(.headline)
                if !app.me["emailVerified"].bool { Text(L("请先验证电子邮件。")).foregroundStyle(app.palette.muted) }
                ForEach(app.config["emailPurposes"].array, id: \.self) { item in let key = item.string
                    Toggle(L(["new_message": "新消息通知", "new_match": "新配对通知", "guestbook": "留言板通知"][key] ?? key), isOn: Binding(get: { let value = app.me["settings"]["notify"]["email"][key]; return value.exists ? value.bool : key != "new_message" }, set: { notify(["email": [key: $0]]) })).disabled(!app.me["emailVerified"].bool)
                }
            }
        }
    }
    private var energy: some View {
        VStack(spacing: 16) {
            Panel { Label(L("补充能量") + " \(data["regen"].int)/\(data["regenMax"].int)", systemImage: "bolt.fill").font(.title2.bold()); ProgressView(value: Double(data["regen"].int), total: Double(max(1, data["regenMax"].int))).tint(app.accent)
                if data["regen"].int >= data["regenMax"].int { Text(L("已满")) }
                else if let next = ERPDate.parse(data["nextRegenAt"].string) { HStack { Text(L("下次恢复")); Text(next, style: .timer) } }
                Label { Text(L("永久能量") + " \(data["permanent"].int)") } icon: { EnergyGem() }; Text(L("不会随时间恢复")).font(.caption).foregroundStyle(app.palette.muted)
            }
            Panel { Text(L("能量如何运作")).font(.headline); Text(L("喜欢与超级喜欢会消耗能量，优先使用补充能量，不足时使用永久能量。")); Text(L("喜欢") + " \(app.config["energyCosts"]["like"].exists ? app.config["energyCosts"]["like"].int : 2) · " + L("超级喜欢") + " \(app.config["energyCosts"]["superlike"].exists ? app.config["energyCosts"]["superlike"].int : 10)"); Button(L("查看会员")) { app.screen = .membership } }
            Panel { Text(L("能量记录")).font(.headline); ForEach(ledger) { item in HStack { VStack(alignment: .leading) { Text(L(item["reason"].string)); date(item["createdAt"].string) }; Spacer(); Text((item["delta"].int > 0 ? "+" : "") + "\(item["delta"].int)").foregroundStyle(item["delta"].int < 0 ? app.accent : .green) } }; if ledger.isEmpty && !loading { Text(L("暂无记录")) }; if !ledgerCursor.isEmpty { Button(L("加载更多记录")) { app.run { try await loadLedger(more: true) } } } }
        }
    }
    private func featureTitle(_ key: String) -> String {
        ["who_liked_me": "查看喜欢我的人", "who_visited_me": "查看访客", "cancel_like": "取消喜欢", "hide_visits": "隐藏访问足迹", "original_upload": "上传原图", "superlike": "超级喜欢", "undo": "撤回滑卡", "secret_like": "悄悄喜欢", "energy": "能量", "remove_brand": "移除网站标识"][key] ?? "会员权益"
    }
    private func date(_ value: String) -> some View { Group { if let date = ERPDate.parse(value) { Text(date, format: .dateTime.year().month().day().hour().minute()) } else if !value.isEmpty { Text(value) } }.font(.caption).foregroundStyle(app.palette.muted) }
    private func choices(_ options: [(String, String)], selected: String, select: @escaping (String) -> Void) -> some View { ForEach(options, id: \.0) { option in Button { select(option.0) } label: { HStack { Text(L(option.1)); Spacer(); if selected == option.0 { Image(systemName: "checkmark") } }.frame(maxWidth: .infinity, minHeight: 44).padding(12).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(selected == option.0 ? app.accent : app.palette.border, lineWidth: selected == option.0 ? 2 : 1)) }.buttonStyle(.plain) } }
    private func setting(_ key: String, _ value: Any) { app.run { _ = try await app.api.request("/me/settings", method: "PATCH", body: [key: value]); await app.reloadSession() } }
    private func notify(_ value: [String: Any]) { setting("notify", value) }
    private func loadLedger(more: Bool = false) async throws { let result = try await app.api.request("/me/energy/ledger" + (more ? "?cursor=" + APIClient.encode(ledgerCursor) : ""), fresh: true); ledger = more ? ledger + result.records.filter { entry in !ledger.contains(where: { $0.id == entry.id }) } : result.records; ledgerCursor = result["nextCursor"].string }
    private func load(more: Bool = false) async {
        let endpoint: [Screen: String] = [.energy: "/me/energy", .invite: "/me/invite", .membership: "/me/membership", .blocks: "/me/blocks", .sanctions: "/me/sanctions", .sessions: "/me/sessions"]
        loading = true; defer { loading = false }
        do {
            if let path = endpoint[screen] { let result = try await app.api.request(path + (more && !cursor.isEmpty ? "?cursor=" + APIClient.encode(cursor) : ""), fresh: true); try Task.checkCancellation(); if more { data = .object(["items": .array(data.records + result.records.filter { entry in !data.records.contains(where: { $0.id == entry.id }) })]) } else { data = result }; cursor = result["nextCursor"].string }
            if screen == .privacy { avoid = try await app.api.request("/me/avoid", fresh: true).records }
            if screen == .energy { try await loadLedger() }
            failure = ""
        } catch { if !Task.isCancelled { failure = error.localizedDescription } }
    }
}

struct NotificationsView: View {
    @EnvironmentObject private var app: AppState
    @State private var items: [JSON] = []
    @State private var cursor = ""
    var body: some View {
        Page(title: "通知") {
            Button(L("全部标为已读")) { app.run { _ = try await app.api.request("/notifications/read", method: "POST", body: ["all": true]); try await load(); await app.refreshCounters() } }.frame(maxWidth: .infinity).padding(14).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 16))
            VStack(spacing: 0) {
                ForEach(items) { item in
                    let copy = NotificationPresentation(item)
                    Button { open(item) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: copy.symbol).foregroundStyle(app.accent).frame(width: 32, height: 28)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(L(copy.title)).font(.headline)
                                if !copy.message.isEmpty { Text(copy.message).font(.subheadline).foregroundStyle(app.palette.muted).fixedSize(horizontal: false, vertical: true) }
                                if let date = copy.date { Text(date, format: .dateTime.year().month().day().hour().minute()).font(.caption).foregroundStyle(app.palette.muted) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            if !item["read"].bool { Dot().padding(.top, 7) }
                        }.padding(18).frame(minHeight: 64).foregroundStyle(app.palette.text).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    SiteDivider()
                }
            }.background(app.palette.surface, in: RoundedRectangle(cornerRadius: 16))
            if items.isEmpty { EmptyState() }
            if !cursor.isEmpty { Button(L("加载更多")) { app.run { try await load(more: true) } } }
        }.refreshable { do { try await load() } catch { app.message = error.localizedDescription } }.task { do { try await load() } catch { app.message = error.localizedDescription } }
    }
    private func load(more: Bool = false) async throws { let result = try await app.api.request("/notifications" + (more ? "?cursor=" + APIClient.encode(cursor) : ""), fresh: !more); items = more ? items + result["items"].array : result["items"].array; cursor = result["nextCursor"].string }
    private func open(_ item: JSON) {
        app.run {
            if !item["read"].bool {
                _ = try await app.api.request("/notifications/read", method: "POST", body: ["ids": [item.id]])
                await app.refreshCounters()
            }
            app.openNotification(item)
        }
    }
}

struct AccountSecurityControls: View {
    @EnvironmentObject private var app: AppState
    @State private var section = ""
    @State private var email = ""
    @State private var password = ""
    @State private var token = ""
    @State private var reset = 0
    @State private var code = ""
    @State private var setup: JSON = .null
    @State private var recovery: [String] = []
    @State private var unlink = ""
    @State private var busy = false
    @State private var authorization: OAuthAuthorization?
    @State private var linkTask: Task<Void, Never>?
    var body: some View {
        VStack(spacing: 16) {
            if !section.isEmpty { HStack { Button(L("返回账号与安全")) { section = ""; setup = .null; code = ""; password = "" }; Spacer() } }
            if section == "email" { emailControls }
            else if section == "2fa" { twoFactor }
            else {
                Panel { Text(L("电子邮件")).font(.headline); Text(app.me["email"].string); Text(L(app.me["emailVerified"].bool ? "已验证" : "未验证")).foregroundStyle(app.palette.muted); Button(L("绑定或更改电子邮件")) { section = "email" } }
                MenuRow(icon: "lock", title: "修改密码") { app.screen = .password }
                MenuRow(icon: "iphone", title: "登录设备") { app.screen = .sessions }
                Panel { Text(L("登录方式")).font(.headline)
                    let linked = Set(app.me["authMethods"].array.map(\.string))
                    ForEach(["email", "x", "discord"], id: \.self) { provider in
                        HStack { Text(provider == "email" ? L("电子邮件") : provider == "x" ? "X" : "Discord"); Spacer()
                            if linked.contains(provider) { Button(L("解除绑定"), role: .destructive) { unlink = provider }.disabled(linked.count <= 1) }
                            else if provider != "email", !app.config["loginMethods"][provider].exists || app.config["loginMethods"][provider].bool { Button(L("绑定")) { link(provider) } }
                            else { Text(L("未绑定")).foregroundStyle(app.palette.muted) }
                        }.frame(minHeight: 44)
                    }
                    if linkTask != nil { Text(L("完成授权后返回应用。")).font(.caption); Button(L("取消授权")) { linkTask?.cancel(); linkTask = nil } }
                }
                MenuRow(icon: "checkmark.shield", title: "两步验证", subtitle: app.me["twoFactorEnabled"].bool ? "已开启" : "使用验证器保护你的账号") { section = "2fa" }
            }
        }.disabled(busy)
            .confirmationDialog(L("解除此登录方式？"), isPresented: Binding(get: { !unlink.isEmpty }, set: { if !$0 { unlink = "" } })) { Button(L("解除绑定"), role: .destructive) { let provider = unlink; unlink = ""; mutation { _ = try await app.api.request("/me/auth-methods/" + provider, method: "DELETE"); await app.reloadSession() } } }
            .sheet(item: $authorization) { value in OAuthBrowser(url: value.url) { authorization = nil } }
            .onDisappear { linkTask?.cancel(); linkTask = nil }
    }
    private var emailControls: some View {
        Panel {
            Text(L("电子邮件")).font(.headline)
            TextField(L("电子邮件"), text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
            if app.me["hasPassword"].bool { SecureField(L("当前密码"), text: $password).textFieldStyle(.roundedBorder) }
            VerificationView(action: "email", token: $token, reset: reset).frame(height: 72)
            Button(L("重试安全验证")) { token = ""; reset += 1 }
            PrimaryButton(title: "发送验证邮件") { mutation { defer { token = ""; reset += 1 }; var body: [String: Any] = ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "turnstileToken": token]; if app.me["hasPassword"].bool { body["password"] = password }; _ = try await app.api.request("/me/email", method: "POST", body: body); password = ""; app.message = L("验证邮件已发送，请检查邮箱。"); section = "" } }.disabled(!email.contains("@") || (app.me["hasPassword"].bool && password.isEmpty) || (app.config["turnstileSiteKey"].exists && !app.config["turnstileSiteKey"].string.isEmpty && token.isEmpty))
        }
    }
    private var twoFactor: some View {
        Panel {
            Text(L("两步验证")).font(.headline)
            if !recovery.isEmpty { Text(L("请保存恢复码")).font(.title2.bold()); Text(L("这些恢复码仅显示一次，请妥善保管。")); ForEach(recovery, id: \.self) { Text($0).font(.system(.body, design: .monospaced)).textSelection(.enabled) }; Button(L("我知道啦")) { recovery = []; section = "" } }
            else if app.me["twoFactorEnabled"].bool {
                Text(L("已开启两步验证"))
                if !app.me["twoFactorRequired"].bool { TextField(L("验证码或恢复码"), text: $code).textInputAutocapitalization(.never).textFieldStyle(.roundedBorder); PrimaryButton(title: "关闭两步验证") { mutation { _ = try await app.api.request("/me/2fa/disable", method: "POST", body: ["code": code]); code = ""; await app.reloadSession() } }.disabled(code.isEmpty) }
            } else if setup.exists {
                Text(L("在验证器中输入以下密钥：")); Text(setup["secret"].string).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                TextField(L("验证码"), text: $code).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                PrimaryButton(title: "启用") { mutation { let result = try await app.api.request("/me/2fa/enable", method: "POST", body: ["code": code]); recovery = result["recoveryCodes"].array.map(\.string); setup = .null; code = ""; await app.reloadSession() } }.disabled(code.count < 6)
            } else { Text(L("使用验证器保护你的账号。")); PrimaryButton(title: "设置两步验证") { mutation { setup = try await app.api.request("/me/2fa/setup", method: "POST", body: [:]) } } }
        }
    }
    private func mutation(_ action: @escaping () async throws -> Void) { guard !busy else { return }; busy = true; app.run { defer { busy = false }; try await action() } }
    private func link(_ provider: String) {
        guard linkTask == nil else { return }
        linkTask = Task { @MainActor in
            defer { linkTask = nil }
            do {
                var bytes = [UInt8](repeating: 0, count: 32)
                guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw URLError(.unknown) }
                func encoded(_ data: Data) -> String { data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
                let secret = encoded(Data(bytes)), hash = encoded(Data(SHA256.hash(data: Data(secret.utf8))))
                let result = try await app.api.request("/auth/oauth/" + provider + "/start", method: "POST", body: ["intent": "link", "claimHash": hash])
                guard let url = URL(string: result["authorizeUrl"].string), url.scheme == "https", let host = url.host, ["erp.sex", "x.com", "twitter.com", "api.x.com", "api.twitter.com", "discord.com", "discordapp.com"].contains(host), url.user == nil else { throw APIError(status: 0, message: L("网站没有返回授权链接")) }
                try Task.checkCancellation(); authorization = OAuthAuthorization(url: url)
                for _ in 0..<120 {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    do { let claim = try await app.api.request("/auth/oauth/claim", method: "POST", body: ["secret": secret]); if claim["status"].string == "done" { authorization = nil; await app.reloadSession(); app.message = L("已绑定"); return } }
                    catch { if let error = error as? APIError, !OAuthRules.retryable(error.status) { throw error } }
                }
                app.message = L("授权已超时，请重新绑定")
            } catch { if !Task.isCancelled { app.message = error.localizedDescription } }
        }
    }
}
