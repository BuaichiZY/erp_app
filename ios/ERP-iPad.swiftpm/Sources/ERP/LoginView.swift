import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var oauth: OAuthLogin
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var totp = ""
    @State private var token = ""
    @State private var busy = false
    @State private var reset = 0
    private var ready: Bool { !app.config["turnstileSiteKey"].exists || app.config["turnstileSiteKey"].string.isEmpty || !token.isEmpty }
    var body: some View {
        GeometryReader { geometry in
            let split = geometry.size.width >= 900 && geometry.size.width > geometry.size.height
            HStack(spacing: 0) {
                if split { LoginCityView().frame(width: geometry.size.width * 0.5) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !split { Text("erp.sex").font(.title.bold()).padding(.bottom, 12) }
                        Text(L("欢迎回来")).font(.largeTitle.bold())
                        Text(L("登录后继续滑卡。")).foregroundStyle(.secondary)
                        if app.config["loginMethods"]["x"].bool {
                            Button {
                                app.run { defer { token = ""; reset += 1 }; try await oauth.start(token: token) }
                            } label: {
                                HStack(spacing: 10) { Text("𝕏").font(.title2); Text(L(oauth.starting ? "正在启动 X 授权…" : "使用 X 继续")).fontWeight(.semibold) }
                                    .frame(maxWidth: .infinity).frame(height: 48).foregroundStyle(.black).background(.white, in: Capsule())
                            }.buttonStyle(.plain).disabled(busy || !ready || oauth.starting || oauth.waiting)
                            Text(L("erp.sex 不会用你的账号发文。")).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                            HStack { Rectangle().frame(height: 1); Text(L("或")).padding(.horizontal, 12); Rectangle().frame(height: 1) }.foregroundStyle(.secondary.opacity(0.4)).font(.caption).padding(.vertical, 4)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("电子邮件")).font(.subheadline.bold())
                            TextField(L("邮箱"), text: $email).keyboardType(.emailAddress).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled().loginField()
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(L("密码")).font(.subheadline.bold()); Spacer(); Link(L("忘记密码？"), destination: URL(string: "https://erp.sex/forgot-password")!).font(.caption) }
                            SecureField(L("密码"), text: $password).textContentType(.password).loginField()
                        }
                        DisclosureGroup(L("二步验证")) {
                            TextField(L("二步验证码（未开启可留空）"), text: $totp).keyboardType(.numberPad).textContentType(.oneTimeCode).loginField().padding(.top, 8)
                        }.font(.caption).foregroundStyle(.secondary)
                        if !app.config["turnstileSiteKey"].string.isEmpty {
                            VerificationView(action: "login", token: $token, reset: reset).frame(height: 72)
                            Button(L("重试安全验证")) { token = ""; reset += 1 }.font(.caption)
                        }
                        if !oauth.status.isEmpty { Text(oauth.status).font(.subheadline).foregroundStyle(.secondary) }
                        if oauth.waiting { Button(L("取消")) { oauth.cancel() } }
                        PrimaryButton(title: busy ? "正在登录…" : "登录", icon: "rectangle.portrait.and.arrow.right") { login() }.disabled(busy || oauth.waiting || oauth.starting || !ready || email.isEmpty || password.isEmpty)
                        HStack { Spacer(); Text(L("第一次来？")).foregroundStyle(.secondary); Link(L("建立账号"), destination: URL(string: "https://erp.sex/register")!); Spacer() }.font(.subheadline).padding(.top, 6)
                        HStack(spacing: 12) {
                            Link(L("服务条款"), destination: URL(string: "https://erp.sex/legal/terms")!)
                            Link(L("隐私说明"), destination: URL(string: "https://erp.sex/legal/privacy")!)
                            Link(L("社群规范"), destination: URL(string: "https://erp.sex/legal/community")!)
                        }.font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 16)
                    }.frame(maxWidth: 440).padding(.horizontal, 28).padding(.top, 64).padding(.bottom, 28)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }.background(Color(hex: 0xf5f6f9))
            }.overlay(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    Menu {
                        ForEach([("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("en", "English"), ("ja", "日本語"), ("ko", "한국어")], id: \.0) { code, title in Button(title) { app.setLanguage(code) } }
                    } label: { Image(systemName: "character.bubble").frame(width: 44, height: 44) }.accessibilityLabel(L("语言"))
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel(L("关闭"))
                }.foregroundStyle(.secondary).padding(12)
            }
        }.preferredColorScheme(.light)
            .sheet(item: $oauth.authorization, onDismiss: { oauth.resume(); if app.authenticated { dismiss() } }) { route in
                OAuthBrowser(url: route.url) { oauth.authorization = nil; oauth.resume() }.ignoresSafeArea()
            }
    }
    private func login() {
        busy = true
        app.run {
            defer { busy = false }
            var body: [String: Any] = ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "password": password, "turnstileToken": token]
            if !totp.isEmpty { body["totpCode"] = totp }
            do { await app.api.syncWebCookies(); _ = try await app.api.request("/auth/login", method: "POST", body: body); password = ""; await app.reloadSession(); dismiss() }
            catch { token = ""; reset += 1; throw error }
        }
    }
}

private extension View {
    func loginField() -> some View {
        self.padding(.horizontal, 14).frame(height: 44).background(.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.18)))
    }
}

struct LoginCityView: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(hex: 0x10102e), Color(hex: 0x21122f), .black], startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                for index in 0..<85 {
                    let x = CGFloat((index * 173 + 19) % 997) / 997 * size.width
                    let y = CGFloat((index * 109 + 31) % 997) / 997 * size.height * 0.72
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: index % 3 == 0 ? 2 : 1, height: 2)), with: .color(.white.opacity(0.28)))
                }
                let moon = CGPoint(x: size.width * 0.73, y: size.height * 0.17)
                for (diameter, opacity) in [(CGFloat(180), 0.12), (CGFloat(88), 0.95)] {
                    context.fill(Path(ellipseIn: CGRect(x: moon.x - diameter / 2, y: moon.y - diameter / 2, width: diameter, height: diameter)), with: .color(Color(hex: 0xe4d3a0).opacity(opacity)))
                }
                for index in 0..<11 {
                    let width = size.width / 8
                    let height = size.height * (0.20 + CGFloat((index * 37) % 7) * 0.06)
                    let x = CGFloat(index) * size.width / 10 - 12
                    context.fill(Path(CGRect(x: x, y: size.height - height, width: width, height: height)), with: .color(Color(hex: index % 2 == 0 ? 0x090917 : 0x0e0b1c)))
                    for row in 0..<Int(height / 24) {
                        for column in 0..<4 where (row * 7 + column * 11 + index * 3) % 5 != 0 {
                            let rect = CGRect(x: x + 10 + CGFloat(column) * 17, y: size.height - height + 15 + CGFloat(row) * 24, width: 6, height: 9)
                            context.fill(Path(rect), with: .color(Color(hex: (row + column + index) % 7 == 0 ? 0xc466a0 : 0xc3aa5e).opacity(0.5)))
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                Text(L("在 VRChat 找到对的人")).font(.system(size: 32, weight: .bold))
                Text(L("一起逛世界的朋友、舞伴、VR 恋人或 ERP 搭档——依照来意、模型和上线时段帮你配对。")).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                ForEach(["滑卡、配对、聊天——只有互相喜欢才能传讯息", "支持繁体中文、日文、英文、韩文", "看什么由你决定：SFW、混合或仅 NSFW"], id: \.self) { line in
                    Label { Text(L(line)).font(.caption) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0xff5753)) }
                }
                Text(L("仅限 18 岁以上成人")).font(.caption).foregroundStyle(.white.opacity(0.5)).padding(.top, 12)
            }.foregroundStyle(.white).padding(32)
        }.overlay(alignment: .topLeading) {
            Text("erp.sex").font(.title2.bold()).foregroundStyle(.white).padding(16).background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 12)).padding(28)
        }.ignoresSafeArea(edges: .bottom)
    }
}
