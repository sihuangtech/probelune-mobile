import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:probelune_mobile/models.dart';
import 'package:probelune_mobile/widgets/home_feed.dart';
import 'package:probelune_mobile/screens/resource_editor.dart';
import 'package:probelune_mobile/screens/management.dart';

final instance = Instance(
  url: 'https://monitor.example.com',
  username: 'viewer',
  role: 'viewer',
  token: 'test',
  expires: 0,
);
Widget app(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  supportedLocales: const [Locale('zh'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
Json monitor(String id, String type, num ms) => {
  'id': id,
  'name': 'Server $id',
  'check': {'type': type},
  'status': 'healthy',
  'coverage_complete': true,
  'states': [
    {
      'last_at': 1,
      'result': {
        'status': 'success',
        'latency_ms': 10000,
        'data': {'avg_ms': ms, 'received': 4},
      },
    },
  ],
};
void main() {
  testWidgets(
    'Type filters preserve protocol order and use ICMP RTT on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          HomeFeed(
            data: {
              'monitors': [
                monitor('one', 'tcp', 1),
                monitor('two', 'ping', 42.5),
              ],
            },
            incidents: const [],
            instance: instance,
            offline: true,
            tab: 0,
          ),
        ),
      );
      await tester.tap(find.text('ICMP 1'));
      await tester.pump();
      expect(find.text('Server one'), findsNothing);
      expect(find.text('Server two'), findsOneWidget);
      expect(find.text('延迟 42.5 ms'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Changing protocol exposes the corresponding native fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ResourceEditor(
          instance: instance,
          title: 'Test',
          value: {'check': defaultCheck()},
          fields: checkFields,
          path: '/diagnostics',
        ),
      ),
    );
    expect(find.widgetWithText(TextFormField, 'UDP 请求内容'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('udp').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('UDP 请求内容'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('UDP 请求内容'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'DNS 期望结果'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Editing preserves monitor version and omitted secret headers', (
    tester,
  ) async {
    http.Request? saved;
    final client = MockClient((request) async {
      saved = request;
      return http.Response('{}', 200);
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceEditor(
            instance: instance,
            title: 'Edit',
            value: {
              'id': 'example',
              'version': 7,
              'name': 'Before',
              'check': {'type': 'tcp', 'target': 'example.com'},
            },
            fields: const [EditField('name', 'Name', '名称')],
            path: '/monitors/example',
            method: 'PUT',
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'After');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }, () => client);
    expect(saved?.method, 'PUT');
    final body = jsonDecode(saved!.body) as Map;
    expect(body['version'], 7);
    expect(body['name'], 'After');
    expect((body['check'] as Map).containsKey('headers'), isFalse);
    expect(saved!.headers['Authorization'], 'Bearer test');
  });
}
