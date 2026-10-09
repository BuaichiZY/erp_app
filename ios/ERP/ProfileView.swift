import SwiftUI
import AVKit

struct LikesView: View {
    @EnvironmentObject private var app: AppState
    @State private var items: [JSON] = []
    @State private var cursor = ""
    @State private var locked = false
    @State private var loading = false
    @State private var requestID = UUID()
    @State private var failure: String?
    @State private var cancelCandidate: JSON?
    @State private var canceling: Set<String> = []
    private var path: String { app.likesKind == "visitors" ? "/visitors" : "/likes/" + app.likesKind }
    var body: some View {
        Page(title: app.likesKind == "secret" ? "我悄悄喜欢的人" : app.likesKind == "sent" ? "我喜欢的人" : app.likesKind == "visitors" ? "访客" : "喜欢我的人") {
            if UIDevice.current.userInterfaceIdiom == .pad { Text(L(app.likesKind == "received" ? "喜欢了你，而你还没滑过的人。" : app.likesKind == "sent" ? "你已喜欢的人。" : app.likesKind == "secret" ? "对方还看不到这些喜欢，配对后才会知道。" : "最近看过你名片的人。")).foregroundStyle(app.palette.muted) }
            HStack(spacing: 0) {
                ForEach([("received", "喜欢我"), ("sent", "我喜欢的"), ("secret", "悄悄喜欢"), ("visitors", "访客")], id: \.0) { kind, title in
                    Button { app.likesKind = kind } label: {
                        Text(L(title)).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity).frame(minHeight: 48)
                            .foregroundStyle(app.likesKind == kind ? app.palette.text : app.palette.muted)
                            .overlay(alignment: .bottom) { Rectangle().fill(app.likesKind == kind ? app.accent : .clear).frame(height: 3) }
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityAddTraits(app.likesKind == kind ? .isSelected : [])
                }
            }.overlay(alignment: .bottom) { Rectangle().fill(app.palette.border).frame(height: 1).allowsHitTesting(false) }.zIndex(1)
            if loading && items.isEmpty { LoadingSkeleton(cards: app.likesKind != "visitors") }
            if let failure { Text(failure).foregroundStyle(app.palette.muted); Button(L("重试")) { app.run { try await load() } } }
            if !app.authenticated { PrimaryButton(title: "登录") { app.screen = .login } }
            else if locked { Panel { Text(L("此功能需要网站相应会员权限。")); PrimaryButton(title: "查看会员权益") { app.screen = .membership } } }
            else {
            if app.likesKind == "visitors" {
                VStack(spacing: 0) { ForEach(items) { item in Button { app.profileRoute = ProfileRoute(id: item["user"].id) } label: {
                    HStack(spacing: 12) { Avatar(user: item["user"], size: 40); Text(item["user"]["displayName"].string).lineLimit(1); VRCIdentityBadge(user: item["user"]); Spacer(); if let date = ERPDate.parse(item["visitedAt"].string) { Text(date, format: .relative(presentation: .named)).font(.caption).foregroundStyle(app.palette.muted) } }.padding(14).foregroundStyle(app.palette.text)
                }.buttonStyle(.plain); SiteDivider() } }.background(app.palette.surface, in: RoundedRectangle(cornerRadius: 16)).clipShape(RoundedRectangle(cornerRadius: 16)).siteOutline(RoundedRectangle(cornerRadius: 16))
            } else { ResponsiveGrid(minimum: 190, compactMinimum: 130) {
                ForEach(items) { item in
                    VStack(spacing: 6) {
                        Button { app.profileRoute = ProfileRoute(id: item["user"].id) } label: { ProfileTile(user: item["user"]) }.buttonStyle(.plain)
                        Group { if let date = ERPDate.parse(item["createdAt"].string) { Text(date, format: .relative(presentation: .named)) } else { Text(item["createdAt"].string.prefix(10)) } }.font(.caption).foregroundStyle(app.palette.muted)
                        if app.likesKind == "secret" {
                            Menu(L("公开喜欢")) { Button(L("公开喜欢")) { publish(item, action: "like") }; Button(L("公开超级喜欢")) { publish(item, action: "superlike") } }
                        }
                        if ["sent", "secret"].contains(app.likesKind) && item["cancelable"].bool {
                            Button(L("取消喜欢")) { if app.me["features"]["cancel_like"]["enabled"].bool { cancelCandidate = item } else { app.screen = .membership } }.disabled(canceling.contains(item.id))
                        }
                    }
                }
            }
            }
            if items.isEmpty && !loading && failure == nil { EmptyState() }
            if !cursor.isEmpty { Button(L("加载更多")) { app.run { try await load(more: true) } }.disabled(loading) }
            }
        }.confirmationDialog(L("取消喜欢？"), isPresented: Binding(get: { cancelCandidate != nil }, set: { if !$0 { cancelCandidate = nil } }), titleVisibility: .visible) {
            if let item = cancelCandidate { Button(L("取消对 ") + item["user"]["displayName"].string + L(" 的喜欢？"), role: .destructive) { canceling.insert(item.id); app.run { defer { canceling.remove(item.id) }; _ = try await app.api.request("/likes/sent/" + APIClient.encode(item["user"].id), method: "DELETE"); try await load() } } }
        }.refreshable { do { try await load() } catch { app.message = error.localizedDescription } }.task(id: "\(app.likesKind)|\(app.mode)|\(app.authenticated)") { do { try await load() } catch { app.message = error.localizedDescription } }
    }
    private func publish(_ item: JSON, action: String) { app.run { _ = try await app.api.request("/swipes/upgrade", method: "POST", body: ["targetId": item["user"].id, "action": action, "secret": false]); try await load(); await app.refreshCounters() } }
    private func load(more: Bool = false) async throws {
        let kind = app.likesKind, mode = app.mode, identity = app.me.id, generation = UUID()
        requestID = generation
        guard app.authenticated else { items = []; cursor = ""; locked = false; loading = false; return }
        loading = true; failure = nil
        if !more { items = []; cursor = ""; locked = false }
        defer { if requestID == generation { loading = false } }
        do {
            let result = try await app.api.request(path + (more ? "?cursor=" + APIClient.encode(cursor) : ""), fresh: !more)
            guard !Task.isCancelled, requestID == generation, app.likesKind == kind, app.mode == mode, app.me.id == identity else { return }
            let values = result["items"].array.filter { !$0["user"].id.isEmpty }.map { value -> JSON in var object = value.object; object["id"] = .string(value["user"].id); return .object(object) }
            items = more ? items + values.filter { value in !items.contains(where: { $0.id == value.id }) } : values
            locked = result["locked"].bool; cursor = result["nextCursor"].string
            await app.refreshCounters()
        } catch {
            guard !Task.isCancelled, requestID == generation, app.likesKind == kind else { return }
            failure = error.localizedDescription
        }
    }
}
struct ProfileDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let id: String
    var readOnly = false
    var onClose: (() -> Void)? = nil
    @State private var user: JSON = .null
    @State private var guestbook: [JSON] = []
    @State private var danmakuNotes: [JSON] = []
    @State private var viewingPhotos = false
    @State private var viewerMedia: [JSON] = []
    @State private var photoIndex = 0
    @AppStorage("danmaku") private var danmaku = true
    @State private var note = ""
    @State private var report = false
    @State private var block = false
    @State private var actionBusy = false
    var body: some View {
        Group {
            if onClose != nil {
                VStack(spacing: 0) {
                    HStack {
                        Button { close() } label: { Label(L("返回"), systemImage: "arrow.left").font(.headline).padding(.vertical, 12) }
                        Spacer()
                    }.padding(.horizontal, 24).foregroundStyle(app.palette.text)
                    profileContent
                }.background(app.palette.background)
            } else {
                NavigationStack {
                    profileContent.toolbar { ToolbarItem(placement: .topBarTrailing) { Button { close() } label: { Image(systemName: "xmark") } } }
                }
            }
        }
    }
    private var profileContent: some View {
            Page(title: "") {
                if user.exists {
                    VStack(spacing: 0) {
                        ZStack(alignment: .bottomLeading) {
                            RemoteImage(media: user["cover"].exists ? user["cover"] : user["avatar"])
                            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                            if danmaku { DanmakuOverlay(items: danmakuNotes).allowsHitTesting(false) }
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .bottom) { Avatar(user: user, size: 72).overlay(Circle().stroke(.white, lineWidth: 3)); VStack(alignment: .leading, spacing: 7) { Text(user["displayName"].string).font(.largeTitle.bold()); VRCIdentityBadge(user: user, compact: false); Text(user.text("tagline")).lineLimit(3) } }
                                HStack(spacing: 8) {
                                    if user["shine"]["likes"].int > 0 { Label("\(user["shine"]["likes"].int)%", systemImage: "heart.fill").padding(5).background(.pink, in: Capsule()) }
                                    if user["shine"]["superlikes"].int > 0 { Label("\(user["shine"]["superlikes"].int)%", systemImage: "star.fill").padding(5).background(.orange, in: Capsule()) }
                                }.font(.caption.bold())
                                if user["mutualMatches"].int > 0 { Text(L("共同配对") + " \(user["mutualMatches"].int) " + L("人")).font(.caption) }
                                if !DiscoveryFacts.time(user).isEmpty { Text(DiscoveryFacts.time(user)).font(.caption) }
                            }.foregroundStyle(.white).padding(16)
                            ReactionControl(user: user, path: "/profiles/\(APIClient.encode(id))/reactions").frame(maxHeight: .infinity, alignment: .top).padding(.top, 12).padding(.trailing, 12).frame(maxWidth: .infinity, alignment: .trailing)
                            let cover = user["cover"].exists ? user["cover"] : user["avatar"]
                            if cover["view"].string.isEmpty || cover["view"].string == "show" {
                                Button { viewerMedia = [cover]; photoIndex = 0; viewingPhotos = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").padding(10).foregroundStyle(.white).background(.black.opacity(0.5), in: Circle()) }.accessibilityLabel(L("查看大图")).padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        }.frame(height: 470)
                        if readOnly {
                            Text(L("热度排行只供浏览。")).font(.subheadline).foregroundStyle(app.palette.muted).padding(18)
                        } else if id == app.me.id {
                            HStack { Button { close(); app.screen = .editProfile } label: { Label(L("编辑名片"), systemImage: "pencil") }; Spacer(); Button { close(); app.screen = .share } label: { Label(L("分享"), systemImage: "square.and.arrow.up") } }.padding(18)
                        } else if user["relation"]["matchState"].string == "active", !user["relation"]["matchId"].string.isEmpty {
                            PrimaryButton(title: "发送消息", icon: "bubble.left") { close(); app.tab = 2; let matchID = user["relation"]["matchId"].string; if app.chatRoute?.id != matchID { app.chatRoute = ChatRoute(id: matchID) } }.padding(14)
                        } else if !readOnly {
                        HStack(spacing: 10) {
                            Button { perform("pass") } label: { Label(L("跳过"), systemImage: "xmark").padding(13) }.foregroundStyle(app.palette.text)
                            SecretActionButton(action: { perform("superlike") }, secretAction: { perform("superlike", secret: true) }) { Label(L("超级喜欢"), systemImage: "star").font(.subheadline.bold()).padding(13).background(LinearGradient(colors: [.green.opacity(0.5), .yellow], startPoint: .leading, endPoint: .trailing), in: Capsule()) }.foregroundStyle(.black)
                            SecretActionButton(action: { perform("like") }, secretAction: { perform("like", secret: true) }) { Label(L("喜欢"), systemImage: "heart").frame(maxWidth: .infinity).padding(14).foregroundStyle(.white).background(app.accent, in: Capsule()) }
                        }.disabled(actionBusy).padding(14)
                        }
                        if id != app.me.id { HStack(spacing: 30) { Spacer(); ShareLink(item: URL(string: "https://erp.sex/likes?u=" + APIClient.encode(id))!) { Image(systemName: "square.and.arrow.up") }; Button { report = true } label: { Image(systemName: "flag") }; Button { block = true } label: { Image(systemName: "nosign") } }.font(.title3).foregroundStyle(app.palette.text).padding(18) }
                    }.background(app.palette.surface).clipShape(RoundedRectangle(cornerRadius: 22)).siteOutline(RoundedRectangle(cornerRadius: 22))
                    Panel { Text(L("详细资料")).font(.headline); ProfileFactsView(user: user) }
                    if !user.text("bio").isEmpty { Panel { Text(L("介绍")).font(.headline); Text(user.text("bio")) } }
                    if !user["photos"].array.isEmpty { Panel { Text(L("照片")).font(.headline); LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))]) { ForEach(user["photos"].array.indices, id: \.self) { index in Button { viewerMedia = user["photos"].array; photoIndex = index; viewingPhotos = true } label: { RemoteImage(media: user["photos"].array[index]).frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 15)) }.buttonStyle(.plain) } } } }
                    if user["voiceCard"].exists { Panel { AudioButton(media: user["voiceCard"]) } }
                    if !user["models"].array.isEmpty { Panel { Text(L("模型展示")).font(.headline); ForEach(user["models"].array, id: \.self) { model in Text(model["name"].string); if let image = model["photos"].array.first { RemoteImage(media: image).frame(height: 180) } } } }
                    if !user["answers"].array.isEmpty { Panel { Text(L("问卷")).font(.headline); ForEach(user["answers"].array, id: \.self) { answer in Text(answer["question"].text).font(.headline); Text(answer["answer"].text.isEmpty ? answer["text"].text : answer["answer"].text) } } }
                    if !user["socialLinks"].array.isEmpty { Panel { ForEach(user["socialLinks"].array, id: \.self) { item in if let url = URL(string: item["url"].string), url.scheme == "https" { Link(item["label"].string.isEmpty ? item["type"].string : item["label"].string, destination: url) } } } }
                    if user["adult"].exists { Panel { Text(L("成人区")).font(.headline); Text(user["adult"]["bio"].text); if !user["adult"]["limits"].array.isEmpty { Text(L("界限") + " · " + DiscoveryFacts.values(user["adult"]["limits"].array)) }; if !user["adult"]["safeword"].string.isEmpty { Text(L("安全词") + " · " + user["adult"]["safeword"].string) } } }
                    if user["guestbook"]["open"].bool { Panel { Text(L("留言板")).font(.headline); ForEach(guestbook) { note in HStack(alignment: .top) { Avatar(user: note["author"], size: 32); VStack(alignment: .leading) { Text(note["author"]["displayName"].string).font(.caption).foregroundStyle(app.palette.muted); Text(note.text("body")) } } }; TextField(L("留言"), text: $note, axis: .vertical); PrimaryButton(title: "发送") { app.run { guard app.requireLogin() else { return }; _ = try await app.api.request("/profiles/\(APIClient.encode(id))/guestbook", method: "POST", body: ["body": note]); note = ""; try await load() } }.disabled(note.isEmpty) } }
                } else { ProgressView().frame(maxWidth: .infinity).padding(40) }
            }.refreshable { do { try await load() } catch { app.message = error.localizedDescription } }.task { do { try await load() } catch { app.message = error.localizedDescription } }
                .task(id: "\(id)|\(danmaku)") {
                    danmakuNotes = []
                    if danmaku, let response = try? await app.api.request("/guestbook/danmaku?ids=\(APIClient.encode(id))&limit=30") {
                        guard !Task.isCancelled else { return }
                        danmakuNotes = response["items"][id].array
                    }
                }
                .fullScreenCover(isPresented: $viewingPhotos) { PostMediaViewer(media: viewerMedia, index: $photoIndex).environmentObject(app).sitePresentation() }
                .sheet(isPresented: $report) { ReportView(target: "user", id: id).environmentObject(app).sitePresentation() }
                .confirmationDialog(L("封锁"), isPresented: $block) { Button(L("封锁"), role: .destructive) { app.run { _ = try await app.api.request("/users/\(APIClient.encode(id))/block", method: "POST", body: [:]); close() } } }
    }
    private func close() { if let onClose { onClose() } else { dismiss() } }
    private func load() async throws { user = try await app.api.request("/profiles/" + APIClient.encode(id), fresh: true).profile; if user["guestbook"]["open"].bool { guestbook = (try? await app.api.request("/profiles/\(APIClient.encode(id))/guestbook?page=1")["items"].array) ?? [] } }
    private func perform(_ action: String, secret: Bool = false) { guard !actionBusy, app.requireLogin() else { return }; actionBusy = true; app.run { defer { actionBusy = false }; try await app.swipe(user, action, secret: secret); close() } }
}
struct MatchSuccessView: View {
    @EnvironmentObject private var app: AppState
    let result: MatchResult
    var body: some View { VStack(spacing: 25) {
        HStack(spacing: -25) { Avatar(user: result.user, size: 112).overlay(Circle().stroke(app.palette.surface, lineWidth: 4)); Avatar(user: app.me, size: 112).overlay(Circle().stroke(app.palette.surface, lineWidth: 4)) }.padding(.top, 25)
        Text(L("配对成功！")).font(.largeTitle.bold()).foregroundStyle(app.accent)
        Text(L("你和") + " " + result.user["displayName"].string + " " + L("互相喜欢")).foregroundStyle(app.palette.muted)
        PrimaryButton(title: "打声招呼", icon: "bubble.left") { app.matched = nil; app.tab = 2; app.chatRoute = ChatRoute(id: result.matchID) }
        Button(L("继续滑卡")) { app.matched = nil }.font(.headline).foregroundStyle(app.palette.text)
    }.padding(25).frame(maxWidth: 650).frame(maxWidth: .infinity, maxHeight: .infinity).background(app.palette.surface) }
}
struct AudioButton: View {
    let media: JSON
    @State private var player: AVPlayer?
    @State private var playing = false
    var body: some View { Button { if playing { player?.pause(); playing = false } else if let url = URL(string: media["url"].string), url.scheme == "https" { player = AVPlayer(url: url); player?.play(); playing = true } } label: { Label(L("播放语音"), systemImage: playing ? "pause.fill" : "play.fill") }.onDisappear { player?.pause() } }
}
