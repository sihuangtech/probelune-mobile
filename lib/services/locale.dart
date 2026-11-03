import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const languageNames = <String, String>{
  'en': 'English',
  'zh-CN': '简体中文',
  'zh-TW': '繁體中文',
  'ja': '日本語',
  'ko': '한국어',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
};
final preferredLocale = ValueNotifier<Locale?>(null);
Locale localeFromTag(String tag) {
  final parts = tag.split('-');
  return Locale(parts[0], parts.length > 1 ? parts[1] : null);
}

Future<void> loadLanguage() async {
  try {
    final value = await const FlutterSecureStorage().read(key: 'language');
    if (value != null && languageNames.containsKey(value)) {
      preferredLocale.value = localeFromTag(value);
    }
  } catch (_) {}
}

Future<void> setLanguage(String tag) async {
  preferredLocale.value = tag.isEmpty ? null : localeFromTag(tag);
  await const FlutterSecureStorage().write(key: 'language', value: tag);
}

Locale resolveDeviceLocale(Locale locale) {
  if (locale.languageCode == 'zh') {
    final traditional =
        locale.scriptCode == 'Hant' ||
        ['TW', 'HK', 'MO'].contains(locale.countryCode);
    return Locale('zh', traditional ? 'TW' : 'CN');
  }
  return languageNames.containsKey(locale.languageCode)
      ? Locale(locale.languageCode)
      : const Locale('en');
}

final preferredTheme = ValueNotifier<ThemeMode>(ThemeMode.system);
Future<void> loadTheme() async {
  try {
    final value = await const FlutterSecureStorage().read(key: 'theme');
    preferredTheme.value =
        ThemeMode.values.where((mode) => mode.name == value).firstOrNull ??
        ThemeMode.system;
  } catch (_) {}
}

Future<void> setTheme(ThemeMode mode) async {
  preferredTheme.value = mode;
  await const FlutterSecureStorage().write(key: 'theme', value: mode.name);
}
