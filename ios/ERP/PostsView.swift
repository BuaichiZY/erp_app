import SwiftUI

private enum PostOptions {
    static let categories = [("daily", "日常分享"), ("dance", "舞伴"), ("photo", "合拍"), ("event", "活动"), ("hangout", "一起玩"), ("creative", "创作合作"), ("erp", "ERP"), ("other", "其他"), ("ad", "广告"), ("club", "社团宣传")]
    static func label(_ value: String) -> String { L(categories.first { $0.0 == value }?.1 ?? "所有分类") }
}
struct PostsView: View {
    @EnvironmentObject private var app: AppState
    @State private var items: [JSON] = []
    @State private var sort = "mix"
    @State private var category = ""
    @State private var query = ""
    @State private var cursor = ""
    @State private var mine = false
    @State private var composing = false
    @State private var selected: PostRoute?
    var body: some View {
        Page(title: "广场") {
            Text(L("找舞伴、合拍、活动搭子，或分享日常。")).foregroundStyle(.secondary)
            HStack {
                Picker(L("内容"), selection: $mine) { Text(L("全部")).tag(false); Text(L("我的发布")).tag(true) }.pickerStyle(.segmented).frame(maxWidth: 250)
                Spacer()
                Picker(L("排序"), selection: $sort) { Text(L("综合")).tag("mix"); Text(L("最新")).tag("new"); Text(L("热门")).tag("hot") }.pickerStyle(.segmented).frame(maxWidth: 260)
                Button { if app.requireLogin() { composing = true } } label: { Label(L("发布"), systemImage: "plus").padding(11).foregroundStyle(.white).background(app.accent, in: Capsule()) }
            }
            HStack {
                Menu { Button(L("所有分类")) { category = "" }; ForEach(PostOptions.categories, id: \.0) { option in Button(L(option.1)) { category = option.0 } } } label: { Label(category.isEmpty ? L("所有分类") : PostOptions.label(category), systemImage: "line.3.horizontal.decrease").padding(10).background(Palette.secondary, in: Capsule()) }
                TextField(L("搜索贴文"), text: $query).textFieldStyle(.roundedBorder).submitLabel(.search)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: UIDevice.current.userInterfaceIdiom == .pad ? 290 : 320), spacing: 16)], spacing: 16) {
                ForEach(items) { post in Button { selected = PostRoute(id: post.id) } label: { PostCard(post: post) }.buttonStyle(.plain) }
            }
            if items.isEmpty { EmptyState(title: "暂无贴文") }
            if !cursor.isEmpty { Button(L("加载更多")) { app.run { try await load(more: true) } }.frame(maxWidth: .infinity) }
        }.refreshable { do { try await load() } catch { app.message = error.localizedDescription } }
            .task(id: "\(sort)|\(category)|\(mine)|\(app.mode)|\(app.eventSerial)") { do { try await load() } catch { app.message = error.localizedDescription } }
            .onSubmit(of: .text) { app.run { try await load() } }
            .sheet(item: $selected) { PostDetailView(id: $0.id).environmentObject(app) }
            .sheet(isPresented: $composing, onDismiss: { app.run { try await load() } }) { PostComposerView().environmentObject(app) }
    }
    private func load(more: Bool = false) async throws {
        var path = "/posts?sort=\(sort)"
        if !category.isEmpty { path += "&category=" + category }
        if mine { path += "&mine=1" } else if category.isEmpty { path += "&hideAds=1" }
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { path += "&q=" + APIClient.encode(query.trimmingCharacters(in: .whitespaces)) }
        if more && !cursor.isEmpty { path += "&cursor=" + APIClient.encode(cursor) }
        let response = try await app.api.request(path, fresh: !more)
        items = more ? items + response["items"].array.filter { entry in !items.contains(where: { $0.id == entry.id }) } : response["items"].array
        cursor = response["nextCursor"].string
    }
}
struct PostRoute: Identifiable { let id: String }
struct PostCard: View {
    @EnvironmentObject private var app: AppState
    let post: JSON
    private var media: JSON { post["media"].array.first ?? post["photos"].array.first ?? .null }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if media.exists { RemoteImage(media: media, size: 600, thumbnail: true).frame(height: 180).clipped() }
            VStack(alignment: .leading, spacing: 10) {
                Text(PostOptions.label(post["category"].string)).font(.caption).padding(6).background(Palette.secondary, in: Capsule())
                Text(post.text("title")).font(.headline).lineLimit(2)
                Text(post.text("body")).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                HStack { Avatar(user: post["author"], size: 30); Text(post["author"]["displayName"].string).lineLimit(1); if post["author"]["vrcVerified"].bool { VerifiedBadge() }; Spacer(); Image(systemName: "heart"); Text("\(post["likes"].int)"); Image(systemName: "bubble.left"); Text("\(post["commentCount"].int)") }.font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 14).padding(.bottom, 15)
        }.frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 20)).clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
struct PostDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let id: String
    @State private var post: JSON = .null
    @State private var comments: [JSON] = []
    @State private var cursor = ""
    @State private var draft = ""
    @State private var replyTo = ""
    @State private var report = false
    @State private var editing = false
    var body: some View {
        NavigationStack {
            Page(title: "") {
                if !post.exists { ProgressView() }
                else {
                    Panel {
                        Text(PostOptions.label(post["category"].string)).font(.caption).foregroundStyle(.secondary)
                        Text(post.text("title")).font(.largeTitle.bold())
                        HStack { Avatar(user: post["author"], size: 42); Text(post["author"]["displayName"].string); if post["author"]["vrcVerified"].bool { VerifiedBadge() }; Spacer(); Text(String(post["createdAt"].string.prefix(10))).font(.caption).foregroundStyle(.secondary) }
                        Text(post.text("body")).textSelection(.enabled)
                        ForEach(post["media"].array.isEmpty ? post["photos"].array : post["media"].array, id: \.self) { photo in RemoteImage(media: photo).frame(height: 290).clipShape(RoundedRectangle(cornerRadius: 12)) }
                        HStack {
                            Button { app.run { guard app.requireLogin() else { return }; _ = try await app.api.request("/posts/" + APIClient.encode(id) + "/like", method: post["liked"].bool ? "DELETE" : "POST"); try await load() } } label: { Label("\(post["likes"].int)", systemImage: post["liked"].bool ? "heart.fill" : "heart") }
                            Label("\(post["commentCount"].int)", systemImage: "bubble.left")
                            Label("\(post["views"].int)", systemImage: "eye")
                            Spacer()
                            ShareLink(item: URL(string: "https://erp.sex/posts/" + id)!) { Image(systemName: "square.and.arrow.up") }
                            Menu { if app.me.id == post["author"].id { Button(L("编辑贴文")) { editing = true }; Button(L("删除贴文"), role: .destructive) { app.run { _ = try await app.api.request("/posts/" + APIClient.encode(id), method: "DELETE"); dismiss() } } } else { Button(L("举报贴文")) { report = true } } } label: { Image(systemName: "ellipsis") }
                        }.foregroundStyle(.secondary)
                    }
                    Text(L("评论")).font(.title2.bold())
                    ForEach(comments) { comment in Panel { HStack { Avatar(user: comment["author"], size: 32); Text(comment["author"]["displayName"].string).font(.headline); Spacer(); Button(L("回复")) { replyTo = comment.id }; if app.me.id == comment["author"].id { Button(L("删除")) { app.run { _ = try await app.api.request("/posts/" + APIClient.encode(id) + "/comments/" + APIClient.encode(comment.id), method: "DELETE"); try await loadComments() } } } ; Text(comment.text("body")) } }
                    }
                    if !cursor.isEmpty { Button(L("加载更多")) { app.run { try await loadComments(more: true) } } }
                    HStack { TextField(replyTo.isEmpty ? L("写评论…") : L("回复评论…"), text: $draft, axis: .vertical).lineLimit(1...4); Button(L("发送")) { send() }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 15))
                }
            }.refreshable { do { try await load() } catch { app.message = error.localizedDescription } }
                .task { do { try await load() } catch { app.message = error.localizedDescription } }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark") } } }
                .sheet(isPresented: $report) { ReportView(target: "post", id: id).environmentObject(app) }
                .sheet(isPresented: $editing, onDismiss: { app.run { try await load() } }) { PostComposerView(initial: post).environmentObject(app) }
        }
    }
    private func load() async throws { let response = try await app.api.request("/posts/" + APIClient.encode(id), fresh: true); post = response["post"].exists ? response["post"] : response; try await loadComments() }
    private func loadComments(more: Bool = false) async throws { let response = try await app.api.request("/posts/" + APIClient.encode(id) + "/comments" + (more ? "?cursor=" + APIClient.encode(cursor) : ""), fresh: !more); comments = more ? comments + response["items"].array : response["items"].array; cursor = response["nextCursor"].string }
    private func send() { guard app.requireLogin() else { return }; app.run { var body: [String: Any] = ["body": draft.trimmingCharacters(in: .whitespacesAndNewlines)]; if !replyTo.isEmpty { body["replyTo"] = replyTo }; _ = try await app.api.request("/posts/" + APIClient.encode(id) + "/comments", method: "POST", body: body); draft = ""; replyTo = ""; try await loadComments() } }
}
struct PostComposerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    var initial: JSON = .null
    @State private var title = ""
    @State private var body = ""
    @State private var category = "daily"
    @State private var rating = ""
    @State private var r18Kind = "sexual"
    @State private var duration = "7"
    @State private var world = ""
    @State private var pledge = false
    @State private var busy = false
    @State private var photos: [JSON] = []
    @State private var pick = false
    var bodyView: some View {
        NavigationStack {
            Page(title: initial.exists ? "编辑贴文" : "发布贴文") {
                Picker(L("分类"), selection: $category) { ForEach(PostOptions.categories.prefix(8), id: \.0) { option in Text(L(option.1)).tag(option.0) } }
                TextField(L("标题"), text: $title).textFieldStyle(.roundedBorder)
                TextField(L("内容"), text: $body, axis: .vertical).lineLimit(6...12).textFieldStyle(.roundedBorder)
                Picker(L("内容分级"), selection: $rating) { Text(L("请选择")).tag(""); Text(L("全年龄")).tag("general"); Text(L("擦边")).tag("suggestive"); Text("R18").tag("r18") }.pickerStyle(.segmented)
                if rating == "r18" { Picker(L("R18 内容类型"), selection: $r18Kind) { Text(L("成人内容")).tag("sexual"); Text(L("血腥内容")).tag("gore") } }
                Picker(L("展示期限"), selection: $duration) { ForEach(["1", "3", "7", "14", "30"], id: \.self) { Text($0 + L(" 天")).tag($0) }; Text(L("长期展示")).tag("long") }
                TextField(L("世界（可选）"), text: $world).textFieldStyle(.roundedBorder)
                if !photos.isEmpty { LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))]) { ForEach(photos) { media in RemoteImage(media: media).frame(height: 90).onTapGesture { photos.removeAll { $0.id == media.id } } } } }
                Button { pick = true } label: { Label(L("添加照片"), systemImage: "photo.badge.plus") }
                Toggle(L("我已阅读并同意遵守社区发布规则"), isOn: $pledge)
                PrimaryButton(title: busy ? "正在提交…" : initial.exists ? "保存修改" : "发布") { save() }.disabled(busy || title.trimmingCharacters(in: .whitespaces).isEmpty || rating.isEmpty || !pledge)
            }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark") } } }
                .sheet(isPresented: $pick) { ImageUploadView(purpose: "post") { media in let value = media["media"].exists ? media["media"] : media; if !value.id.isEmpty { photos.append(value) } }.environmentObject(app) }
                .onAppear { if initial.exists { title = initial.text("title"); body = initial.text("body"); category = initial["category"].string; rating = initial["rating"].string; photos = initial["media"].array } }
        }
    }
    var body: some View { bodyView }
    private func save() {
        busy = true
        app.run { defer { busy = false }
            var payload: [String: Any] = ["category": category, "title": title.trimmingCharacters(in: .whitespacesAndNewlines), "body": body.trimmingCharacters(in: .whitespacesAndNewlines), "rating": rating, "mediaIds": photos.map(\.id), "languages": [], "worldId": world.isEmpty ? NSNull() : world]
            if rating == "r18" { payload["r18Kind"] = r18Kind }
            if !initial.exists { payload["expiresAt"] = duration == "long" ? NSNull() : ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(Int(duration) ?? 7) * 86400)) }
            _ = try await app.api.request(initial.exists ? "/posts/" + APIClient.encode(initial.id) : "/posts", method: initial.exists ? "PATCH" : "POST", body: payload)
            dismiss()
        }
    }
}
