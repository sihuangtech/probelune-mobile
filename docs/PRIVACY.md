# Privacy / 隐私

The app contacts dashboard origins explicitly entered or paired by the user. Passwords are used for login; returned sessions, addresses and last-known overview snapshots use operating-system secure storage. No Probelune-operated account, analytics endpoint or cloud synchronization is bundled.

Camera permission scans one-time pairing codes. Internet/local-network permissions connect to self-hosted dashboards. Notifications are optional and require a configured build plus explicit opt-in.

With native push enabled, the dashboard registers an installation identifier and sends Firebase/APNs the event ID, instance URL, event kind and generic text. Targets, request headers and diagnostic evidence are fetched directly from the dashboard. Firebase/Apple process transport/device metadata under their terms.

删除实例会清除本地会话/缓存，并尝试撤销服务器会话和推送注册。面板不可达时远端撤销可能失败，请恢复连接后从网页设置撤销设备/会话。卸载、系统备份与 Keychain 行为由操作系统管理，不能替代服务器撤销。Android 默认禁止备份。

The dashboard operator controls retention and access. This describes the open-source implementation, not a hosted-service privacy contract. Distributors should publish contact and retention information for their own deployment.
