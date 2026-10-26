> 历史交付说明（已脱敏）。其中工具链兼容表、第三方工具版本和“尚未验收”等状态是当时记录；当前已完成的实测以 docs/G0_REAL_IPHONE_REPORT.md 为准。

# iPhone 7 Plus 免费 7 天测试：最终安装路线

## 结论

- **不需要朋友证书、付费 Apple Developer 或 Xcode 直接识别 iOS 15 真机**。
- Xcode 27 只负责编译 iOS 15 的 arm64 应用；`build_free_ipa.command` 将编译后的 `.app` 封装为 **未签名的 IPA**。
- 用 [Sideloadly 官方网站](https://sideloadly.io/) 下载的免费 macOS 应用，使用自己的免费 Apple Account 签名、安装到已连接的 iPhone 7 Plus。
- 苹果个人免费签名约 7 天，需要过期前刷新或重新安装。该软件是第三方**免费安装器**，不是收费摄像头 App。

## 1. Mac 编译打包

在当前目录：

```sh
brew install xcodegen   # 已经安装可跳过
bash ./build_free_ipa.command
```

成功后得到 `output/RPASnapshot-unsigned.ipa`。注意 `.ipa` 还未签名。
如果已经成功执行过 `build_unsigned_archive.command`，可以：

```sh
bash ./build_free_ipa.command --package-only
```

旧 Swift 编译失败已修复：`AVLayerVideoGravity.resizeAspectFit` 更正为 `resizeAspect`。如重新编译仍报错，以新日志第一处 `error:` 为准。本资料没有在本环境执行 Xcode/真机测试。

## 2. 免费签名安装

1. Mac 打开 https://sideloadly.io/ 下载免费的 Sideloadly（只从官方站点下载）。
2. 用 Lightning 数据线连接 iPhone 7 Plus，解锁并信任电脑。Finder 已经能看到手机，说明线具备数据通信能力。
3. 在 Sideloadly 里选择识别到的 iPhone 设备，拖入 `output/RPASnapshot-unsigned.ipa`。
4. 选择 Apple ID Sideload 之类的默认免费签名方式，输入**自己的** Apple Account，并按提示完成验证，点击 Start。
5. 安装后在手机 **设置 → 通用 → VPN 与设备管理**（不同 iOS 15 文字可能为“描述文件与设备管理”）中信任自己的开发者证书。
6. 打开 `RPA Camera`，允许相机权限，保持 App 前台运行；用原有 `Host/poll_snapshots.py` 从 Mac/Windows 拉 JPEG，做 5–10 秒采样测试。

⚠️ Sideloadly 是第三方程序，会处理登录凭据。官方称凭据只发送给 Apple，但无法由此独立证明软件内部实现。若不愿在第三方安装器登录常用 Apple ID，可考虑使用一个**独立且启用两步验证的测试 Apple Account**；绝不关闭安全功能，也不要向他人提供账号密码。

## 3. 已知边界

- 免费个人账号：苹果官方上限为每设备最多 3 个开发测试 App、设备/Provisioning Profile 有效期约 7 天。
- 用同一个 Apple ID + Bundle ID 续签覆盖安装，一般可保留应用数据；本相机 App 不应把重要业务数据保存在手机本地。
- Sideloadly 官方 FAQ 明示支持 iOS 15、macOS 27、无签名 IPA；但对**你这台**设备是否安装成功，仍须现场验证。
- iPhone 7 Plus 的 iOS 15 不必找 iOS 16 新增的 Developer Mode 开关。
- 不要使用 Apple Configurator 直接安装未签名 IPA；必须先签名。
- 手机上的相机 App 应一直在前台、保持供电、关闭自动锁屏以维持按需拍照服务。
- 它不是自有签名基础设施的替代：今后长期运营仍需正当分发方案。

## 4. 故障分类

- Xcode 报错：检查 `output/build.log` 第一处 `error:`，与签名无关。
- Sideloadly 不显示手机：检查设备信任和 Sideloadly 的 USB 发现，不必重复换已经能在 Finder 使用的数据线。
- Sideloadly 出现 Apple ID/Anisette 问题：按 Sideloadly 官方 FAQ；不要禁用 2FA。
- 手机提示 Untrusted Developer：进入设备管理验证自己的账号。
- 已安装但打开闪退：收集设备日志，核实最低系统版本、签名权限和相机权限。

## 5. 官方来源

- Apple free Personal Team: https://developer.apple.com/help/account/basics/about-your-developer-account
- Sideloadly free signed installs: https://sideloadly.io/faq
- Sideloadly unsigned IPA support: https://sideloadly.io/changelog
