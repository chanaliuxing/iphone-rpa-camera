# 真机 G0 验收流程

1. 运行 `python3 -m unittest discover -s tests -v`；这是本地假 HTTP 测试，不是真机通过。
2. 手机启动局域网拍照服务，确认“服务就绪”，保持前台和解锁。电脑安全读取环境变量 Token，禁止写入命令历史、公开日志和 Git。
3. curl 绕过代理，GET /shot.jpg，使用 X-RPA-Token 请求头。保存响应头和第一张 JPEG；验证 HTTP 200、image/jpeg、Capture ID / 时间头、实际 JPEG 宽高，并打开图片确认此刻场景。Token 可通过 curl `-H @-` 从进程 stdin 传入，避免出现在进程命令行。
4. 原生 Host/poll_snapshots.py 单拍 1 次，再以 5 秒间隔拍 12 次，归档每张图片和 JSONL；实际移动场景至少两次，查看前后内容变化，不只检查 ID。
5. 统计 12 次成功数、文件数/字节、全局 Capture ID 唯一性、JPEG 宽高、时间顺序、延迟 p50/p95，保留失败。
6. 人工在手机点击停止，发 1 次请求，预期非零退出码、status=error、latest.jpg 哈希不变；人工重启服务，再拍 1 张，预期恢复且新 ID/新内容。
7. 仅一次错误 Token 负测，预期 HTTP 403。
8. Mac 核心通过后，再在 Surface Windows 用同一客户端实际复现；无 Windows 会话时标为 NOT_RUN。

GO 必须同时具备真实可打开 JPEG、12 连拍及实际画面变化、停止失败与重启恢复。单元测试或安装成功不能代替这些条件。

局域网、手机屏幕和权限操作由设备持有人完成，自动化工具不能假称已操作手机。若必须改 Swift，应先获得更新安装授权，再重新构建签名安装。不要在这个阶段改微信 Reader、ESP32 或业务状态机。
