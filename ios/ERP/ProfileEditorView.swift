import SwiftUI

struct ProfileEditorView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var profile: JSON = .null
    @State private var name = "", tagline = "", bio = "", tonight = ""
    @State private var platform = "pcvr", language = "zh", busy = false, picking = false
    @State private var photos: [JSON] = []
    var body: some View {
        Page(title: "编辑名片") {
            Panel {
                Text(L("基本信息")).font(.title2.bold())
                TextField(L("昵称"), text: $name).textFieldStyle(.roundedBorder)
                TextField(L("一句话介绍"), text: $tagline).textFieldStyle(.roundedBorder)
                TextField(L("自我介绍"), text: $bio, axis: .vertical).lineLimit(4...8).textFieldStyle(.roundedBorder)
                TextField(L("现在想做什么"), text: $tonight).textFieldStyle(.roundedBorder)
                PrimaryButton(title: busy ? "保存中…" : "保存名片") { save() }.disabled(busy || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Panel {
                Text(L("照片")).font(.title2.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 12) { ForEach(photos) { media in RemoteImage(media: media).frame(height: 140).clipShape(RoundedRectangle(cornerRadius: 12)) } }
                Button { picking = true } label: { Label(L("添加照片"), systemImage: "photo.badge.plus") }
            }
            Panel {
                Text(L("平台与语言")).font(.title2.bold())
                Picker(L("平台"), selection: $platform) { Text("PC VR").tag("pcvr"); Text("Quest").tag("quest"); Text(L("手机")).tag("mobile"); Text(L("桌面")).tag("desktop") }
                Picker(L("语言"), selection: $language) { Text(L("中文")).tag("zh"); Text("English").tag("en"); Text(L("日文")).tag("ja"); Text(L("韩文")).tag("ko") }
                Button(L("保存偏好")) { app.run { _ = try await app.api.request("/me/profile", method: "PATCH", body: ["platforms": [platform], "languages": [language]]); await load() } }
            }
        }.task { await load() }
            .sheet(isPresented: $picking) { ImageUploadView(purpose: "profile") { media in let value = media["media"].exists ? media["media"] : media; if !value.id.isEmpty { photos.append(value); app.run { _ = try await app.api.request("/me/profile", method: "PATCH", body: ["photoIds": photos.map(\.id)]); await load() } } }.environmentObject(app) }
    }
    private func load() async { do { profile = try await app.api.request("/me/profile", fresh: true); name = profile["displayName"].string; tagline = profile.text("tagline"); bio = profile.text("bio"); tonight = profile["tonight"].string; photos = profile["photos"].array; platform = profile["platforms"].array.first?.string ?? "pcvr"; language = profile["languages"].array.first?.string ?? "zh" } catch { app.message = error.localizedDescription } }
    private func save() { busy = true; app.run { defer { busy = false }; _ = try await app.api.request("/me/profile", method: "PATCH", body: ["displayName": name, "tagline": tagline, "bio": bio]); if !tonight.isEmpty { _ = try await app.api.request("/me/tonight", method: "PUT", body: ["text": tonight]) }; await app.reloadSession(); dismiss() } }
}

struct VRCView: View {
    @EnvironmentObject private var app: AppState
    @State private var data: JSON = .null
    @State private var user = "", saving = false
    private let lights = [("blue", "蓝灯"), ("green", "绿灯"), ("orange", "橙灯"), ("red", "红灯")]
    @State private var lightText: [String: String] = [:]
    var body: some View {
        Page(title: "VRC 账号") {
            Text(L("验证你的 VRChat 帐号，也可以分享在线状态。")).foregroundStyle(.secondary)
            Panel {
                Text(L("已绑定的帐号")).font(.headline)
                if data["bound"].bool || data["state"].string == "bound" {
                    HStack { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green); Text(data["displayName"].string) }
                    Text(L("信任等级") + " " + data["trust"].string)
                    HStack { Button(L("刷新")) { app.run { _ = try await app.api.request("/me/vrc/check", method: "POST", body: [:]); await load() } }; Spacer(); Button(L("解除绑定"), role: .destructive) { app.run { _ = try await app.api.request("/me/vrc", method: "DELETE"); await load() } } }
                } else {
                    TextField(L("VRChat 用户 ID"), text: $user).textFieldStyle(.roundedBorder)
                    PrimaryButton(title: "开始绑定") { app.run { _ = try await app.api.request("/me/vrc/bind", method: "POST", body: ["vrcUser": user]); await load() } }.disabled(user.isEmpty)
                    if !data["code"].string.isEmpty { Text(data["code"].string).font(.title.bold()).textSelection(.enabled) }
                }
            }
            Panel {
                Text(L("分享在线状态（选用）")).font(.headline)
                Text(L("加我们的机器为好友，别人就能看到你是否在线。"))
                Button(L(data["presenceEnabled"].bool ? "停止分享" : "开始分享")) { app.run { _ = try await app.api.request("/me/vrc/presence", method: data["presenceEnabled"].bool ? "DELETE" : "POST", body: data["presenceEnabled"].bool ? nil : [:]); await load() } }
            }
            Panel {
                Text(L("个人主页上的 VRChat 状态")).font(.headline)
                ForEach([("whoCanSee", "谁可以看到"), ("online", "在线／离线"), ("world", "所在世界名称"), ("joinable", "可加入的房间")], id: \.0) { option in
                    Text(L(option.1)).font(.subheadline)
                    Picker(L(option.1), selection: Binding(get: { data["privacy"][option.0].string }, set: { value in app.run { _ = try await app.api.request("/me/vrc/privacy", method: "PATCH", body: [option.0: value]); await load() } })) { Text(L("不显示")).tag("none"); Text(L("仅配对对象")).tag("matches"); Text(L("所有人")).tag("everyone") }.pickerStyle(.menu)
                }
            }
            Panel {
                Text(L("灯牌说明")).font(.headline)
                ForEach(lights, id: \.0) { light in TextField(L(light.1), text: Binding(get: { lightText[light.0] ?? "" }, set: { lightText[light.0] = $0 })).textFieldStyle(.roundedBorder) }
                PrimaryButton(title: "储存") { app.run { _ = try await app.api.request("/me/profile", method: "PATCH", body: ["statusLights": lightText]); await load() } }
            }
        }.task { await load() }.refreshable { await load() }
    }
    private func load() async { do { data = try await app.api.request("/me/vrc", fresh: true); let profile = try await app.api.request("/me/profile", fresh: true); for light in lights { lightText[light.0] = profile["statusLights"][light.0].string } } catch { app.message = error.localizedDescription } }
}
