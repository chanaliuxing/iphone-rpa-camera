> 历史交付说明（已脱敏）。其中工具链兼容表、第三方工具版本和“尚未验收”等状态是当时记录；当前已完成的实测以 docs/G0_REAL_IPHONE_REPORT.md 为准。

# iPhone 7 Plus → Mac / Windows：自有源码、局域网按需拍照 POC

**原则：只使用自有源码，不购买第三方摄像头 App、不订阅云服务、不更改 ESP32。**

- iPhone 7 Plus（iOS 15）运行 `iOS/App/SnapshotCameraApp.swift`。
- 手机上的 Swift App 开一个带随机 Token 鉴权的 HTTP 服务：`GET /shot.jpg`。每收到一次请求，触发一次 `AVCapturePhotoOutput.capturePhoto`，返回新的 JPEG 和新 Capture ID，**不是直播视频或旧缓存照片**。
- Mac 和 Windows 使用相同的纯 Python 标准库客户端 `Host/poll_snapshots.py`；每隔 5–10 秒取一张，点击后可立即调用一次 `take_photo`。
- **通信走可信 Wi-Fi 局域网，不使用专属 Mac USB 转发**；Lightning 只负责充电，现有数据线可保留。iPhone 保持 App 前台、屏幕解锁。

## 开发与安装（有一个真实的兼容性阻碍）

在**能够真机部署 iOS 15 App 的受支持 Xcode + macOS 组合**上：

```bash
# 在 iOS/ 目录中
brew install xcodegen
xcodegen generate
open RPASnapshot.xcodeproj
```

Xcode 中选择 Apple Account 的免费 **Personal Team**、勾选 `Automatically manage signing`、修改唯一 Bundle Identifier、连接真机、允许相机权限，Run。

**非常重要**：历史环境中 Finder 能看到手机，但 Xcode 未发现设备。Apple 的兼容表规定 Xcode 27 真机设备支持 iOS 17 起，无法直接调试 iOS 15；Xcode 26.5 可支持 iOS 15 真机，但官方列出的主机运行系统为 macOS 26.x，用户当前 macOS 27 未包含在该支持范围内。因此，当前 Mac + Xcode 组合**不能假定能够安装**。请先处理开发设备/版本兼容性。不要用付费 Apple Developer 账号解决 Xcode 真机不兼容，也不要让用户再次检查已经在 Finder 验证过的数据线。

Apple 官方：
- https://developer.apple.com/xcode/system-requirements/
- https://developer.apple.com/help/account/basics/about-your-developer-account

免费 Personal Team 的开发 Provisioning Profile 最长 **7 天**，到期需重签/重装，因此这是实验机 POC 路线，**不适合直接声明为免维护的商业化大规模部署方案**。

## 连接与使用

1. iPhone 和电脑连接**同一可信 Wi-Fi 网络**。在 iPhone **设置 → Wi-Fi → 当前网络旁的 ⓘ**，查看手机 IP，例如 `192.168.0.10`。
2. 打开 App，允许摄像头和本地网络权限，点击“启动局域网拍照服务”。记下 App 显示的 Token。保持 App 前台、屏幕亮起、手机固定拍摄显示器。
3. 在 Mac 运行（不用任何 pip 安装）：

```bash
python3 Host/poll_snapshots.py --url http://192.168.0.10:8080 --token '手机App显示的Token' --count 1 --output latest.jpg
python3 Host/poll_snapshots.py --url http://192.168.0.10:8080 --token '手机App显示的Token' --interval 5 --count 12 --output latest.jpg --archive evidence/frames --log evidence/poll.jsonl
```

4. 在 Windows PowerShell 运行相同客户端：

```powershell
py -3 Host\poll_snapshots.py --url http://192.168.0.10:8080 --token "手机App显示的Token" --interval 10 --count 12 --output latest.jpg
```

> 把示例 IP 换成 iPhone 的真实 IP。无需任何 Mac 系统摄像头驱动，网络与输出逻辑在 Windows 一样。

## 验收（尚未真机完成）

- 单拍一张真正 JPEG，记录原图分辨率、文字清晰度、拍摄耗时。
- Mac 连续拍 12 张（5 秒间隔），每张返回不同 `X-Capture-Id`；没有超时/伪造成功。
- 同一手机切到 Surface Windows，**不改 iOS App，不改 Python 业务代码**，重复测试。
- 手机锁屏、网络断开时必须报错，不得把上一张 `latest.jpg` 当作新照片。
- 同样视场和放置条件，与现有 USB 摄像头比较 OCR 成功率。
- 微信的动作验证**不等 5 秒**；ESP32 执行后再主动拍一张。

**目前真实状态：** Python 假 HTTP 设备单元测试通过；未运行 Swift 真机编译/签名及 Mac/Windows-iPhone 网络端到端测试；不能宣称 G0 已通过。

## 安全范围

HTTP Token 在局域网明文传输：此 POC 只在自有可信网络运行；不要开放公网端口，不要在公共 Wi-Fi 使用。建议固定手机 Wi-Fi IP 或配置 DHCP Reservation。错误令牌返回 403；同时只处理一张照片请求，避免相机操作重入。图片默认本地覆盖保存，`--archive` 仅在人工开启收集证据时存多份。正式生产应使用认证且加密的传输或退回直接 USB UVC 摄像头。

**为什么这比第三方 App 更适合？** 原生静态照片、接口可控、Mac 和 Windows 一套客户端、无功能锁定和额外订阅费。但免费签名每 7 天重装是实际限制，不是“永久无需维护”。
