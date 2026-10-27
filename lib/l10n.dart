import 'package:flutter/widgets.dart';

String tr(BuildContext context, String en, String zh) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;
String timeText(dynamic seconds) => seconds is num && seconds > 0
    ? DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000)
          .toLocal()
          .toString()
          .split('.')
          .first
    : '—';
String percent(dynamic n) => n is num ? '${n.toStringAsFixed(1)}%' : '—';
String statusText(BuildContext c, String status) => switch (status) {
  'healthy' => tr(c, 'Healthy', '正常'),
  'down' => tr(c, 'All locations failing', '所有位置异常'),
  'partial' => tr(c, 'Partial outage', '部分位置异常'),
  'unknown' => tr(c, 'Unknown', '未知'),
  'pending' => tr(c, 'Pending', '待确认'),
  'paused' => tr(c, 'Paused', '已暂停'),
  'archived' => tr(c, 'Archived', '已归档'),
  'failed' => tr(c, 'Failed', '失败'),
  'success' => tr(c, 'Success', '成功'),
  'failure' => tr(c, 'Target failed', '目标失败'),
  'error' => tr(c, 'Executor error', '执行错误'),
  'maintenance' => tr(c, 'Maintenance', '维护中'),
  _ => status,
};
