import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'generated/l10n/app_localizations.dart';
import 'generated/l10n/lookup.dart';
import 'services/locale.dart';

String message(BuildContext context, String key) {
  final messages = AppLocalizations.of(context)!;
  return localizedMessage(messages, key);
}

String timeText(dynamic seconds) => seconds is num && seconds > 0
    ? DateFormat.yMd().add_Hms().format(
        DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000).toLocal(),
      )
    : '—';
String decimal(num value) => NumberFormat('0.0').format(value);
String percent(dynamic n) => n is num ? '${decimal(n)}%' : '—';
String statusText(BuildContext c, String status) => switch (status) {
  'healthy' => message(c, 'mHealthy1b83'),
  'down' => message(c, 'mUnavailable142d'),
  'partial' => message(c, 'mPartialOutage0d1b'),
  'unknown' => message(c, 'mUnknown4ff8'),
  'pending' => message(c, 'mPending6cef'),
  'paused' => message(c, 'mPausedd9c5'),
  'archived' => message(c, 'mArchived35b1'),
  'failed' => message(c, 'mFailedd9a3'),
  'success' => message(c, 'mSuccessd79f'),
  'failure' => message(c, 'mTargetFailed7c98'),
  'error' => message(c, 'mExecutorError1730'),
  'maintenance' => message(c, 'mMaintenancebef8'),
  'active' => message(c, 'mActived2f1'),
  'recovered' => message(c, 'mRecovered1be5'),
  'all' => message(c, 'mAllStatuses241b'),
  _ => status,
};

String apiErrorMessage(String source) {
  final tag = Intl.getCurrentLocale().replaceAll('_', '-');
  final locale = resolveDeviceLocale(localeFromTag(tag));
  return localizedBackendError(lookupAppLocalizations(locale), source) ??
      source;
}
