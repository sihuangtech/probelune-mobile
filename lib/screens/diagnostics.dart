import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../services/api.dart';
import '../widgets/status_badge.dart';

/// 即时复查独立轮询，不改写持续监测的故障判定。
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    super.key,
    required this.instance,
    required this.jobs,
  });
  final Instance instance;
  final List<Json> jobs;
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsState();
}

class _DiagnosticsState extends State<DiagnosticsScreen> {
  late List<Json> rows;
  List<Json> nodes = [];
  Timer? timer;
  bool busy = false;
  String error = '';
  Api get api => Api(widget.instance.url, widget.instance.token);

  @override
  void initState() {
    super.initState();
    rows = widget.jobs.map((j) => <String, dynamic>{'job': j}).toList();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (busy) return;
    busy = true;
    try {
      final response = await Future.wait([
        api.request('/diagnostics'),
        api.request('/nodes'),
      ]);
      final ids = widget.jobs.map((j) => j['id']).toSet();
      if (mounted) {
        setState(() {
          rows = objects(response[0])
              .where((r) => ids.contains(object(r['job'])['id']))
              .toList();
          nodes = objects(response[1]);
          error = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      busy = false;
    }
  }

  Future<void> cancel(Json job) async {
    try {
      await api.request(
        '/diagnostics/${job['id']}/cancel',
        method: 'POST',
        body: {},
      );
      await refresh();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Widget resultCard(Json row) {
    final job = object(row['job']), result = object(row['result']);
    final name =
        nodes.where((n) => n['id'] == job['node_id']).firstOrNull?['name'] ??
        job['node_id'];
    final status = (result['status'] as String?)?.isNotEmpty == true
        ? result['status'] as String
        : job['status'] as String;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            StatusBadge(status),
            Text(
              '${timeText(result['started_at'] ?? job['created_at'])} · ${result['latency_ms'] ?? '—'} ms',
            ),
            if (result['error'] != null)
              Text('${result['stage'] ?? ''}: ${result['error']}'),
            if (result['status'] != null && result['status'] != '')
              ExpansionTile(
                title: Text(tr(context, 'Evidence', '检测证据')),
                children: [
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(result),
                  ),
                ],
              ),
            if (job['status'] == 'queued' || job['status'] == 'running')
              TextButton(
                onPressed: () => cancel(job),
                child: Text(tr(context, 'Cancel', '取消')),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'Recheck results', '即时复查结果'))),
    body: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr(
              context,
              'Each location reports independently. This does not change continuous monitoring.',
              '各位置独立返回结果，不改变持续监测判定。',
            ),
          ),
          if (error.isNotEmpty)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ...rows.map(resultCard),
        ],
      ),
    ),
  );
}
