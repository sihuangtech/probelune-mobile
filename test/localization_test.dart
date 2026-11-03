import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:probelune_mobile/app.dart';
import 'package:probelune_mobile/services/instances.dart';
import 'package:probelune_mobile/services/locale.dart';

void main() {
  test('Every locale contains the complete ARB message catalog', () {
    final template =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final keys = template.keys
        .where((k) => !k.toString().startsWith('@'))
        .toSet();
    for (final file in Directory('lib/l10n').listSync().whereType<File>()) {
      if (!file.path.endsWith('.arb')) continue;
      final messages = jsonDecode(file.readAsStringSync()) as Map;
      expect(
        messages.keys.where((k) => !k.toString().startsWith('@')).toSet(),
        keys,
        reason: file.path,
      );
      expect(messages.values.any((v) => v == ''), isFalse, reason: file.path);
    }
  });
  testWidgets(
    'Language changes replace the title and themes change actual brightness',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProbeluneApp(instances: Instances()));
      for (final tag in languageNames.keys) {
        preferredLocale.value = localeFromTag(tag);
        preferredTheme.value = ThemeMode.dark;
        await tester.pumpAndSettle();
        final title = 'Probelune';
        expect(find.text(title), findsOneWidget);
        expect(find.text('Probelune - 巡汐'), findsNothing);
        final context = tester.element(find.byType(Scaffold).first);
        expect(Theme.of(context).brightness, Brightness.dark);
        expect(tester.takeException(), isNull);
      }
      preferredTheme.value = ThemeMode.light;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );
      await tester.pumpWidget(const SizedBox());
      preferredLocale.value = null;
      preferredTheme.value = ThemeMode.system;
    },
  );
}
