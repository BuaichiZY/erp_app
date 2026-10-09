import SwiftUI

/// Browse cards show server metadata; reactions on the grid are summaries, as on the website.
struct BrowseTile: View {
    @EnvironmentObject private var app: AppState
    let user: JSON
    let notes: [JSON]
    let open: () -> Void
    private var cover: JSON { user["cover"].exists ? user["cover"] : user["avatar"] }
    private var rating: String {
        switch cover["rating"].string {
        case "suggestive": return L("擦边")
        case "r18": return "R18"
        case "r18g", "r18-g": return "R18-G"
        default: return ""
        }
    }
    var body: some View {
        Button(action: open) {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(media: cover, size: 650)
                LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                if ["blur", "hide"].contains(cover["view"].string) {
                    VStack(spacing: 7) { Image(systemName: "eye.slash").font(.title); Text(rating.isEmpty ? L("内容暂不可见") : rating).font(.caption).padding(6).background(.black.opacity(0.5), in: Capsule()) }.foregroundStyle(.white.opacity(0.85)).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                VStack {
                    HStack(alignment: .top, spacing: 5) {
                        VStack(alignment: .leading, spacing: 5) {
                            if user["presence"]["state"].string == "online" { Circle().fill(.green).frame(width: 9, height: 9).overlay(Circle().stroke(.white, lineWidth: 1.5)).accessibilityLabel(L("现在在线")) }
                            if !rating.isEmpty { Text(rating).font(.system(size: 10, weight: .bold)).padding(5).background(rating == L("擦边") ? Color.orange : .red, in: RoundedRectangle(cornerRadius: 6)) }
                        }
                        Spacer(minLength: 0)
                        ViewThatFits(in: .horizontal) {
                            reactionSummary(limit: 3)
                            reactionSummary(limit: 2)
                            reactionSummary(limit: 1)
                        }
                    }.foregroundStyle(.white)
                    Spacer(minLength: 0)
                }.padding(8)
                if !notes.isEmpty { DanmakuOverlay(items: notes, compact: true).allowsHitTesting(false) }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        if user["shine"]["likes"].int > 0 { shine("heart.fill", percent: user["shine"]["likes"].int, color: .pink) }
                        if user["shine"]["superlikes"].int > 0 { shine("star.fill", percent: user["shine"]["superlikes"].int, color: .orange) }
                    }
                    HStack(spacing: 5) { Text(user["displayName"].string).font(.headline).lineLimit(1); if VRCTrust.verified(user) { Image(systemName: "checkmark.seal.fill").font(.caption).padding(.horizontal, 5).padding(.vertical, 3).background(Color(hex: VRCTrust.background(VRCTrust.key(user))), in: Capsule()).accessibilityLabel(L(VRCTrust.label(VRCTrust.key(user)))) } }
                    if !user.text("tagline").isEmpty { Text(user.text("tagline")).font(.caption).lineLimit(1) }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 7) { matches; mutualMatches }
                        VStack(alignment: .leading, spacing: 3) { matches; mutualMatches }
                    }.font(.system(size: 10))
                    HStack(spacing: 4) { ForEach(user["commonIntents"].array.prefix(2), id: \.self) { intent in Text(L(DiscoveryFacts.label(intent.string))).font(.system(size: 10, weight: .semibold)).lineLimit(1).padding(.horizontal, 6).padding(.vertical, 3).background(app.accent, in: Capsule()) } }
                }.foregroundStyle(.white).padding(11).frame(maxWidth: .infinity, alignment: .leading)
            }.aspectRatio(3.0 / 4, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 18)).siteOutline(RoundedRectangle(cornerRadius: 18))
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityElement(children: .combine)
    }
    @ViewBuilder private var matches: some View { if user["matchCount"].int > 0 { Label(L("已配对") + " \(user["matchCount"].int) " + L("人"), systemImage: "heart") } }
    @ViewBuilder private var mutualMatches: some View { if user["mutualMatches"].int > 0 { Label(L("共同配对") + " \(user["mutualMatches"].int) " + L("人"), systemImage: "person.2") } }
    private func shine(_ symbol: String, percent: Int, color: Color) -> some View { Label("\(percent)%", systemImage: symbol).font(.system(size: 10, weight: .bold)).padding(.horizontal, 5).padding(.vertical, 2).background(color, in: Capsule()).accessibilityLabel(L(symbol == "heart.fill" ? "喜欢" : "超级喜欢") + " \(percent)%") }
    private func reactionSummary(limit: Int) -> some View { HStack(spacing: 3) { ForEach(user["reactions"].array.prefix(limit), id: \.self) { reaction in Text(reaction["emoji"].string + " \(reaction["count"].int)").font(.system(size: 10, weight: .semibold)).padding(.horizontal, 5).padding(.vertical, 4).background(.black.opacity(0.6), in: Capsule()) } } }
}
