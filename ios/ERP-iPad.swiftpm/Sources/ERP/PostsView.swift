import SwiftUI

private struct PostFeed<Content: View>: View {
    @Environment(\.pageLayout) private var layout
    @ViewBuilder let content: Content
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 16, alignment: .top), count: layout.postColumns), spacing: 16) { content }
    }
}

private enum PostOptions {
    static let categories = [("daily", "日常分享"), ("dance", "舞伴"), ("photo", "合拍"), ("event", "活动"), ("hangout", "一起玩"), ("creative", "创作合作"), ("erp", "ERP"), ("other", "其他"), ("ad", "广告"), ("club", "社团宣传")]
    @MainActor static func label(_ value: String) -> String { L(categories.first { $0.0 == value }?.1 ?? "所有分类") }
}
struct PostsView: View {
    @EnvironmentObject private var app: AppState
    @State private var items: [JSON] = []
    @State private var sort = "mix"
    @State private var categories: Set<String> = []
    @State private var showAds = true
    @State private var categoryCursors: [String: String] = [:]
    @State private var query = ""
    @State private var cursor = ""
    @State private var mine = false
    @State private var composing = false
    @State private var requestID = UUID()
    @State private var loading = false
    var body: some View {
        ZStack {
            listContent.opacity(app.postRoute == nil ? 1 : 0)
                .allowsHitTesting(app.postRoute == nil).accessibilityHidden(app.postRoute != nil)
            if let route = app.postRoute {
                PostDetailView(id: route.id) { app.postRoute = nil }.id(route.id)
            }
        }
    }
    private var listContent: some View {
        Page(title: "") {
            HStack { Text(L("广场")).font(.largeTitle.bold()); Spacer(); Button { if app.requireLogin() { composing = true } } label: { Label(L("发布"), systemImage: "plus").font(.subheadline.bold()).padding(.horizontal, 20).frame(minHeight: 42).foregroundStyle(.white).background(app.accent, in: RoundedRectangle(cornerRadius: app.palette.pop ? 14 : 24)).siteOutline(RoundedRectangle(cornerRadius: app.palette.pop ? 14 : 24), normalBorder: false) }.buttonStyle(.plain) }
            Text(L("找舞伴、合拍、活动搭子，或分享日常。")).foregroundStyle(app.palette.muted)
            PostToolbar(mine: $mine, sort: $sort, categories: $categories, showAds: $showAds, query: $query)
            PostFeed {
                ForEach(items) { post in
                    ZStack(alignment: .topTrailing) {
                        Button { app.postRoute = PostRoute(id: post.id) } label: { PostCard(post: post) }.buttonStyle(.plain)
                        ReactionControl(user: post, path: "/posts/" + APIClient.encode(post.id) + "/reactions").padding(10)
                    }
                }
            }
            if loading && items.isEmpty { ProgressView().frame(maxWidth: .infinity) }
            else if items.isEmpty { EmptyState(title: "暂无贴文") }
            if !cursor.isEmpty { Button(L("加载更多")) { app.run { try await load(more: true) } }.frame(maxWidth: .infinity) }
        }.refreshable { do { try await load() } catch { app.message = error.localizedDescription } }
             .task(id: "\(sort)|\(categories.sorted().joined(separator: ","))|\(showAds)|\(mine)|\(query)|\(app.mode)|\(app.authenticated)|\(app.eventSerial)") {
                do { if !query.isEmpty { try await Task.sleep(nanoseconds: 300_000_000) }; try await load() } catch { if !Task.isCancelled { app.message = error.localizedDescription } }
            }
            .sheet(isPresented: $composing, onDismiss: { app.run { try await load() } }) { PostComposerView().environmentObject(app).sitePresentation() }
    }
    private func load(more: Bool = false) async throws {
        let generation = UUID(), selection = "\(sort)|\(categories.sorted().joined(separator: ","))|\(showAds)|\(mine)|\(query)|\(app.mode)|\(app.me.id)"
        requestID = generation; loading = true
        defer { if requestID == generation { loading = false } }
        let streams = categories.isEmpty ? [""] : categories.sorted()
        var batches: [[JSON]] = [], next: [String: String] = [:]
        for category in streams {
            if more && (categoryCursors[category] ?? "").isEmpty { continue }
            var path = "/posts?sort=\(sort)"
            if !category.isEmpty { path += "&category=" + APIClient.encode(category) }
            if mine { path += "&mine=1" }
            if !showAds { path += "&hideAds=1" }
            let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !search.isEmpty { path += "&q=" + APIClient.encode(search) }
            if more, let value = categoryCursors[category], !value.isEmpty { path += "&cursor=" + APIClient.encode(value) }
            let response = try await app.api.request(path, fresh: !more)
            try Task.checkCancellation()
            batches.append(response["items"].array); let value = response["nextCursor"].string; next[category] = more && value == categoryCursors[category] ? "" : value
        }
        guard requestID == generation, selection == "\(sort)|\(categories.sorted().joined(separator: ","))|\(showAds)|\(mine)|\(query)|\(app.mode)|\(app.me.id)" else { return }
        let merged = PostCategoryRules.merge(batches, existing: more ? items : [], sort: sort)
        items = merged; categoryCursors = next
        cursor = next.values.contains(where: { !$0.isEmpty }) ? "more" : ""

    }
}
private struct PostToolbar: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var mine: Bool
    @Binding var sort: String
    @Binding var categories: Set<String>
    @Binding var showAds: Bool
    @State private var filtering = false
    @Binding var query: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let controls = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 8))
            controls {
                PostPills(selection: $mine, choices: [(false, "全部"), (true, "我的发布")], rectangular: true)
                Spacer(minLength: 0)
                PostPills(selection: $sort, choices: [("mix", "综合"), ("new", "最新"), ("hot", "热门")], rectangular: true)
            }
            let filters = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 8))
            filters {
                Button { filtering.toggle() } label: {
                    HStack(spacing: 5) { Image(systemName: "line.3.horizontal.decrease"); Text(categories.isEmpty ? L("所有分类") : categories.count == 1 ? PostOptions.label(categories.first!) : L("分类") + " (\(categories.count))"); Image(systemName: "chevron.down").font(.caption2) }.font(.subheadline).padding(.horizontal, 11).frame(minHeight: 42).background(app.palette.secondary, in: RoundedRectangle(cornerRadius: 14)).siteOutline(RoundedRectangle(cornerRadius: 14), normalBorder: false).contentShape(Rectangle())
                }.buttonStyle(.plain).fixedSize().foregroundStyle(app.palette.text)
                    .popover(isPresented: $filtering) {
                        VStack(spacing: 16) {
                            HStack { Text(L("分类")).font(.headline); Spacer(); Button(L("完成")) { filtering = false } }
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                categoryChoice("", "所有分类")
                                ForEach(PostOptions.categories, id: \.0) { categoryChoice($0.0, $0.1) }
                            }
                            Divider(); Toggle(L("显示广告"), isOn: $showAds)
                        }.padding(20).frame(width: 320).background(app.palette.surface).foregroundStyle(app.palette.text).tint(app.accent).presentationCompactAdaptation(.popover)
                    }

                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(app.palette.muted)
                    TextField(L("搜索贴文"), text: $query).font(.subheadline).submitLabel(.search)
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark").frame(width: 28, height: 34) }.accessibilityLabel(L("清除搜索")) }
                }.padding(.horizontal, 10).frame(minHeight: 42).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 14)).siteOutline(RoundedRectangle(cornerRadius: 14))
            }
        }.zIndex(1)
    }
    private func categoryChoice(_ value: String, _ label: String) -> some View {
        let selected = value.isEmpty ? categories.isEmpty : categories.contains(value)
        return Button {
            if value.isEmpty { categories.removeAll() }
            else if categories.contains(value) { categories.remove(value) }
            else { categories.insert(value) }
        } label: { HStack(spacing: 4) { if selected { Image(systemName: "checkmark") }; Text(L(label)) }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 44).background(selected ? app.accent : app.palette.secondary, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(selected ? .white : app.palette.text).contentShape(Rectangle()) }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

}
struct PostPills<Value: Hashable>: View {
    @EnvironmentObject private var app: AppState
    @Binding var selection: Value
    let choices: [(Value, String)]
    var rectangular = false
    private var selectedShape: AnyShape { rectangular ? AnyShape(RoundedRectangle(cornerRadius: 11)) : AnyShape(Capsule()) }
    private var frameShape: RoundedRectangle { RoundedRectangle(cornerRadius: rectangular || app.palette.pop ? 14 : 24) }
    var body: some View {
        HStack(spacing: 0) { ForEach(choices, id: \.0) { value, label in
            Button { selection = value } label: { Text(L(label)).font(.subheadline).fixedSize().padding(.horizontal, 10).frame(minHeight: 38).background(selection == value ? app.palette.selection : .clear, in: selectedShape).contentShape(selectedShape) }
                .buttonStyle(.plain).foregroundStyle(selection == value ? app.palette.selectionText : app.palette.muted).accessibilityAddTraits(selection == value ? .isSelected : [])
        } }.padding(3).background(app.palette.secondary, in: frameShape).siteOutline(frameShape, shadow: false, normalBorder: false)
    }
}
struct PostRoute: Identifiable { let id: String }
struct PostCard: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.pageLayout) private var layout
    let post: JSON
    private var media: JSON { post["media"].array.first ?? post["photos"].array.first ?? .null }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if media.exists {
                Group {
                    if !media["view"].string.isEmpty && !["show", "blur"].contains(media["view"].string) { Text(L("内容暂不可见")).foregroundStyle(app.palette.muted).frame(maxWidth: .infinity, maxHeight: .infinity).background(app.palette.secondary) }
                    else { ZStack { RemoteImage(media: media, size: 900, thumbnail: true); if media["view"].string == "blur" { Label(L("点开查看"), systemImage: "eye.slash").font(.caption).foregroundStyle(.white).padding(9).background(.black.opacity(0.6), in: Capsule()) } } }
                }.frame(height: layout.postCardWidth * 0.5).clipped().contentShape(Rectangle())
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(PostOptions.label(post["category"].string)).font(.caption).padding(6).background(app.palette.pop ? app.palette.surface : app.palette.secondary, in: Capsule()).siteOutline(Capsule(), shadow: false, normalBorder: false)
                    if post["rating"].string != "general", !post["rating"].string.isEmpty { Text(post["rating"].string == "r18" ? "R18" : ["r18g", "r18-g"].contains(post["rating"].string) ? "R18-G" : L("擦边")).font(.caption.bold()).padding(6).foregroundStyle(app.palette.pop ? .white : app.palette.text).background(app.palette.pop ? (["r18", "r18g", "r18-g"].contains(post["rating"].string) ? Color.red : Color.orange) : app.palette.secondary, in: RoundedRectangle(cornerRadius: 8)) }
                }
                Text(post.text("title")).font(.title2.bold()).lineLimit(2).frame(minHeight: layout.postColumns > 1 ? 54 : 0, alignment: .topLeading)
                Text(post.text("body")).font(.subheadline).foregroundStyle(app.palette.muted).lineLimit(3).frame(minHeight: layout.postColumns > 1 ? 54 : 0, alignment: .topLeading)
                if let date = ERPDate.parse(post["createdAt"].string) { Text(date, format: .dateTime.year().month().day().hour().minute()).font(.caption).foregroundStyle(app.palette.muted) }
                HStack(spacing: 5) { Avatar(user: post["author"], size: 30); Text(post["author"]["displayName"].string).lineLimit(1); VRCIdentityBadge(user: post["author"]); Spacer(minLength: 2); Image(systemName: "heart"); Text("\(post["likes"].int)"); Image(systemName: "bubble.left"); Text("\(post["commentCount"].int)"); Image(systemName: "eye"); Text("\(post["views"].int)") }.font(.caption).foregroundStyle(app.palette.muted)
            }.padding(.horizontal, 14).padding(.bottom, 15)
        }.frame(maxWidth: .infinity, alignment: .leading).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 20)).clipShape(RoundedRectangle(cornerRadius: 20)).siteOutline(RoundedRectangle(cornerRadius: 20)).contentShape(RoundedRectangle(cornerRadius: 20))
    }
}
struct PostDetailView: View {
    @EnvironmentObject private var app: AppState
    let id: String
    let onClose: () -> Void
    @State private var post: JSON = .null
    @State private var comments: [JSON] = []
    @State private var cursor = ""
    @State private var draft = ""
    @State private var replyTo = ""
    @State private var replyName = ""
    @State private var report = false
    @State private var editing = false
    @State private var sending = false
    @State private var failure: String?
    @State private var profileRoute: ProfileRoute?
    @State private var showingMedia = false
    @State private var mediaIndex = 0
    @FocusState private var commentFocused: Bool
    private var media: [JSON] { post["media"].array.isEmpty ? post["photos"].array : post["media"].array }
    private var commentLength: Int { draft.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count }
    var body: some View {
        ScrollViewReader { proxy in
            Page(title: "", maximumWidth: 900) {
                HStack(spacing: 14) {
                    Button(action: onClose) { Image(systemName: "arrow.left").frame(width: 44, height: 44) }.accessibilityLabel(L("返回"))
                    Text(post.text("title")).font(.title.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    if post.exists {
                        if app.me.id == post["author"].id {
                            Menu { Button(L("编辑贴文")) { editing = true }; Button(L("删除贴文"), role: .destructive) { app.run { _ = try await app.api.request("/posts/" + APIClient.encode(id), method: "DELETE"); onClose() } } } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        } else { Button { if app.requireLogin() { report = true } } label: { Label(L("举报贴文"), systemImage: "flag").frame(minHeight: 44) } }
                    }
                }.foregroundStyle(app.palette.text).buttonStyle(.plain)
                if let failure { Panel { Text(failure).foregroundStyle(app.palette.muted); Button(L("重试")) { reload() } } }
                if !post.exists && failure == nil { ProgressView().frame(maxWidth: .infinity).padding(40) }
                if post.exists {
                    Panel {
                        HStack {
                            authorButton(post["author"], size: 44)
                            Spacer()
                            Text(String(post["createdAt"].string.prefix(10))).font(.caption).foregroundStyle(app.palette.muted)
                        }
                        Text(PostOptions.label(post["category"].string)).font(.caption).padding(.horizontal, 10).padding(.vertical, 5).background(app.palette.secondary, in: Capsule())
                        Text(post.text("body")).textSelection(.enabled)
                        ForEach(Array(media.enumerated()), id: \.offset) { index, photo in
                            Button { mediaIndex = index; showingMedia = true } label: {
                                RemoteImage(media: photo, fit: true).aspectRatio(photo["width"].int > 0 && photo["height"].int > 0 ? CGFloat(photo["width"].int) / CGFloat(photo["height"].int) : 1, contentMode: .fit)
                                    .frame(maxWidth: 560).clipShape(RoundedRectangle(cornerRadius: 14)).contentShape(Rectangle()).frame(maxWidth: .infinity)
                            }.buttonStyle(.plain).accessibilityLabel(L("查看大图"))
                        }
                        SiteDivider()
                        HStack(spacing: 18) {
                            Button { profileRoute = ProfileRoute(id: post["author"].id) } label: { Label(L("查看名片"), systemImage: "person.crop.rectangle") }
                            Spacer(minLength: 0)
                            Button { app.run { guard app.requireLogin() else { return }; _ = try await app.api.request("/posts/" + APIClient.encode(id) + "/like", method: post["liked"].bool ? "DELETE" : "POST"); try await load() } } label: { Label("\(post["likes"].int)", systemImage: post["liked"].bool ? "heart.fill" : "heart") }.foregroundStyle(post["liked"].bool ? app.accent : app.palette.muted)
                            Label("\(post["views"].int)", systemImage: "eye")
                            ShareLink(item: URL(string: "https://erp.sex/posts/" + id)!) { Image(systemName: "square.and.arrow.up") }
                        }.font(.subheadline).foregroundStyle(app.palette.muted).buttonStyle(.plain).frame(minHeight: 44)
                    }
                    Panel {
                        Text(L("评论") + " \(post["commentCount"].int)").font(.title2.bold())
                        VStack(alignment: .leading, spacing: 10) {
                            if !replyTo.isEmpty { HStack { Text(L("回复") + " " + replyName).font(.subheadline).foregroundStyle(app.accent); Spacer(); Button(L("取消回复")) { replyTo = ""; replyName = "" } } }
                            TextField(app.authenticated ? L("写评论…") : L("登录后发表评论"), text: $draft, axis: .vertical).lineLimit(3...6).focused($commentFocused).disabled(sending)
                            HStack { Text("\(commentLength)/500").font(.caption).foregroundStyle(commentLength > 500 ? app.accent : app.palette.muted); Spacer(); Button(L(app.authenticated ? sending ? "发送中" : "发送" : "登录")) { send() }.buttonStyle(.borderedProminent).disabled(sending || (app.authenticated && (commentLength == 0 || commentLength > 500))) }
                        }.padding(12).background(app.palette.secondary, in: RoundedRectangle(cornerRadius: 14)).id("comment-composer")
                        if comments.isEmpty { Text(L("暂无评论")).foregroundStyle(app.palette.muted).padding(.vertical, 12) }
                        ForEach(comments) { comment in
                            commentRow(comment)
                            ForEach(comment["replies"].array) { reply in commentRow(reply).padding(.leading, 30) }
                            SiteDivider()
                        }
                        if !cursor.isEmpty { Button(L("加载更多")) { app.run { try await loadComments(more: true) } }.frame(maxWidth: .infinity, minHeight: 44) }
                    }
                }
            }.refreshable { await refresh() }.task { await refresh() }
                .onChange(of: replyTo) { value in if !value.isEmpty { withAnimation { proxy.scrollTo("comment-composer", anchor: .center) }; commentFocused = true } }
                .sheet(isPresented: $report) { ReportView(target: "post", id: id).environmentObject(app).sitePresentation() }
                .sheet(isPresented: $editing, onDismiss: reload) { PostComposerView(initial: post).environmentObject(app).sitePresentation() }
                .sheet(item: $profileRoute) { ProfileDetailView(id: $0.id).environmentObject(app).sitePresentation() }
                .fullScreenCover(isPresented: $showingMedia) { PostMediaViewer(media: media, index: $mediaIndex).environmentObject(app).sitePresentation() }
        }
    }
    private func authorButton(_ user: JSON, size: CGFloat) -> some View {
        Button { if !user.id.isEmpty { profileRoute = ProfileRoute(id: user.id) } } label: {
            HStack(spacing: 10) { Avatar(user: user, size: size); Text(user["displayName"].string).font(.headline).lineLimit(1); VRCIdentityBadge(user: user) }.contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(app.palette.text)
    }
    private func commentRow(_ comment: JSON) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { authorButton(comment["author"], size: 30); Spacer(); Text(String(comment["createdAt"].string.prefix(10))).font(.caption2).foregroundStyle(app.palette.muted) }
            Text(comment.text("body")).textSelection(.enabled)
            HStack {
                Button(L("回复")) { if app.requireLogin() { replyName = comment["author"]["displayName"].string; replyTo = comment.id } }
                if app.me.id == comment["author"].id { Button(L("删除"), role: .destructive) { app.run { _ = try await app.api.request("/posts/" + APIClient.encode(id) + "/comments/" + APIClient.encode(comment.id), method: "DELETE"); if replyTo == comment.id { replyTo = ""; replyName = "" }; try await load() } } }
            }.font(.caption).frame(minHeight: 36)
        }.padding(.vertical, 8)
    }
    private func reload() { app.run { await refresh() } }
    private func refresh() async { failure = nil; do { try await load() } catch { if !Task.isCancelled { failure = error.localizedDescription } } }
    private func load() async throws {
        let response = try await app.api.request("/posts/" + APIClient.encode(id), fresh: true)
        guard !Task.isCancelled else { return }
        post = response["post"].exists ? response["post"] : response
        try await loadComments()
    }
    private func loadComments(more: Bool = false) async throws {
        let response = try await app.api.request("/posts/" + APIClient.encode(id) + "/comments" + (more ? "?cursor=" + APIClient.encode(cursor) : ""), fresh: !more)
        guard !Task.isCancelled else { return }
        comments = more ? comments + response["items"].array.filter { entry in !comments.contains { $0.id == entry.id } } : response["items"].array
        let next = response["nextCursor"].string; cursor = more && next == cursor ? "" : next
    }
    private func send() {
        guard app.requireLogin(), !sending, commentLength > 0, commentLength <= 500 else { return }
        sending = true
        app.run { defer { sending = false }; var body: [String: Any] = ["body": draft.trimmingCharacters(in: .whitespacesAndNewlines)]; if !replyTo.isEmpty { body["replyTo"] = replyTo }; _ = try await app.api.request("/posts/" + APIClient.encode(id) + "/comments", method: "POST", body: body); draft = ""; replyTo = ""; replyName = ""; commentFocused = false; try await load() }
    }
}
struct PostMediaViewer: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppState
    let media: [JSON]
    @Binding var index: Int
    @State private var revealed: [String: JSON] = [:]
    @State private var loading: Set<String> = []
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) { ForEach(Array(media.enumerated()), id: \.offset) { offset, photo in
                ZStack {
                    RemoteImage(media: revealed[photo.id] ?? photo, size: 2000, fit: true)
                    if (revealed[photo.id] ?? photo)["view"].string == "blur" {
                        Button { guard !loading.contains(photo.id) else { return }; loading.insert(photo.id); app.run { defer { loading.remove(photo.id) }; let response = try await app.api.request("/media/" + APIClient.encode(photo.id), fresh: true); let value = response["media"].exists ? response["media"] : response; if value["view"].string == "show" { revealed[photo.id] = value } else { app.message = L("内容暂不可见") } } } label: { Label(L(loading.contains(photo.id) ? "正在加载…" : "查看图片"), systemImage: "eye").padding(14).background(.black.opacity(0.7), in: Capsule()).foregroundStyle(.white) }.disabled(loading.contains(photo.id))
                    }
                }.tag(offset).padding(.vertical, 64)
            } }.tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .always : .never))
            Button { dismiss() } label: { Image(systemName: "xmark").font(.title2).foregroundStyle(.white).frame(width: 48, height: 48).background(.black.opacity(0.6), in: Circle()) }.padding(16).accessibilityLabel(L("关闭"))
        }
    }
}
struct PostComposerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    var initial: JSON = .null
    @State private var title = ""
    @State private var postText = ""
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
                TextField(L("内容"), text: $postText, axis: .vertical).lineLimit(6...12).textFieldStyle(.roundedBorder)
                Picker(L("内容分级"), selection: $rating) { Text(L("请选择")).tag(""); Text(L("全年龄")).tag("general"); Text(L("擦边")).tag("suggestive"); Text("R18").tag("r18") }.pickerStyle(.segmented)
                if rating == "r18" { Picker(L("R18 内容类型"), selection: $r18Kind) { Text(L("成人内容")).tag("sexual"); Text(L("血腥内容")).tag("gore") } }
                Picker(L("展示期限"), selection: $duration) { ForEach(["1", "3", "7", "14", "30"], id: \.self) { Text($0 + L(" 天")).tag($0) }; Text(L("长期展示")).tag("long") }
                TextField(L("世界（可选）"), text: $world).textFieldStyle(.roundedBorder)
                if !photos.isEmpty { LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))]) { ForEach(photos) { media in RemoteImage(media: media).frame(height: 90).onTapGesture { photos.removeAll { $0.id == media.id } } } } }
                Button { pick = true } label: { Label(L("添加照片"), systemImage: "photo.badge.plus") }
                Toggle(L("我已阅读并同意遵守社区发布规则"), isOn: $pledge)
                PrimaryButton(title: busy ? "正在提交…" : initial.exists ? "保存修改" : "发布") { save() }.disabled(busy || title.trimmingCharacters(in: .whitespaces).isEmpty || rating.isEmpty || !pledge)
            }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark") } } }
                .sheet(isPresented: $pick) { ImageUploadView(purpose: "post") { media in let value = media["media"].exists ? media["media"] : media; if !value.id.isEmpty { photos.append(value) } }.environmentObject(app).sitePresentation() }
                .onAppear { if initial.exists { title = initial.text("title"); postText = initial.text("body"); category = initial["category"].string; rating = initial["rating"].string; photos = initial["media"].array } }
        }
    }
    var body: some View { bodyView }
    private func save() {
        busy = true
        app.run { defer { busy = false }
            var payload: [String: Any] = ["category": category, "title": title.trimmingCharacters(in: .whitespacesAndNewlines), "body": postText.trimmingCharacters(in: .whitespacesAndNewlines), "rating": rating, "mediaIds": photos.map(\.id), "languages": [], "worldId": world.isEmpty ? NSNull() : world]
            if rating == "r18" { payload["r18Kind"] = r18Kind }
            if !initial.exists { payload["expiresAt"] = duration == "long" ? NSNull() : ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(Int(duration) ?? 7) * 86400)) }
            _ = try await app.api.request(initial.exists ? "/posts/" + APIClient.encode(initial.id) : "/posts", method: initial.exists ? "PATCH" : "POST", body: payload)
            dismiss()
        }
    }
}
