# 巡汐 Probelune 移动端

[English](README.md) · [网页面板](https://github.com/sihuangtech/probelune-dashboard) · [产品与 PRD](https://github.com/sihuangtech/probelune)

Flutter Android/iOS 客户端，连接自托管面板，在手机查看多位置监测、处理故障并发起远程复查。手机不充当持续后台探针。

## 功能

- 多实例保存与切换，密码登录、一次性短期二维码配对。
- 总览、节点健康、监测详情、分位置证据、可用率/覆盖率与历史曲线。
- 事件时间线、确认、备注、一小时静默，由服务器校验权限。
- 手机内查看即时复查进度、各节点结果并取消未完成任务。
- 安全存储会话与最长 24 小时的总览缓存，离线时显示旧数据时间。
- 跟随系统使用中英文；可选接入自己的 Firebase/APNs 原生推送。

## 开发与构建

已验证 Flutter 3.47.8 / Dart 3.13.7。Android 需要 Android SDK/JDK，iOS 需要 macOS/Xcode。

```sh
git clone https://github.com/sihuangtech/probelune-mobile.git
cd probelune-mobile
flutter pub get
flutter analyze
flutter run
flutter build apk --debug
flutter build ios --no-codesign
```

输入面板 HTTPS 根地址；受控开发环境可显式允许 HTTP。Android 模拟器通过 `10.0.2.2` 访问电脑，真机使用局域网/VPN 地址。手机 localhost 不指向电脑。

面板“设置 → 配对移动端”的二维码两分钟有效且仅用一次，不包含密码或长期令牌。移动会话有效期 30 天，可在面板撤销。删除实例会尝试撤销远程会话和设备注册，并清除本地数据。

上述构建命令生成 Android 调试包和 iOS 无签名产物。[发布与推送说明](docs/RELEASE.md)包含正式签名、Firebase/APNs 与真机验收。发布构建不会自动回退到 debug 密钥；构建成功不代表推送送达或上架成功。

`lib/screens` 为页面，`widgets` 为复用界面，`services` 负责网络、安全存储和推送。不内置后端、不依赖同级仓库源码。依赖使用 `flutter pub add/remove/upgrade` 官方命令管理并提交锁文件。

[隐私](docs/PRIVACY.md) · [更新记录](CHANGELOG.md) · [贡献](CONTRIBUTING.md) · [安全](SECURITY.md) · [验收](https://github.com/sihuangtech/probelune/blob/main/docs/acceptance.md)

采用 [GPL-3.0-or-later](LICENSE) 开源。
