# 星璃陪伴：Windows + iPad 安装

已编译的安装包：`星璃iPad-unsigned.ipa`（约 1.2 MB）。适用于 iPadOS 16 或更高版本。已经通过 Xcode 真实设备 arm64 编译和本地 IPA 结构检查，尚未在你的 iPad 上实测。

## 安装

1. 在 Windows 电脑按 [AltStore Classic 官方 Windows 安装说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)安装 AltServer，以及它要求的 Apple iTunes / iCloud 组件。下载入口以该官方说明为准。
2. 用 USB 连接已解锁的 iPad，按提示信任电脑；在 AltServer 中选择「Install AltStore」及你的 iPad。Apple 账号和验证只在你自己的电脑与官方工具中操作。
3. 在 iPad 根据系统提示信任个人开发者，并按 AltStore 官方步骤启用开发者模式；如要求重启，完成重启。
4. 把 `.ipa` 保存到 iPad 的「文件」中。保持电脑上的 AltServer 运行，并让电脑与 iPad 连接正常；在 iPad 的 AltStore Classic → My Apps，通过添加（＋）入口选择这个 IPA，完成个人签名和安装。
5. 主屏幕出现「星璃陪伴」后打开。默认无需 ChatGPT 账号；可使用角色互动、离线预设回应、朗读和专注计时。自由 AI 对话需要在设置中填写自备模型和 API 密钥，软件没有内置付费额度。

未签名 IPA 无法直接点开安装。免费个人签名通常 7 天过期，请在到期前保持 AltServer 可连接，并在 AltStore 中刷新应用。参考 [AltStore 刷新说明](https://faq.altstore.io/altstore-classic/your-altstore)和 [Apple 个人团队限制](https://developer.apple.com/help/account/basics/about-your-developer-account)。

## 校验与源码

- IPA SHA-256：`54eec8d1ddaa1d47de524f63cef9f60c7f46c9c7dbf9a006500614acc1b39370`
- [成功编译记录](https://github.com/z462628727-dot/haozhang/actions/runs/44230549848)
- [公开源码](https://github.com/z462628727-dot/haozhang)

聊天记录只存本机；API 密钥只在当前应用内存中使用，重启后需重新填写。应用本体可离线打开，AI 服务和 GitHub 下载仍受网络及各服务可用地区影响，不能保证所有地区都能连接。
