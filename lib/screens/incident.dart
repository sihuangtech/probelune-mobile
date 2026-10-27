import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../l10n.dart';
import '../services/api.dart';
import 'diagnostics.dart';

class IncidentScreen extends StatefulWidget {
  const IncidentScreen({
    super.key,
    required this.instance,
    required this.id,
    this.initial,
    this.offline = false,
  });
  final Instance instance;
  final String id;
  final Json? initial;
  final bool offline;
  @override
  State<IncidentScreen> createState() => _IncidentState();
}

class _IncidentState extends State<IncidentScreen> {
  Json incident = {};
  String error = '';
  bool busy = false;
  bool fresh = false;
  Timer? timer;
  Api get api => Api(widget.instance.url, widget.instance.token);
  @override
  void initState() {
    super.initState();
    incident = widget.initial ?? {};
    refresh();
    timer = Timer.periodic(const Duration(seconds: 8), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final values = objects(await api.request('/incidents'));
      final found = values.where((i) => i['id'] == widget.id).firstOrNull;
      if (found == null) {
        throw ApiException('Incident not found or outside retention.', 404);
      }
      if (mounted) {
        setState(() {
          incident = found;
          error = '';
          fresh = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> action(String kind, {String note = ''}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await api.request(
        '/incidents/${widget.id}/actions',
        method: 'POST',
        body: {'action': kind, 'minutes': 60, 'note': note},
      );
      await refresh();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> note() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, 'Add note', '添加备注')),
        content: TextField(
          controller: controller,
          maxLength: 1000,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(c, 'Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: Text(tr(c, 'Save', '保存')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null && text.trim().isNotEmpty) {
      await action('note', note: text);
    }
  }

  Future<void> recheck() async {
    try {
      final jobs = objects(
        await api.request(
          '/diagnostics',
          method: 'POST',
          body: {'monitor_id': incident['monitor_id']},
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

  @override
  Widget build(BuildContext context) {
    final allowed = widget.instance.canEdit && fresh && error.isEmpty && !busy;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Incident', '故障事件'))),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              incident['name'] as String? ?? 'Probelune',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${tr(context, 'Opened', '发生时间')}: ${timeText(incident['opened_at'])}\n${tr(context, 'Recovered', '恢复时间')}: ${timeText(incident['recovered_at'])}',
            ),
            if (error.isNotEmpty)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: allowed ? () => action('ack') : null,
                  child: Text(tr(context, 'Acknowledge', '确认知悉')),
                ),
                FilledButton.tonal(
                  onPressed: allowed ? () => action('silence') : null,
                  child: Text(tr(context, 'Silence 1h', '静默 1 小时')),
                ),
                OutlinedButton(
                  onPressed: allowed ? note : null,
                  child: Text(tr(context, 'Add note', '备注')),
                ),
                if ((incident['monitor_id'] as String? ?? '').isNotEmpty)
                  OutlinedButton(
                    onPressed: allowed ? recheck : null,
                    child: Text(tr(context, 'Recheck', '立即复查')),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ...objects(incident['events']).reversed.map(
              (e) => Card(
                child: ListTile(
                  leading: const Icon(Icons.timeline),
                  title: Text('${e['kind']} · ${e['message'] ?? ''}'),
                  subtitle: Text(timeText(e['at'])),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
