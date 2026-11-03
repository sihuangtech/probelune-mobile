import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
    Widget group(String title, List<(String, String, IconData)> entries) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
              child: Text(
                message(context, title),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final entry in entries)
                    ListTile(
                      leading: Icon(entry.$3),
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
                ],
              ),
            ),
          ],
        );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          message(context, 'mSettings4d92'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(i.username),
                subtitle: Text('${i.url}\n${i.role}'),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(message(context, 'mSessionExpires8b18')),
                subtitle: Text(timeText(i.expires)),
              ),
            ],
          ),
        ),
        group('mInstanceSettingsccf9', [
          ('/settings', 'mInstanceSettingsccf9', Icons.tune),
          ('/status', 'mPublicStatusPagecf35', Icons.public),
          ('/nodes', 'mNodeManagement29e4', Icons.dns_outlined),
          ('/diagnostics', 'mDiagnostics9e30', Icons.network_check),
          ('/maintenance', 'mMaintenanceWindowseba5', Icons.build_outlined),
        ]),
        if (i.canEdit)
          group('mIncidentNotificationsf0ab', [
            (
              '/deliveries',
              'mNotificationDeliveries6afd',
              Icons.outbox_outlined,
            ),
            if (i.role == 'admin')
              (
                '/channels',
                'mNotificationChannels7bf8',
                Icons.notifications_outlined,
              ),
          ]),
        group('mInstanceDevice9b94', [
          if (i.role == 'admin')
            ('/users', 'mMembers1266', Icons.people_outline),
          if (i.role == 'admin') ('/audit', 'mAuditLogc987', Icons.history),
          ('/auth/sessions', 'mSessionsAndPairing9681', Icons.key_outlined),
          ('/devices', 'mDevices1329', Icons.devices),
        ]),
        const SizedBox(height: 16),
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
        Row(
          children: [
            Expanded(
              child: Text(
                message(context, 'mProbelune011GPL3283e'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              tooltip: 'GitHub',
              icon: const FaIcon(FontAwesomeIcons.github),
              onPressed: () async {
                final uri = Uri.https(
                  'github.com',
                  '/sihuangtech/probelune-mobile',
                );
                try {
                  if (await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  )) {
                    return;
                  }
                } catch (_) {}
                if (context.mounted) {
                  showDialog<void>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('GitHub'),
                      content: SelectableText(uri.toString()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: Text(message(c, 'mDone4bc2')),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
