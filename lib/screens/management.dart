import 'dart:convert';

import 'package:flutter/material.dart';

import '../models.dart';
import '../localization.dart';
import '../services/api.dart';
import 'resource_editor.dart';

const checkFields = [
  EditField(
    'check.type',
    'mType5196',
    options: ['tcp', 'udp', 'ping', 'http', 'dns', 'mtr', 'traceroute'],
  ),
  EditField('check.target', 'mTargetb918'),
  EditField('check.port', 'mPortcda2', kind: 'int'),
  EditField('check.timeout', 'mTimeoutSeconds3df8', kind: 'int'),
  EditField('check.family', 'mIPFamily75d7', options: ['auto', 'ipv4', 'ipv6']),
  EditField('check.retries', 'mRetries8fcf', kind: 'int'),
  EditField('check.method', 'mHTTPMethodaa0d', options: ['GET', 'HEAD']),
  EditField('check.expected_status', 'mExpectedHTTPStatus7f94', kind: 'int'),
  EditField('check.contains', 'mResponseContains0db8'),
  EditField(
    'check.certificate_min_days',
    'mMinimumCertificateDayse78c',
    kind: 'int',
  ),
  EditField('check.follow_redirects', 'mFollowRedirectsf007', kind: 'bool'),
  EditField('check.insecure_tls', 'mSkipTLSVerification1e1d', kind: 'bool'),
  EditField('check.headers', 'mHTTPHeadersJSONc5cd', kind: 'json'),
  EditField('check.udp_encoding', 'mUDPEncodinga956', options: ['text', 'hex']),
  EditField('check.udp_payload', 'mUDPPayload5a91'),
  EditField('check.udp_expected', 'mExpectedUDPResponse7625'),
  EditField(
    'check.dns_record',
    'mDNSRecord6c34',
    options: ['A', 'AAAA', 'CNAME', 'MX', 'TXT', 'NS', 'SOA'],
  ),
  EditField('check.resolver', 'mDNSResolverf2a1'),
  EditField('check.expected_dns', 'mExpectedDNSAnswerec4a'),
  EditField('check.count', 'mPacketCount8ee8', kind: 'int'),
  EditField('check.size', 'mPacketSize4fa1', kind: 'int'),
  EditField('check.max_loss', 'mMaximumLossbd48', kind: 'int'),
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
    title: message(context, 'mMonitorConfigurationfc0e'),
    value: value,
    choices: choices,
    hint: panelName == null
        ? null
        : '${message(context, 'mProbeSource339f')} $panelName',
    path: '/monitors${value['id'] == null ? '' : '/${value['id']}'}',
    method: value['id'] == null ? 'POST' : 'PUT',
    fields: [
      const EditField('name', 'mName0f2c'),
      const EditField('group', 'mGroupf7c7'),
      const EditField(
        'check.type',
        'mType5196',
        options: ['tcp', 'udp', 'ping', 'http', 'dns'],
      ),
      ...checkFields.where((f) => f.key != 'check.type'),
      const EditField('interval', 'mIntervalSeconds640f', kind: 'int'),
      const EditField('fail_threshold', 'mFailureThreshold193c', kind: 'int'),
      const EditField(
        'recover_threshold',
        'mRecoveryThresholde504',
        kind: 'int',
      ),
      if (panelName == null)
        const EditField(
          'min_failed_nodes',
          'mMinimumFailingSources8cbe',
          kind: 'int',
        ),
      const EditField('tags', 'mTagsOnePerLine1cb5', kind: 'list'),
      if (panelName == null)
        const EditField('node_ids', 'mProbeSource339f', kind: 'list'),
      if (instance.role == 'admin')
        const EditField(
          'channel_ids',
          'mNotificationChannels7bf8',
          kind: 'list',
        ),
      const EditField('enabled', 'mEnabled2faa', kind: 'bool'),
      const EditField('public', 'mPublicStatus52b7', kind: 'bool'),
    ],
  );
}
