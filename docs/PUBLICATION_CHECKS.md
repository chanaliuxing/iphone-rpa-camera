# 公开版发布检查

- 白名单复制源码、原有测试、构建脚本和经过清理的文档，建立全新 Git 历史。
- 公开布局中的 Python 单元测试 4/4 通过，Swift 语法检查通过。
- 在公开仓库布局执行 build_free_ipa.command，archive / IPA 打包成功；最低 iOS 15.0，arm64。未因整理仓库再次安装到手机。
- 首次发布时保留 Mac 真机 GO 和 Windows NOT_RUN 的区别。后续 Windows 用户验收记录见 evidence/windows_user_acceptance.json；原 Mac 统计保留初次采集时的状态。
- 已扫描待提交文本，检查真实 Token、账号、设备标识、本地路径、实际私有 IP、签名材料与图片/安装器等。
- 提交身份使用 GitHub noreply 地址，避免公开本机 Git 邮箱。
- 编译输出、原图与原始日志不纳入 Git；公开数值证据位于 docs/evidence/。
