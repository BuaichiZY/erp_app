import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var app: AppState
    @State private var cards: [JSON] = []
    @State private var index = 0
    @State private var busy = false
    @State private var offset = CGSize.zero
    @State private var grid = false
    @AppStorage("danmaku") private var danmaku = true
    @State private var filters = false
    @State private var query: [String: String] = [:]
    @State private var nextCursor = ""
    @State private var lastIndex: Int?
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Text(L(grid ? "浏览" : "探索")).font(.title.bold()); Spacer()
                        Toggle(isOn: $danmaku) { Image(systemName: "bubble.left.and.bubble.right") }.labelsHidden().frame(width: 50)
                        Button { grid.toggle(); app.run { try await load() } } label: { Image(systemName: grid ? "rectangle.stack" : "square.grid.2x2") }
                        Button { filters = true } label: { Image(systemName: "slider.horizontal.3").padding(10).background(Palette.surface, in: Circle()) }
                    }
                    if grid { LazyVGrid(columns: [GridItem(.adaptive(minimum: 155))], spacing: 14) { ForEach(cards) { user in ProfileTile(user: user).onTapGesture { app.profileRoute = ProfileRoute(id: user.id) } } }; if !nextCursor.isEmpty { Button(L("加载更多")) { app.run { try await load(more: true) } } } }
                    else if index < cards.count {
                        let user = cards[index]
                        ZStack {
                            DiscoveryCard(user: user, danmaku: danmaku)
                            swipeStamps
                        }.frame(height: max(380, min(geometry.size.height - 155, 780)))
                            .offset(offset).rotationEffect(.degrees(Double(offset.width / 25)))
                            .gesture(DragGesture(minimumDistance: 12).onChanged { if !busy { offset = $0.translation } }.onEnded { value in
                                if let action = ERPRules.swipe(x: value.translation.width, y: value.translation.height) { perform(action) }
                                else { withAnimation(.spring()) { offset = .zero } }
                            })
                        HStack(spacing: 18) {
                            circle("arrow.uturn.backward", size: 46, color: .secondary) { undo() }.disabled(lastIndex == nil)
                            circle("xmark", size: 62, color: .secondary) { perform("pass") }
                            SuperLikeButton { perform("superlike") }
                            circle("heart.fill", size: 66, color: .white, background: app.accent) { perform("like") }
                        }.disabled(busy).padding(.vertical, 6)
                    } else { EmptyState(title: "暂无推荐名片"); Button(L("重新加载")) { app.run { try await load() } } }
                }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }.refreshable { if offset == .zero { do { try await load() } catch { app.message = error.localizedDescription } } }
                .background(Palette.background)
                .task(id: "\(app.mode)|\(app.localeCode)|\(app.authenticated)") { do { try await load() } catch { app.message = error.localizedDescription } }
                .sheet(isPresented: $filters) { DiscoverFilterView(values: $query) { app.run { try await load() } }.environmentObject(app) }
        }
    }
    @ViewBuilder private var swipeStamps: some View {
        GeometryReader { geo in
            let action = abs(offset.width) >= abs(offset.height) ? (offset.width > 0 ? "喜欢" : "跳过") : offset.height < 0 ? "超喜欢" : ""
            if !action.isEmpty {
                Text(L(action)).font(.largeTitle.weight(.black)).foregroundStyle(action == "喜欢" ? .green : action == "跳过" ? .red : .black).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(action == "喜欢" ? Color.green : action == "跳过" ? Color.red : Color.yellow, lineWidth: 4)).rotationEffect(.degrees(action == "喜欢" ? -12 : action == "跳过" ? 12 : 0)).opacity(min(1, max(abs(offset.width), abs(offset.height)) / 100)).position(x: action == "喜欢" ? geo.size.width * 0.25 : action == "跳过" ? geo.size.width * 0.75 : geo.size.width / 2, y: geo.size.height * (action == "超喜欢" ? 0.66 : 0.25))
            }
        }.allowsHitTesting(false)
    }
    private func circle(_ symbol: String, size: CGFloat, color: Color, background: Color = Palette.surface, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(color).frame(width: size, height: size).background(background, in: Circle()) }.buttonStyle(.plain)
    }
    private func load(more: Bool = false) async throws {
        let parameters = query.map { "\(APIClient.encode($0.key))=\(APIClient.encode($0.value))" }.sorted().joined(separator: "&")
        let endpoint = grid ? "/browse?limit=24" : app.authenticated ? "/feed?limit=12" : "/public/feed?limit=12"
        let cursor = more && !nextCursor.isEmpty ? "&cursor=" + APIClient.encode(nextCursor) : ""
        let result = try await app.api.request(endpoint + (parameters.isEmpty ? "" : "&" + parameters) + cursor, fresh: !more)
        let users = result["items"].array.map(\.profile).filter { !$0.id.isEmpty }
        if more { cards += users.filter { value in !cards.contains(where: { $0.id == value.id }) } } else { cards = users; index = 0; lastIndex = nil }
        nextCursor = result["nextCursor"].string; offset = .zero
    }
    private func perform(_ action: String) {
        guard !busy, index < cards.count, app.requireLogin() else { return }; busy = true
        app.run {
            defer { busy = false }
            do { try await app.swipe(cards[index], action); withAnimation(.easeOut(duration: 0.18)) { offset = action == "superlike" ? CGSize(width: 0, height: -900) : CGSize(width: action == "like" ? 700 : -700, height: 0) }; try? await Task.sleep(nanoseconds: 180_000_000); lastIndex = index; index += 1; offset = .zero; if index >= cards.count { try await load() } }
            catch { withAnimation(.spring()) { offset = .zero }; throw error }
        }
    }
    private func undo() { guard let lastIndex else { return }; app.run { _ = try await app.api.request("/swipes/undo", method: "POST", body: [:]); index = lastIndex; self.lastIndex = nil; await app.refreshCounters() } }
}
struct SuperLikeButton: View {
    let action: () -> Void
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06)) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8) / 8 * 360
            Button(action: action) { Image(systemName: "star.fill").font(.system(size: 29)).foregroundStyle(.yellow).frame(width: 58, height: 58).background(AngularGradient(colors: [.pink.opacity(0.3), .cyan.opacity(0.25), .yellow.opacity(0.35), .green.opacity(0.2), .pink.opacity(0.3)], center: .center, angle: .degrees(angle)), in: Circle()).overlay(Circle().stroke(.yellow.opacity(0.35), lineWidth: 1)) }.accessibilityLabel(L("超级喜欢"))
        }
    }
}
struct DiscoveryCard: View {
    @EnvironmentObject private var app: AppState
    let user: JSON
    var danmaku = true
    @State private var photoIndex = 0
    @State private var reactions = false
    @State private var notes: [JSON] = []
    private var photos: [JSON] { let list = ([user["cover"]] + user["photos"].array).filter { $0.exists && ($0["view"].string.isEmpty || $0["view"].string == "show") }; return list.isEmpty ? [user["avatar"]] : list }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RemoteImage(media: photos[min(photoIndex, photos.count - 1)])
                    HStack(spacing: 4) { ForEach(photos.indices, id: \.self) { index in Capsule().fill(.white.opacity(index == photoIndex ? 1 : 0.35)).frame(height: 3) } }.padding(13).frame(maxHeight: .infinity, alignment: .top)
                    HStack(spacing: 0) { Color.clear.contentShape(Rectangle()).onTapGesture { photoIndex = max(0, photoIndex - 1) }; Color.clear.contentShape(Rectangle()).onTapGesture { photoIndex = min(photos.count - 1, photoIndex + 1) } }
                    ReactionControl(user: user, path: "/profiles/\(APIClient.encode(user.id))/reactions").padding(.top, 28).padding(.trailing, 12)
                    if danmaku { DanmakuOverlay(items: notes).allowsHitTesting(false) }
                }.frame(height: max(210, geometry.size.height - 155))
                VStack(alignment: .leading, spacing: 7) {
                    HStack { Text(user["displayName"].string).font(.title2.bold()).lineLimit(1); Spacer(); Button(L("查看名片 ↗")) { app.profileRoute = ProfileRoute(id: user.id) }.font(.caption).padding(9).background(Palette.secondary, in: Capsule()) }
                    Text(user.text("bio").isEmpty ? user.text("tagline") : user.text("bio")).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    Text(user["platforms"].array.map(\.string).joined(separator: " · ") + " · " + user["languages"].array.map { $0.string.isEmpty ? $0["code"].string : $0.string }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).frame(height: 155)
            }.background(Palette.surface).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.secondary.opacity(0.2)))
        }.task(id: user.id) { photoIndex = 0; if danmaku, let result = try? await app.api.request("/guestbook/danmaku?ids=\(APIClient.encode(user.id))&limit=30") { notes = result["items"][user.id].array } }
    }
}
struct ProfileTile: View {
    let user: JSON
    var body: some View { ZStack(alignment: .bottomLeading) { RemoteImage(media: user["cover"].exists ? user["cover"] : user["avatar"], size: 650); LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom); VStack(alignment: .leading, spacing: 5) { HStack { Text(user["displayName"].string).font(.headline); if user["vrcVerified"].bool { VerifiedBadge() } }; Text(user.text("tagline")).font(.caption).lineLimit(2) }.foregroundStyle(.white).padding(12) }.frame(height: 250).clipShape(RoundedRectangle(cornerRadius: 18)) }
}
struct DanmakuOverlay: View {
    let items: [JSON]
    var body: some View { GeometryReader { geo in TimelineView(.animation(minimumInterval: 0.08)) { timeline in let clock = timeline.date.timeIntervalSinceReferenceDate; ForEach(Array(items.prefix(5).enumerated()), id: \.offset) { index, item in let progress = (clock + Double(index) * 4).truncatingRemainder(dividingBy: 15) / 15; Text(item.text("body")).font(.caption).foregroundStyle(.white).padding(8).background(.black.opacity(0.5), in: Capsule()).position(x: geo.size.width * (1.3 - progress * 1.6), y: geo.size.height * (0.25 + Double(index % 3) * 0.12)) } } }.clipped() }
}
struct ReactionControl: View {
    @EnvironmentObject private var app: AppState
    let user: JSON
    let path: String
    @State private var showing = false
    @State private var local: JSON?
    @State private var busy = false
    private var emojis: [String] { app.config["reactionEmojis"].array.isEmpty ? ["❤️","🥰","😍","😘","😊","🥺","😆","🤣","😮","😎","🤗","👍","👏","🙌","🙏","✨","🔥","💯","🎉","🌸","🌙","⭐","🌈","🦊","🐱","🐰","🎮","🎵","💃","☕","🥵","🐖","👅","🐷","🐵","🐽","🐓","🦆","👀"] : app.config["reactionEmojis"].array.map(\.string) }
    var body: some View {
        HStack(spacing: 5) {
            ForEach((local ?? user)["reactions"].array.prefix(3), id: \.self) { reaction in Button { send(reaction["emoji"].string) } label: { Text(reaction["emoji"].string + " " + String(reaction["count"].int)).font(.caption.bold()).padding(8).background(reaction["mine"].bool ? app.accent.opacity(0.9) : .black.opacity(0.6), in: Capsule()) } }
            Button { showing.toggle() } label: { Image(systemName: "face.smiling").font(.title3).padding(9).background(.black.opacity(0.65), in: Circle()) }
                .popover(isPresented: $showing, arrowEdge: .top) { LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) { ForEach(emojis, id: \.self) { emoji in Button { send(emoji) } label: { Text(emoji).font(.system(size: 26)).frame(width: 32, height: 34) } } }.padding(14).frame(width: 345).background(Palette.surface).presentationCompactAdaptation(.popover) }
        }.foregroundStyle(.white).buttonStyle(.plain).disabled(busy)
    }
    private func send(_ emoji: String) {
        guard app.requireLogin() else { showing = false; return }; busy = true
        app.run { defer { busy = false }; let mine = (local ?? user)["reactions"].array.contains { $0["emoji"].string == emoji && $0["mine"].bool }; _ = try await app.api.request(path + (mine ? "?emoji=" + APIClient.encode(emoji) : ""), method: mine ? "DELETE" : "POST", body: mine ? nil : ["emoji": emoji]); showing = false
            let read = path.replacingOccurrences(of: "/reactions", with: ""); local = try await app.api.request(read, fresh: true).profile
        }
    }
}
struct DiscoverFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var values: [String: String]
    let apply: () -> Void
    @State private var selected: [String: String] = [:]
    let groups: [(String, String, [(String, String)])] = [
        ("交友意向", "intents", [("friends", "交朋友"), ("romance", "恋爱"), ("erp", "角色扮演"), ("activity", "一起玩"), ("creative", "创作")]),
        ("平台", "platforms", [("pcvr", "PC VR"), ("quest", "Quest"), ("mobile", "手机"), ("desktop", "桌面")]),
        ("语言", "languages", [("zh", "中文"), ("yue", "粤语"), ("ja", "日文"), ("ko", "韩文"), ("en", "英文"), ("th", "泰文"), ("vi", "越南文"), ("id", "印尼文"), ("ms", "马来文"), ("tl", "菲律宾文"), ("hi", "印地文"), ("ru", "俄文"), ("es", "西班牙文"), ("fr", "法文"), ("de", "德文"), ("pt", "葡萄牙文")]),
        ("说话方式", "speech", [("voice", "开麦"), ("mute", "静音"), ("sign", "手语"), ("gesture", "表情／肢体语言")]),
        ("模型性别呈现", "modelGender", [("masculine", "男性化"), ("feminine", "女性化"), ("androgynous", "中性"), ("nonhuman", "非人"), ("other", "其他")]),
        ("声音", "voice", [("male", "男声"), ("female", "女声"), ("neutral", "中性"), ("voice_changer", "变声器"), ("mute", "静音")])
    ]
    var body: some View {
        NavigationStack {
            Form {
                ForEach(groups, id: \.1) { group in
                    Section(L(group.0)) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))]) {
                            ForEach(group.2, id: \.0) { option in
                                let active = (selected[group.1] ?? "").split(separator: ",").contains(Substring(option.0))
                                Button(L(option.1)) { var current = Set((selected[group.1] ?? "").split(separator: ",").map(String.init)); if !current.insert(option.0).inserted { current.remove(option.0) }; selected[group.1] = current.sorted().joined(separator: ",") }.buttonStyle(.bordered).tint(active ? .red : .secondary)
                            }
                        }
                    }
                }
                ForEach([("全身追踪", "fullBody"), ("有语音名片", "hasVoiceCard"), ("现在在线", "onlineNow"), ("时区相近", "nearTimezone")], id: \.1) { field in
                    Toggle(L(field.0), isOn: Binding(get: { selected[field.1] == "true" }, set: { selected[field.1] = $0 ? "true" : nil }))
                }
            }.navigationTitle(L("筛选")).toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(L("重设")) { selected = [:] } }
                ToolbarItem(placement: .topBarTrailing) { Button(L("应用")) { values = selected.filter { !$0.value.isEmpty }; apply(); dismiss() } }
            }
        }.onAppear { selected = values }
    }
}
