# ERP Android

ERP 1.0.0-beta，适配 [erp.sex](https://erp.sex) 的非官方 Android 原生客户端。最低支持 Android 8.0（API 26）。

首次启动会显示应用说明。“关于 ERP”的“开源项目”会在浏览器中打开本仓库。界面支持简体中文、繁体中文、日语、英语及韩语；默认自动识别手机语言，也可在设置里手动选择。

## 权限与数据

清单只声明网络和麦克风权限。麦克风权限仅在用户主动开始录音时申请。图片通过系统选择器选择，不申请相册、存储、相机、位置、联系人或通知权限。账号登录 Cookie、基本缓存及使用偏好保存在本机；请求发送至网站现有接口。

## 构建 APK

需要 Python 3、JDK 17、Android SDK Platform 35 和 Build-Tools 35.0.0。无需 Gradle，也无需额外 Python 包。

Windows PowerShell 示例：

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
$env:ANDROID_SDK_ROOT = 'C:\Users\你的用户名\AppData\Local\Android\Sdk'
python build.py
```

标准 SDK 环境下输出为 `dist/ERP-Native-1.0.0-beta.apk`，并生成 SHA-256 文件。`ERP_OUTPUT_DIR` 可指定输出目录；`ERP_JAVA_HOME` 可覆盖 JDK 位置；`ERP_BUILD_TOOLS` 可指定 Build-Tools 版本。

首次构建会在被忽略的 `.signing/` 目录生成本机签名密钥和随机密码。`ERP_SIGNING_DIR` 可指定已有签名目录，该目录需包含 `release.p12` 和 `password.txt`，密钥别名为 `erp-release`。请保留自己的密钥；不同签名的 APK 无法直接覆盖安装。已交付 APK 使用的密钥不随源码上传。

构建脚本会编译资源和 Java、生成 DEX、对齐 APK、签名，并校验签名及安装信息。目前已在 Windows 上验证构建；其他系统仍需实测。

## 验证

```powershell
python run_tests.py
```

这些检查覆盖内容与主题规则、配对状态、手势、聊天链接、刷新批次及 WebSocket 帧解析等纯逻辑。界面、触控动画、Cloudflare 和真实账号操作仍需在 Android 设备上验证。

## 源码

- `src/sex/erp/android/`：原生界面、网站接口与实时连接。
- `res/`：应用图标、站点图标、主题和语言资源。
- `AndroidManifest.xml`：版本、兼容级别与权限。
- `tests/`：纯 Java 逻辑检查。
- `build.py`：独立 APK 构建脚本。

应用源码按 [MIT License](LICENSE) 开源。网站名称、标志及第三方图标不属于本项目的授权范围；图标许可见 `res/raw/third_party_licenses.txt`。本项目与网站及 VRChat 官方没有隶属关系。
