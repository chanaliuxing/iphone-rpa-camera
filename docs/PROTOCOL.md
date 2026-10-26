# HTTP 协议与诊断

基础 URL：`http://<IPHONE_PRIVATE_IPV4>:8080`。

请求：`GET /shot.jpg`，头部 `X-RPA-Token: <APP_TOKEN>`。Token 大小写敏感。服务端每次有效请求调用 AVCapturePhotoOutput.capturePhoto；没有直播接口、缓存照片接口或 URL Token 参数。

成功响应：HTTP 200，Content-Type: image/jpeg，Content-Length，Cache-Control: no-store，X-Capture-Id，X-Captured-At。客户端校验 ID/时间头、JPEG 起止标记与 20 MB 大小上限，使用原子替换保存。Capture ID 是随机 UUID，不应单独作为新画面的完整证明，验收需移动场景并查看图像内容。

| 结果 | 排查 |
|---|---|
| Connection refused / timeout | 手机当前 Wi-Fi 地址、服务是否启动、App 前台、同 LAN、访客隔离、VPN |
| 403 | 请求头是否存在、Token 是否与 App 完全一致 |
| 404 | 只支持 GET /shot.jpg |
| 429 | 已有拍照处理中，保持单一客户端 |
| 503 | 相机未运行，确认 App 状态 |
| 504 | 采集超过 15 秒，核对前台状态和相机负载 |
| curl 成功 Python 失败 | 同一环境变量、URL、系统代理与 NO_PROXY |

不以 ping 决定相机可用性；以真实 HTTP 响应与 JPEG 为准。没有弹出“本地网络”权限不单独计为失败，先测试入站 HTTP。

App 切到非 active 状态会停止服务。成功启动时禁止自动锁屏，停止时恢复系统自动锁屏行为。失败后磁盘上的 latest.jpg 是旧成功样本，只有新的 status=ok 才可供下游当作新照片。
