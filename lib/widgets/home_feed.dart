import 'package:flutter/material.dart';

import '../models.dart';
import '../l10n.dart';
import '../screens/monitor.dart';
import '../screens/incident.dart';
import 'status_badge.dart';

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
  String search = '';
  Json get data => widget.data;
  List<Json> get incidents => widget.incidents;
  bool get offline => widget.offline;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: switch (widget.tab) {
      1 => incidentCards(widget.instance),
      2 => nodeCards(),
      _ => monitorCards(widget.instance),
    },
  );
  List<Widget> monitorCards(Instance instance) {
    final list = objects(data['monitors'])
        .where(
          (m) => '${m['name']} ${m['group']} ${object(m['check'])['target']}'
              .toLowerCase()
              .contains(search.toLowerCase()),
        )
        .toList();
    final summary = object(data['summary']);
    return [
      Text(
        tr(context, 'Observation network', '观测网络'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '${tr(context, 'Healthy', '正常')} ${summary['healthy'] ?? 0}  ·  ${tr(context, 'Issues', '异常')} ${(summary['down'] ?? 0) + (summary['partial'] ?? 0)}  ·  ${tr(context, 'Online nodes', '在线节点')} ${data['online_nodes'] ?? 0}',
        ),
      ),
      TextField(
        onChanged: (v) => setState(() => search = v),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: tr(context, 'Search monitors', '搜索监测'),
        ),
      ),
      const SizedBox(height: 12),
      if (list.isEmpty) empty(),
      ...list.map(
        (m) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(m['name'] as String),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m['group'] ?? ''} · ${object(m['check'])['type']}'),
                const SizedBox(height: 8),
                StatusBadge(
                  m['maintenance'] == true
                      ? 'maintenance'
                      : m['status'] as String,
                ),
                if (m['coverage_complete'] != true)
                  Text(tr(context, 'Incomplete coverage', '覆盖不足')),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
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

  List<Widget> incidentCards(Instance instance) => [
    Text(
      tr(context, 'Incident timeline', '故障时间线'),
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    if (incidents.isEmpty) empty(),
    ...incidents.map(
      (i) => Card(
        child: ListTile(
          title: Text(i['name'] as String),
          subtitle: Text(
            '${timeText(i['opened_at'])}\n${tr(context, i['recovered_at'] == 0 ? 'Active' : 'Recovered', i['recovered_at'] == 0 ? '进行中' : '已恢复')}',
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
      tr(context, 'Probe nodes', '探测节点'),
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    if (objects(data['nodes']).isEmpty) empty(),
    ...objects(data['nodes']).map(
      (n) => Card(
        child: ListTile(
          title: Text(n['name'] as String),
          subtitle: Text(
            '${n['region']} · ${n['network']}\n${timeText(n['last_seen'])}',
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
    child: Text(
      tr(
        context,
        'No data yet. Configure monitors and nodes in the dashboard.',
        '暂无数据。请在网页面板配置监测和节点。',
      ),
    ),
  );
}
