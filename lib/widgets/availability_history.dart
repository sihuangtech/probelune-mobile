import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/material.dart';

import '../localization.dart';
import '../models.dart';
import '../services/api.dart';

class AvailabilityHistory extends StatefulWidget {
  const AvailabilityHistory({
    super.key,
    required this.instance,
    required this.monitorId,
    this.compact = false,
    this.onSelect,
    this.initialHistory,
    this.publicStatus = false,
    this.offline = false,
  });
  final Instance instance;
  final String monitorId;
  final bool compact, offline;
  final bool publicStatus;
  final ValueChanged<Json>? onSelect;
  final Json? initialHistory;
  @override
  State<AvailabilityHistory> createState() => _AvailabilityHistoryState();
}

class _AvailabilityHistoryState extends State<AvailabilityHistory> {
  static final preference = ValueNotifier<(int, int)>((15, 24));
  static final storage = const FlutterSecureStorage();
  int minutes = preference.value.$1, hours = preference.value.$2;
  void preferenceChanged() {
    if (!mounted) return;
    setState(() {
      minutes = preference.value.$1;
      hours = preference.value.$2;
    });
    refresh();
  }

  Future<void> loadPreference() async {
    try {
      final raw = await storage.read(key: 'uptime-range');
      if (raw == null) return;
      final v = object(jsonDecode(raw));
      final m = v['minutes'], h = v['hours'];
      if (m is int &&
          h is int &&
          m >= 5 &&
          m <= 1440 &&
          m % 5 == 0 &&
          h >= 1 &&
          h <= 720 &&
          (h * 60 / m).ceil() <= 2016) {
        preference.value = (m, h);
      }
    } catch (_) {}
  }

  void persistPreference() {
    preference.value = (minutes, hours);
    storage
        .write(
          key: 'uptime-range',
          value: jsonEncode({'minutes': minutes, 'hours': hours}),
        )
        .catchError((Object _) {});
  }

  Json history = {};
  String error = '';
  bool busy = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    history = widget.initialHistory ?? {};
    preference.addListener(preferenceChanged);
    loadPreference();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    preference.removeListener(preferenceChanged);
    super.dispose();
  }

  Future<void> refresh() async {
    if (busy || widget.offline) return;
    busy = true;
    final requestedMinutes = minutes, requestedHours = hours;
    final queryHours = widget.compact
        ? ((minutes * 24) / 60).ceil().clamp(1, hours)
        : hours;
    try {
      final value = await Api(widget.instance.url, widget.instance.token).request(
        widget.publicStatus
            ? '/status?hours=$queryHours&bucket_minutes=$minutes'
            : '/monitors/${widget.monitorId}/uptime?hours=$queryHours&bucket_minutes=$minutes',
      );
      if (mounted && requestedMinutes == minutes && requestedHours == hours) {
        setState(() {
          history = widget.publicStatus
              ? object(
                  objects(object(value)['monitors'])
                      .where((m) => m['id'] == widget.monitorId)
                      .firstOrNull?['uptime'],
                )
              : object(value);
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
          title: Text(message(context, 'mHistorySettings5de5')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: message(context, 'mMinutesPerCella8b7'),
                ),
              ),
              TextField(
                controller: lookback,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: message(context, 'mLookbackHoursa95a'),
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
              child: Text(message(context, 'mCancel5f4d')),
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
                    () => validation = message(
                      context,
                      'mUse5MinuteMultiples172086f9',
                    ),
                  );
                  return;
                }
                setState(() {
                  minutes = m;
                  hours = h;
                });
                Navigator.pop(context, true);
              },
              child: Text(message(context, 'mApply3b4e')),
            ),
          ],
        ),
      ),
    );
    duration.dispose();
    lookback.dispose();
    if (applied == true) {
      persistPreference();
      refresh();
    }
  }

  Color color(String? status) => switch (status) {
    'healthy' => const Color(0xff19967e),
    'partial' => const Color(0xffd9a23d),
    'down' => const Color(0xffcb5753),
    'incomplete' => const Color(0xff8bbeb1),
    _ => Theme.of(context).colorScheme.surfaceContainerHighest,
  };

  void inspect(Json cell) {
    widget.onSelect?.call(cell);
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
                '${message(context, 'mAvailabilitye10b')}: ${percent(cell['availability'])}',
              ),
              Text(
                '${message(context, 'mCoverageb47a')}: ${percent(cell['coverage'])}',
              ),
              Text(
                '${message(context, 'mSuccessFailureError30e1')}: ${cell['success']} / ${cell['failed']} / ${cell['errors']}',
              ),
              Text(
                '${message(context, 'mExpectedSamplesffba')}: ${cell['expected']}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      final cells = objects(history['cells']);
      final recent = cells
          .skip(cells.length > 24 ? cells.length - 24 : 0)
          .toList();
      if (error.isNotEmpty) {
        return Text(message(context, 'mHistoryUnavailable75bf'));
      }
      if (recent.isEmpty) {
        return Text(
          message(
            context,
            (widget.offline
                ? 'mOfflineHistoryUnavailablece2b'
                : 'mLoadingHistory7475'),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            for (final cell in recent)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Tooltip(
                    message:
                        '${timeText(cell['at'])} — ${timeText(cell['end'])}',
                    child: InkWell(
                      onTap: () => inspect(cell),
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: color(cell['status'] as String?),
                          borderRadius: BorderRadius.circular(2),
                          border: cell['status'] == 'incomplete'
                              ? Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message(context, 'mAvailabilityHistory3f1c'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: configure,
                  icon: const Icon(Icons.tune),
                  tooltip: message(context, 'mHistorySettings5de5'),
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
                      });
                      refresh();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$hours h / $minutes min'),
            if (error.isNotEmpty)
              Text(
                '${message(context, 'mUnableToRefresh787f')}: $error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Text(
              '${message(context, 'mAvailabilitye10b')} ${percent(history['availability'])} / ${message(context, 'mCoverageb47a')} ${percent(history['coverage'])}',
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
                        message:
                            '${timeText(cell['at'])} — ${timeText(cell['end'])}',
                        child: InkWell(
                          onTap: () => inspect(cell),
                          child: Container(
                            width: 9,
                            height: 27,
                            decoration: BoxDecoration(
                              color: color(cell['status'] as String?),
                              borderRadius: BorderRadius.circular(2),
                              border: cell['status'] == 'incomplete'
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 1.5,
                                    )
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
              message(context, 'mGreenHealthyOrangeRedFailedChecks8b78'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
