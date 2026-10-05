[🇨🇳 简体中文](README.md) | [🇺🇸 English](README_EN.md)

# ERP Android

ERP 1.3.5_beta，适配 [erp.sex](https://erp.sex) 的非官方 Android 原生客户端。最低支持 Android 8.0（API 26）。

首次启动会显示应用说明。“关于 ERP”的“开源项目”会在浏览器中打开本仓库。界面支持简体中文、繁体中文、日语、英语及韩语；默认自动识别手机语言，也可在设置里手动选择。

## 权限与数据

清单声明网络、麦克风、相机和安装更新所需权限。麦克风仅在用户主动录音时申请；相机仅在扫码页主动启用相机时申请。也可通过系统图片选择器扫描相册中的二维码，或选择聊天图片，不申请相册和存储权限。“检查更新”仅在用户选择安装新版时引导系统授予安装权限。账号登录 Cookie、受限大小的头像与名片图缓存及使用偏好保存在本机；请求发送至网站现有接口。

## 构建 APK

需要 Python 3、JDK 17、Android SDK Platform 35 和 Build-Tools 35.0.0。无需 Gradle，也无需额外 Python 包。

Windows PowerShell 示例：

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:ANDROID_SDK_ROOT = 'C:\Users\你的用户名\AppData\Local\Android\Sdk'
python build.py
```

标准 SDK 环境下输出为 `dist/ERP-Native-1.3.5_beta.apk`，并生成 SHA-256 文件。`ERP_OUTPUT_DIR` 可指定输出目录；`ERP_JAVA_HOME` 可覆盖 JDK 位置；`ERP_BUILD_TOOLS` 可指定 Build-Tools 版本。

首次构建会在被忽略的 `.signing/` 目录生成本机签名密钥和随机密码。`ERP_SIGNING_DIR` 可指定已有签名目录，该目录需包含 `release.p12` 和 `password.txt`，密钥别名为 `erp-release`。请保留自己的密钥；不同签名的 APK 无法直接覆盖安装。已交付 APK 使用的密钥不随源码上传。

构建脚本会编译资源和 Java、生成 DEX、对齐 APK、签名，并校验签名及安装信息。目前已在 Windows 上验证构建；其他系统仍需实测。

## 验证

```powershell
python run_tests.py
```

这些检查覆盖内容与主题规则、配对状态、手势、聊天链接、刷新批次、更新版本比较及 WebSocket 帧解析等纯逻辑。界面、扫码相机、下载与安装、Cloudflare 和真实账号操作仍需在 Android 设备上验证。

## 源码

- `src/sex/erp/android/`：原生界面、网站接口与实时连接。
- `src/io/nayuki/qrcodegen/`：名片二维码生成器。
- `third_party/zxing-core-3.5.3.jar`：扫码解码器。
- `res/`：应用图标、站点图标、主题和语言资源。
- `AndroidManifest.xml`：版本、兼容级别与权限。
- `tests/`：纯 Java 逻辑检查。
- `build.py`：独立 APK 构建脚本。

应用源码按 [MIT License](LICENSE) 开源。网站名称、标志及第三方图标不属于本项目的授权范围；图标许可见 `res/raw/third_party_licenses.txt`。二维码生成器采用 MIT 许可，解码器采用 Apache 2.0 许可，完整文本分别见 `res/raw/nayuki_license.txt` 和 `res/raw/zxing_license.txt`。本项目与网站及 VRChat 官方没有隶属关系。
