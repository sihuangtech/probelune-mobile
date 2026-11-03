import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/export.dart';
import '../widgets/availability_history.dart';

import 'dart:convert';

import '../l10n.dart';
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
          title: Text(tr(c, 'Confirm action', '确认操作')),
          content: Text(
            tr(c, 'This changes the selected resource.', '此操作将修改选中的资源。'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr(c, 'Cancel', '取消')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr(c, 'Confirm', '确认')),
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
            title: Text(tr(c, 'Credential', '凭据')),
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
                child: Text(tr(c, 'Done', '完成')),
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
          EditField('name', 'Name', '名称'),
          EditField('region', 'Region', '地区'),
          EditField('network', 'Network', '网络'),
          EditField(
            'policy.allow_cidrs',
            'Allowed destination CIDRs (one per line)',
            '允许探测的 CIDR（每行一个）',
            kind: 'list',
          ),
          EditField('enabled', 'Enabled', '启用', kind: 'bool'),
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
          EditField('name', 'Name', '名称'),
          EditField('type', 'Type', '类型', options: ['webhook', 'smtp', 'push']),
          EditField('url', 'Webhook URL', 'Webhook 地址'),
          EditField('smtp_host', 'SMTP host', 'SMTP 主机'),
          EditField('smtp_port', 'SMTP port', 'SMTP 端口', kind: 'int'),
          EditField(
            'tls_mode',
            'TLS mode',
            'TLS 模式',
            options: ['starttls', 'tls'],
          ),
          EditField('username', 'Username', '用户名'),
          EditField(
            'password',
            'Password (blank to preserve)',
            '密码（留空保留原值）',
            kind: 'secret',
          ),
          EditField('from', 'From', '发件人'),
          EditField('to', 'To', '收件人'),
          EditField(
            'policy.allow_cidrs',
            'Allowed destination CIDRs',
            '允许访问的 CIDR',
            kind: 'list',
          ),
          EditField(
            'reminder_minutes',
            'Reminder interval (minutes, 0 disables)',
            '提醒间隔（分钟，0 禁用）',
            kind: 'int',
          ),
          EditField('enabled', 'Enabled', '启用', kind: 'bool'),
        ];
      case '/maintenance':
        value = {
          'name': '',
          'monitor_ids': <String>[],
          'start': now,
          'end': now + 3600,
        };
        fields = const [
          EditField('name', 'Name', '名称'),
          EditField(
            'monitor_ids',
            'Monitors (empty means all)',
            '监测（不选则为全部）',
            kind: 'list',
          ),
          EditField('start', 'Start', '开始时间', kind: 'date'),
          EditField('end', 'End', '结束时间', kind: 'date'),
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
          EditField('username', 'Username', '用户名'),
          EditField(
            'password',
            'Password (blank to preserve)',
            '密码（留空保留原值）',
            kind: 'secret',
          ),
          EditField(
            'role',
            'Role',
            '角色',
            options: ['viewer', 'operator', 'admin'],
          ),
          EditField('disabled', 'Disabled', '禁用', kind: 'bool'),
        ];
      case '/settings':
        value = rows.first;
        method = 'PUT';
        fields = const [
          EditField('name', 'Instance name', '面板名称'),
          EditField('public_url', 'Public URL', '面板地址'),
          EditField('timezone', 'Timezone', '时区'),
          EditField(
            'raw_days',
            'Raw data retention (days)',
            '原始数据保留天数',
            kind: 'int',
          ),
          EditField(
            'event_days',
            'Event retention (days)',
            '事件保留天数',
            kind: 'int',
          ),
          EditField(
            'public_status',
            'Public status page',
            '公开状态页',
            kind: 'bool',
          ),
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
            const EditField('node_ids', 'Probe sources', '探测来源', kind: 'list'),
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
          '${tr(context, 'Last heartbeat', '最近心跳')} ${timeText(row['last_seen'])}',
        );
        lines.add(
          '${tr(context, 'Allowed destinations', '允许探测的地址')} ${object(row['policy'])['allow_cidrs'] ?? []}',
        );
      case '/channels':
        lines.add(
          '${row['type']}  ${row['type'] == 'smtp' ? row['smtp_host'] : row['url'] ?? ''}',
        );
        lines.add(
          '${tr(context, 'Reminder minutes', '提醒间隔（分钟）')} ${row['reminder_minutes'] ?? 0}',
        );
      case '/maintenance':
        lines.add('${timeText(row['start'])} — ${timeText(row['end'])}');
        final ids = row['monitor_ids'] as List? ?? [];
        lines.add(
          ids.isEmpty
              ? tr(context, 'All monitors', '全部监测')
              : monitors
                    .where((m) => ids.contains(m['id']))
                    .map((m) => m['name'])
                    .join(' / '),
        );
      case '/users':
        lines.add('${row['role']}');
      case '/auth/sessions':
        lines.add(
          '${tr(context, 'Expires', '到期时间')} ${timeText(row['expires'])}',
        );
      case '/devices':
        lines.add(timeText(row['created_at']));
      case '/deliveries':
        lines.add('${tr(context, 'Attempts', '尝试次数')} ${row['attempts']}');
        lines.add(timeText(row['created_at']));
        if ('${row['error'] ?? ''}'.isNotEmpty) lines.add('${row['error']}');
      case '/audit':
        lines.add('${row['user']}  ${row['resource']}');
        lines.add(timeText(row['at']));
      case '/settings':
        lines.add('${row['public_url']}');
        lines.add('${tr(context, 'Timezone', '时区')} ${row['timezone']}');
        lines.add(
          '${tr(context, 'Raw data / event retention days', '原始数据 / 事件保留天数')} ${row['raw_days']} / ${row['event_days']}',
        );
        lines.add(
          '${tr(context, 'Public status', '公开状态页')} ${row['public_status'] == true ? tr(context, 'Enabled', '启用') : tr(context, 'Disabled', '禁用')}',
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
            tooltip: tr(context, 'Export data', '导出数据'),
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
            tooltip: tr(context, 'Add', '添加'),
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
                child: Text(tr(context, 'Create pairing code', '生成配对码')),
              ),
            if (rows.isEmpty && !loading)
              Text(tr(context, 'No entries', '暂无记录')),
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
                                  child: Text(tr(context, 'Edit', '编辑')),
                                ),
                              if (widget.resource == '/channels' && admin)
                                TextButton(
                                  onPressed: () => action(
                                    '/channels/$id/test',
                                    'POST',
                                    body: {},
                                  ),
                                  child: Text(tr(context, 'Send test', '发送测试')),
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
                                    tr(context, 'Rotate credentials', '轮换凭据'),
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
                                    tr(context, 'Revoke credentials', '撤销凭据'),
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
                                  child: Text(tr(context, 'Remove', '移除')),
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
                                  child: Text(tr(context, 'Results', '结果')),
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
