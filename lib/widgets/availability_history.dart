import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models.dart';
import '../services/api.dart';

class AvailabilityHistory extends StatefulWidget {
  const AvailabilityHistory({
    super.key,
    required this.instance,
    required this.monitorId,
  });
  final Instance instance;
  final String monitorId;
  @override
  State<AvailabilityHistory> createState() => _AvailabilityHistoryState();
}

class _AvailabilityHistoryState extends State<AvailabilityHistory> {
  static int preferredMinutes = 15;
  int minutes = preferredMinutes, hours = 24;
  Json history = {};
  String error = '';
  bool busy = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (busy) return;
    busy = true;
    final requestedMinutes = minutes, requestedHours = hours;
    try {
      final value = await Api(widget.instance.url, widget.instance.token).request(
        '/monitors/${widget.monitorId}/uptime?hours=$hours&bucket_minutes=$minutes',
      );
      if (mounted && requestedMinutes == minutes && requestedHours == hours) {
        setState(() {
          history = object(value);
          error = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      busy = false;
      if (mounted && (requestedMinutes != minutes || requestedHours != hours)) {
        refresh();
      }
    }
  }

  Future<void> configure() async {
    final duration = TextEditingController(text: '$minutes');
    final lookback = TextEditingController(text: '$hours');
    String validation = '';
    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(tr(context, 'History settings', '历史设置')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr(context, 'Minutes per cell', '每个色块的分钟数'),
                ),
              ),
              TextField(
                controller: lookback,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr(context, 'Lookback hours', '回看小时数'),
                ),
              ),
              if (validation.isNotEmpty)
                Text(
                  validation,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'Cancel', '取消')),
            ),
            TextButton(
              onPressed: () {
                final m = int.tryParse(duration.text),
                    h = int.tryParse(lookback.text);
                if (m == null ||
                    h == null ||
                    m < 5 ||
                    m > 1440 ||
                    m % 5 != 0 ||
                    h < 1 ||
                    h > 720 ||
                    (h * 60 / m).ceil() > 2016) {
                  update(
                    () => validation = tr(
                      context,
                      'Use 5-minute multiples, 1–720 hours and at most 2016 cells.',
                      '粒度为 5 分钟倍数，范围 1—720 小时，最多 2016 个色块。',
                    ),
                  );
                  return;
                }
                setState(() {
                  minutes = m;
                  hours = h;
                  preferredMinutes = m;
                });
                Navigator.pop(context, true);
              },
              child: Text(tr(context, 'Apply', '应用')),
            ),
          ],
        ),
      ),
    );
    duration.dispose();
    lookback.dispose();
    if (applied == true) refresh();
  }

  Color color(String? status) => switch (status) {
    'healthy' => const Color(0xff19967e),
    'partial' => const Color(0xffd9a23d),
    'down' => const Color(0xffcb5753),
    'incomplete' => const Color(0xff8bbeb1),
    _ => const Color(0xffd9e1df),
  };

  void inspect(Json cell) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${timeText(cell['at'])} — ${timeText(cell['end'])}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                '${tr(context, 'Availability', '可用率')}: ${percent(cell['availability'])}',
              ),
              Text(
                '${tr(context, 'Coverage', '覆盖率')}: ${percent(cell['coverage'])}',
              ),
              Text(
                '${tr(context, 'Success / failure / error', '成功 / 失败 / 错误')}: ${cell['success']} / ${cell['failed']} / ${cell['errors']}',
              ),
              Text(
                '${tr(context, 'Expected samples', '应执行样本')}: ${cell['expected']}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'Availability history', '可用性历史'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: configure,
                icon: const Icon(Icons.tune),
                tooltip: tr(context, 'History settings', '历史设置'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final value in [15, 60])
                ChoiceChip(
                  label: Text(value == 15 ? '15 min' : '1 h'),
                  selected: minutes == value,
                  onSelected: (_) {
                    setState(() {
                      minutes = value;
                      preferredMinutes = value;
                    });
                    refresh();
                  },
                ),
            ],
          ),
          Text('$hours h / $minutes min'),
          if (error.isNotEmpty)
            Text(
              '${tr(context, 'Unable to refresh', '刷新失败')}: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Text(
            '${tr(context, 'Availability', '可用率')} ${percent(history['availability'])} / ${tr(context, 'Coverage', '覆盖率')} ${percent(history['coverage'])}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 3,
            runSpacing: 4,
            children: objects(history['cells'])
                .map(
                  (cell) => Semantics(
                    button: true,
                    label:
                        '${timeText(cell['at'])}: ${cell['status']}, ${percent(cell['availability'])}, ${percent(cell['coverage'])}',
                    child: Tooltip(
                      message: timeText(cell['at']),
                      child: InkWell(
                        onTap: () => inspect(cell),
                        child: Container(
                          width: 9,
                          height: 27,
                          decoration: BoxDecoration(
                            color: color(cell['status'] as String?),
                            borderRadius: BorderRadius.circular(2),
                            border: cell['status'] == 'incomplete'
                                ? Border.all(color: Colors.white, width: 1.5)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            tr(
              context,
              'Green: healthy. Orange/red: failed checks. Pale: incomplete coverage. Grey: no valid samples.',
              '绿：正常；橙红：检查失败；浅绿：覆盖不足；灰：无有效样本。',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
