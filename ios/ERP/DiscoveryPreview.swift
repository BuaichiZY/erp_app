import SwiftUI

@MainActor enum DiscoveryFacts {
    static func label(_ value: String) -> String {
        ["pcvr": "PC VR", "desktop": "桌面", "quest": "Quest", "mobile": "手机", "voice": "开麦", "mute": "静音", "sign": "手语", "gesture": "表情／肢体语言", "friends": "交朋友", "browsing": "随便看看", "activity": "一起活动", "relationship": "寻找伴侣", "erp": "ERP", "sleep": "一起睡觉", "native": "母语", "fluent": "流利", "conversational": "可交流", "basic": "基础", "beginner": "基础", "intermediate": "可交流", "creative": "创作", "other": "其他", "male": "男声", "female": "女声", "neutral": "中性", "masculine": "男性化", "feminine": "女性化", "androgynous": "中性", "nonhuman": "非人"][value] ?? value
    }
    static func values(_ items: [JSON]) -> String { items.map { L(label($0["name"].text.isEmpty ? $0.text : $0["name"].text)) }.filter { !$0.isEmpty }.joined(separator: " · ") }
    static func platforms(_ user: JSON) -> String {
        let vrc = user["vrc"]
        var values = vrc["platforms"].array.isEmpty ? user["platforms"].array : vrc["platforms"].array
        if vrc["fullBodyTracking"].bool { values.append(.string("全身追踪")) }
        if vrc["handTracking"].bool { values.append(.string("手部追踪")) }
        return Self.values(values)
    }
    static func time(_ user: JSON) -> String {
        guard user["utcOffsetMin"].exists else { return "" }
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: user["utcOffsetMin"].int * 60)
        return L("当地时间") + " " + formatter.string(from: Date())
    }
}

struct DiscoveryPreview: View {
    @EnvironmentObject private var app: AppState
    let user: JSON
    @Binding var photoIndex: Int
    private var photos: [JSON] { DiscoveryMedia.photos(user) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L("快速预览")).font(.caption.bold()).foregroundStyle(app.palette.muted)
            Text(user["displayName"].string).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
            if !user.text("tagline").isEmpty { Text(user.text("tagline")).foregroundStyle(app.palette.muted) }
            GeometryReader { geometry in
                let columns = geometry.size.width >= 560 ? 4 : geometry.size.width >= 390 ? 3 : 2
                let side = (geometry.size.width - CGFloat(columns - 1) * 8) / CGFloat(columns)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                    ForEach(photos.indices, id: \.self) { index in
                        Button { photoIndex = index } label: {
                            RemoteImage(media: photos[index], size: 650).frame(height: side * 1.05)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(index == photoIndex ? app.accent : .clear, lineWidth: 3))
                        }.buttonStyle(.plain).accessibilityLabel(L("照片") + " \(index + 1)")
                            .accessibilityAddTraits(index == photoIndex ? .isSelected : [])
                    }
                }
            }.frame(height: galleryHeight)
            VStack(spacing: 0) {
                if user["matchCount"].exists { fact("已配对", value: "\(user["matchCount"].int) " + L("人")) }
                if user["mutualMatches"].exists { fact("共同配对", value: "\(user["mutualMatches"].int) " + L("人")) }
                fact("对方时间", value: DiscoveryFacts.time(user))
                fact("平台", value: DiscoveryFacts.platforms(user))
                fact("说话方式", value: DiscoveryFacts.values(user["vrc"]["speech"].array))
                fact("素体", value: DiscoveryFacts.values(user["baseAvatars"].array + user["baseAvatarCustom"].array))
                fact("主模型", value: user["models"].array.first(where: { $0["isPrimary"].bool })?["name"].string ?? "")
                fact("语言", value: user["languages"].array.map { item in
                    item.string.isEmpty ? item["code"].string.uppercased() + " " + L(DiscoveryFacts.label(item["level"].string)) : item.string.uppercased()
                }.joined(separator: " · "))
            }
            WrappingLayout { ForEach(user["tags"].array, id: \.self) { tag in Text(tag.text.isEmpty ? tag["name"].text : tag.text).font(.caption).padding(8).background(app.palette.secondary, in: Capsule()) } }
            if !user.text("bio").isEmpty { Text(user.text("bio")).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
            Button(L("查看完整名片 ↗")) { app.profileRoute = ProfileRoute(id: user.id) }.buttonStyle(.bordered).frame(minHeight: 44)
            Text(L("打开完整名片会留下访问记录。")).font(.caption).foregroundStyle(app.palette.muted)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(app.palette.surface, in: RoundedRectangle(cornerRadius: 20))
            .siteOutline(RoundedRectangle(cornerRadius: 20))
    }
    @Environment(\.pageLayout) private var layout
    private var galleryHeight: CGFloat {
        let width = max(1, layout.discoveryPreviewWidth - 40)
        let columns = width >= 560 ? 4 : width >= 390 ? 3 : 2
        let side = (width - CGFloat(columns - 1) * 8) / CGFloat(columns)
        return CGFloat((photos.count + columns - 1) / columns) * (side * 1.05 + 8) - 8
    }
    @ViewBuilder private func fact(_ title: String, value: String) -> some View {
        if !value.isEmpty {
            SiteDivider()
            HStack(alignment: .top, spacing: 12) { Text(L(title)).foregroundStyle(app.palette.muted).frame(width: 82, alignment: .leading); Text(value).frame(maxWidth: .infinity, alignment: .leading) }.font(.subheadline).padding(.vertical, 13)
        }
    }
}

struct ProfileFactsView: View {
    @EnvironmentObject private var app: AppState
    let user: JSON
    var body: some View {
        VStack(spacing: 0) {
            row("交友意向", value: DiscoveryFacts.values(user["intents"].array))
            row("平台", value: DiscoveryFacts.platforms(user))
            row("说话方式", value: DiscoveryFacts.values(user["vrc"]["speech"].array))
            row("素体", value: DiscoveryFacts.values(user["baseAvatars"].array + user["baseAvatarCustom"].array))
            row("模型风格", value: DiscoveryFacts.values(user["vrc"]["avatarStyles"].array))
            row("模型性别呈现", value: DiscoveryFacts.values(user["gender"]["modelPresentation"].array))
            row("声音", value: L(DiscoveryFacts.label(user["gender"]["voice"].string)))
            row("性别认同", value: user["gender"]["identity"].text)
            row("称呼", value: user["gender"]["pronouns"].text)
            row("关系状态", value: user["relationship"].text)
            row("对方时间", value: DiscoveryFacts.time(user))
            if user["matchCount"].exists { row("已配对", value: "\(user["matchCount"].int) " + L("人")) }
            if !user["languages"].array.isEmpty {
                SiteDivider()
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("语言")).foregroundStyle(app.palette.muted)
                    ForEach(user["languages"].array, id: \.self) { language in
                        let code = language.string.isEmpty ? language["code"].string.uppercased() : language.string.uppercased()
                        let level = language["level"].string
                        VStack(spacing: 5) {
                            HStack { Text(code); Spacer(); Text(L(DiscoveryFacts.label(level))).foregroundStyle(app.palette.muted) }
                            if !level.isEmpty { ProgressView(value: ["native": 1.0, "fluent": 0.8, "conversational": 0.6, "intermediate": 0.6, "basic": 0.2, "beginner": 0.2][level] ?? 0.4).accessibilityLabel(code + " " + L(DiscoveryFacts.label(level))) }
                        }
                    }
                }.padding(.vertical, 12).font(.subheadline)
            }
        }
    }
    @ViewBuilder private func row(_ title: String, value: String) -> some View {
        if !value.isEmpty { HStack(alignment: .top, spacing: 12) { Text(L(title)).foregroundStyle(app.palette.muted).frame(width: 100, alignment: .leading); Text(value).frame(maxWidth: .infinity, alignment: .leading) }.font(.subheadline).padding(.vertical, 10); SiteDivider() }
    }
}
