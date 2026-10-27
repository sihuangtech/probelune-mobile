import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'instances.dart';
import 'api.dart';
import '../models.dart';

const pushEnabled = bool.fromEnvironment('FIREBASE_ENABLED');
FirebaseOptions get firebaseOptions => const FirebaseOptions(
  apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
  appId: String.fromEnvironment('FIREBASE_APP_ID'),
  messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
  projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
  iosBundleId: 'cn.sihuangtech.probeluneMobile',
);

@pragma('vm:entry-point')
Future<void> backgroundMessage(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: firebaseOptions);
  }
  // 背景通知由系统展示，正文不包含监测目标、响应或身份凭据。
}

class PushService {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> initialize(
    Instances instances,
    void Function(Json) open,
    void Function(String) foreground,
  ) async {
    if (!pushEnabled) return;
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseMessaging.onBackgroundMessage(backgroundMessage);
    _subscriptions.add(
      FirebaseMessaging.instance.onRegistered.listen((fid) async {
        for (final instance
            in instances.items.where((i) => i.deviceId.isNotEmpty).toList()) {
          try {
            await _save(instances, instance, fid);
          } catch (_) {
            /* 断连后可由用户重新开启推送以重试。 */
          }
        }
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((m) => open(m.data)),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen(
        (m) => foreground(m.notification?.title ?? 'Probelune'),
      ),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) open(initial.data);
    if (instances.items.any((i) => i.deviceId.isNotEmpty)) {
      await FirebaseMessaging.instance.register();
    }
  }

  Future<void> register(Instances instances) async {
    if (!pushEnabled) {
      throw ApiException('This build has no Firebase configuration.', 400);
    }
    final permission = await FirebaseMessaging.instance.requestPermission();
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      throw ApiException('Notification permission was not granted.', 403);
    }
    final instance = instances.current!;
    final registered = FirebaseMessaging.instance.onRegistered.first.timeout(
      const Duration(seconds: 20),
    );
    final values = await Future.wait<Object?>([
      registered,
      FirebaseMessaging.instance.register(),
    ], eagerError: true);
    await _save(instances, instance, values.first as String);
  }

  Future<void> _save(
    Instances instances,
    Instance instance,
    String token,
  ) async {
    if (!instances.items.contains(instance)) return;
    final api = Api(instance.url, instance.token);
    final result = object(
      await api.request(
        '/devices',
        method: 'POST',
        body: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      ),
    );
    final old = instance.deviceId;
    instance.deviceId = result['id'] as String;
    if (old.isNotEmpty && old != instance.deviceId) {
      await api.request('/devices/$old', method: 'DELETE');
    }
    await instances.persist();
  }

  Future<void> unregister(Instances instances) async {
    final instance = instances.current!;
    if (instance.deviceId.isNotEmpty) {
      await instances.api.request(
        '/devices/${instance.deviceId}',
        method: 'DELETE',
      );
    }
    instance.deviceId = '';
    await instances.persist();
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
  }
}
