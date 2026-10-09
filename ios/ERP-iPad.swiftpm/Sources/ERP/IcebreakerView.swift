import SwiftUI

struct IcebreakerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let matchID: String
    let peerName: String
    let canAct: Bool
    let onPick: (String) -> Void
    @State private var ice: JSON = .null
    @State private var tab = "common"
    @State private var busy = false
    @State private var failure: String?
    @State private var answers: [String: Set<String>] = [:]
    @State private var wishes: Set<String> = []
    private var path: String { "/matches/" + APIClient.encode(matchID) + "/icebreaker" }
    private var tabs: [(String, String)] {
        [("common", "共同点"), ("dealbreakers", "TA 的雷点"), ("quiz", "双盲问答")] + (ice["adult"]["available"].bool ? [("adult", "成人区")] : [])
    }
    var body: some View {
        NavigationStack {
            Page(title: "") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tabs, id: \.0) { item in
                            Button(L(item.1)) { tab = item.0 }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(tab == item.0 ? app.accent.opacity(0.15) : app.palette.surface, in: Capsule())
                                .foregroundStyle(tab == item.0 ? app.accent : .primary)
                                .accessibilityAddTraits(tab == item.0 ? .isSelected : [])
                        }
                    }
                }
                if let failure { Text(failure).foregroundStyle(.secondary); Button(L("重试")) { app.run { try await load() } } }
                if !ice.exists && failure == nil { ProgressView().frame(maxWidth: .infinity) }
                else if ice.exists {
                    switch tab {
                    case "dealbreakers": dealbreakers
                    case "quiz": quiz
                    case "adult": adult
                    default: common
                    }
                }
            }.navigationTitle(L("✧ 破冰")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L("关闭")) { dismiss() } } }
                .task { do { try await load() } catch { failure = error.localizedDescription } }
                .refreshable { do { try await load() } catch { failure = error.localizedDescription } }
                .onChange(of: app.eventSerial) { _ in if !busy { app.run { try await load() } } }
        }
    }

    @ViewBuilder private var common: some View {
        let value = ice["common"]
        let keys = ["intents", "tags", "likes", "worlds", "baseAvatars", "baseAvatarCustom", "models", "languages", "sameAnswers", "peerAnswers", "overlapHours"]
        if !keys.contains(where: { !value[$0].array.isEmpty || !value[$0].string.isEmpty }) { EmptyState(title: "还没有找到共同点，试试双盲问答吧。") }
        else {
            Text(L("点一下，开场白会放进输入框。")).foregroundStyle(.secondary)
            questionList("问卷选了一样的", values: value["sameAnswers"].array, same: true)
            topics("共同来意", values: value["intents"].array, kind: "intent")
            topics("相同素体", values: value["baseAvatars"].array + value["baseAvatarCustom"].array, kind: "avatar")
            topics("同款模型", values: value["models"].array, kind: "model")
            topics("都喜欢的世界", values: value["worlds"].array, kind: "world")
            topics("都喜欢", values: value["likes"].array, kind: "like")
            topics("共同标签", values: value["tags"].array, kind: "tag")
            let hours = value["overlapHours"].array.isEmpty ? value["overlapHours"].string : IcebreakerRules.hours(value["overlapHours"].array.map(\.int))
            if !hours.isEmpty { Panel { Text(L("都常在线（你的时间）")).font(.headline); chip(hours) { pick("hours", name: hours) } } }
            topics("都会的语言", values: value["languages"].array, kind: "language", clickable: false)
            questionList("TA 的问卷", values: value["peerAnswers"].array, same: false)
        }
    }
    @ViewBuilder private var dealbreakers: some View {
        let value = ice["dealbreakers"]
        if ["hits", "tags", "dislikes", "limitsNo"].allSatisfy({ value[$0].array.isEmpty }) && value["note"].string.isEmpty && value["safeword"].string.isEmpty { EmptyState(title: "TA 没有写雷点。") }
        else {
            topics("你的名片有 TA 的雷点", values: value["hits"].array, clickable: false)
            topics("雷点", values: value["tags"].array, clickable: false)
            if !value["note"].string.isEmpty { Panel { Text(L("备注")).font(.headline); Text(value["note"].string) } }
            topics("不喜欢", values: value["dislikes"].array, clickable: false)
            topics("底线（不行）", values: value["limitsNo"].array, clickable: false)
            if !value["safeword"].string.isEmpty { Panel { Text(L("安全词")).font(.headline); Text(value["safeword"].string) } }
        }
    }
    private var adult: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(L("成人区"), isOn: Binding(get: { ice["adult"]["on"].bool }, set: { act("PUT", suffix: "/adult", payload: ["on": $0]) })).disabled(busy || !canAct)
            Text(L("开启后会显示双方共同的 R18 喜好，双盲问答也会加入成人题目。")).foregroundStyle(.secondary)
            if ice["adult"]["on"].bool {
                if ice["adult"]["likes"].array.isEmpty { EmptyState(title: "目前没有共同的 R18 喜好。") }
                else { topics("共同的 R18 喜好", values: ice["adult"]["likes"].array, kind: "adult") }
            }
        }
    }
    private var quiz: some View {
        VStack(alignment: .leading, spacing: 16) {
            let open = ice["quiz"]["open"], last = ice["quiz"]["last"]
            if !open.id.isEmpty {
                if open["myDone"].bool {
                    Text(L("你交卷了，等待对方作答。"))
                    if open["startedByMe"].bool { Button(L("取消这一轮"), role: .destructive) { act("DELETE", suffix: "/rounds/" + APIClient.encode(open.id)) }.disabled(busy) }
                } else if canAct { answerRound(open) }
                else { Text(L("现在无法作答。")) }
            } else {
                Text(L("双方都交卷后，答案会同时揭晓。"))
                PrimaryButton(title: last.id.isEmpty ? "开始一轮" : "再来一轮") { act("POST", suffix: "/rounds", payload: [:]) }.disabled(busy || !canAct)
            }
            if !last.id.isEmpty {
                results(last).task(id: last.id) {
                    if !last["seen"].bool { _ = try? await app.api.request(path + "/rounds/" + APIClient.encode(last.id) + "/seen", method: "POST", body: [:]) }
                }
            }
        }
    }
    private func answerRound(_ round: JSON) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !round["startedByMe"].bool { Text(peerName + L(" 邀请你一起答题")) }
            ForEach(round["questions"].array) { question in
                Panel {
                    Text(question["text"].string + (question["rating"].string == "r18" ? " · R18" : "")).font(.headline)
                    ForEach(question["options"].array) { option in
                        Button {
                            var selected = answers[question.id] ?? []
                            if question["type"].string == "single" { selected = [option.id] }
                            else if !selected.insert(option.id).inserted { selected.remove(option.id) }
                            answers[question.id] = selected
                        } label: {
                            HStack { Image(systemName: (answers[question.id] ?? []).contains(option.id) ? "checkmark.circle.fill" : "circle"); Text(option["text"].string).frame(maxWidth: .infinity, alignment: .leading) }.padding(.vertical, 8)
                        }.buttonStyle(.plain).foregroundStyle(.primary).disabled(busy)
                    }
                }
            }
            if !round["wish"]["candidates"].array.isEmpty {
                Panel {
                    Text(L("想和对方一起试的")).font(.headline)
                    Text(L("只有双方都选中的项目才会揭晓。")).font(.subheadline).foregroundStyle(.secondary)
                    ForEach(Array(round["wish"]["candidates"].array.enumerated()), id: \.offset) { _, option in
                        let key = option["key"].string, maximum = round["wish"]["max"].int
                        Toggle(option["name"].string, isOn: Binding(get: { wishes.contains(key) }, set: { if $0 { wishes.insert(key) } else { wishes.remove(key) } }))
                            .disabled(busy || key.isEmpty || (!wishes.contains(key) && maximum > 0 && wishes.count >= maximum))
                    }
                }
            }
            Text(L("交卷后不能修改。")).foregroundStyle(.secondary)
            PrimaryButton(title: "交卷") {
                var payload: [String: Any] = ["answers": answers.mapValues { $0.sorted() }]
                if !round["wish"]["candidates"].array.isEmpty { payload["wishes"] = wishes.sorted() }
                act("PUT", suffix: "/rounds/" + APIClient.encode(round.id) + "/answers", payload: payload)
            }.disabled(busy || !IcebreakerRules.complete(round["questions"].array, answers: answers))
        }
    }
    private func results(_ round: JSON) -> some View {
        Panel {
            Text(L("揭晓结果")).font(.title2.bold())
            ForEach(round["questions"].array) { question in
                VStack(alignment: .leading, spacing: 8) {
                    Text(question["text"].string).font(.headline)
                    Text(L("我") + "：" + answerText(question, ids: round["mine"][question.id].array))
                    Text(peerName + "：" + answerText(question, ids: round["peer"][question.id].array))
                }
            }
            topics("你们都想试的", values: round["wish"]["mutual"].array, clickable: false)
        }
    }
    @ViewBuilder private func topics(_ title: String, values: [JSON], kind: String = "", clickable: Bool = true) -> some View {
        if !values.isEmpty {
            Panel {
                Text(L(title)).font(.headline)
                WrappingLayout(spacing: 8) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        let name = label(value, kind: kind)
                        if clickable { chip(name) { pick(kind, name: name) } }
                        else { Text(name).font(.subheadline).padding(.horizontal, 12).padding(.vertical, 8).background(app.palette.secondary, in: Capsule()) }
                    }
                }
            }
        }
    }
    @ViewBuilder private func questionList(_ title: String, values: [JSON], same: Bool) -> some View {
        if !values.isEmpty {
            Panel {
                Text(L(title)).font(.headline)
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Button { pick(same ? "same" : "peer", name: value["answer"].string, question: value["question"].string) } label: {
                        VStack(alignment: .leading, spacing: 6) { Text(value["question"].string).font(.caption).foregroundStyle(.secondary); Text(value["answer"].string).font(.headline) }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(app.palette.secondary, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).disabled(!canAct)
                }
            }
        }
    }
    private func chip(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(name).font(.subheadline).padding(.horizontal, 12).padding(.vertical, 8).background(app.palette.secondary, in: Capsule()) }.buttonStyle(.plain).disabled(!canAct)
    }
    private func label(_ value: JSON, kind: String) -> String {
        let name = value["name"].string.isEmpty ? value.string : value["name"].string
        if kind == "intent" { return L(["friends": "交朋友", "romance": "恋爱", "erp": "成人互动", "activity": "一起玩", "creative": "创作", "browsing": "随便看看", "other": "其他"][name] ?? name) }
        if kind == "language" { return L(["zh": "中文", "ja": "日文", "en": "英文", "ko": "韩文"][name] ?? name) }
        return name
    }
    private func answerText(_ question: JSON, ids: [JSON]) -> String {
        let selected = Set(ids.map(\.string))
        return question["options"].array.filter { selected.contains($0.id) }.map { $0["text"].string }.joined(separator: "、")
    }
    private func pick(_ kind: String, name: String, question: String = "") {
        guard canAct else { return }
        let templates = ["same": "「{{question}}」我们都选了「{{answer}}」！", "peer": "看到你在「{{question}}」回答「{{answer}}」，可以多说一点吗？", "intent": "我们的来意都有「{{name}}」，你最想遇到什么样的人？", "tag": "看到你也有「{{name}}」，想多听你聊聊！", "like": "你也喜欢{{name}}吗？", "world": "你也喜欢「{{name}}」吗？要不要一起去？", "avatar": "你也在用{{name}}吗？", "model": "我们用的是同款模型「{{name}}」耶！", "hours": "我们都常在 {{hours}} 上线，要不要约那时候见？", "adult": "看到我们都对{{name}}有兴趣，想听听你的想法～"]
        guard let template = templates[kind] else { return }
        let opener = L(template).replacingOccurrences(of: "{{question}}", with: question).replacingOccurrences(of: "{{answer}}", with: name).replacingOccurrences(of: "{{name}}", with: name).replacingOccurrences(of: "{{hours}}", with: name)
        onPick(opener); dismiss()
    }
    private func load() async throws { let value = try await app.api.request(path, fresh: true); apply(value); failure = nil }
    private func apply(_ value: JSON) {
        if value["quiz"]["open"].id != ice["quiz"]["open"].id { answers = [:]; wishes = [] }
        ice = value
        if tab == "adult" && !value["adult"]["available"].bool { tab = "common" }
    }
    private func act(_ method: String, suffix: String, payload: [String: Any]? = nil) {
        guard !busy, canAct || method == "DELETE" else { return }
        busy = true
        app.run {
            defer { busy = false }
            let value = try await app.api.request(path + suffix, method: method, body: payload)
            if value["quiz"].exists || value["common"].exists || value["adult"].exists { apply(value) }
            else { try await load() }
        }
    }
}
