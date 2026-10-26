> 历史交付说明（已脱敏）。其中工具链兼容表、第三方工具版本和“尚未验收”等状态是当时记录；当前已完成的实测以 docs/G0_REAL_IPHONE_REPORT.md 为准。

# Codex Desktop：自有 iPhone 7 Plus 摄像头 G0 POC 最小任务

不要搜索或购买任何付费/内购摄像头 App；不要动 ESP32 以及微信 RPA 主业务流程。只验证 `iOS/` 与 `Host/` 现有自有代码。

## 目标
1. 使用 iPhone 7 Plus 原生后置摄像头按需拍摄真实 JPEG（每 5–10 秒一张，或主机即时请求）。
2. Mac 与 Windows 使用同一个 `Host/poll_snapshots.py`，只变更 host URL 和设备配置。
3. 不需要直播、摄像头驱动、付费软件、Camo 或 iOS 后台摄像头权限。

## 先决关卡——开发设备兼容性
用户现有 macOS 27，Finder 能看到 iPhone 7 Plus UDID，但 Xcode 找不到；Apple 官方 Xcode 27 真机 iOS 17+，Xcode 26.5 可支持 iOS 15，但 macOS 27 不在其官方支持主机范围。
先读取 `xcodebuild -version`、`xcode-select -p`、Mac OS 与 `xcrun devicectl list devices`，判断是否存在可以真正面向 iOS 15 签名/安装的兼容组合。不反复尝试无效数据线步骤，不声称只调 Bundle Identifier 就能修好设备兼容性。若没有可用安装路径：明确出具 BLOCKED_DEVICE_TOOLCHAIN，不假造真机 PASS。不要绕过 iOS 安全机制。

## 实现/验收
- 复用当前 Swift + Network + AVCapturePhotoOutput；重点检查 iOS 15 API、Local Network 权限、权限拒绝、前台/锁屏行为。
- 保持 `GET /shot.jpg` + `X-RPA-Token` 协议不变；同请求不重用旧 JPEG；每次返回唯一 capture_id/时刻。
- 先运行 `python3 -m unittest discover -s tests -v`。
- 真机安装成功后先单拍，再 Mac 12 张，接着 Windows 12 张；保存每次响应状态、JPEG 信息和延迟。
- 检查真实 OCR：拍中文 8–10pt/常规字，记录光学质量，不要因手机像素数高就默认胜过已成功 USB 摄像头。
- 交付 `G0_CAMERA_REPORT.md` 与相机证据；并将此 source 作为微信 POC CameraSource 接口候选，不立即重写 Reader。

## 禁止
- 不扩展 iPhone UI 为产品，不加入用户管理、账号、云端计费等。
- 不购买开发者会员，不购买 App Store 软件。
- 不以模拟 HTTP 单测代表 iPhone 实测。
- 不将签名有效期 7 天的 Personal Team 路线宣传为免维护生产方案。
