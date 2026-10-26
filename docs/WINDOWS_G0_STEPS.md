# Surface Windows 复现（NOT_RUN）

Windows 尚未在本次验收中实际运行。复制/克隆同一仓库，安装 Python 3.10+；不需要 pip 包或另一款 iOS App。手机和 Surface 在同一可信 Wi-Fi，手机 RPA Camera 保持前台并启动服务。

在仓库根目录运行 PowerShell（IP 为示例，替换为手机当前私有地址）：

```powershell
$secret = Read-Host 'iPhone App Token' -AsSecureString
$env:RPA_SNAPSHOT_TOKEN = [System.Net.NetworkCredential]::new('', $secret).Password
$env:NO_PROXY = '192.168.0.10,localhost,127.0.0.1'
py -3 Host\poll_snapshots.py --url 'http://192.168.0.10:8080' --interval 10 --count 5 --output latest.jpg --archive evidence\frames --log evidence\poll_win.jsonl
$LASTEXITCODE
Remove-Item Env:RPA_SNAPSHOT_TOKEN
```

核验退出码 0、5 条 status=ok、5 个不同 capture_id、5 张可打开的 JPEG，并检查移动物体后画面变化；任何失败保留日志，不虚报 PASS。不要把真实 Token、原图或含设备信息的日志上传公开仓库。
