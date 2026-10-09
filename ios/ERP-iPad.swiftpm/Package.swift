// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "ERP",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS("17.0")],
    products: [
        .iOSApplication(
            name: "ERP",
            targets: ["ERP"],
            bundleIdentifier: "sex.erp.ios",
            displayVersion: "1.4.5",
            bundleVersion: "9",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.red),
            supportedDeviceFamilies: [.phone, .pad],
            supportedInterfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown(.when(deviceFamilies: [.pad]))],
            capabilities: [
                .camera(purposeString: "仅在扫描名片二维码时使用相机。"),
                .microphone(purposeString: "仅在录制聊天语音时使用麦克风。")
            ],
            appCategory: .socialNetworking
        )
    ],
    targets: [.executableTarget(name: "ERP", resources: [.process("Resources"), .process("Assets.xcassets")])]
)
