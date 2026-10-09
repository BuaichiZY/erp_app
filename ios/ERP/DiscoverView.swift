import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var app: AppState
    @State private var cards: [JSON] = []
    @State private var index = 0
    @State private var busy = false
    @State private var offset = CGSize.zero
    @AppStorage("danmaku") private var danmaku = true
    @State private var filters = false
    @State private var query: [String: String] = [:]
    @State private var nextCursor = ""
    @State private var lastIndex: Int?
    @State private var photoIndex = 0
    @State private var requestID = UUID()
    @State private var browseSort = "hot"
    @State private var loadedIdentity: String?
    @State private var sourceIdentity: String?
    @State private var loading = false
    @State private var loadError: String?
    @State private var browseNotes: JSON = .null
    private var selectedSort: String { BrowseRules.selected(browseSort, me: app.me) }
    private var loadIdentity: String { "\(app.mode)|\(app.localeCode)|\(app.me.id)|\(app.discoveryGrid)|\(selectedSort)|" + query.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "&") }
    private var filterCount: Int { query.filter { !$0.value.isEmpty && ($0.key != "onlineNow" || app.config["vrcPresenceAvailable"].bool) }.count }
    private var filterTitle: String { L("筛选") + (filterCount > 0 ? " \(filterCount)" : "") }
    private var danmakuIDs: [String] { app.discoveryGrid && danmaku ? cards.filter { $0["guestbook"]["open"].bool && $0["guestbook"]["count"].int > 0 }.map(\.id) : [] }
    var body: some View {
        GeometryReader { geometry in
            let layout = LayoutMetrics(width: geometry.size.width)
            let preview = !app.discoveryGrid && layout.showsDiscoveryPreview(viewportHeight: geometry.size.height)
            let tabletSingle = UIDevice.current.userInterfaceIdiom == .pad && !preview
            let deckWidth = preview ? layout.discoveryDeckWidth : tabletSingle ? layout.singleDiscoveryDeckWidth(viewportHeight: geometry.size.height) : min(572, layout.contentWidth)
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Text(L(app.discoveryGrid ? "浏览" : "探索")).font(.title.bold()); Spacer()
                        if app.discoveryGrid && BrowseRules.sorts(app.me).count > 1 {
                            Menu(L(BrowseRules.label(selectedSort))) { ForEach(BrowseRules.sorts(app.me), id: \.self) { value in Button(L(BrowseRules.label(value))) { browseSort = value } } }.font(.subheadline)
                        }
                        if layout.contentWidth >= 600 {
                            Toggle(isOn: $danmaku) { Label(L("弹幕"), systemImage: "bubble.left.and.bubble.right") }.fixedSize().font(.subheadline).padding(10).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 14)).siteOutline(RoundedRectangle(cornerRadius: 14), normalBorder: false)
                            Button { app.discoveryGrid.toggle() } label: { Label(L(app.discoveryGrid ? "滑卡" : "网格"), systemImage: app.discoveryGrid ? "rectangle.stack" : "square.grid.2x2").font(.subheadline).padding(12).background(app.palette.secondary, in: RoundedRectangle(cornerRadius: 14)).siteOutline(RoundedRectangle(cornerRadius: 14), normalBorder: false) }
                            Button { filters = true } label: { Label(filterTitle, systemImage: "slider.horizontal.3").font(.subheadline).padding(12).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 14)).siteOutline(RoundedRectangle(cornerRadius: 14), normalBorder: false) }
                        } else {
                            Toggle(L("弹幕"), isOn: $danmaku).fixedSize().font(.subheadline)
                            Button { app.discoveryGrid.toggle() } label: { Image(systemName: app.discoveryGrid ? "rectangle.stack" : "square.grid.2x2") }
                            Button { filters = true } label: { HStack(spacing: 3) { Image(systemName: "slider.horizontal.3"); if filterCount > 0 { Text(String(filterCount)).font(.caption.bold()) } }.padding(10).background(app.palette.surface, in: Capsule()).siteOutline(Capsule(), normalBorder: false) }.accessibilityLabel(filterTitle)
                        }
                    }
                    if app.discoveryGrid && !app.authenticated {
                        EmptyState(title: "登录后即可使用此功能，账号与网站共用。")
                        PrimaryButton(title: "登录") { app.screen = .login }
                    } else if loading && cards.isEmpty { ProgressView(L("正在加载…")).frame(maxWidth: .infinity).padding(40) }
                    else if let loadError, cards.isEmpty {
                        EmptyState(title: "暂时无法加载名片")
                        Text(loadError).font(.subheadline).foregroundStyle(app.palette.muted)
                        Button(L("重试")) { app.run { await load() } }
                    } else if app.discoveryGrid {
                        if selectedSort == "hot" { Label(L(app.me["browse"]["hotShuffle"].bool ? "全服高热度玩家随机排序，这个榜单不是排名榜。这里不能按喜欢。" : "♨ 按收到的喜欢与超级喜欢排序，这里不能送出喜欢。"), systemImage: "flame").font(.subheadline).foregroundStyle(app.palette.muted).frame(maxWidth: .infinity, alignment: .leading) }
                        if app.me["browse"]["mode"].string == "members", !BrowseRules.sorts(app.me).contains("recommended") { Button(L("更多排序需会员权限")) { app.screen = .membership }.font(.subheadline) }
                        if cards.isEmpty { EmptyState(title: "暂时没有符合筛选条件的名片") }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 14), count: layout.browseColumns), spacing: 14) {
                            ForEach(cards) { user in BrowseTile(user: user, notes: danmaku ? browseNotes[user.id].array : []) { app.profileRoute = ProfileRoute(id: user.id, readOnly: selectedSort == "hot") } }
                            if !nextCursor.isEmpty {
                                Section {} footer: {
                                    Button(L(loading ? "正在加载…" : "加载更多")) { app.run { await load(more: true) } }.disabled(loading)
                                        .id(nextCursor).onAppear { if !loading && loadError == nil { app.run { await load(more: true) } } }
                                }
                            }
                        }
                    }
                    else if index < cards.count {
                        let user = cards[index]
                        HStack(alignment: .top, spacing: 24) {
                            VStack(spacing: 14) {
                                ZStack {
                                    if tabletSingle && app.palette.pop && index + 1 < cards.count {
                                        RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0xbaff69)).siteOutline(RoundedRectangle(cornerRadius: 20), shadow: false).scaleEffect(0.97).offset(x: 10, y: 8).allowsHitTesting(false)
                                    }
                                    DiscoveryCard(user: user, danmaku: danmaku, detailed: tabletSingle, photoIndex: $photoIndex)
                                    swipeStamps
                                }.frame(height: preview ? min(deckWidth + 205, max(320, geometry.size.height - 205)) : tabletSingle ? deckWidth * 4.3 / 3 : layout.discoveryCardHeight(viewportHeight: geometry.size.height))
                                    .offset(offset).rotationEffect(.degrees(Double(offset.width / 25)))
                                    .gesture(DragGesture(minimumDistance: 12, coordinateSpace: .global).onChanged { if !busy { offset = $0.translation } }.onEnded { value in
                                        guard !busy else { return }
                                        if let action = ERPRules.swipe(x: value.translation.width, y: value.translation.height) { perform(action) }
                                        else { withAnimation(.spring()) { offset = .zero } }
                                    })
                                HStack(spacing: deckWidth < 350 ? 10 : 18) {
                                    circle("arrow.uturn.backward", size: tabletSingle ? 54 : 46, color: app.palette.muted) { undo() }.disabled(lastIndex == nil)
                                    circle("xmark", size: tabletSingle ? 76 : 62, color: app.palette.muted) { perform("pass") }.accessibilityLabel(L("跳过"))
                                    SuperLikeButton(size: tabletSingle ? 70 : 58, action: { perform("superlike") }, secretAction: { perform("superlike", secret: true) })
                                    SecretActionButton(action: { perform("like") }, secretAction: { perform("like", secret: true) }) { Image(systemName: "heart.fill").font(.system(size: (tabletSingle ? 80.0 : 66.0) * 0.4)).foregroundStyle(.white).frame(width: tabletSingle ? 80 : 66, height: tabletSingle ? 80 : 66).background(app.accent, in: Circle()).siteOutline(Circle()) }.accessibilityLabel(L("喜欢"))
                                }.disabled(busy).padding(.vertical, 6)
                                Label(L("长按 ♥ 或 ★ 可以悄悄喜欢，对方要等你们配对才知道。"), systemImage: "theatermasks").font(.caption).foregroundStyle(app.palette.muted).multilineTextAlignment(.center).padding(.top, 2)
                            }.frame(width: deckWidth)
                            if preview { DiscoveryPreview(user: user, photoIndex: $photoIndex).frame(width: layout.discoveryPreviewWidth) }
                        }.frame(maxWidth: .infinity).padding(.top, tabletSingle ? 18 : 0)
                            .onChange(of: user.id) { _ in photoIndex = 0 }
                    } else { EmptyState(title: "暂无推荐名片"); Button(L("重新加载")) { app.run { await load() } } }
                    if let loadError, !cards.isEmpty { Text(loadError).font(.subheadline).foregroundStyle(app.palette.muted); Button(L("重试")) { app.run { await load() } } }
                }.environment(\.pageLayout, layout)
                    .padding(layout.pagePadding).frame(maxWidth: layout.pageWidth).frame(maxWidth: .infinity)
            }.refreshable { if offset == .zero { await load() } }
                .background(app.palette.background)
                .task(id: loadIdentity) { if loadedIdentity != loadIdentity { await load() } }
                .task(id: "\(app.mode)|\(app.localeCode)|\(danmakuIDs.joined(separator: ","))") {
                    browseNotes = .null
                    let ids = danmakuIDs
                    for start in stride(from: 0, to: ids.count, by: 30) {
                        let batch = ids[start..<min(start + 30, ids.count)].joined(separator: ",")
                        if let result = try? await app.api.request("/guestbook/danmaku?ids=\(APIClient.encode(batch))&limit=30"), !Task.isCancelled { browseNotes = .object(browseNotes.object.merging(result["items"].object) { _, new in new }) }
                        if Task.isCancelled { return }
                    }
                }
                .sheet(isPresented: $filters) { DiscoverFilterView(values: $query) {}.environmentObject(app).sitePresentation() }
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
    private func circle(_ symbol: String, size: CGFloat, color: Color, background: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(color).frame(width: size, height: size).background(background ?? app.palette.surface, in: Circle()).siteOutline(Circle(), normalBorder: false) }.buttonStyle(.plain)
    }
    private func load(more: Bool = false) async {
        guard !more || (!loading && !nextCursor.isEmpty) else { return }
        let generation = UUID(); requestID = generation
        let identity = loadIdentity
        if sourceIdentity != identity { cards = []; index = 0; nextCursor = ""; sourceIdentity = identity }
        loadError = nil; loading = true
        defer { if requestID == generation { loading = false } }
        guard !app.discoveryGrid || app.authenticated else { return }
        let parameters = query.filter { $0.key != "onlineNow" || app.config["vrcPresenceAvailable"].bool }.map { "\(APIClient.encode($0.key))=\(APIClient.encode($0.value))" }.sorted().joined(separator: "&")
        let endpoint = app.discoveryGrid ? "/browse?sort=\(APIClient.encode(selectedSort))&limit=24" : app.authenticated ? "/feed?limit=12" : "/public/feed?limit=12"
        let cursor = more && !nextCursor.isEmpty ? "&cursor=" + APIClient.encode(nextCursor) : ""
        do {
        let result = try await app.api.request(endpoint + (parameters.isEmpty ? "" : "&" + parameters) + cursor, fresh: !more)
        guard !Task.isCancelled, requestID == generation else { return }
        let users = result["items"].array.map(\.profile).filter { !$0.id.isEmpty }
        if more { cards += users.filter { value in !cards.contains(where: { $0.id == value.id }) } } else { cards = users; index = 0; lastIndex = nil }
        nextCursor = result["nextCursor"].string; offset = .zero
        loadedIdentity = identity
        } catch {
            guard !Task.isCancelled, requestID == generation, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            loadError = error.localizedDescription
        }
    }
    private func perform(_ action: String, secret: Bool = false) {
        guard !busy, index < cards.count, app.requireLogin() else { return }; busy = true
        app.run {
            defer { busy = false }
            do { try await app.swipe(cards[index], action, secret: secret); withAnimation(.easeOut(duration: 0.18)) { offset = action == "superlike" ? CGSize(width: 0, height: -900) : CGSize(width: action == "like" ? 700 : -700, height: 0) }; try? await Task.sleep(nanoseconds: 180_000_000); lastIndex = index; index += 1; offset = .zero; if index >= cards.count { await load() } }
            catch { withAnimation(.spring()) { offset = .zero }; throw error }
        }
    }
    private func undo() { guard let lastIndex else { return }; app.run { _ = try await app.api.request("/swipes/undo", method: "POST", body: [:]); index = lastIndex; self.lastIndex = nil; await app.refreshCounters() } }
}
struct SuperLikeButton: View {
    @EnvironmentObject private var app: AppState
    var size: CGFloat = 58
    let action: () -> Void
    var secretAction: (() -> Void)? = nil
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06)) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8) / 8 * 360
            SecretActionButton(action: action, secretAction: secretAction) { Image(systemName: "star.fill").font(.system(size: size * 0.5)).foregroundStyle(app.palette.pop ? .black : .yellow).frame(width: size, height: size).background(AngularGradient(colors: app.palette.pop ? [Color(hex: 0xb99aff), Color(hex: 0x7fe3fa), Color(hex: 0xb99aff)] : [.pink.opacity(0.3), .cyan.opacity(0.25), .yellow.opacity(0.35), .green.opacity(0.2), .pink.opacity(0.3)], center: .center, angle: .degrees(angle)), in: Circle()).overlay(Circle().stroke(.yellow.opacity(app.palette.pop ? 0 : 0.35), lineWidth: 1)).siteOutline(Circle(), normalBorder: false) }.accessibilityLabel(L("超级喜欢"))
        }
    }
}
struct DiscoveryCard: View {
    @EnvironmentObject private var app: AppState
    let user: JSON
    var danmaku = true
    var detailed = false
    @Binding var photoIndex: Int
    @State private var reactions = false
    @State private var notes: [JSON] = []
    private var photos: [JSON] { DiscoveryMedia.photos(user) }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    RemoteImage(media: photos[min(photoIndex, photos.count - 1)])
                    HStack(spacing: 4) { ForEach(photos.indices, id: \.self) { index in Capsule().fill(.white.opacity(index == photoIndex ? 1 : 0.35)).frame(height: 3) } }.padding(13).frame(maxHeight: .infinity, alignment: .top)
                    HStack(spacing: 0) { Color.clear.contentShape(Rectangle()).onTapGesture { photoIndex = max(0, photoIndex - 1) }; Color.clear.contentShape(Rectangle()).onTapGesture { photoIndex = min(photos.count - 1, photoIndex + 1) } }
                    if detailed && user["nsfw"].bool { Text("NSFW").font(.caption.bold()).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4).background(.black.opacity(0.6), in: Capsule()).padding(.leading, 12).padding(.top, 28).frame(maxWidth: .infinity, alignment: .leading).allowsHitTesting(false) }
                    ReactionControl(user: user, path: "/profiles/\(APIClient.encode(user.id))/reactions").padding(.top, 28).padding(.trailing, 12)
                    if danmaku { DanmakuOverlay(items: notes).allowsHitTesting(false) }
                }.frame(height: max(120, geometry.size.height - 205))
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) { Text(user["displayName"].string).font(.title2.bold()).lineLimit(1); if detailed { VRCIdentityBadge(user: user) }; Spacer(minLength: 0); Button(L("查看名片 ↗")) { app.profileRoute = ProfileRoute(id: user.id) }.font(.caption).padding(9).background(app.palette.secondary, in: Capsule()) }
                    Text(user.text("bio").isEmpty ? user.text("tagline") : user.text("bio")).font(.subheadline).foregroundStyle(app.palette.muted).lineLimit(2)
                    Text(detailed ? [DiscoveryFacts.platforms(user), DiscoveryFacts.time(user)].filter { !$0.isEmpty }.joined(separator: " · ") : DiscoveryFacts.platforms(user)).font(.caption).foregroundStyle(app.palette.muted).lineLimit(1)
                    Text(DiscoveryFacts.values(user["baseAvatars"].array + user["baseAvatarCustom"].array)).font(.caption).foregroundStyle(app.palette.muted).lineLimit(1)
                    if detailed {
                        HStack(spacing: 12) {
                            if user["matchCount"].exists { Label(L("已配对") + " \(user["matchCount"].int) " + L("人"), systemImage: "heart") }
                            if user["mutualMatches"].exists { Label(L("共同配对") + " \(user["mutualMatches"].int) " + L("人"), systemImage: "person.2") }
                        }.font(.caption).foregroundStyle(app.palette.muted)
                    }
                    WrappingLayout(spacing: 6) { ForEach(user["intents"].array, id: \.self) { intent in Text(intent.string == "other" && !user["intentOther"].text.isEmpty ? user["intentOther"].text : L(DiscoveryFacts.label(intent.string))).font(.caption).padding(.horizontal, 9).padding(.vertical, 4).background(app.palette.secondary, in: Capsule()).siteOutline(Capsule(), shadow: false, normalBorder: false) } }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).frame(height: 205)
            }.background(app.palette.surface).clipShape(RoundedRectangle(cornerRadius: 20)).siteOutline(RoundedRectangle(cornerRadius: 20))
        }.task(id: "\(user.id)|\(danmaku)") { notes = []; if danmaku, let result = try? await app.api.request("/guestbook/danmaku?ids=\(APIClient.encode(user.id))&limit=30") { if !Task.isCancelled { notes = result["items"][user.id].array } } }
    }
}
struct ProfileTile: View {
    @EnvironmentObject private var app: AppState
    let user: JSON
    var body: some View { ZStack(alignment: .bottomLeading) { RemoteImage(media: user["cover"].exists ? user["cover"] : user["avatar"], size: 650); LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom); VStack(alignment: .leading, spacing: 5) { HStack { Text(user["displayName"].string).font(.headline).lineLimit(1); VRCIdentityBadge(user: user, compact: false) }; Text(user.text("tagline")).font(.caption).lineLimit(2) }.foregroundStyle(.white).padding(12) }.aspectRatio(0.78, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 18)).siteOutline(RoundedRectangle(cornerRadius: 18), normalBorder: false).contentShape(RoundedRectangle(cornerRadius: 18)) }
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
                .popover(isPresented: $showing, arrowEdge: .top) { LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) { ForEach(emojis, id: \.self) { emoji in Button { send(emoji) } label: { Text(emoji).font(.system(size: 26)).frame(width: 32, height: 34) } } }.padding(14).frame(width: 345).background(app.palette.surface).presentationCompactAdaptation(.popover) }
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
    @EnvironmentObject private var app: AppState
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
                                Button(L(option.1)) { var current = Set((selected[group.1] ?? "").split(separator: ",").map(String.init)); if !current.insert(option.0).inserted { current.remove(option.0) }; selected[group.1] = current.sorted().joined(separator: ",") }.buttonStyle(.bordered).tint(active ? app.accent : app.palette.muted)
                            }
                        }
                    }
                }
                ForEach([("全身追踪", "fullBody"), ("有语音名片", "hasVoiceCard"), ("现在在线", "onlineNow"), ("时区相近", "nearTimezone")].filter { $0.1 != "onlineNow" || app.config["vrcPresenceAvailable"].bool }, id: \.1) { field in
                    Toggle(L(field.0), isOn: Binding(get: { selected[field.1] == "true" }, set: { selected[field.1] = $0 ? "true" : nil }))
                }
            }.navigationTitle(L("筛选")).toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(L("重设")) { selected = [:] } }
                ToolbarItem(placement: .topBarTrailing) { Button(L("应用")) { values = selected.filter { !$0.value.isEmpty }; apply(); dismiss() } }
            }
        }.onAppear { selected = values }
    }
}
