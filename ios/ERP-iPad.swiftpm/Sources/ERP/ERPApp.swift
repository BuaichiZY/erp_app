import SwiftUI

@main struct ERPApp: App {
    @StateObject private var app = AppState()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(app).environmentObject(app.oauth).tint(app.accent)
                .task { await app.prepare() }
                .onChange(of: scenePhase) { phase in if phase == .active { app.configure(); app.oauth.resume(); app.connectRealtime(); app.run { await app.refreshCounters() } } else { app.oauth.pause(); app.disconnectRealtime() } }
        }
    }
}
struct RootView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = LayoutMetrics(width: geometry.size.width).sidebarWidth(isPad: UIDevice.current.userInterfaceIdiom == .pad, accessibility: dynamicTypeSize.isAccessibilitySize)
            let desktop = sidebarWidth > 0
            // Keep one content tree while the window switches between sidebar and compact tabs.
            HStack(spacing: 0) {
                DesktopSidebar().frame(width: sidebarWidth).clipped()
                    .background(app.palette.surface.ignoresSafeArea(.container, edges: .bottom))
                    .accessibilityHidden(!desktop).allowsHitTesting(desktop)
                Rectangle().fill(app.palette.border).frame(width: desktop ? (app.palette.pop ? 2.5 : 1) : 0).ignoresSafeArea(.container, edges: .bottom)
                VStack(spacing: 0) {
                    HeaderView(showAllLabels: desktop || (UIDevice.current.userInterfaceIdiom == .pad && geometry.size.width >= 700)).padding(.horizontal, desktop ? 24 : 16)
                        .padding(.vertical, desktop ? 12 : 8)
                        .frame(height: !desktop && ((app.tab == 2 && app.chatRoute != nil) || (app.tab == 3 && app.postRoute != nil)) ? 0 : nil).clipped()
                    Rectangle().fill(app.palette.border).frame(height: !desktop && ((app.tab == 2 && app.chatRoute != nil) || (app.tab == 3 && app.postRoute != nil)) ? 0 : (app.palette.pop ? 2.5 : 1))
                    TabView(selection: $app.tab) {
                        DiscoverView().toolbar(desktop ? .hidden : .visible, for: .tabBar).tabItem { Label(L("探索"), systemImage: "safari") }.tag(0)
                        LikesView().toolbar(desktop ? .hidden : .visible, for: .tabBar).tabItem { Label(L("喜欢我"), systemImage: "heart") }.badge(app.counters["newLikes"].int).tag(1)
                        MatchesView().toolbar(desktop || app.chatRoute != nil ? .hidden : .visible, for: .tabBar).tabItem { Label(L("配对"), systemImage: "bubble.left") }.badge(app.counters["unreadMessages"].int).tag(2)
                        PostsView().toolbar(desktop || app.postRoute != nil ? .hidden : .visible, for: .tabBar).tabItem { Label(L("广场"), systemImage: "megaphone") }.tag(3)
                        MyView().toolbar(desktop ? .hidden : .visible, for: .tabBar).tabItem { Label(L("我"), systemImage: "person") }.badge(app.counters["newVisitors"].int > 0 ? String(app.counters["newVisitors"].int) : app.updateAvailable ? "•" : nil).tag(4)
                    }
                    .environment(\.horizontalSizeClass, desktop ? .regular : .compact)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }.frame(maxWidth: .infinity)
            }
        }.background {
            PhonePortraitRequirement(background: UIColor(app.palette.background), foreground: UIColor(app.palette.text), title: L("请竖屏使用此应用"))
                .allowsHitTesting(false).accessibilityHidden(true)
        }.foregroundStyle(app.palette.text).background(app.palette.background)
            .preferredColorScheme(app.preferredScheme)
            .environment(\.locale, Locale(identifier: app.localeCode))
            .sheet(item: Binding(get: { app.screen == .login ? nil : app.screen }, set: { if app.screen != .login { app.screen = $0 } }), onDismiss: app.finishNotificationNavigation) { screen in ScreenView(screen: screen).environmentObject(app).sitePresentation() }
            .fullScreenCover(isPresented: Binding(get: { app.screen == .login }, set: { if !$0 && app.screen == .login { app.screen = nil } })) { LoginView().environmentObject(app).environmentObject(app.oauth) }
            .sheet(item: $app.profileRoute) { route in ProfileDetailView(id: route.id, readOnly: route.readOnly).environmentObject(app).sitePresentation() }
            .sheet(item: $app.matched) { result in MatchSuccessView(result: result).environmentObject(app).presentationDetents([.medium, .large]) }
            .sheet(isPresented: $app.firstRun) { IntroductionView().environmentObject(app).interactiveDismissDisabled() }
            .alert(L("提示"), isPresented: Binding(get: { app.message != nil }, set: { if !$0 { app.message = nil } })) { Button(L("我知道啦")) { app.message = nil } } message: { Text(app.message ?? "") }
    }
}
struct DesktopSidebar: View {
    @EnvironmentObject private var app: AppState
    private let tabs: [(String, String)] = [("探索", "safari"), ("喜欢我", "heart"), ("配对", "bubble.left"), ("广场", "megaphone"), ("我", "person")]
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("erp.sex").font(.title2.bold()).padding(.horizontal, 13).padding(.vertical, 12)
            ForEach(tabs.indices, id: \.self) { index in
                Button { app.tab = index; if index == 0 { app.discoveryGrid = false } } label: {
                    HStack(spacing: 13) {
                        Image(systemName: tabs[index].1).frame(width: 24)
                        Text(L(tabs[index].0)).font(.headline)
                        Spacer(minLength: 0)
                        if index == 1 && app.counters["newLikes"].int > 0 { Dot(count: app.counters["newLikes"].int) }
                        if index == 2 && app.counters["unreadMessages"].int > 0 { Dot(count: app.counters["unreadMessages"].int) }
                        if index == 4 && (app.counters["newVisitors"].int > 0 || app.updateAvailable) { Dot(count: app.counters["newVisitors"].int) }
                    }.padding(.horizontal, 13).frame(height: 48)
                        .foregroundStyle((app.tab == index && (index != 0 || !app.discoveryGrid)) ? (app.palette.pop ? .white : app.accent) : app.palette.muted)
                        .background((app.tab == index && (index != 0 || !app.discoveryGrid)) ? app.accent.opacity(app.palette.pop ? 1 : 0.12) : .clear, in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
                    .accessibilityAddTraits((app.tab == index && (index != 0 || !app.discoveryGrid)) ? .isSelected : [])
            }
            SiteDivider().padding(.vertical, 14)
            Button { app.tab = 0; app.discoveryGrid = true } label: {
                Label(L("浏览"), systemImage: "square.grid.2x2").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    .foregroundStyle(app.tab == 0 && app.discoveryGrid ? (app.palette.pop ? .white : app.accent) : app.palette.muted)
                    .background(app.tab == 0 && app.discoveryGrid ? app.accent.opacity(app.palette.pop ? 1 : 0.12) : .clear, in: RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(.plain)
            if app.authenticated {
                Button { app.screen = .settings } label: { Label(L("设置"), systemImage: "gearshape").frame(maxWidth: .infinity, alignment: .leading).padding(14) }
                    .buttonStyle(.plain).foregroundStyle(app.palette.muted)
            }
            Spacer(minLength: 0)
        }.padding(14).frame(maxHeight: .infinity).background(app.palette.surface)
    }
}
struct HeaderView: View {
    @EnvironmentObject private var app: AppState
    @Namespace private var modeAnimation
    var showAllLabels = false
    let modes = [("sfw", "SFW", "heart"), ("mixed", "混合", "square.stack.3d.up"), ("nsfw", "NSFW", "flame")]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                modePicker
                Spacer(minLength: 12)
                HStack(spacing: showAllLabels ? 9 : 3) {
                    energyButton
                    scanButton
                    notificationButton
                    appearanceMenu
                }.fixedSize()
            }
            VStack(spacing: 6) {
                HStack { modePicker; Spacer(minLength: 4); energyButton }
                HStack { Spacer(); scanButton; notificationButton; appearanceMenu }
            }
        }.font(showAllLabels ? .title3 : .body).buttonStyle(.plain)
    }
    private var energyCount: Int { app.energy["regen"].int + app.energy["permanent"].int }
    private var modePicker: some View {
        HStack(spacing: 3) {
                ForEach(modes, id: \.0) { value in
                    Button { withAnimation(.spring(response: 0.3)) { app.setMode(value.0) } } label: {
                        HStack(spacing: showAllLabels ? 4 : 3) { Image(systemName: value.2); if showAllLabels || app.mode == value.0 { Text(L(value.0 == "nsfw" && showAllLabels ? "仅 NSFW" : value.1)).font(showAllLabels ? .subheadline : .caption) } }.padding(.horizontal, showAllLabels ? 9 : 6).frame(height: 36).background { if app.mode == value.0 { Capsule().fill(app.palette.selection).matchedGeometryEffect(id: "mode", in: modeAnimation) } }
                    }.foregroundStyle(app.mode == value.0 ? app.palette.selectionText : app.palette.muted)
                        .accessibilityLabel(value.1.isEmpty ? L("混合") : value.1)
                        .accessibilityAddTraits(app.mode == value.0 ? .isSelected : [])
                }
        }.padding(4).background(app.palette.secondary, in: Capsule()).siteOutline(Capsule(), shadow: false, normalBorder: false).fixedSize()
    }
    private var energyButton: some View {
        Button { if app.requireLogin() { app.screen = .energy } } label: {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").foregroundStyle(app.palette.energy)
                Text(showAllLabels && app.energy["regenMax"].exists ? "\(app.energy["regen"].int)/\(app.energy["regenMax"].int)" : String(energyCount))
                if showAllLabels && app.energy["permanent"].exists { EnergyGem(); Text(String(app.energy["permanent"].int)) }
            }
                .font(showAllLabels ? .subheadline : .caption).padding(showAllLabels ? 9 : 7).background(app.palette.secondary, in: Capsule())
        }.foregroundStyle(app.palette.text).accessibilityLabel(L("能量") + " \(energyCount)")
    }
    private var scanButton: some View {
        Button { app.screen = .scan } label: { Image(systemName: "qrcode.viewfinder").frame(width: showAllLabels ? 44 : 32, height: 44) }.accessibilityLabel(L("扫描二维码"))
    }
    private var notificationButton: some View {
        Button { if app.requireLogin() { app.screen = .notifications } } label: { Image(systemName: "bell").frame(width: showAllLabels ? 44 : 32, height: 44).overlay(alignment: .topTrailing) { if app.counters["unreadNotifications"].int > 0 { Dot() } } }.accessibilityLabel(L("通知"))
    }
    private var appearanceMenu: some View {
        Menu { appearanceChoices } label: { Image(systemName: app.appearance == "light" ? "sun.max" : "moon").frame(width: showAllLabels ? 44 : 32, height: 44) }.accessibilityLabel(L("主题与外观"))
    }
    private var appearanceChoices: some View {
        ForEach([("auto", "跟随模式风格", "square.stack.3d.up"), ("light", "浅色", "sun.max"), ("dark", "深色", "moon"), ("system", "跟随系统设置", "desktopcomputer")], id: \.0) { choice in Button { app.setAppearance(choice.0) } label: { Label(L(choice.1), systemImage: choice.2) } }
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
            }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button { app.screen = nil } label: { Image(systemName: "xmark") }.accessibilityLabel(L("关闭")) } }.toolbarBackground(app.palette.background, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        }.foregroundStyle(app.palette.text).presentationBackground(app.palette.background).preferredColorScheme(app.preferredScheme)
    }
}

/// A scene-level curtain also covers sheets without dismissing their state.
private struct PhonePortraitRequirement: UIViewRepresentable {
    let background: UIColor
    let foreground: UIColor
    let title: String
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> OrientationProbe {
        let probe = OrientationProbe()
        probe.changed = { [weak coordinator = context.coordinator] view in coordinator?.refresh(from: view) }
        return probe
    }
    func updateUIView(_ view: OrientationProbe, context: Context) {
        context.coordinator.background = background
        context.coordinator.foreground = foreground
        context.coordinator.title = title
        context.coordinator.refresh(from: view)
    }
    static func dismantleUIView(_ view: OrientationProbe, coordinator: Coordinator) { coordinator.curtain?.isHidden = true; coordinator.curtain = nil }
    final class OrientationProbe: UIView {
        var changed: ((UIView) -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); changed?(self) }
        override func layoutSubviews() { super.layoutSubviews(); changed?(self) }
    }
    final class Coordinator {
        var curtain: UIWindow?
        var background = UIColor.systemBackground
        var foreground = UIColor.label
        var title = ""
        private let label = UILabel()
        func refresh(from view: UIView) {
            guard UIDevice.current.userInterfaceIdiom == .phone, let scene = view.window?.windowScene else { return }
            let bounds = scene.coordinateSpace.bounds
            guard LayoutMetrics.requiresPortrait(isPhone: true, width: bounds.width, height: bounds.height) else { curtain?.isHidden = true; return }
            if curtain == nil {
                let window = UIWindow(windowScene: scene)
                window.windowLevel = .alert + 1
                let controller = UIViewController()
                controller.view.accessibilityViewIsModal = true
                let icon = UIImageView(image: UIImage(systemName: "iphone.gen3"))
                icon.contentMode = .scaleAspectFit
                icon.heightAnchor.constraint(equalToConstant: 62).isActive = true
                label.font = .preferredFont(forTextStyle: .title2)
                label.adjustsFontForContentSizeCategory = true
                label.numberOfLines = 0
                label.textAlignment = .center
                let stack = UIStackView(arrangedSubviews: [icon, label])
                stack.axis = .vertical; stack.spacing = 20; stack.translatesAutoresizingMaskIntoConstraints = false
                controller.view.addSubview(stack)
                NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor), stack.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor), stack.leadingAnchor.constraint(greaterThanOrEqualTo: controller.view.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(lessThanOrEqualTo: controller.view.trailingAnchor, constant: -24)])
                window.rootViewController = controller
                curtain = window
            }
            curtain?.frame = bounds
            curtain?.rootViewController?.view.backgroundColor = background
            curtain?.tintColor = foreground
            label.textColor = foreground; label.text = title
            curtain?.isHidden = false
        }
    }
}
