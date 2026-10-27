import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models.dart';
import '../l10n.dart';
import '../services/api.dart';
import '../widgets/status_badge.dart';
import '../widgets/history_chart.dart';
import 'diagnostics.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({
    super.key,
    required this.instance,
    required this.monitor,
    this.offline = false,
  });
  final Instance instance;
  final Json monitor;
  final bool offline;
  @override
  State<MonitorScreen> createState() => _MonitorState();
}

class _MonitorState extends State<MonitorScreen> {
  late Json monitor;
  Json history = {};
  List<Json> nodes = [];
  String error = '';
  int hours = 24;
  bool loading = false;
  bool fresh = false;
  Timer? timer;
  Api get api => Api(widget.instance.url, widget.instance.token);
  @override
  void initState() {
    super.initState();
    monitor = widget.monitor;
    refresh();
    timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    try {
      final values = await Future.wait([
        api.request('/monitors/${monitor['id']}/history?hours=$hours'),
        api.request('/nodes'),
        api.request('/monitors'),
      ]);
      if (mounted) {
        setState(() {
          history = object(values[0]);
          nodes = objects(values[1]);
          monitor = objects(
            values[2],
          ).firstWhere((m) => m['id'] == monitor['id'], orElse: () => monitor);
          error = '';
          fresh = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      loading = false;
    }
  }

  Future<void> recheck() async {
    try {
      final jobs = objects(
        await api.request(
          '/diagnostics',
          method: 'POST',
          body: {'monitor_id': monitor['id']},
        ),
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DiagnosticsScreen(instance: widget.instance, jobs: jobs),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  String nodeName(dynamic id) =>
      nodes
          .where((n) => n['id'] == id)
          .map((n) => n['name'] as String)
          .firstOrNull ??
      id.toString();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(monitor['name'] as String),
      actions: [
        if (widget.instance.canEdit)
          IconButton(
            onPressed: error.isEmpty && fresh ? recheck : null,
            icon: const Icon(Icons.replay),
            tooltip: tr(context, 'Recheck now', '立即复查'),
          ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            object(monitor['check'])['target'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(
              monitor['maintenance'] == true
                  ? 'maintenance'
                  : monitor['status'] as String,
            ),
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${tr(context, 'Offline / last state', '离线 / 最后状态')}: $error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1h')),
              ButtonSegment(value: 24, label: Text('24h')),
              ButtonSegment(value: 168, label: Text('7d')),
              ButtonSegment(value: 720, label: Text('30d')),
            ],
            selected: {hours},
            onSelectionChanged: (v) {
              setState(() => hours = v.first);
              refresh();
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: HistoryChart(
                buckets: objects(history['buckets']),
                width: history['bucket_seconds'] as int? ?? 300,
              ),
            ),
          ),
          ...objects(history['summary']).map(
            (s) => Card(
              child: ListTile(
                title: Text(nodeName(s['node_id'])),
                subtitle: Text(
                  '${tr(context, 'Availability', '可用率')} ${percent(s['availability'])}  ·  ${tr(context, 'Coverage', '覆盖率')} ${percent(s['coverage'])}\n${tr(context, 'Samples', '样本')} ${s['success']} / ${s['failed']} / ${s['errors']}',
                ),
                isThreeLine: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(context, 'Latest evidence', '最近证据'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ...objects(monitor['states']).map(
            (s) => Card(
              child: ExpansionTile(
                title: Text(nodeName(s['node_id'])),
                subtitle: Text(timeText(s['last_at'])),
                trailing: StatusBadge(s['status'] as String),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(s['result']),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(context, 'Recent samples', '最近检测'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ...objects(history['results'])
              .take(30)
              .map(
                (r) => ListTile(
                  title: Text(nodeName(r['node_id'])),
                  subtitle: Text(
                    '${timeText(r['scheduled_at'])} · ${r['latency_ms'] ?? '—'} ms\n${r['error'] ?? ''}',
                  ),
                  trailing: StatusBadge(r['status'] as String),
                ),
              ),
        ],
      ),
    ),
  );
}
