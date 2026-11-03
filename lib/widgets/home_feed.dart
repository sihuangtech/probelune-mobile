import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models.dart';
import '../localization.dart';
import '../screens/monitor.dart';
import '../screens/incident.dart';
import 'status_badge.dart';
import 'availability_history.dart';
import '../screens/management.dart';
import '../services/api.dart';
import '../check_catalog.dart';

/// 首页列表展示与连接、轮询生命周期独立，避免页面状态互相耦合。
class HomeFeed extends StatefulWidget {
  const HomeFeed({
    super.key,
    required this.data,
    required this.incidents,
    required this.instance,
    required this.offline,
    required this.tab,
  });
  final Json data;
  final List<Json> incidents;
  final Instance instance;
  final bool offline;
  final int tab;
  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {
  String search = '',
      selectedType = '',
      selectedStatus = '',
      incidentFilter = 'active';
  final storage = const FlutterSecureStorage();
  String get typeKey => 'monitor-type:${widget.instance.url}';
  @override
  void initState() {
    super.initState();
    storage
        .read(key: typeKey)
        .then((v) {
          if (mounted && types.contains(v)) setState(() => selectedType = v!);
        })
        .catchError((Object _) {});
  }

  void chooseType(String type) {
    setState(() => selectedType = type);
    storage.write(key: typeKey, value: type).catchError((Object _) {});
  }

  Future<void> manage(Json? monitor, String action) async {
    try {
      if (action == 'edit' || action == 'copy' || action == 'add') {
        await editMonitor(
          context,
          widget.instance,
          monitor: monitor,
          copy: action == 'copy',
          type: selectedType.isEmpty ? 'http' : selectedType,
        );
      } else if (monitor != null) {
        if (action == 'archive') {
          final yes = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(message(c, 'mArchiveMonitorab80')),
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
        await Api(widget.instance.url, widget.instance.token).request(
          '/monitors/${monitor['id']}',
          method: 'PUT',
          body: {
            ...monitor,
            if (action == 'pause') 'enabled': monitor['enabled'] != true,
            if (action == 'archive') 'archived': monitor['archived'] != true,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  static const types = ['', 'tcp', 'udp', 'ping', 'http', 'dns'];
  String typeLabel(String type) => switch (type) {
    '' => message(context, 'mAllTypes9c1a'),
    'ping' => 'ICMP',
    'http' => 'HTTP / HTTPS',
    _ => type.toUpperCase(),
  };
  String latency(Json monitor) {
    final states = objects(monitor['states'])
      ..sort(
        (a, b) => ((b['last_at'] as num?) ?? 0).compareTo(
          (a['last_at'] as num?) ?? 0,
        ),
      );
    if (states.isEmpty) return '—';
    final result = object(states.first['result']);
    final stats = object(result['data']);
    final isPing = object(monitor['check'])['type'] == 'ping';
    final value = isPing ? stats['avg_ms'] : result['latency_ms'];
    final valid = isPing
        ? (stats['received'] as num? ?? 0) > 0
        : result['status'] == 'success';
    return valid && value is num ? '${decimal(value)} ms' : '—';
  }

  Json get data => widget.data;
  List<Json> get incidents => widget.incidents;
  bool get offline => widget.offline;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: switch (widget.tab) {
      1 => incidentCards(widget.instance),
      2 => nodeCards(),
      4 => overviewCards(),
      _ => monitorCards(widget.instance),
    },
  );
  List<Widget> monitorCards(Instance instance) {
    final list = objects(data['monitors'])
        .where(
          (m) =>
              (selectedStatus.isEmpty || m['status'] == selectedStatus) &&
              (selectedType.isEmpty ||
                  object(m['check'])['type'] == selectedType) &&
              '${m['name']} ${m['group']} ${object(m['check'])['target']}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    final now =
        (data['time'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final onlineNodes = objects(data['nodes'])
        .where(
          (n) =>
              n['role'] != 'panel' &&
              n['revoked'] != true &&
              n['enabled'] == true &&
              now - (n['last_seen'] as num? ?? 0) <= 60,
        )
        .length;
    final healthy = list.where((m) => m['status'] == 'healthy').length;
    final issues = list
        .where((m) => ['down', 'partial'].contains(m['status']))
        .length;
    return [
      Text(
        message(context, 'mMonitorManagement436b'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '${message(context, 'mHealthy1b83')} $healthy  -  ${message(context, 'mIssues5faa')} $issues  -  ${message(context, 'mOnlineNodes6438')} $onlineNodes',
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final type in types)
            ChoiceChip(
              label: Text(
                '${typeLabel(type)} ${objects(data['monitors']).where((m) => type.isEmpty || object(m['check'])['type'] == type).length}',
              ),
              selected: selectedType == type,
              onSelected: (_) => chooseType(type),
            ),
        ],
      ),
      if (checkIntroductions.containsKey(selectedType))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(message(context, checkIntroductions[selectedType]!)),
        ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: selectedStatus,
        decoration: InputDecoration(labelText: message(context, 'mStatus7082')),
        items: [
          for (final status in [
            '',
            'healthy',
            'down',
            'partial',
            'unknown',
            'pending',
            'paused',
            'archived',
          ])
            DropdownMenuItem(
              value: status,
              child: status.isEmpty
                  ? Text(message(context, 'mAllStatuses241b'))
                  : StatusBadge(status),
            ),
        ],
        onChanged: (v) => setState(() => selectedStatus = v ?? ''),
      ),
      if (widget.instance.canEdit && !offline)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => manage(null, 'add'),
            icon: const Icon(Icons.add),
            label: Text(message(context, 'mAddMonitorfdde')),
          ),
        ),
      TextField(
        onChanged: (v) => setState(() => search = v),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: message(context, 'mSearchMonitors43db'),
        ),
      ),
      const SizedBox(height: 12),
      if (list.isEmpty) empty(),
      ...list.map(
        (m) => Card(
          key: ValueKey('${instance.url}:${m['id']}'),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(m['name'] as String),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(typeLabel(object(m['check'])['type'] as String? ?? '')),
                Text(endpoint(object(m['check']))),
                const SizedBox(height: 8),
                StatusBadge(
                  m['maintenance'] == true
                      ? 'maintenance'
                      : m['status'] as String,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${message(context, 'mLatency267d')} ${latency(m)}',
                  ),
                ),
                AvailabilityHistory(
                  key: ValueKey('${instance.url}:${instance.id}:${m['id']}'),
                  instance: instance,
                  monitorId: m['id'] as String,
                  compact: true,
                  offline: offline,
                ),
                if (m['coverage_complete'] != true)
                  Text(message(context, 'mIncompleteCoverage77f2')),
              ],
            ),
            trailing: widget.instance.canEdit && !offline
                ? PopupMenuButton<String>(
                    onSelected: (action) => manage(m, action),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(message(context, 'mEditcf6b')),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: Text(message(context, 'mCopy362a')),
                      ),
                      PopupMenuItem(
                        value: 'pause',
                        child: Text(
                          m['enabled'] == true
                              ? message(context, 'mPause81c2')
                              : message(context, 'mResume7049'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(
                          m['archived'] == true
                              ? message(context, 'mRestore9a8d')
                              : message(context, 'mArchive51a5'),
                        ),
                      ),
                    ],
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MonitorScreen(
                  instance: instance,
                  monitor: m,
                  offline: offline,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> overviewCards() {
    final nodes = objects(data['nodes'])
        .where((n) => n['role'] != 'panel' && n['revoked'] != true)
        .toList();
    final monitors = objects(data['monitors'])
        .where((m) => m['archived'] != true)
        .toList();
    final assigned = <String>{};
    final cards = <Widget>[
      Text(
        message(context, 'mServerHealth41b9'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    ];
    for (final node in nodes) {
      final checks = nodes.where((n) => n['name'] == node['name']).length == 1
          ? monitors.where((m) => m['name'] == node['name']).toList()
          : <Json>[];
      checks.sort(
        (a, b) => types
            .indexOf(object(a['check'])['type'] as String)
            .compareTo(types.indexOf(object(b['check'])['type'] as String)),
      );
      assigned.addAll(checks.map((m) => m['id'] as String));
      final live = checks.where((m) => m['enabled'] == true).toList();
      final status = live.isEmpty
          ? 'unknown'
          : live.every((m) => m['status'] == 'down')
          ? 'down'
          : live.any((m) => ['down', 'partial'].contains(m['status']))
          ? 'partial'
          : live.every(
              (m) => m['status'] == 'healthy' && m['coverage_complete'] == true,
            )
          ? 'healthy'
          : 'unknown';
      cards.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node['name'] as String,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                StatusBadge(status),
                Text(
                  '${message(context, 'mNodeHeartbeatf1f6')} ${timeText(node['last_seen'])}',
                ),
                if (checks.isEmpty) Text(message(context, 'mNoChecksa1b1')),
                for (final m in checks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      typeLabel(object(m['check'])['type'] as String),
                    ),
                    trailing: StatusBadge(m['status'] as String),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MonitorScreen(
                          instance: widget.instance,
                          monitor: m,
                          offline: offline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final remaining = monitors
        .where((m) => !assigned.contains(m['id']))
        .toList();
    if (remaining.isNotEmpty) {
      cards.add(Text(message(context, 'mPanelAndOtherTargetsf637')));
    }
    for (final m in remaining) {
      cards.add(
        Card(
          child: ListTile(
            title: Text(m['name'] as String),
            trailing: StatusBadge(m['status'] as String),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MonitorScreen(
                  instance: widget.instance,
                  monitor: m,
                  offline: offline,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return cards;
  }

  List<Widget> incidentCards(Instance instance) => [
    Text(
      message(context, 'mIncidentTimeline284d'),
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      children: [
        for (final kind in ['active', 'recovered', 'all'])
          ChoiceChip(
            label: Text(statusText(context, kind)),
            selected: incidentFilter == kind,
            onSelected: (_) => setState(() => incidentFilter = kind),
          ),
      ],
    ),
    if (incidents.isEmpty) empty(),
    ...incidents
        .where(
          (i) =>
              incidentFilter == 'all' ||
              (incidentFilter == 'active'
                  ? i['recovered_at'] == 0
                  : (i['recovered_at'] as num? ?? 0) > 0),
        )
        .map(
          (i) => Card(
            child: ListTile(
              title: Text(i['name'] as String),
              subtitle: Text(
                '${timeText(i['opened_at'])}\n${message(context, (i['recovered_at'] == 0 ? 'mActived2f1' : 'mRecovered1be5'))}',
              ),
              isThreeLine: true,
              trailing: Icon(
                i['recovered_at'] == 0
                    ? Icons.warning_amber
                    : Icons.check_circle_outline,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IncidentScreen(
                    instance: instance,
                    id: i['id'] as String,
                    initial: i,
                    offline: offline,
                  ),
                ),
              ),
            ),
          ),
        ),
  ];
  List<Widget> nodeCards() => [
    Text(
      message(context, 'mProbeNodes7d8c'),
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    if (objects(data['nodes']).isEmpty) empty(),
    ...objects(data['nodes'])
        .where((n) => n['role'] != 'panel')
        .map(
          (n) => Card(
            child: ListTile(
              title: Text(n['name'] as String),
              subtitle: Text(
                '${n['region']} - ${n['network']}\n${timeText(n['last_seen'])}',
              ),
              isThreeLine: true,
              trailing: StatusBadge(
                n['revoked'] == true || n['enabled'] != true
                    ? 'paused'
                    : DateTime.now().millisecondsSinceEpoch ~/ 1000 -
                              (n['last_seen'] as int) >
                          60
                    ? 'unknown'
                    : 'healthy',
              ),
            ),
          ),
        ),
  ];
  Widget empty() => Padding(
    padding: const EdgeInsets.all(32),
    child: Text(message(context, 'mNoMatchingEntriesAdjustFiltersOrdc24')),
  );
}
