# ERP iOS 的 TestFlight 构建

项目标识为 `sex.erp.ios`，iPhone 和 iPad 共用一个安装包。仓库的 `TestFlight upload` 工作流程使用 macOS 26 / Xcode 26 生成已签名的 IPA，并上传到 App Store Connect。Windows 本机无需安装 Xcode。

首次上传前，需要在 Apple Developer / App Store Connect 中完成以下设置：

1. 确认 Apple Developer Program 会员资格有效，并接受当前协议。在“Certificates, Identifiers & Profiles”创建显式 App ID `sex.erp.ios`，在 App Store Connect 的“Apps”中创建对应的 iOS App 记录。
2. 准备 Apple Distribution 证书及其私钥，导出为设有密码的 `.p12`。再为 `sex.erp.ios` 创建 **App Store Connect** 分发描述文件，下载 `.mobileprovision`。证书与描述文件必须属于同一个 Team ID。
3. 在 App Store Connect → Users and Access → Integrations → App Store Connect API 创建 **Team API Key**，下载一次性提供的 `.p8` 文件，并记下 Key ID、Issuer ID。不要把这些私钥提交到仓库或发送到聊天中。
4. 在 GitHub 仓库 Settings → Secrets and variables → Actions 中设置下表全部机密。三个文件用文件字节的 Base64 文本保存，`.p12` 的密码原样保存。

| GitHub Actions 机密 | 值 |
| --- | --- |
| `APPLE_TEAM_ID` | Apple 开发者 Team ID |
| `APPLE_DISTRIBUTION_P12_BASE64` | `.p12` 文件的 Base64 |
| `APPLE_DISTRIBUTION_P12_PASSWORD` | `.p12` 导出密码 |
| `APPLE_APPSTORE_PROFILE_BASE64` | `.mobileprovision` 文件的 Base64 |
| `APP_STORE_CONNECT_API_KEY_ID` | Team API Key 的 Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Team API Key 的 Issuer ID |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | `.p8` 文件的 Base64 |

在 Windows PowerShell 中，可用 `[Convert]::ToBase64String([IO.File]::ReadAllBytes('文件绝对路径'))` 转换文件；转换后的文本仍是敏感凭据，应只填入 GitHub Actions 机密。

本机已在仓库根目录的 `.signing/` 生成 `ERP_Distribution.certSigningRequest` 及对应的 `ERP_Distribution.key`。如需新建 Apple Distribution 证书，把前者上传至 Apple Developer 的证书创建页面，下载 `.cer` 后运行 `powershell -File ios/finish-distribution-certificate.ps1 -CertificatePath '下载的证书绝对路径'`，即可在同目录生成 `.p12`。**私钥和 `.p12` 不应上传到 GitHub 仓库。** 如已有可用的 Apple Distribution `.p12`，可以直接使用，无需新建证书。

配置完成后，在已包含 iOS 源码的提交上创建 `testflight/1.3.0-1` 形式的 tag 并推送，或在 GitHub Actions 手动运行 `TestFlight upload`。上传成功后，等待 Apple 处理构建，再到 App Store Connect 的 TestFlight 标签将构建加入内部测试组并邀请测试者。首次外部测试可能需要 Apple 的 Beta App Review。

目前此仓库尚未配置上述机密，因此可完成设备版编译和未签名归档，但无法直接生成可安装的已签名 IPA，也无法向 TestFlight 上传。`ios/ERP-iPad.swiftpm` 可作为 iPad Swift Playgrounds 项目使用，但它与 TestFlight 分发是两条不同路径。
