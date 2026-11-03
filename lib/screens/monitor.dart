import 'dart:async';
import 'dart:convert';

import '../services/export.dart';

import 'package:flutter/material.dart';

import '../models.dart';
import '../l10n.dart';
import '../services/api.dart';
import '../widgets/status_badge.dart';
import '../widgets/history_chart.dart';
import '../widgets/availability_history.dart';
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
  int hours = 24, offset = 0;
  String nodeFilter = '', statusFilter = '', stageFilter = '';
  Json? selectedCell;
  String get historyQuery => Uri(
    queryParameters: {
      'hours': '$hours',
      'limit': '100',
      'offset': '$offset',
      if (nodeFilter.isNotEmpty) 'node_id': nodeFilter,
      if (statusFilter.isNotEmpty) 'status': statusFilter,
      if (stageFilter.isNotEmpty) 'stage': stageFilter,
      if (selectedCell != null) 'from': '${selectedCell!['at']}',
      if (selectedCell != null) 'until': '${selectedCell!['end']}',
    },
  ).query;

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
    final requested = historyQuery;
    try {
      final values = await Future.wait([
        api.request('/monitors/${monitor['id']}/history?$historyQuery'),
        api.request('/nodes'),
        api.request('/monitors'),
      ]);
      if (mounted && requested == historyQuery) {
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
      if (mounted && requested != historyQuery) refresh();
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
            endpoint(object(monitor['check'])),
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
          AvailabilityHistory(
            instance: widget.instance,
            monitorId: monitor['id'] as String,
            onSelect: (cell) {
              setState(() {
                selectedCell = cell;
                offset = 0;
              });
              refresh();
            },
          ),
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

          DropdownButtonFormField<String>(
            initialValue: nodeFilter,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: tr(context, 'Probe source', '探测来源'),
            ),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(tr(context, 'All sources', '全部来源')),
              ),
              for (final n in nodes)
                DropdownMenuItem(
                  value: n['id'] as String,
                  child: Text(n['name'] as String),
                ),
            ],
            onChanged: (v) {
              setState(() {
                nodeFilter = v ?? '';
                offset = 0;
              });
              refresh();
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: statusFilter,
            decoration: InputDecoration(
              labelText: tr(context, 'Result status', '结果状态'),
            ),
            items: [
              for (final v in ['', 'success', 'failure', 'error', 'cancelled'])
                DropdownMenuItem(
                  value: v,
                  child: Text(
                    v.isEmpty
                        ? tr(context, 'All statuses', '全部状态')
                        : statusText(context, v),
                  ),
                ),
            ],
            onChanged: (v) {
              setState(() {
                statusFilter = v ?? '';
                offset = 0;
              });
              refresh();
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: stageFilter,
            decoration: InputDecoration(
              labelText: tr(context, 'Stage', '执行阶段'),
            ),
            items: [
              for (final v in [
                '',
                'dns',
                'connect',
                'tls',
                'http',
                'assertion',
                'timeout',
                'policy',
                'executor',
                'response',
                'complete',
              ])
                DropdownMenuItem(
                  value: v,
                  child: Text(
                    v.isEmpty ? tr(context, 'All stages', '全部阶段') : v,
                  ),
                ),
            ],
            onChanged: (v) {
              setState(() {
                stageFilter = v ?? '';
                offset = 0;
              });
              refresh();
            },
          ),
          if (selectedCell != null)
            TextButton(
              onPressed: () {
                setState(() {
                  selectedCell = null;
                  offset = 0;
                });
                refresh();
              },
              child: Text(tr(context, 'Clear selected time range', '清除选中时间段')),
            ),
          Builder(
            builder: (c) => TextButton.icon(
              onPressed: () => shareJson(c, 'monitor-history', history),
              icon: const Icon(Icons.ios_share),
              label: Text(tr(context, 'Export history', '导出历史')),
            ),
          ),
          ...objects(history['results']).map(
            (r) => ListTile(
              title: Text(nodeName(r['node_id'])),
              subtitle: Text(
                '${timeText(r['scheduled_at'])} · ${r['latency_ms'] ?? '—'} ms\n${r['error'] ?? ''}',
              ),
              trailing: StatusBadge(r['status'] as String),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: offset > 0
                    ? () {
                        setState(
                          () => offset = (offset - 100).clamp(0, 10000000),
                        );
                        refresh();
                      }
                    : null,
                child: Text(tr(context, 'Previous', '上一页')),
              ),
              Text('${offset + 1} / ${history['total'] ?? 0}'),
              TextButton(
                onPressed: offset + 100 < (history['total'] as int? ?? 0)
                    ? () {
                        setState(() => offset += 100);
                        refresh();
                      }
                    : null,
                child: Text(tr(context, 'Next', '下一页')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
