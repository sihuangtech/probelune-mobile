import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/export.dart';
import '../widgets/availability_history.dart';

import 'dart:convert';

import '../localization.dart';
import '../models.dart';
import '../services/api.dart';
import 'resource_editor.dart';
import 'management.dart';
import 'diagnostics.dart';
import '../widgets/status_badge.dart';

class AdminResources extends StatefulWidget {
  const AdminResources({
    super.key,
    required this.instance,
    required this.resource,
    required this.title,
  });
  final Instance instance;
  final String resource, title;
  @override
  State<AdminResources> createState() => _AdminResourcesState();
}

class _AdminResourcesState extends State<AdminResources> {
  List<Json> rows = [], nodes = [], monitors = [];
  String error = '';
  bool loading = false;
  Api get api => Api(widget.instance.url, widget.instance.token);
  bool get admin => widget.instance.role == 'admin';
  bool get edit => widget.instance.canEdit;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final response = await api.request(widget.resource);
      final selections = await Future.wait([
        api.request('/nodes'),
        api.request('/monitors'),
      ]);
      if (mounted) {
        setState(() {
          rows = response is List
              ? objects(response)
              : widget.resource == '/status'
              ? objects(object(response)['monitors'])
              : [object(response)];
          nodes = objects(selections[0]);
          monitors = objects(selections[1]);
          error = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> action(
    String path,
    String method, {
    Json? body,
    bool confirm = false,
  }) async {
    if (confirm) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(message(c, 'mConfirmActionab35')),
          content: Text(message(c, 'mThisChangesTheSelectedResourced5e4')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(message(c, 'mCancel5f4d')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(message(c, 'mConfirm5ef9')),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    try {
      final result = object(
        await api.request(path, method: method, body: body),
      );
      if (!mounted) return;
      if (result['registration_token'] != null || result['code'] != null) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(message(c, 'mCredentiale88d')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (result['code'] is String)
                    QrImageView(
                      data: jsonEncode({
                        'type': 'probelune-pair',
                        'version': 1,
                        'url': widget.instance.url,
                        'code': result['code'],
                      }),
                      size: 220,
                    ),
                  SelectableText(
                    '${result['registration_token'] ?? result['code']}\n${timeText(result['expires'])}',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(message(c, 'mDone4bc2')),
              ),
            ],
          ),
        );
      }
      await refresh();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> configure([Json? row]) async {
    final kind = widget.resource;
    Json value = {...?row};
    List<EditField> fields = [];
    String path = kind, method = row == null ? 'POST' : 'PUT';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    switch (kind) {
      case '/nodes':
        value = {
          'name': '',
          'region': '',
          'network': '',
          'enabled': true,
          'policy': {'allow_cidrs': <String>[]},
          ...?row,
        };
        fields = const [
          EditField('name', 'mName0f2c'),
          EditField('region', 'mRegion940c'),
          EditField('network', 'mNetworkb4a4'),
          EditField(
            'policy.allow_cidrs',
            'mAllowedDestinationCIDRsOnePerLinecde0',
            kind: 'list',
          ),
          EditField('enabled', 'mEnabled2faa', kind: 'bool'),
        ];
      case '/channels':
        value = {
          'type': 'webhook',
          'name': '',
          'enabled': true,
          'reminder_minutes': 0,
          'url': '',
          'smtp_host': '',
          'smtp_port': 587,
          'tls_mode': 'starttls',
          'username': '',
          'password': '',
          'from': '',
          'to': '',
          'policy': {'allow_cidrs': <String>[]},
          ...?row,
        };
        fields = const [
          EditField('name', 'mName0f2c'),
          EditField('type', 'mType5196', options: ['webhook', 'smtp', 'push']),
          EditField('url', 'mWebhookURLb6b0'),
          EditField('smtp_host', 'mSMTPHostaeea'),
          EditField('smtp_port', 'mSMTPPort71b0', kind: 'int'),
          EditField('tls_mode', 'mTLSMode4cfa', options: ['starttls', 'tls']),
          EditField('username', 'mUsernamede33'),
          EditField('password', 'mPasswordBlankToPreservecc40', kind: 'secret'),
          EditField('from', 'mFrom107e'),
          EditField('to', 'mTo9c63'),
          EditField(
            'policy.allow_cidrs',
            'mAllowedDestinationCIDRs02da',
            kind: 'list',
          ),
          EditField(
            'reminder_minutes',
            'mReminderIntervalMinutes0Disables167e',
            kind: 'int',
          ),
          EditField('enabled', 'mEnabled2faa', kind: 'bool'),
        ];
      case '/maintenance':
        value = {
          'name': '',
          'monitor_ids': <String>[],
          'start': now,
          'end': now + 3600,
        };
        fields = const [
          EditField('name', 'mName0f2c'),
          EditField('monitor_ids', 'mMonitorsEmptyMeansAllb675', kind: 'list'),
          EditField('start', 'mStart12e8', kind: 'date'),
          EditField('end', 'mEndb8a1', kind: 'date'),
        ];
      case '/users':
        value = {
          'username': '',
          'role': 'viewer',
          'disabled': false,
          ...?row,
          'password': '',
        };
        fields = const [
          EditField('username', 'mUsernamede33'),
          EditField('password', 'mPasswordBlankToPreservecc40', kind: 'secret'),
          EditField(
            'role',
            'mRole3657',
            options: ['viewer', 'operator', 'admin'],
          ),
          EditField('disabled', 'mDisabledf8cb', kind: 'bool'),
        ];
      case '/settings':
        value = rows.first;
        method = 'PUT';
        fields = const [
          EditField('name', 'mInstanceName6d10'),
          EditField('public_url', 'mPublicURLfcdb'),
          EditField('timezone', 'mTimezone1b5e'),
          EditField('raw_days', 'mRawDataRetentionDays373a', kind: 'int'),
          EditField('event_days', 'mEventRetentionDays3d64', kind: 'int'),
          EditField('public_status', 'mPublicStatusPagecf35', kind: 'bool'),
        ];
      case '/diagnostics':
        value = {'check': defaultCheck(), 'node_ids': <String>[]};
        final panel = nodes
            .where((n) => n['role'] == 'panel' && n['revoked'] != true)
            .firstOrNull;
        if (panel != null) value['node_ids'] = [panel['id']];
        fields = [
          ...checkFields,
          if (panel == null)
            const EditField('node_ids', 'mProbeSources82d6', kind: 'list'),
        ];
    }
    if (row != null &&
        !['/settings', '/maintenance', '/diagnostics'].contains(kind)) {
      path += '/${row['id']}';
    }
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ResourceEditor(
          instance: widget.instance,
          title: widget.title,
          value: value,
          fields: fields,
          path: path,
          method: method,
          choices: {
            'monitor_ids': {
              for (final m in monitors) m['id'] as String: m['name'] as String,
            },
            'node_ids': {
              for (final n in nodes.where((n) => n['revoked'] != true))
                n['id'] as String: n['name'] as String,
            },
          },
        ),
      ),
    );
    if (result == true) await refresh();
  }

  bool get canCreate => switch (widget.resource) {
    '/nodes' || '/channels' || '/users' => admin,
    '/maintenance' || '/diagnostics' => edit,
    _ => false,
  };
  String title(Json row) =>
      '${row['name'] ?? row['username'] ?? row['device'] ?? row['platform'] ?? row['kind'] ?? row['action'] ?? widget.title}';
  Widget details(Json row) {
    final kind = widget.resource;
    final lines = <String>[];
    switch (kind) {
      case '/nodes':
        lines.add('${row['region'] ?? ''}  ${row['network'] ?? ''}');
        lines.add(
          '${message(context, 'mLastHeartbeatb32b')} ${timeText(row['last_seen'])}',
        );
        lines.add(
          '${message(context, 'mAllowedDestinations17c6')} ${object(row['policy'])['allow_cidrs'] ?? []}',
        );
      case '/channels':
        lines.add(
          '${row['type']}  ${row['type'] == 'smtp' ? row['smtp_host'] : row['url'] ?? ''}',
        );
        lines.add(
          '${message(context, 'mReminderMinutes13c2')} ${row['reminder_minutes'] ?? 0}',
        );
      case '/maintenance':
        lines.add('${timeText(row['start'])} — ${timeText(row['end'])}');
        final ids = row['monitor_ids'] as List? ?? [];
        lines.add(
          ids.isEmpty
              ? message(context, 'mAllMonitors4303')
              : monitors
                    .where((m) => ids.contains(m['id']))
                    .map((m) => m['name'])
                    .join(' / '),
        );
      case '/users':
        lines.add('${row['role']}');
      case '/auth/sessions':
        lines.add(
          '${message(context, 'mExpires0c9d')} ${timeText(row['expires'])}',
        );
      case '/devices':
        lines.add(timeText(row['created_at']));
      case '/deliveries':
        lines.add('${message(context, 'mAttempts3fea')} ${row['attempts']}');
        lines.add(timeText(row['created_at']));
        if ('${row['error'] ?? ''}'.isNotEmpty) lines.add('${row['error']}');
      case '/audit':
        lines.add('${row['user']}  ${row['resource']}');
        lines.add(timeText(row['at']));
      case '/settings':
        lines.add('${row['public_url']}');
        lines.add('${message(context, 'mTimezone1b5e')} ${row['timezone']}');
        lines.add(
          '${message(context, 'mRawDataEventRetentionDays683f')} ${row['raw_days']} / ${row['event_days']}',
        );
        lines.add(
          '${message(context, 'mPublicStatus52b7')} ${row['public_status'] == true ? message(context, 'mEnabled2faa') : message(context, 'mDisabledf8cb')}',
        );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (row['status'] is String) StatusBadge(row['status'] as String),
        if (row['enabled'] is bool)
          StatusBadge(row['enabled'] == true ? 'healthy' : 'paused'),
        if (row['disabled'] is bool)
          StatusBadge(row['disabled'] == true ? 'paused' : 'healthy'),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SelectableText(line),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        Builder(
          builder: (c) => IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: message(context, 'mExportData7c6b'),
            onPressed: () => shareJson(c, 'probelune', rows),
          ),
        ),
        IconButton(
          onPressed: loading ? null : refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: canCreate
        ? FloatingActionButton(
            onPressed: () => configure(),
            tooltip: message(context, 'mAdd0453'),
            child: const Icon(Icons.add),
          )
        : null,
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (error.isNotEmpty)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (loading) const LinearProgressIndicator(),
            if (widget.resource == '/auth/sessions')
              TextButton(
                onPressed: () => action('/auth/pair', 'POST', body: {}),
                child: Text(message(context, 'mCreatePairingCoded63a')),
              ),
            if (rows.isEmpty && !loading)
              Text(message(context, 'mNoEntries0577')),
            for (final raw in rows)
              Builder(
                builder: (context) {
                  final row = widget.resource == '/channels'
                      ? object(raw['channel'])
                      : raw;
                  final id = '${row['id']}';
                  final diagnostic = widget.resource == '/diagnostics';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diagnostic
                                ? '${object(row['job'])['check'] == null ? '' : object(object(row['job'])['check'])['type']}'
                                : title(row),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          details(row),
                          if (widget.resource == '/status')
                            AvailabilityHistory(
                              instance: widget.instance,
                              monitorId: id,
                              publicStatus: true,
                              initialHistory: object(row['uptime']),
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (admin &&
                                  [
                                    '/nodes',
                                    '/channels',
                                    '/users',
                                    '/settings',
                                  ].contains(widget.resource))
                                TextButton(
                                  onPressed: () => configure(row),
                                  child: Text(message(context, 'mEditcf6b')),
                                ),
                              if (widget.resource == '/channels' && admin)
                                TextButton(
                                  onPressed: () => action(
                                    '/channels/$id/test',
                                    'POST',
                                    body: {},
                                  ),
                                  child: Text(
                                    message(context, 'mSendTestc2ec'),
                                  ),
                                ),
                              if (widget.resource == '/nodes' && admin) ...[
                                TextButton(
                                  onPressed: () => action(
                                    '/nodes/$id/credentials',
                                    'POST',
                                    body: {'revoke': false},
                                    confirm: true,
                                  ),
                                  child: Text(
                                    message(context, 'mRotateCredentialsd16e'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => action(
                                    '/nodes/$id/credentials',
                                    'POST',
                                    body: {'revoke': true},
                                    confirm: true,
                                  ),
                                  child: Text(
                                    message(context, 'mRevokeCredentials8634'),
                                  ),
                                ),
                              ],
                              if ((widget.resource == '/maintenance' && edit) ||
                                  [
                                    '/auth/sessions',
                                    '/devices',
                                  ].contains(widget.resource))
                                TextButton(
                                  onPressed: () => action(
                                    '${widget.resource}/$id',
                                    'DELETE',
                                    confirm: true,
                                  ),
                                  child: Text(message(context, 'mRemoveac5c')),
                                ),
                              if (diagnostic)
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DiagnosticsScreen(
                                        instance: widget.instance,
                                        jobs: [object(row['job'])],
                                      ),
                                    ),
                                  ),
                                  child: Text(message(context, 'mResults9278')),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}
