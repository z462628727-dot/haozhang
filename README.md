# 星璃 · 原生 iPad 版

本包包含原生 SwiftUI 应用代码、角色图片、Xcode 工程和免费云端编译流程。适用于 iPadOS 16 或更高版本。角色、离线预设互动、聊天记录、朗读和专注计时均在 App 内实现，不通过网站加载角色，不需要 ChatGPT 或 Render 账号。

**当前文件包还不是可直接安装的 IPA。当前 Windows 环境没有 Apple 的 iOS 编译工具，尚未完成 Xcode 编译、Apple 签名或实体 iPad 测试。**

## Windows + iPad 的免费路线

1. 把本工程放入你自己的 GitHub 仓库。使用公开仓库的标准 macOS Actions runner 可以免费编译；公开源码和角色图之前需要你的明确同意。不要上传聊天、API 密钥、Apple 密码或签名证书。
2. 在仓库「Actions」中打开「Build iPad IPA」，点击「Run workflow」。流程会用 Xcode 编译面向真实设备的 arm64 应用，随后生成 `Xingli-unsigned.ipa`。
3. 成功后从该次运行的 Artifacts 下载 `Xingli-unsigned-IPA`，解压下载文件，取出 `.ipa`。
4. 在 Windows 上按 AltStore 官方说明安装 AltServer / AltStore Classic。连接并信任自己的 iPad，在你自己的电脑和官方工具中输入 Apple 账号完成个人签名。
5. 在 iPad 的 AltStore Classic 中导入 `.ipa`，按工具和系统提示完成安装。未签名 IPA 不能只在「文件」App 中点一下就安装。

免费 Apple 个人签名通常有 7 天有效期，需要定期刷新。它不是永久免签名的 App Store 安装包。系统是否需要启用开发者模式等，以 Apple 和 AltStore 当前提示为准。

官方参考：[AltStore Classic 的 Windows 安装步骤](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)、[AltStore 使用说明](https://faq.altstore.io/altstore-classic/your-altstore)、[Apple 个人开发团队限制](https://developer.apple.com/help/account/basics/about-your-developer-account)、[GitHub 标准运行器的免费范围](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job)。

## App 功能与 AI

默认提供有明确标注的离线预设互动。设置中保留 DeepSeek / OpenAI 接口：填写你账户中可用的模型名称及 API 密钥后，iPad 直接调用该服务。真实 AI 对话需要网络、自备模型账户及该服务在使用地区可用；服务可能计费。安装 App 本身不附带免费模型额度。

API 密钥只在当前 App 进程内存中保留，不写入聊天存档。设置、专注结束时刻和最近最多 100 条聊天写入本机 App 文档目录；不自动跨设备同步。卸载 App 可能移除本机数据，可先在设置中分享或备份聊天文本。

角色只在 App 内显示，不悬浮在其他 iPad 应用上。切回 App 时会根据结束时刻更新专注计时；没有申请后台通知或麦克风权限。

## 工程文件

- `Xingli.xcodeproj`：原生 Xcode 工程，已共享 Xingli scheme。
- `Xingli/`：SwiftUI 界面、模型请求与角色资源。
- `.github/workflows/build-ipad.yml`：按需启动的 macOS 编译流程。
- `scripts/build-ipa.sh`：在 macOS / Xcode 上编译真实设备 IPA，不使用模拟器包冒充安装包。

如果以后使用 Mac，也可直接打开工程，使用自己的 Apple Personal Team，在 Xcode 中选择已连接的 iPad 安装。需要时更改 Bundle Identifier，使它在你的账号中唯一。
