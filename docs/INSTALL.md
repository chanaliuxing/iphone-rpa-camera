# 构建与安装

需要 macOS、完整 Xcode、已接受许可，以及 xcodegen。先核对本机 Xcode/macOS/目标 iOS 的兼容性，不把 SDK 可编译与真机可部署混为一谈。

```bash
brew install xcodegen
bash ./build_free_ipa.command
```

输出为 `output/RPASnapshot-unsigned.ipa`，支持 arm64，最低 iOS 15。它没有签名，不能直接装到普通 iPhone。构建日志在 output/build.log。已有 archive 时可运行 `bash ./build_free_ipa.command --package-only`。

也可以在 iOS 目录运行 xcodegen generate，用受支持的 Xcode + 真机组合选择自己的 Personal Team、唯一 Bundle Identifier 和自动签名。

## 免费签名工具路径

从工具作者的官方来源下载签名安装器，使用自己的 Apple Account，按提示完成验证；不分享账号密码。免费账号签名通常约 7 天有效，需续签。支持情况和服务端认证随版本变化，应现场核验。

本次现场记录：Sideloadly 0.71.1 在 Apple 登录阶段遇到 -80046；改用 iLoader 2.4.0 后登录、签名、安装完成。此记录不保证该版本永久可用。它们是第三方工具，会处理凭据；本仓库不分发其安装器，也不要求付费签名、购买会员或关闭 2FA。

- [iLoader 官方站点](https://iloader.app/)
- [iLoader 官方发布](https://github.com/nab138/iloader/releases)
- [Sideloadly 官方站点](https://sideloadly.io/)
- [Apple 账号与免费开发能力](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Xcode 官方系统要求](https://developer.apple.com/xcode/system-requirements/)

USB 连接并信任电脑，选择目标手机，导入本地生成的 IPA 后签名安装。安装器报告完成后，在手机“设置 → 通用 → VPN 与设备管理”信任自己的开发者证书，打开 RPA Camera 并允许相机权限。iOS 15 不需要 iOS 16 才引入的 Developer Mode 开关。

覆盖安装需使用一致的签名账号和最终 Bundle ID 才有机会保留本地配置；不要先卸载。若 Token 改变，重新读取 App 显示值。

当前界面已加入竖向 ScrollView，解决小屏幕无法看到启动按钮的问题。停止/启动和前后台行为应在实际手机上验证。
