import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/instances.dart';
import '../services/push.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen(this.instances, this.push, {super.key});
  final Instances instances;
  final PushService push;
  Future<void> action(
    BuildContext context,
    Future<void> Function() task,
  ) async {
    try {
      await task();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(context, 'Saved', '已保存'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = instances.current!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr(context, 'Instance & device', '实例与设备'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(i.url),
                subtitle: Text('${i.username} · ${i.role}'),
              ),
              ListTile(
                title: Text(tr(context, 'Session expires', '会话到期')),
                subtitle: Text(timeText(i.expires)),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: i.deviceId.isNotEmpty,
                onChanged: pushEnabled
                    ? (v) => action(
                        context,
                        () => v
                            ? push.register(instances)
                            : push.unregister(instances),
                      )
                    : null,
                title: Text(tr(context, 'Incident notifications', '故障推送')),
                subtitle: Text(
                  pushEnabled
                      ? tr(
                          context,
                          'Only this device registration is changed.',
                          '仅修改本设备在当前实例的注册。',
                        )
                      : tr(
                          context,
                          'FCM is not configured in this build.',
                          '当前构建尚未配置 FCM。',
                        ),
                ),
              ),
            ],
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: Text(tr(context, 'Disconnect this instance', '断开当前实例')),
            subtitle: Text(
              tr(
                context,
                'Revoke the session and remove local credentials and cache.',
                '撤销会话并清除本地凭据与缓存。',
              ),
            ),
            onTap: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(tr(c, 'Disconnect?', '断开连接？')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(tr(c, 'Cancel', '取消')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(tr(c, 'Disconnect', '断开')),
                    ),
                  ],
                ),
              );
              if (yes == true && context.mounted) {
                await action(context, () => instances.remove(i));
              }
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          tr(
            context,
            'Probelune 0.1.0 · GPL-3.0\nMonitoring configuration is managed in the web dashboard. Mobile provides observation, incident handling and rechecks.',
            '巡汐 0.1.0 · GPL-3.0\n监测配置在网页面板管理，移动端负责观测、故障处置和复查。',
          ),
        ),
      ],
    );
  }
}
