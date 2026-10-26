# iPhone RPA Camera

将闲置 iPhone 作为局域网按需拍照设备。原生 Swift App 收到一次有效请求才拍摄一张新的 JPEG，Mac / Windows 使用同一个 Python 标准库客户端拉取照片。适合作为本地 RPA 的 Camera Adapter 候选。

## 已验证状态

- iPhone 7 Plus / iOS 15.8.6、Mac：真实 JPEG 4032×3024；12 连拍 12/12 成功；停止后明确失败，重启后恢复；错误 Token 返回 403。
- 连拍延迟 p50 0.555 秒、p95 1.236 秒。这是单次现场 POC，不能推断所有网络或设备都达到该性能。
- Windows：**NOT_RUN**；提供相同客户端和复现步骤，未声称 Windows 实测通过。
- 尚未接入微信 Reader、OCR、ESP32 或业务状态机。

## 工程结构

```text
iOS/                     SwiftUI + AVFoundation + Network 服务端
Host/poll_snapshots.py    Mac / Windows Python 客户端
tests/test_receiver.py   不依赖真机的 4 项客户端测试
build_free_ipa.command   编译并打包未签名 IPA
build_unsigned_archive.command
docs/                    安装、协议、验收、Windows、隐私和历史文档
```

## 快速开始

1. 按 [安装说明](docs/INSTALL.md) 编译、自行签名并安装 App。
2. 手机与电脑加入同一可信 Wi-Fi；打开 App，允许相机权限，点击“启动局域网拍照服务”。页面支持上下滚动。保持 App 前台、手机解锁；USB 可用于供电。
3. 从手机设置确认当前私有 IPv4，从 App 取得 Token。不要把 Token 放在 URL、Git 或公开日志中。
4. 在同一个 Mac shell 会话执行（地址是示例，请替换）：

```bash
export RPA_CAMERA_URL='http://192.168.0.10:8080'
read -r -s -p 'Camera Token: ' RPA_SNAPSHOT_TOKEN; echo
export RPA_SNAPSHOT_TOKEN
export NO_PROXY='192.168.0.10,localhost,127.0.0.1'
python3 Host/poll_snapshots.py --url "$RPA_CAMERA_URL" --count 1 --output latest.jpg
python3 Host/poll_snapshots.py --url "$RPA_CAMERA_URL" --interval 5 --count 12 --output latest.jpg --archive evidence/frames --log evidence/poll.jsonl
unset RPA_SNAPSHOT_TOKEN
```

上述隐藏输入语法适用于 Bash；若默认终端是 zsh，请先运行 `bash`。客户端需要 Python **3.10+**，无需 pip 安装。

```bash
python3 -m unittest discover -s tests -v
```

接口仅为 `GET /shot.jpg`，请求头 `X-RPA-Token`；不支持 `/snapshot.jpg` 或查询参数 Token。失败时客户端返回非零退出码并保留旧照片，调用方必须检查成功状态，不能仅凭 latest.jpg 存在判断拍摄成功。

## 文档

- [编译与免费签名安装](docs/INSTALL.md)
- [HTTP 协议与故障排查](docs/PROTOCOL.md)
- [真实 iPhone G0 验收报告（脱敏版）](docs/G0_REAL_IPHONE_REPORT.md)
- [可复现的验收流程](docs/ACCEPTANCE.md)
- [Surface Windows 复现](docs/WINDOWS_G0_STEPS.md)
- [公开仓库隐私处理](docs/PRIVACY.md)
- [历史交付说明](docs/archive/)

HTTP Token 以明文在 LAN 传输，只在可信私有网络使用，不开放公网端口。App 离开前台会停止服务。免费 Personal Team 签名通常约 7 天需续签；Token 本身没有实现 7 天自动失效。此项目是 POC，不能当作免维护的生产摄像头方案。
