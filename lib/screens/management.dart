import 'dart:convert';

import 'package:flutter/material.dart';

import '../models.dart';
import '../l10n.dart';
import '../services/api.dart';
import 'resource_editor.dart';

const checkFields = [
  EditField(
    'check.type',
    'Type',
    '探测类型',
    options: ['tcp', 'udp', 'ping', 'http', 'dns', 'mtr', 'traceroute'],
  ),
  EditField('check.target', 'Target', '目标地址'),
  EditField('check.port', 'Port', '端口', kind: 'int'),
  EditField('check.timeout', 'Timeout (seconds)', '超时（秒）', kind: 'int'),
  EditField(
    'check.family',
    'IP family',
    'IP 协议',
    options: ['auto', 'ipv4', 'ipv6'],
  ),
  EditField('check.retries', 'Retries', '重试次数', kind: 'int'),
  EditField('check.method', 'HTTP method', 'HTTP 方法', options: ['GET', 'HEAD']),
  EditField(
    'check.expected_status',
    'Expected HTTP status',
    '期望 HTTP 状态码',
    kind: 'int',
  ),
  EditField('check.contains', 'Response contains', '响应包含'),
  EditField(
    'check.certificate_min_days',
    'Minimum certificate days',
    '证书最少剩余天数',
    kind: 'int',
  ),
  EditField(
    'check.follow_redirects',
    'Follow redirects',
    '跟随重定向',
    kind: 'bool',
  ),
  EditField(
    'check.insecure_tls',
    'Skip TLS verification',
    '跳过证书验证',
    kind: 'bool',
  ),
  EditField(
    'check.headers',
    'HTTP headers (JSON)',
    'HTTP 请求头（JSON）',
    kind: 'json',
  ),
  EditField(
    'check.udp_encoding',
    'UDP encoding',
    'UDP 编码',
    options: ['text', 'hex'],
  ),
  EditField('check.udp_payload', 'UDP payload', 'UDP 请求内容'),
  EditField('check.udp_expected', 'Expected UDP response', 'UDP 期望响应'),
  EditField(
    'check.dns_record',
    'DNS record',
    'DNS 记录',
    options: ['A', 'AAAA', 'CNAME', 'MX', 'TXT', 'NS', 'SOA'],
  ),
  EditField('check.resolver', 'DNS resolver', 'DNS 解析器'),
  EditField('check.expected_dns', 'Expected DNS answer', 'DNS 期望结果'),
  EditField('check.count', 'Packet count', '发包数', kind: 'int'),
  EditField('check.size', 'Packet size', '包大小', kind: 'int'),
  EditField('check.max_loss', 'Maximum loss (%)', '允许丢包率（%）', kind: 'int'),
];
Json defaultCheck() => {
  'type': 'http',
  'target': '',
  'port': 443,
  'timeout': 10,
  'family': 'auto',
  'retries': 0,
  'method': 'GET',
  'expected_status': 200,
  'contains': '',
  'certificate_min_days': 0,
  'follow_redirects': true,
  'insecure_tls': false,
  'udp_encoding': 'text',
  'udp_payload': '',
  'udp_expected': '',
  'dns_record': 'A',
  'resolver': '',
  'expected_dns': '',
  'count': 4,
  'size': 32,
  'max_loss': 0,
};
Future<bool?> editMonitor(
  BuildContext context,
  Instance instance, {
  Json? monitor,
  bool copy = false,
  String type = 'http',
}) async {
  final api = Api(instance.url, instance.token);
  final nodes = objects(await api.request('/nodes'));
  if (!context.mounted) return null;
  final source = nodes
      .where((n) => n['role'] == 'panel' && n['revoked'] != true)
      .firstOrNull;
  final channels = instance.role == 'admin'
      ? objects(await api.request('/channels'))
      : <Json>[];
  if (!context.mounted) return null;
  final choices = <String, Map<String, String>>{
    'node_ids': {
      for (final n in nodes.where((n) => n['revoked'] != true))
        n['id'] as String: n['name'] as String,
    },
    'channel_ids': {
      for (final c in channels)
        object(c['channel'])['id'] as String:
            object(c['channel'])['name'] as String,
    },
  };
  final v = monitor == null
      ? <String, dynamic>{
          'name': '',
          'group': '',
          'tags': [],
          'check': {...defaultCheck(), 'type': type},
          'interval': 60,
          'fail_threshold': 3,
          'recover_threshold': 2,
          'min_failed_nodes': 1,
          'enabled': true,
          'public': false,
          'node_ids': source == null ? [] : [source['id']],
          'channel_ids': [],
        }
      : object(jsonDecode(jsonEncode(monitor)));
  v['check'] = {...defaultCheck(), ...object(v['check'])};
  if (source != null) {
    v['node_ids'] = [source['id']];
    v['min_failed_nodes'] = 1;
  }
  if (copy) {
    v.remove('id');
    v['version'] = 0;
  }
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => MonitorEditorScreen(
        instance: instance,
        value: v,
        choices: choices,
        panelName: source?['name'] as String?,
      ),
    ),
  );
}

class MonitorEditorScreen extends StatelessWidget {
  const MonitorEditorScreen({
    super.key,
    required this.instance,
    required this.value,
    required this.choices,
    this.panelName,
  });
  final Instance instance;
  final String? panelName;
  final Json value;
  final Map<String, Map<String, String>> choices;
  @override
  Widget build(BuildContext context) => ResourceEditor(
    instance: instance,
    title: tr(context, 'Monitor configuration', '监测配置'),
    value: value,
    choices: choices,
    hint: panelName == null
        ? null
        : tr(context, 'Probe source: $panelName', '探测来源：$panelName'),
    path: '/monitors${value['id'] == null ? '' : '/${value['id']}'}',
    method: value['id'] == null ? 'POST' : 'PUT',
    fields: [
      const EditField('name', 'Name', '名称'),
      const EditField('group', 'Group', '分组'),
      const EditField(
        'check.type',
        'Type',
        '探测类型',
        options: ['tcp', 'udp', 'ping', 'http', 'dns'],
      ),
      ...checkFields.where((f) => f.key != 'check.type'),
      const EditField('interval', 'Interval (seconds)', '探测间隔（秒）', kind: 'int'),
      const EditField(
        'fail_threshold',
        'Failure threshold',
        '故障确认次数',
        kind: 'int',
      ),
      const EditField(
        'recover_threshold',
        'Recovery threshold',
        '恢复确认次数',
        kind: 'int',
      ),
      if (panelName == null)
        const EditField(
          'min_failed_nodes',
          'Minimum failing sources',
          '故障来源阈值',
          kind: 'int',
        ),
      const EditField('tags', 'Tags (one per line)', '标签（每行一个）', kind: 'list'),
      if (panelName == null)
        const EditField('node_ids', 'Probe source', '探测来源', kind: 'list'),
      if (instance.role == 'admin')
        const EditField(
          'channel_ids',
          'Notification channels',
          '通知渠道',
          kind: 'list',
        ),
      const EditField('enabled', 'Enabled', '启用', kind: 'bool'),
      const EditField('public', 'Public status', '公开状态', kind: 'bool'),
    ],
  );
}
