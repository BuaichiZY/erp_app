import SwiftUI
import AVKit

struct LikesView: View {
    @EnvironmentObject private var app: AppState
    @State private var kind = "received"
    @State private var items: [JSON] = []
    @State private var cursor = ""
    @State private var locked = false
    private var path: String { kind == "visitors" ? "/visitors" : "/likes/" + kind }
    var body: some View {
        Page(title: "喜欢我的人") {
            Picker(L("喜欢我"), selection: $kind) { Text(L("喜欢我")).tag("received"); Text(L("我喜欢的")).tag("sent"); Text(L("访客") + (app.counters["newVisitors"].int > 0 ? " •" : "")).tag("visitors") }.pickerStyle(.segmented)
            if !app.authenticated { PrimaryButton(title: "登录") { app.screen = .login } }
            else if locked { Panel { Text(L("此功能需要网站相应会员权限。")); PrimaryButton(title: "查看会员权益") { app.screen = .membership } } }
            else { LazyVGrid(columns: [GridItem(.adaptive(minimum: 155))], spacing: 16) {
                ForEach(items) { item in VStack(spacing: 6) { ProfileTile(user: item["user"]).onTapGesture { app.profileRoute = ProfileRoute(id: item["user"].id) }; Text(item["createdAt"].string.prefix(10)).font(.caption).foregroundStyle(.secondary); if kind == "sent" && item["cancelable"].bool { Button(L("取消喜欢")) { app.run { _ = try await app.api.request("/likes/sent/" + APIClient.encode(item["user"].id), method: "DELETE"); try await load() } } } }
                }
            }; if items.isEmpty { EmptyState() }; if !cursor.isEmpty { Button(L("加载更多")) { app.run { try await load(more: true) } } } }
        }.refreshable { do { try await load() } catch { app.message = error.localizedDescription } }.task(id: "\(kind)|\(app.mode)|\(app.authenticated)") { do { try await load() } catch { app.message = error.localizedDescription } }
    }
    private func load(more: Bool = false) async throws {
        guard app.authenticated else { return }
        let result = try await app.api.request(path + (more ? "?cursor=" + APIClient.encode(cursor) : ""), fresh: !more)
        let values = result["items"].array.filter { !$0["user"].id.isEmpty }.map { value -> JSON in var object = value.object; object["id"] = .string(value["user"].id); return .object(object) }
        items = more ? items + values.filter { value in !items.contains(where: { $0.id == value.id }) } : values; locked = result["locked"].bool; cursor = result["nextCursor"].string
        await app.refreshCounters()
    }
}
struct ProfileDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let id: String
    @State private var user: JSON = .null
    @State private var guestbook: [JSON] = []
    @State private var note = ""
    @State private var report = false
    @State private var block = false
    @State private var actionBusy = false
    var body: some View {
        NavigationStack {
            Page(title: "") {
                if user.exists {
                    VStack(spacing: 0) {
                        ZStack(alignment: .bottomLeading) {
                            RemoteImage(media: user["cover"].exists ? user["cover"] : user["avatar"])
                            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .bottom) { Avatar(user: user, size: 72).overlay(Circle().stroke(.white, lineWidth: 3)); VStack(alignment: .leading, spacing: 7) { Text(user["displayName"].string).font(.largeTitle.bold()); if user["vrcVerified"].bool { VerifiedBadge() }; Text(user.text("tagline")).lineLimit(3) } }
                                Text(L("共同配对") + " \(user["mutualMatches"].int) " + L("人")).font(.caption)
                            }.foregroundStyle(.white).padding(16)
                            ReactionControl(user: user, path: "/profiles/\(APIClient.encode(id))/reactions").frame(maxHeight: .infinity, alignment: .top).padding(.top, 12).padding(.trailing, 12).frame(maxWidth: .infinity, alignment: .trailing)
                        }.frame(height: 470)
                        HStack(spacing: 10) {
                            Button { perform("pass") } label: { Label(L("跳过"), systemImage: "xmark").padding(13) }.foregroundStyle(.primary)
                            Button { perform("superlike") } label: { Label(L("超级喜欢"), systemImage: "star").font(.subheadline.bold()).padding(13).background(LinearGradient(colors: [.green.opacity(0.5), .yellow], startPoint: .leading, endPoint: .trailing), in: Capsule()) }.foregroundStyle(.black)
                            PrimaryButton(title: "喜欢", icon: "heart") { perform("like") }
                        }.disabled(actionBusy).padding(14)
                        HStack(spacing: 30) { Spacer(); ShareLink(item: URL(string: "https://erp.sex/likes?u=" + APIClient.encode(id))!) { Image(systemName: "square.and.arrow.up") }; Button { report = true } label: { Image(systemName: "flag") }; Button { block = true } label: { Image(systemName: "nosign") } }.font(.title3).foregroundStyle(.primary).padding(18)
                    }.background(Palette.surface).clipShape(RoundedRectangle(cornerRadius: 22))
                    if !user.text("bio").isEmpty { Panel { Text(L("介绍")).font(.headline); Text(user.text("bio")) } }
                    if !user["photos"].array.isEmpty { Panel { Text(L("照片")).font(.headline); LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))]) { ForEach(user["photos"].array, id: \.self) { photo in RemoteImage(media: photo).frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 15)) } } } }
                    if user["voiceCard"].exists { Panel { AudioButton(media: user["voiceCard"]) } }
                    if !user["models"].array.isEmpty { Panel { Text(L("模型展示")).font(.headline); ForEach(user["models"].array, id: \.self) { model in Text(model["name"].string); if let image = model["photos"].array.first { RemoteImage(media: image).frame(height: 180) } } } }
                    if !user["answers"].array.isEmpty { Panel { Text(L("问卷")).font(.headline); ForEach(user["answers"].array, id: \.self) { answer in Text(answer["question"].text).font(.headline); Text(answer["answer"].text) } } }
                    if !user["socialLinks"].array.isEmpty { Panel { ForEach(user["socialLinks"].array, id: \.self) { item in if let url = URL(string: item["url"].string), url.scheme == "https" { Link(item["label"].string.isEmpty ? item["type"].string : item["label"].string, destination: url) } } } }
                    if user["guestbook"]["open"].bool { Panel { Text(L("留言板")).font(.headline); ForEach(guestbook) { note in HStack(alignment: .top) { Avatar(user: note["author"], size: 32); VStack(alignment: .leading) { Text(note["author"]["displayName"].string).font(.caption).foregroundStyle(.secondary); Text(note.text("body")) } } }; TextField(L("留言"), text: $note, axis: .vertical); PrimaryButton(title: "发送") { app.run { guard app.requireLogin() else { return }; _ = try await app.api.request("/profiles/\(APIClient.encode(id))/guestbook", method: "POST", body: ["body": note]); note = ""; try await load() } }.disabled(note.isEmpty) } }
                } else { ProgressView().frame(maxWidth: .infinity).padding(40) }
            }.refreshable { do { try await load() } catch { app.message = error.localizedDescription } }.task { do { try await load() } catch { app.message = error.localizedDescription } }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark") } } }
                .sheet(isPresented: $report) { ReportView(target: "user", id: id).environmentObject(app) }
                .confirmationDialog(L("封锁"), isPresented: $block) { Button(L("封锁"), role: .destructive) { app.run { _ = try await app.api.request("/users/\(APIClient.encode(id))/block", method: "POST", body: [:]); dismiss() } } }
        }
    }
    private func load() async throws { user = try await app.api.request("/profiles/" + APIClient.encode(id), fresh: true).profile; if user["guestbook"]["open"].bool { guestbook = (try? await app.api.request("/profiles/\(APIClient.encode(id))/guestbook?page=1")["items"].array) ?? [] } }
    private func perform(_ action: String) { guard !actionBusy, app.requireLogin() else { return }; actionBusy = true; app.run { defer { actionBusy = false }; try await app.swipe(user, action); dismiss() } }
}
struct MatchSuccessView: View {
    @EnvironmentObject private var app: AppState
    let result: MatchResult
    var body: some View { VStack(spacing: 25) {
        HStack(spacing: -25) { Avatar(user: result.user, size: 112).overlay(Circle().stroke(Palette.surface, lineWidth: 4)); Avatar(user: app.me, size: 112).overlay(Circle().stroke(Palette.surface, lineWidth: 4)) }.padding(.top, 25)
        Text(L("配对成功！")).font(.largeTitle.bold()).foregroundStyle(app.accent)
        Text(L("你和") + " " + result.user["displayName"].string + " " + L("互相喜欢")).foregroundStyle(.secondary)
        PrimaryButton(title: "打声招呼", icon: "bubble.left") { app.matched = nil; app.tab = 2; app.chatRoute = ChatRoute(id: result.matchID) }
        Button(L("继续滑卡")) { app.matched = nil }.font(.headline).foregroundStyle(.primary)
    }.padding(25).frame(maxWidth: 650).frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.surface) }
}
struct AudioButton: View {
    let media: JSON
    @State private var player: AVPlayer?
    @State private var playing = false
    var body: some View { Button { if playing { player?.pause(); playing = false } else if let url = URL(string: media["url"].string), url.scheme == "https" { player = AVPlayer(url: url); player?.play(); playing = true } } label: { Label(L("播放语音"), systemImage: playing ? "pause.fill" : "play.fill") }.onDisappear { player?.pause() } }
}
