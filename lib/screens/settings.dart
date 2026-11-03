import 'package:flutter/material.dart';

import '../localization.dart';
import '../services/instances.dart';
import '../services/push.dart';
import 'admin_resources.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message(context, 'mSaveda841'))));
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
          message(context, 'mInstanceDevice9b94'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        for (final entry in [
          ('/settings', 'mInstanceSettingsccf9'),
          ('/status', 'mPublicStatusPagecf35'),
          ('/nodes', 'mNodeManagement29e4'),
          ('/diagnostics', 'mDiagnostics9e30'),
          ('/maintenance', 'mMaintenanceWindowseba5'),
          if (i.canEdit) ('/deliveries', 'mNotificationDeliveries6afd'),
          if (i.role == 'admin') ('/channels', 'mNotificationChannels7bf8'),
          if (i.role == 'admin') ('/users', 'mMembers1266'),
          if (i.role == 'admin') ('/audit', 'mAuditLogc987'),
          ('/auth/sessions', 'mSessionsAndPairing9681'),
          ('/devices', 'mDevices1329'),
        ])
          ListTile(
            title: Text(message(context, entry.$2)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminResources(
                  instance: i,
                  resource: entry.$1,
                  title: message(context, entry.$2),
                ),
              ),
            ),
          ),

        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(i.url),
                subtitle: Text('${i.username} - ${i.role}'),
              ),
              ListTile(
                title: Text(message(context, 'mSessionExpires8b18')),
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
                title: Text(message(context, 'mIncidentNotificationsf0ab')),
                subtitle: Text(
                  pushEnabled
                      ? message(
                          context,
                          'mOnlyThisDeviceRegistrationIsChanged44cd',
                        )
                      : message(context, 'mFCMIsNotConfiguredInThis8c5a'),
                ),
              ),
            ],
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: Text(message(context, 'mDisconnectThisInstance21c1')),
            subtitle: Text(
              message(context, 'mRevokeTheSessionAndRemoveLocal76df'),
            ),
            onTap: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(message(c, 'mDisconnect72bf')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(message(c, 'mCancel5f4d')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(message(c, 'mDisconnect6e12')),
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
        Text(message(context, 'mProbelune011GPL3283e')),
      ],
    );
  }
}
