# 在 iPad 上用普通 Apple 账号测试

`ERP-1.4.5-build9-unsigned.ipa` 是已编译的 iPhone/iPad 设备版，但**没有签名**。普通 Apple 账号无法使用 TestFlight，也不能直接在 iPad 上点开此文件安装；需要先用自己的 Apple 账号为它签名。

在 Windows 上可使用 [Sideloadly 官方下载页](https://sideloadly.io/)：安装其要求的网页版 iTunes、iCloud，USB 连接 iPad 并在设备上点“信任”，把 IPA 拖入 Sideloadly，输入自己的 Apple 账号并开始安装。若 iPad 提示需要开发者模式，在“设置 → 隐私与安全性 → 开发者模式”启用；若提示开发者未受信任，在“设置 → 通用 → VPN 与设备管理”信任该账号。具体界面以 [Sideloadly 的说明](https://sideloadly.io/faq.html)为准。

普通 Apple 账号的个人设备签名通常在 **7 天**后失效，需要用同一账号重新签名安装。此路径供本人设备测试，不是 TestFlight 分发。签名和实体 iPad 安装尚未在本项目中验证。
