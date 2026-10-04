import SwiftUI

@main struct ERPApp: App {
    @StateObject private var app = AppState()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(app).tint(app.accent)
                .task { await app.prepare() }
                .onChange(of: scenePhase) { phase in if phase == .active { app.configure(); app.connectRealtime(); app.run { await app.refreshCounters() } } else { app.disconnectRealtime() } }
        }
    }
}
struct RootView: View {
    @EnvironmentObject private var app: AppState
    var body: some View {
        GeometryReader { geometry in
            let desktop = UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width >= 700
            VStack(spacing: 0) {
                HeaderView().frame(maxWidth: desktop ? 1440 : .infinity)
                    .padding(.horizontal, desktop ? 28 : 16).padding(.vertical, desktop ? 16 : 10)
                    .frame(maxWidth: .infinity)
                Rectangle().fill(.secondary.opacity(0.13)).frame(height: 1)
                if desktop {
                    HStack(alignment: .top, spacing: 0) {
                        DesktopSidebar().frame(width: geometry.size.width < 950 ? 188 : 230)
                        Rectangle().fill(.secondary.opacity(0.13)).frame(width: 1)
                        selectedTab.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.frame(maxWidth: 1440).frame(maxWidth: .infinity)
                } else {
                    TabView(selection: $app.tab) {
                        DiscoverView().tabItem { Label(L("探索"), systemImage: "safari") }.tag(0)
                        LikesView().tabItem { Label(L("喜欢我"), systemImage: "heart") }.badge(app.counters["newLikes"].int).tag(1)
                        MatchesView().tabItem { Label(L("配对"), systemImage: "bubble.left") }.badge(app.counters["unreadMessages"].int).tag(2)
                        PostsView().tabItem { Label(L("广场"), systemImage: "megaphone") }.tag(3)
                        MyView().tabItem { Label(L("我"), systemImage: "person") }.badge(app.counters["newVisitors"].int > 0 ? String(app.counters["newVisitors"].int) : app.updateAvailable ? "•" : nil).tag(4)
                    }
                }
            }
        }.background(Palette.background)
            .preferredColorScheme(app.appearance == "dark" ? .dark : app.appearance == "light" ? .light : app.appearance == "system" ? nil : app.mode == "nsfw" ? .dark : .light)
            .environment(\.locale, Locale(identifier: app.localeCode))
            .sheet(item: $app.screen) { screen in ScreenView(screen: screen).environmentObject(app) }
            .sheet(item: $app.profileRoute) { route in ProfileDetailView(id: route.id).environmentObject(app) }
            .fullScreenCover(item: $app.chatRoute) { route in ChatView(id: route.id).environmentObject(app) }
            .sheet(item: $app.matched) { result in MatchSuccessView(result: result).environmentObject(app).presentationDetents([.medium, .large]) }
            .sheet(isPresented: $app.firstRun) { IntroductionView().environmentObject(app).interactiveDismissDisabled() }
            .alert(L("提示"), isPresented: Binding(get: { app.message != nil }, set: { if !$0 { app.message = nil } })) { Button(L("我知道啦")) { app.message = nil } } message: { Text(app.message ?? "") }
    }
    @ViewBuilder private var selectedTab: some View {
        switch app.tab {
        case 1: LikesView()
        case 2: MatchesView()
        case 3: PostsView()
        case 4: MyView()
        default: DiscoverView()
        }
    }
}
struct DesktopSidebar: View {
    @EnvironmentObject private var app: AppState
    private let tabs: [(String, String)] = [("探索", "safari"), ("喜欢我", "heart"), ("配对", "bubble.left"), ("广场", "megaphone"), ("我", "person")]
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(tabs.indices, id: \.self) { index in
                Button { app.tab = index } label: {
                    HStack(spacing: 13) {
                        Image(systemName: tabs[index].1).frame(width: 24)
                        Text(L(tabs[index].0)).font(.headline)
                        Spacer(minLength: 0)
                        if index == 1 && app.counters["newLikes"].int > 0 { Dot(count: app.counters["newLikes"].int) }
                        if index == 2 && app.counters["unreadMessages"].int > 0 { Dot(count: app.counters["unreadMessages"].int) }
                        if index == 4 && (app.counters["newVisitors"].int > 0 || app.updateAvailable) { Dot(count: app.counters["newVisitors"].int) }
                    }.padding(.horizontal, 13).frame(height: 48)
                        .foregroundStyle(app.tab == index ? app.accent : .primary)
                        .background(app.tab == index ? app.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            if app.authenticated {
                Button { app.screen = .settings } label: { Label(L("设置"), systemImage: "gearshape").frame(maxWidth: .infinity, alignment: .leading).padding(14) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }.padding(14).frame(maxHeight: .infinity).background(Palette.background)
    }
}
struct HeaderView: View {
    @EnvironmentObject private var app: AppState
    @Namespace private var modeAnimation
    let modes = [("sfw", "SFW", "heart"), ("mixed", "", "square.3.layers"), ("nsfw", "NSFW", "flame")]
    var body: some View {
        HStack(spacing: 9) {
            HStack(spacing: 3) {
                ForEach(modes, id: \.0) { value in
                    Button { withAnimation(.spring(response: 0.3)) { app.setMode(value.0) } } label: {
                        HStack(spacing: 4) { Image(systemName: value.2); if app.mode == value.0 { Text(value.1).font(.subheadline) } }.padding(.horizontal, 9).frame(height: 36).background { if app.mode == value.0 { Capsule().fill(Palette.surface).matchedGeometryEffect(id: "mode", in: modeAnimation) } }
                    }.foregroundStyle(app.mode == value.0 ? .primary : .secondary)
                }
            }.padding(4).background(Palette.secondary, in: Capsule())
            Spacer(minLength: 0)
            Button { if app.requireLogin() { app.screen = .energy } } label: { HStack(spacing: 3) { Image(systemName: "bolt.fill").foregroundStyle(.yellow); Text(String(app.energy["regen"].int + app.energy["permanent"].int)) }.font(.subheadline).padding(9).background(Palette.secondary, in: Capsule()) }.foregroundStyle(.primary)
            Button { app.screen = .scan } label: { Image(systemName: "qrcode.viewfinder") }.accessibilityLabel(L("扫描二维码"))
            Button { if app.requireLogin() { app.screen = .notifications } } label: { Image(systemName: "bell").overlay(alignment: .topTrailing) { if app.counters["unreadNotifications"].int > 0 { Dot().offset(x: 3, y: -3) } } }.accessibilityLabel(L("通知"))
            Menu {
                ForEach([("auto", "跟随模式风格", "square.3.layers"), ("light", "浅色", "sun.max"), ("dark", "深色", "moon"), ("system", "跟随系统设置", "desktopcomputer")], id: \.0) { choice in Button { app.setAppearance(choice.0) } label: { Label(L(choice.1), systemImage: choice.2) } }
            } label: { Image(systemName: app.appearance == "light" ? "sun.max" : "moon") }.accessibilityLabel(L("主题与外观"))
        }.font(.title3).buttonStyle(.plain)
    }
}
struct ScreenView: View {
    @EnvironmentObject private var app: AppState
    let screen: Screen
    var body: some View {
        NavigationStack {
            Group {
                switch screen {
                case .login: LoginView()
                case .notifications: NotificationsView()
                case .scan: QRScannerView()
                case .share: ShareCardView()
                case .settings: SettingsView()
                case .about: AboutView()
                case .editProfile: ProfileEditorView()
                case .vrc: VRCView()
                default: SettingsDetailView(screen: screen)
                }
            }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button { app.screen = nil } label: { Image(systemName: "xmark") }.accessibilityLabel(L("关闭")) } }.toolbarBackground(Palette.background, for: .navigationBar)
        }
    }
}
struct LoginView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = "", password = "", totp = "", token = ""
    @State private var busy = false
    @State private var reset = 0
    private var ready: Bool { !app.config["turnstileSiteKey"].exists || app.config["turnstileSiteKey"].string.isEmpty || !token.isEmpty }
    var body: some View {
        Page(title: "登录") {
            Text(L("使用你已有的 erp.sex 账号")).foregroundStyle(.secondary)
            Panel { VStack(spacing: 18) {
                TextField(L("邮箱"), text: $email).keyboardType(.emailAddress).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField(L("密码"), text: $password).textContentType(.password)
                TextField(L("二步验证码（未开启可留空）"), text: $totp).keyboardType(.numberPad).textContentType(.oneTimeCode)
                VerificationView(action: "login", token: $token, reset: reset).frame(height: app.config["turnstileSiteKey"].string.isEmpty ? 0 : 110)
                PrimaryButton(title: busy ? "正在登录…" : "登录") { login() }.disabled(busy || !ready || email.isEmpty || password.isEmpty)
                Button(L("重试安全验证")) { token = ""; reset += 1 }
            } }
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
