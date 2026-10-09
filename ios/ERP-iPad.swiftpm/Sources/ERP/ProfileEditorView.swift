import SwiftUI

struct ProfileEditorView: View {
    @EnvironmentObject private var app: AppState
    @State private var profile: JSON = .null
    @State private var draft: JSON = .null
    @State private var tab = 0
    @State private var busy = false
    @State private var failure = ""
    @State private var uploadPurpose: String?
    @State private var voice = false
    @State private var tags: [JSON] = []
    @State private var questions: [JSON] = []
    @State private var limitText = ""
    @State private var customPreference = ""
    @State private var customCategory = "behavior"
    @State private var customAttitude = "like"
    @State private var attitudes: JSON = .null
    @State private var search = ""
    @State private var baseQuery = ""
    @State private var bases: [JSON] = []
    @State private var worldQuery = ""
    @State private var worlds: [JSON] = []
    @State private var tonight = ""
    @State private var model: JSON = .null
    @State private var editingModel = false
    @State private var preview = false
    private let tabs = ["基本资料", "照片", "VRChat", "性别与关系", "介绍与语音", "模型衣柜", "问卷", "喜好与雷点", "成人区", "社群链接"]
    var body: some View {
        Page(title: "编辑名片") {
            if !failure.isEmpty { Text(failure); Button(L("重试")) { app.run { await load() } } }
            if draft.exists {
                HStack { Text(L("资料完整度") + " \(profile["completeness"]["score"].exists ? profile["completeness"]["score"].int : app.me["profileCompleteness"].int)%").font(.headline); Spacer(); Button { preview = true } label: { Label(L("预览"), systemImage: "eye") } }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { ForEach(tabs.indices, id: \.self) { index in
                    Button { tab = index; search = "" } label: { Text(L(tabs[index])).font(.subheadline.bold()).fixedSize().padding(12).background(tab == index ? app.accent : app.palette.secondary, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(tab == index ? .white : app.palette.text) }.buttonStyle(.plain)
                } } }
                section.disabled(busy)
            } else if failure.isEmpty { ProgressView().frame(maxWidth: .infinity) }
        }.task { await load() }
            .sheet(isPresented: Binding(get: { uploadPurpose != nil }, set: { if !$0 { uploadPurpose = nil } })) {
                if let purpose = uploadPurpose { ImageUploadView(purpose: purpose) { response in acceptUpload(response, purpose: purpose) }.environmentObject(app).sitePresentation() }
            }
            .sheet(isPresented: $voice) { VoiceRecordView(matchID: nil, purpose: "voice_card") { acceptUpload($0, purpose: "voice_card") }.environmentObject(app).sitePresentation() }
            .sheet(isPresented: $editingModel) { ProfileModelEditor(initial: model, media: profile["media"].array, tags: tags) { app.run { await load() } }.environmentObject(app).sitePresentation() }
            .sheet(isPresented: $preview) { ProfileDetailView(id: app.me.id).environmentObject(app).sitePresentation() }
    }
    @ViewBuilder private var section: some View {
        switch tab {
        case 0: basics
        case 1: photos
        case 2: vrchat
        case 3: identity
        case 4: introduction
        case 5: models
        case 6: questionnaire
        case 7: preferences
        case 8: adult
        default: links
        }
    }
    private var basics: some View {
        Panel {
            heading("基本资料", "别人在卡片上最先看到的信息。")
            field("显示名称", ["displayName"], limit: 30)
            field("一句话简介", ["tagline"], limit: 60)
            MultiChoices(title: "来意", options: [("friends", "找朋友／一起逛世界"), ("romance", "找对象（VR 恋爱）"), ("erp", "找 ERP 搭档"), ("activity", "找活动搭子"), ("creative", "找创作合作"), ("browsing", "随便看看"), ("other", "其他")], selected: selection(["intents"]))
            if draft["intents"].array.contains(.string("other")) { field("其他来意", ["intentOther"], limit: 30); translations("intent-other", title: "其他来意的多语言版本") }
            Toggle(L("NSFW 名片"), isOn: Binding(get: { draft["nsfwManual"].bool || draft["nsfwAuto"].bool }, set: { set(["nsfwManual"], .bool($0)) })).disabled(draft["nsfwAuto"].bool)
            basePicker
            translations("tagline", title: "一句话简介的多语言版本")
            tagPicker("标签", path: ["tagIds"], limit: 30)
            saveButton(["displayName", "tagline", "intents", "intentOther", "tagIds", "nsfwManual", "baseAvatarTagIds", "baseAvatarCustom"])
        }
    }
    private var photos: some View {
        VStack(spacing: 16) {
            Panel {
                heading("照片", "封面、头像、分享图和名片照片可分别设置。")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 10) {
                    ForEach([("cover", "上传封面"), ("avatar", "上传头像"), ("share_image", "上传分享图"), ("photo", "添加照片")], id: \.0) { purpose, title in
                        Button { uploadPurpose = purpose } label: { Label(L(title), systemImage: "photo.badge.plus").frame(maxWidth: .infinity, minHeight: 44).background(app.palette.secondary, in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain)
                    }
                }
                let ids = draft["photoIds"].array.map(\.string)
                ForEach(ids, id: \.self) { id in
                    HStack { RemoteImage(media: media(id)).frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10)); Spacer()
                        Button { movePhoto(id, delta: -1) } label: { Image(systemName: "arrow.up") }.disabled(ids.first == id).accessibilityLabel(L("向前移动"))
                        Button { movePhoto(id, delta: 1) } label: { Image(systemName: "arrow.down") }.disabled(ids.last == id).accessibilityLabel(L("向后移动"))
                        Button(role: .destructive) { draft = draft.replacing(at: ["photoIds"], with: .array(draft["photoIds"].array.filter { $0.string != id })) } label: { Image(systemName: "minus.circle") }.accessibilityLabel(L("从名片移除"))
                    }
                }
                saveButton(["photoIds", "coverId", "avatarId", "shareImageId"])
            }
            ResponsiveGrid(minimum: 220) {
                ForEach(profile["media"].array.filter { !$0["mime"].string.hasPrefix("audio") }) { item in
                    Panel {
                        RemoteImage(media: item).frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 12))
                        ForEach([("coverId", "设为封面"), ("avatarId", "设为头像"), ("shareImageId", "设为分享图")], id: \.0) { key, label in
                            Button { draft = draft.replacing(at: [key], with: .string(item.id)) } label: { HStack { Text(L(label)); Spacer(); if draft[key].string == item.id { Image(systemName: "checkmark") } }.frame(minHeight: 40) }.buttonStyle(.plain)
                        }
                        Button(L("加入名片照片")) { var ids = draft["photoIds"].array; if !ids.contains(.string(item.id)) { ids.append(.string(item.id)); draft = draft.replacing(at: ["photoIds"], with: .array(ids)) } }
                    }
                }
            }
        }
    }
    private var vrchat: some View {
        VStack(spacing: 16) {
            Panel {
                heading("VRChat", "帮助别人找到玩法相近的你。")
                MultiChoices(title: "平台", options: [("pcvr", "PC VR"), ("quest", "Quest"), ("mobile", "手机"), ("desktop", "桌面")], selected: selection(["vrc", "platforms"]))
                Toggle(L("全身追踪"), isOn: boolean(["vrc", "fullBodyTracking"]))
                Toggle(L("手部追踪"), isOn: boolean(["vrc", "handTracking"]))
                MultiChoices(title: "说话方式", options: [("voice", "开麦"), ("mute", "静音"), ("sign", "手语"), ("gesture", "表情／肢体语言")], selected: selection(["vrc", "speech"]))
                HStack { Text(L("开麦比例")); Spacer(); Button(L("清除")) { draft = draft.replacing(at: ["vrc", "voiceRatio"], with: .null) } }
                Slider(value: Binding(get: { Double(draft["vrc"]["voiceRatio"].int) }, set: { draft = draft.replacing(at: ["vrc", "voiceRatio"], with: .number($0.rounded())) }), in: 0...10, step: 1)
                Text(L("开麦") + " \(draft["vrc"]["voiceRatio"].int) / 10").font(.caption)
                tagPicker("模型风格", path: ["vrc", "avatarStyleTagIds"], limit: 10)
                Text(L("语言能力")).font(.headline)
                ForEach(draft["languages"].array.indices, id: \.self) { index in languageRow(index) }
                Button(L("新增语言")) { var values = draft["languages"].array; values.append(.object(["code": .string("en"), "level": .string("intermediate")])); draft = draft.replacing(at: ["languages"], with: .array(values)) }
                field("时区", ["timezone"])
                Text(L("常在线时段（当地时间）")).font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(0..<24) { hour in
                        let value = JSON.number(Double(hour)), selected = draft["activeHours"].array.contains(value)
                        Button { var hours = draft["activeHours"].array; if selected { hours.removeAll { $0 == value } } else { hours.append(value) }; draft = draft.replacing(at: ["activeHours"], with: .array(hours.sorted { $0.int < $1.int })) } label: { Text(String(format: "%02d", hour)).frame(maxWidth: .infinity, minHeight: 42).background(selected ? app.accent : app.palette.secondary, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(selected ? .white : app.palette.text) }.buttonStyle(.plain)
                    }
                }
                Text(L("喜欢的世界")).font(.headline)
                ForEach(draft["favoriteWorldIds"].array, id: \.self) { world in HStack { Text(world.string).font(.caption); Spacer(); Button(L("移除")) { draft = draft.replacing(at: ["favoriteWorldIds"], with: .array(draft["favoriteWorldIds"].array.filter { $0 != world })) } } }
                HStack { TextField(L("世界名称或 VRChat 世界链接"), text: $worldQuery).textFieldStyle(.roundedBorder); Button(L("搜索")) { searchWorlds() }.disabled(worldQuery.isEmpty) }
                ForEach(worlds) { world in Button(world["name"].string) { var ids = draft["favoriteWorldIds"].array; if !ids.contains(.string(world.id)) { ids.append(.string(world.id)); draft = draft.replacing(at: ["favoriteWorldIds"], with: .array(ids)) }; worlds = [] } }
                saveButton(["vrc", "languages", "timezone", "activeHours", "favoriteWorldIds"])
            }
            Panel {
                heading("今晚想玩", "24 小时后自动消失的状态。")
                TextField(L("你今晚的安排"), text: $tonight, axis: .vertical).lineLimit(3...5).textFieldStyle(.roundedBorder)
                HStack { Button(L("发布")) { mutation { _ = try await app.api.request("/me/tonight", method: "PUT", body: ["text": tonight]); app.message = L("已更新") } }.disabled(tonight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty); Spacer(); Button(L("清除今晚状态")) { mutation { _ = try await app.api.request("/me/tonight", method: "DELETE"); tonight = "" } } }
            }
        }
    }
    private var identity: some View {
        Panel {
            heading("性别与关系")
            MultiChoices(title: "模型性别呈现", options: [("masculine", "男性化"), ("feminine", "女性化"), ("androgynous", "中性"), ("nonhuman", "非人"), ("other", "其他")], selected: selection(["gender", "modelPresentation"]))
            picker("声音", path: ["gender", "voice"], options: [("male", "男声"), ("female", "女声"), ("neutral", "中性"), ("voice_changer", "变声器"), ("mute", "静音")])
            field("性别认同", ["gender", "identity"]); field("称呼", ["gender", "pronouns"])
            picker("关系状态", path: ["relationship"], options: [("single", "单身"), ("vrc_partner", "有 VRChat 伴侣"), ("real_partner", "有现实伴侣"), ("open", "开放关系")])
            saveButton(["gender", "relationship"])
        }
    }
    private var introduction: some View {
        Panel {
            heading("介绍与语音")
            field("自我介绍", ["bio", "text"], lines: 7, limit: 3000)
            picker("自我介绍语言", path: ["bio", "lang"], options: Self.languages)
            saveButton(["bio"])
            translations("bio", title: "介绍的多语言版本")
            if let audio = profile["media"].array.first(where: { $0.id == draft["voiceCardId"].string }) { AudioButton(media: audio); Button(L("移除语音名片")) { draft = draft.replacing(at: ["voiceCardId"], with: .null); save(["voiceCardId"]) } }
            Button { voice = true } label: { Label(L("录制或选择语音名片"), systemImage: "mic") }
        }
    }
    private var models: some View {
        VStack(spacing: 16) {
            Button(L("添加模型")) { model = .null; editingModel = true }
            if draft["models"].array.isEmpty { EmptyState(title: "尚未添加模型") }
            ForEach(draft["models"].array) { item in Panel { Text(item["name"].string).font(.headline); if let id = item["photoIds"].array.first?.string { RemoteImage(media: media(id)).frame(height: 180) }; Button(L("编辑模型")) { model = item; editingModel = true } } }
        }
    }
    private var questionnaire: some View {
        VStack(spacing: 16) {
            if questions.isEmpty { EmptyState(title: "目前没有问卷") }
            ForEach(questions.filter { $0["kind"].string != "chosen" }) { question in Panel {
                Text(question["text"].text).font(.headline)
                MultiChoices(title: "", options: question["options"].array.map { ($0.id, $0["text"].text) }, selected: Binding(get: { Set(answer(question.id)["optionIds"].array.map(\.string)) }, set: { updateAnswer(question.id, key: "optionIds", value: .array($0.sorted().map(JSON.string))) }), single: question["type"].string == "single")
            } }
            let chosen = questions.filter { $0["kind"].string == "chosen" }
            if !chosen.isEmpty { Panel {
                let limit = app.config["limits"]["chosenQuestions"].exists ? app.config["limits"]["chosenQuestions"].int : 3
                MultiChoices(title: "自选问题（最多 \(limit) 个）", options: chosen.map { ($0.id, $0["text"].text) }, selected: Binding(get: { Set(draft["answers"].array.map { $0["questionId"].string }).intersection(Set(chosen.map(\.id))) }, set: { selected in
                    var answers = draft["answers"].array.filter { item in !chosen.contains { $0.id == item["questionId"].string } || selected.contains(item["questionId"].string) }
                    for id in selected where !answers.contains(where: { $0["questionId"].string == id }) { answers.append(.object(["questionId": .string(id), "text": .string("")])) }
                    set(["answers"], .array(answers))
                }), limit: limit)
                ForEach(chosen.filter { question in draft["answers"].array.contains { $0["questionId"].string == question.id } }) { question in
                    Text(question["text"].text).font(.headline)
                    TextField(L("回答"), text: Binding(get: { answer(question.id)["text"].string }, set: { updateAnswer(question.id, key: "text", value: .string(String($0.prefix(300)))) }), axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
                }
            } }
            saveButton(["answers"])
        }
    }
    private var preferences: some View {
        Panel {
            heading("喜好与雷点", "这些偏好会影响配对推荐。")
            TextField(L("搜索标签"), text: $search).textFieldStyle(.roundedBorder)
            ForEach(filteredTags) { tag in
                VStack(alignment: .leading, spacing: 8) {
                    Text(tag["name"].text).font(.headline)
                    let saved = attitudes["items"].array.first { $0["tagId"].string == tag.id }?["attitude"].string ?? ""
                    PostPills(selection: Binding(get: { saved }, set: { value in var items = attitudes["items"].array.filter { $0["tagId"].string != tag.id }; if value != saved { items.append(.object(["tagId": .string(tag.id), "attitude": .string(value)])) }; attitudes = attitudes.replacing(at: ["items"], with: .array(items)) }), choices: [("want", "想要"), ("like", "喜欢"), ("dislike", "不喜欢"), ("dealbreaker", "雷点")], rectangular: true)
                }
            }
            Text(L("自定义偏好")).font(.headline)
            ForEach(Array(attitudes["custom"].array.enumerated()), id: \.offset) { index, item in
                HStack { Text(item["name"].string); Spacer(); Text(L(["want": "想要", "like": "喜欢", "dislike": "不喜欢", "dealbreaker": "雷点"][item["attitude"].string] ?? "")); Button(L("移除")) { var items = attitudes["custom"].array; items.remove(at: index); attitudes = attitudes.replacing(at: ["custom"], with: .array(items)) } }
            }
            TextField(L("输入自定义偏好"), text: $customPreference).textFieldStyle(.roundedBorder)
            Picker(L("分类"), selection: $customCategory) { ForEach([("behavior", "行为"), ("hobby", "兴趣"), ("personality", "个性"), ("device", "设备"), ("adult", "成人"), ("xp", "XP")], id: \.0) { value, title in Text(L(title)).tag(value) } }
            PostPills(selection: $customAttitude, choices: [("want", "想要"), ("like", "喜欢"), ("dislike", "不喜欢"), ("dealbreaker", "雷点")], rectangular: true)
            Button(L("添加偏好")) {
                let name = String(customPreference.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
                if let tag = tags.first(where: { $0["name"].text.caseInsensitiveCompare(name) == .orderedSame }) { var items = attitudes["items"].array.filter { $0["tagId"].string != tag.id }; items.append(.object(["tagId": .string(tag.id), "attitude": .string(customAttitude)])); attitudes = attitudes.replacing(at: ["items"], with: .array(items)) }
                else { var items = attitudes["custom"].array.filter { $0["name"].string.caseInsensitiveCompare(name) != .orderedSame }; items.append(.object(["name": .string(name), "category": .string(customCategory), "attitude": .string(customAttitude)])); attitudes = attitudes.replacing(at: ["custom"], with: .array(items)) }
                customPreference = ""
            }.disabled(customPreference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            field("雷点补充说明", ["dealbreakerNote"], lines: 3, limit: 300)
            Toggle(L("公开偏好"), isOn: Binding(get: { attitudes["public"].bool }, set: { attitudes = attitudes.replacing(at: ["public"], with: .bool($0)) }))
            PrimaryButton(title: "保存偏好") { mutation { _ = try await app.api.request("/me/tag-attitudes", method: "PUT", body: ["items": attitudes["items"].foundation, "custom": attitudes["custom"].array.map(\.foundation), "public": attitudes["public"].bool]); _ = try await app.api.request("/me/profile", method: "PATCH", body: ["dealbreakerNote": draft["dealbreakerNote"].string]); app.message = L("已保存") } }
        }
    }
    @ViewBuilder private var adult: some View {
        if app.me["r18ConsentAt"].string.isEmpty { Panel { Text(L("请先在官方网站完成成人内容规则确认。")); Link(L("前往官网"), destination: APIClient.origin.appendingPathComponent("settings/content")) } }
        else { Panel {
            heading("成人区")
            field("成人内容介绍", ["adult", "bio"], lines: 5, limit: 2000)
            field("安全词", ["adult", "safeword"], limit: 60)
            field("角色倾向", ["adult", "roleTendency"], limit: 60)
            Text(L("界限")).font(.headline)
            ForEach(Array(draft["adult"]["limits"].array.enumerated()), id: \.offset) { index, item in
                HStack { Text(item["item"].string); Spacer(); Picker(L("程度"), selection: Binding(get: { item["level"].string }, set: { value in var limits = draft["adult"]["limits"].array; limits[index] = item.replacing(at: ["level"], with: .string(value)); set(["adult", "limits"], .array(limits)) })) { Text(L("可以")).tag("yes"); Text(L("视情况")).tag("maybe"); Text(L("不可以")).tag("no") }; Button { var limits = draft["adult"]["limits"].array; limits.remove(at: index); set(["adult", "limits"], .array(limits)) } label: { Image(systemName: "minus.circle") }.accessibilityLabel(L("移除界限")) }
            }
            TextField(L("输入界限"), text: $limitText).textFieldStyle(.roundedBorder)
            HStack { ForEach([("yes", "可以"), ("maybe", "视情况"), ("no", "不可以")], id: \.0) { value, title in Button(L(title)) {
                let text = String(limitText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
                var limits = draft["adult"]["limits"].array.filter { $0["item"].string != text }
                var item: [String: JSON] = ["item": .string(text), "level": .string(value)]
                if let tag = tags.first(where: { ["adult", "xp"].contains($0["category"].string) && $0["name"].text.caseInsensitiveCompare(text) == .orderedSame }) { item["tagId"] = .string(tag.id) }
                limits.append(.object(item)); set(["adult", "limits"], .array(limits)); limitText = ""
            }.frame(maxWidth: .infinity, minHeight: 44) }.disabled(limitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            stringList("RP 形式", path: ["adult", "rpForms"])
            Toggle(L("OSC 触觉设备"), isOn: boolean(["adult", "oscHaptics"]))
            picker("成人资料可见性", path: ["adultVisibility"], options: [("everyone", "所有人"), ("matches", "仅配对对象")])
            saveButton(["adult", "adultVisibility"])
        } }
    }
    private var links: some View {
        Panel {
            heading("社群链接")
            ForEach(draft["socialLinks"].array.indices, id: \.self) { index in
                VStack(alignment: .leading) {
                    Picker(L("平台"), selection: arrayText("socialLinks", index, "type")) { ForEach(["x", "discord", "instagram", "youtube", "twitch", "booth", "other"], id: \.self) { Text($0).tag($0) } }
                    TextField(L("链接地址"), text: arrayText("socialLinks", index, "url")).keyboardType(.URL).textInputAutocapitalization(.never).textFieldStyle(.roundedBorder)
                    Picker(L("谁可以看到"), selection: arrayText("socialLinks", index, "visibility")) { Text(L("所有人")).tag("everyone"); Text(L("仅配对对象")).tag("matches") }
                    Button(L("移除链接"), role: .destructive) { var values = draft["socialLinks"].array; values.remove(at: index); draft = draft.replacing(at: ["socialLinks"], with: .array(values)) }
                    Divider()
                }
            }
            Button(L("添加链接")) { var values = draft["socialLinks"].array; values.append(.object(["type": .string("other"), "url": .string("https://"), "visibility": .string("everyone")])); draft = draft.replacing(at: ["socialLinks"], with: .array(values)) }
            saveButton(["socialLinks"])
        }
    }
    private var basePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("常用素体")).font(.headline)
            let selected = draft["baseAvatarTagIds"].array.map(\.string)
            ForEach(selected, id: \.self) { id in
                let name = (profile["baseAvatars"].array + bases).first { $0.id == id }?["name"].text ?? id
                HStack { Text(name); Spacer(); Button(L("移除")) { draft = draft.replacing(at: ["baseAvatarTagIds"], with: .array(selected.filter { $0 != id }.map(JSON.string))) } }
            }
            TextField(L("输入素体名称…"), text: $baseQuery).textFieldStyle(.roundedBorder)
                .task(id: baseQuery) { do { if !baseQuery.isEmpty { try await Task.sleep(nanoseconds: 180_000_000) }; let found = try await app.api.request("/tags/search?category=avatar&limit=10&q=" + APIClient.encode(baseQuery))["items"].array; if !Task.isCancelled { bases = found } } catch { if !Task.isCancelled { app.message = error.localizedDescription } } }
            ForEach(bases) { item in Button(item["name"].text) { guard selected.count + draft["baseAvatarCustom"].array.count < 10, !selected.contains(item.id) else { return }; draft = draft.replacing(at: ["baseAvatarTagIds"], with: .array((selected + [item.id]).map(JSON.string))); baseQuery = "" } }
            stringList("自制／其他素体", path: ["baseAvatarCustom"])
            Text(L("可多选，最多 10 个素体。")).font(.caption).foregroundStyle(app.palette.muted)
        }
    }
    private func translations(_ key: String, title: String) -> some View {
        DisclosureGroup(L(title)) {
            ForEach([("zh-Hant", "繁體中文"), ("ja", "日本語"), ("en", "English"), ("ko", "한국어")], id: \.0) { lang, name in
                TextTranslationEditor(title: name, language: lang, kind: key, initial: profile[key + "Translations"].array.first { $0["lang"].string == lang } ?? .null) { app.run { profile = try await app.api.request("/me/profile", fresh: true) } }
            }
        }
    }
    private var filteredTags: [JSON] { tags.filter { search.isEmpty || $0["name"].text.localizedCaseInsensitiveContains(search) } }
    private static let languages = [("zh", "中文"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어"), ("other", "其他")]
    private func heading(_ title: String, _ subtitle: String = "") -> some View { VStack(alignment: .leading, spacing: 8) { Text(L(title)).font(.title2.bold()); if !subtitle.isEmpty { Text(L(subtitle)).foregroundStyle(app.palette.muted) } } }
    private func set(_ path: [String], _ value: JSON) { draft = draft.replacing(at: path, with: value) }
    private func text(_ path: [String], limit: Int = 3000) -> Binding<String> { Binding(get: { draft.value(at: path).text }, set: { draft = draft.replacing(at: path, with: .string(String($0.prefix(limit)))) }) }
    private func boolean(_ path: [String]) -> Binding<Bool> { Binding(get: { draft.value(at: path).bool }, set: { draft = draft.replacing(at: path, with: .bool($0)) }) }
    private func selection(_ path: [String]) -> Binding<Set<String>> { Binding(get: { Set(draft.value(at: path).array.map(\.string)) }, set: { draft = draft.replacing(at: path, with: .array($0.sorted().map(JSON.string))) }) }
    private func field(_ label: String, _ path: [String], lines: Int = 1, limit: Int = 3000) -> some View { VStack(alignment: .leading, spacing: 7) { Text(L(label)).font(.subheadline.bold()); TextField(L(label), text: text(path, limit: limit), axis: lines > 1 ? .vertical : .horizontal).lineLimit(lines...max(lines, lines + 3)).textFieldStyle(.roundedBorder) } }
    private func picker(_ label: String, path: [String], options: [(String, String)]) -> some View { Picker(L(label), selection: text(path)) { Text(L("未设置")).tag(""); ForEach(options, id: \.0) { Text(L($0.1)).tag($0.0) } }.pickerStyle(.menu) }
    private func tagPicker(_ title: String, path: [String], limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L(title) + " \(draft.value(at: path).array.count)/\(limit)").font(.headline)
            TextField(L("搜索标签"), text: $search).textFieldStyle(.roundedBorder)
            MultiChoices(title: "", options: filteredTags.map { ($0.id, $0["name"].text) }, selected: selection(path), limit: limit)
        }
    }
    private func stringList(_ label: String, path: [String]) -> some View { VStack(alignment: .leading, spacing: 7) { Text(L(label)).font(.subheadline.bold()); TextField(L("用逗号分隔"), text: Binding(get: { draft.value(at: path).array.map(\.string).joined(separator: "，") }, set: { draft = draft.replacing(at: path, with: .array($0.components(separatedBy: CharacterSet(charactersIn: ",，")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.map(JSON.string))) })).textFieldStyle(.roundedBorder) } }
    private func arrayText(_ key: String, _ index: Int, _ field: String) -> Binding<String> { Binding(get: { let values = draft[key].array; return values.indices.contains(index) ? values[index][field].string : "" }, set: { value in var values = draft[key].array; guard values.indices.contains(index) else { return }; values[index] = values[index].replacing(at: [field], with: .string(value)); draft = draft.replacing(at: [key], with: .array(values)) }) }
    private func languageRow(_ index: Int) -> some View { HStack {
        Picker(L("语言"), selection: arrayText("languages", index, "code")) { ForEach(Self.languages, id: \.0) { Text(L($0.1)).tag($0.0) } }
        Picker(L("熟练度"), selection: arrayText("languages", index, "level")) { Text(L("母语")).tag("native"); Text(L("流利")).tag("fluent"); Text(L("普通")).tag("intermediate"); Text(L("初学者")).tag("beginner") }
        Button { var values = draft["languages"].array; values.remove(at: index); draft = draft.replacing(at: ["languages"], with: .array(values)) } label: { Image(systemName: "minus.circle") }.accessibilityLabel(L("移除语言"))
    } }
    private func media(_ id: String) -> JSON { profile["media"].array.first { $0.id == id } ?? .null }
    private func movePhoto(_ id: String, delta: Int) { var ids = draft["photoIds"].array; guard let index = ids.firstIndex(of: .string(id)), ids.indices.contains(index + delta) else { return }; ids.swapAt(index, index + delta); draft = draft.replacing(at: ["photoIds"], with: .array(ids)) }
    private func answer(_ id: String) -> JSON { draft["answers"].array.first { $0["questionId"].string == id } ?? .object(["questionId": .string(id)]) }
    private func updateAnswer(_ id: String, key: String, value: JSON) { var values = draft["answers"].array.filter { $0["questionId"].string != id }; values.append(answer(id).replacing(at: [key], with: value)); draft = draft.replacing(at: ["answers"], with: .array(values)) }
    private func saveButton(_ keys: [String]) -> some View { PrimaryButton(title: busy ? "保存中…" : "储存") { save(keys) }.disabled(busy) }
    private func save(_ keys: [String]) {
        if keys.contains("displayName"), draft["displayName"].string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { app.message = L("请填写昵称"); return }
        if keys.contains("intents"), draft["intents"].array.contains(.string("other")), draft.text("intentOther").trimmingCharacters(in: .whitespaces).isEmpty { app.message = L("请填写其他交友意向"); return }
        if keys.contains("socialLinks"), draft["socialLinks"].array.contains(where: { URL(string: $0["url"].string)?.scheme != "https" || URL(string: $0["url"].string)?.host == nil }) { app.message = L("请填写有效的 HTTPS 链接"); return }
        if keys.contains("baseAvatarCustom"), draft["baseAvatarTagIds"].array.count + draft["baseAvatarCustom"].array.count > 10 { app.message = L("最多 10 个素体"); return }
        if keys.contains("answers") { draft = draft.replacing(at: ["answers"], with: .array(draft["answers"].array.filter { !$0["optionIds"].array.isEmpty || !$0["text"].string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })) }
        let payload = Dictionary(uniqueKeysWithValues: keys.map { ($0, draft[$0].foundation) })
        mutation { _ = try await app.api.request("/me/profile", method: "PATCH", body: payload); profile = try await app.api.request("/me/profile", fresh: true); await app.reloadSession(); app.message = L("名片已保存") }
    }
    private func mutation(_ action: @escaping () async throws -> Void) { guard !busy else { return }; busy = true; app.run { defer { busy = false }; try await action() } }
    private func acceptUpload(_ response: JSON, purpose: String) {
        let item = response["media"].exists ? response["media"] : response
        guard !item.id.isEmpty else { app.message = L("上传未返回可用的附件"); return }
        if purpose == "photo" { var ids = draft["photoIds"].array; ids.append(.string(item.id)); draft = draft.replacing(at: ["photoIds"], with: .array(ids)); save(["photoIds"]) }
        else { let key = purpose == "share_image" ? "shareImageId" : purpose == "voice_card" ? "voiceCardId" : purpose + "Id"; draft = draft.replacing(at: [key], with: .string(item.id)); save([key]) }
    }
    private func searchWorlds() { app.run {
        let query = worldQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = URL(string: query)?.lastPathComponent ?? query
        if id.hasPrefix("wrld_") { worlds = [try await app.api.request("/worlds/" + APIClient.encode(id))] }
        else { worlds = try await app.api.request("/worlds/search?q=" + APIClient.encode(query))["items"].array }
    } }
    private func load() async {
        do {
            let value = try await app.api.request("/me/profile", fresh: true); try Task.checkCancellation()
            profile = value; draft = value; failure = ""
            draft = draft.replacing(at: ["baseAvatarTagIds"], with: .array(value["baseAvatarTagIds"].exists ? value["baseAvatarTagIds"].array : value["baseAvatars"].array.map { .string($0.id) }))
            for key in ["displayName", "tagline", "intentOther"] { draft = draft.replacing(at: [key], with: .string(value.text(key))) }
            for key in ["intents", "tagIds", "baseAvatarCustom", "photoIds", "languages", "answers", "socialLinks", "favoriteWorldIds", "activeHours"] { if !draft[key].exists { draft = draft.replacing(at: [key], with: .array([])) } }
            if !draft["bio"]["lang"].exists { draft = draft.replacing(at: ["bio"], with: .object(["text": .string(value.text("bio")), "lang": .string("zh")])) }
            tonight = value["tonight"].text
            tags = try await app.api.request("/tags")["items"].array
            questions = try await app.api.request("/questions")["items"].array
            attitudes = try await app.api.request("/me/tag-attitudes")
        } catch { if !Task.isCancelled { failure = error.localizedDescription } }
    }
}

struct MultiChoices: View {
    @EnvironmentObject private var app: AppState
    let title: String
    let options: [(String, String)]
    @Binding var selected: Set<String>
    var limit = Int.max
    var single = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty { Text(L(title)).font(.headline) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], spacing: 8) {
                ForEach(options, id: \.0) { value, label in
                    Button { if selected.contains(value) { selected.remove(value) } else if single { selected = [value] } else if selected.count < limit { selected.insert(value) } } label: {
                        HStack(spacing: 5) { if selected.contains(value) { Image(systemName: "checkmark") }; Text(L(label)).font(.subheadline).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity, minHeight: 44).padding(.horizontal, 8).background(selected.contains(value) ? app.accent : app.palette.secondary, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(selected.contains(value) ? .white : app.palette.text).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityAddTraits(selected.contains(value) ? .isSelected : [])
                }
            }
        }
    }
}

struct ProfileModelEditor: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let initial: JSON
    let media: [JSON]
    var tags: [JSON] = []
    let saved: () -> Void
    @State private var draft: JSON = .null
    @State private var uploading = false
    @State private var confirmingDelete = false
    @State private var busy = false
    var body: some View {
        Page(title: "模型衣柜") {
            TextField(L("模型名称"), text: binding("name")).textFieldStyle(.roundedBorder)
            Picker(L("分级"), selection: binding("rating")) { Text(L("全年龄")).tag("general"); Text(L("擦边")).tag("suggestive"); Text("R18").tag("r18") }
            Toggle(L("主模型"), isOn: Binding(get: { draft["isPrimary"].bool }, set: { draft = draft.replacing(at: ["isPrimary"], with: .bool($0)) }))
            MultiChoices(title: "照片", options: media.filter { !$0["mime"].string.hasPrefix("audio") }.enumerated().map { ($0.element.id, L("照片") + " \($0.offset + 1)") }, selected: Binding(get: { Set(draft["photoIds"].array.map(\.string)) }, set: { draft = draft.replacing(at: ["photoIds"], with: .array($0.sorted().map(JSON.string))) }))
            MultiChoices(title: "模型风格", options: tags.filter { $0["category"].string == "avatar_style" }.map { ($0.id, $0["name"].text) }, selected: Binding(get: { Set(draft["styleTagIds"].array.map(\.string)) }, set: { draft = draft.replacing(at: ["styleTagIds"], with: .array($0.sorted().map(JSON.string))) }), limit: 10)
            Button(L("上传模型照片")) { uploading = true }
            TextField(L("来源链接（用逗号分隔）"), text: Binding(get: { draft["sourceUrls"].array.map(\.string).joined(separator: ",") }, set: { draft = draft.replacing(at: ["sourceUrls"], with: .array($0.split(separator: ",").map { .string($0.trimmingCharacters(in: .whitespaces)) })) })).textFieldStyle(.roundedBorder)
            PrimaryButton(title: "储存") { busy = true; app.run { defer { busy = false }; let body = draft.object.filter { ["name", "rating", "photoIds", "styleTagIds", "sourceUrls", "isPrimary"].contains($0.key) }.mapValues(\.foundation); _ = try await app.api.request(initial.id.isEmpty ? "/me/profile/models" : "/me/profile/models/" + APIClient.encode(initial.id), method: initial.id.isEmpty ? "POST" : "PATCH", body: body); saved(); dismiss() } }.disabled(busy || draft["name"].string.trimmingCharacters(in: .whitespaces).isEmpty || draft["photoIds"].array.isEmpty)
            if !initial.id.isEmpty { Button(L("删除模型"), role: .destructive) { confirmingDelete = true } }
        }.onAppear { draft = initial.exists ? initial : .object(["name": .string(""), "rating": .string("general"), "photoIds": .array([]), "styleTagIds": .array([]), "sourceUrls": .array([]), "isPrimary": .bool(false)]) }
            .sheet(isPresented: $uploading) { ImageUploadView(purpose: "model") { response in let item = response["media"].exists ? response["media"] : response; if !item.id.isEmpty { var ids = draft["photoIds"].array; ids.append(.string(item.id)); draft = draft.replacing(at: ["photoIds"], with: .array(ids)) } }.environmentObject(app).sitePresentation() }
            .confirmationDialog(L("删除这个模型？"), isPresented: $confirmingDelete) { Button(L("删除"), role: .destructive) { app.run { _ = try await app.api.request("/me/profile/models/" + APIClient.encode(initial.id), method: "DELETE"); saved(); dismiss() } } }
    }
    private func binding(_ key: String) -> Binding<String> { Binding(get: { draft[key].string }, set: { draft = draft.replacing(at: [key], with: .string($0)) }) }
}

struct VRCView: View {
    @EnvironmentObject private var app: AppState
    @State private var data: JSON = .null
    @State private var user = ""
    @State private var lightText: [String: String] = [:]
    @State private var translations: [JSON] = []
    @State private var unbinding = false
    @State private var failure = ""
    private let lights = [("blue", "蓝灯 · Join Me"), ("green", "绿灯 · 在线"), ("orange", "橙灯 · Ask Me"), ("red", "红灯 · 请勿打扰")]
    var body: some View {
        Page(title: "VRChat 绑定与隐私") {
            Text(L("验证你的 VRChat 帐号，也可以分享在线状态。")).foregroundStyle(app.palette.muted)
            if !failure.isEmpty { Text(failure); Button(L("重试")) { app.run { await load() } } }
            if data.exists {
                Panel {
                    if data["state"].string == "bound" {
                        Text(L("已绑定的账号")).font(.headline)
                        Label(data["vrcDisplayName"].string.isEmpty ? data["vrcUserId"].string : data["vrcDisplayName"].string, systemImage: "checkmark.seal.fill")
                        Text(L("信任等级") + " · " + L(VRCTrust.label(data["trust"].string)))
                        Button(L("更新信任等级")) { request("/me/vrc/trust", "POST") }
                        if data["trustUpdate"].string == "pending" { Text(L("信任等级正在更新…")) }
                        Button(L("解除绑定"), role: .destructive) { unbinding = true }
                    } else if data["state"].string == "pending" {
                        Text(L("等待验证")).font(.headline)
                        Text(data["code"].string).font(.title.bold()).textSelection(.enabled)
                        Text(L("请将验证码放到 VRChat 个人简介，然后检查绑定状态。"))
                        Button(L("检查绑定状态")) { request("/me/vrc/check", "POST") }
                        Button(L("取消绑定")) { unbinding = true }
                    } else {
                        Text(L("绑定 VRChat 账号")).font(.headline)
                        TextField(L("VRChat 用户名或用户链接"), text: $user).textInputAutocapitalization(.never).textFieldStyle(.roundedBorder)
                        PrimaryButton(title: "开始绑定") { app.run { _ = try await app.api.request("/me/vrc/bind", method: "POST", body: ["vrcUser": user.trimmingCharacters(in: .whitespacesAndNewlines)]); await load() } }.disabled(user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (data["presenceAvailable"].exists && !data["presenceAvailable"].bool))
                    }
                }
                if data["state"].string == "bound" {
                    Panel {
                        Text(L("分享在线状态（选用）")).font(.headline)
                        if data["presence"].string == "on" { Text(L("正在分享在线状态")); Button(L("停止分享")) { request("/me/vrc/presence", "DELETE") } }
                        else if ["pending", "rebind"].contains(data["presence"].string) { Text(L("请在 VRChat 添加以下机器人为好友，然后检查状态。")); Text(data["bot"]["displayName"].string); Button(L("检查绑定状态")) { request("/me/vrc/check", "POST") }; Button(L("取消分享")) { request("/me/vrc/presence", "DELETE") } }
                        else { Text(L("加我们的机器人为好友，别人就能看到你是否在线。随时可以停止。")); Button(L("开始分享")) { request("/me/vrc/presence", "POST") }.disabled(data["presenceAvailable"].exists && !data["presenceAvailable"].bool) }
                    }
                    Panel {
                        Text(L("个人主页与在线状态隐私")).font(.headline)
                        visibility("account", "谁可以看到 VRChat 账号", publicAllowed: true)
                        visibility("online", "在线／离线", publicAllowed: true)
                        visibility("world", "所在世界名称", publicAllowed: false)
                        visibility("instance", "可加入的房间", publicAllowed: false)
                        Text(L("在私人房间时显示为「私人房间」。")).font(.caption).foregroundStyle(app.palette.muted)
                    }
                    Panel {
                        Text(L("灯牌说明")).font(.headline)
                        ForEach(lights, id: \.0) { light in TextField(L(light.1), text: Binding(get: { lightText[light.0] ?? "" }, set: { lightText[light.0] = String($0.prefix(60)) })).textFieldStyle(.roundedBorder) }
                        PrimaryButton(title: "储存") { app.run { _ = try await app.api.request("/me/profile", method: "PATCH", body: ["statusLights": lightText.filter { !$0.value.isEmpty }]); await load() } }
                        ForEach([("zh-Hant", "繁體中文"), ("ja", "日本語"), ("en", "English"), ("ko", "한국어")], id: \.0) { lang, name in
                            DisclosureGroup(name) { LightTranslationEditor(language: lang, initial: translations.first { $0["lang"].string == lang } ?? .null) { app.run { await load() } } }
                        }
                    }
                }
            } else if failure.isEmpty { ProgressView().frame(maxWidth: .infinity) }
        }.task { await load() }.refreshable { await load() }
            .confirmationDialog(L("解除 VRChat 账号绑定？"), isPresented: $unbinding) { Button(L("解除绑定"), role: .destructive) { request("/me/vrc", "DELETE") } }
    }
    private func visibility(_ key: String, _ title: String, publicAllowed: Bool) -> some View {
        Picker(L(title), selection: Binding(get: { data["privacy"][key].string.isEmpty ? publicAllowed ? "everyone" : "matches" : data["privacy"][key].string }, set: { value in app.run { _ = try await app.api.request("/me/vrc/privacy", method: "PATCH", body: [key: value]); await load() } })) { if publicAllowed { Text(L("所有人")).tag("everyone") }; Text(L("仅配对对象")).tag("matches"); Text(L("不显示")).tag("nobody") }.pickerStyle(.menu)
    }
    private func request(_ path: String, _ method: String) { app.run { _ = try await app.api.request(path, method: method, body: method == "POST" ? [:] : nil); await load() } }
    private func load() async { do { let value = try await app.api.request("/me/vrc", fresh: true); let profile = try await app.api.request("/me/profile", fresh: true); try Task.checkCancellation(); data = value; for light in lights { lightText[light.0] = profile["statusLights"][light.0].string }; translations = profile["statusLightTranslations"].array; failure = "" } catch { if !Task.isCancelled { failure = error.localizedDescription } } }
}

private struct LightTranslationEditor: View {
    @EnvironmentObject private var app: AppState
    let language: String
    let initial: JSON
    let saved: () -> Void
    @State private var values: [String: String] = [:]
    var body: some View {
        VStack(spacing: 12) {
            ForEach([("blue", "蓝灯"), ("green", "绿灯"), ("orange", "橙灯"), ("red", "红灯")], id: \.0) { key, label in TextField(L(label), text: Binding(get: { values[key] ?? "" }, set: { values[key] = String($0.prefix(60)) })).textFieldStyle(.roundedBorder) }
            Button(L("储存翻译")) { app.run { _ = try await app.api.request("/me/profile/status-light-translations/" + language, method: "PUT", body: ["texts": values.filter { !$0.value.isEmpty }]); saved() } }.disabled(values.values.allSatisfy { $0.isEmpty })
            if initial["source"].string == "manual" { Button(L("使用 AI 翻译")) { app.run { _ = try await app.api.request("/me/profile/status-light-translations/" + language, method: "DELETE"); saved() } } }
        }.onAppear { values = initial["texts"].object.mapValues(\.string) }
    }
}

private struct TextTranslationEditor: View {
    @EnvironmentObject private var app: AppState
    let title: String, language: String, kind: String
    let initial: JSON
    let saved: () -> Void
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            TextField(title, text: $text, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
            HStack { Button(L("储存翻译")) { app.run { _ = try await app.api.request("/me/profile/" + kind + "-translations/" + language, method: "PUT", body: ["text": text]); saved() } }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty); Spacer(); if initial["source"].string == "manual" { Button(L("使用 AI 翻译")) { app.run { _ = try await app.api.request("/me/profile/" + kind + "-translations/" + language, method: "DELETE"); saved() } } } }
        }.padding(.vertical, 8).onAppear { text = initial["text"].text }
    }
}
