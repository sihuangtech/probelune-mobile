import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models.dart';
import 'api.dart';

class Instances extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final List<Instance> items = [];
  int selected = 0;
  String error = '';
  Instance? get current =>
      items.isEmpty ? null : items[selected.clamp(0, items.length - 1)];
  Api get api => Api(current!.url, current!.token);
  Future<void> load() async {
    try {
      final raw = await _storage.read(key: 'instances');
      if (raw != null) {
        items.addAll(objects(jsonDecode(raw)).map(Instance.fromJson));
      }
    } catch (e) {
      error = 'Could not unlock saved instances: $e';
    }
  }

  Future<void> persist() async {
    // 凭据与本地快照都进入系统安全存储，不写入明文偏好设置。
    await _storage.write(
      key: 'instances',
      value: jsonEncode(items.map((i) => i.toJson()).toList()),
    );
    notifyListeners();
  }

  void select(int index) {
    selected = index;
    notifyListeners();
  }

  Future<void> connect(
    String url,
    String username,
    String password, {
    String code = '',
    bool allowHttp = false,
  }) async {
    final base = Api.normalize(url, allowHttp: allowHttp);
    final response = object(
      await Api(base).request(
        code.isEmpty ? '/auth/login' : '/auth/pair/exchange',
        method: 'POST',
        body: code.isEmpty
            ? {'username': username, 'password': password}
            : {'code': code},
      ),
    );
    final user = object(response['user']);
    final instance = Instance(
      url: base,
      username: user['username'] as String,
      role: user['role'] as String,
      token: response['token'] as String,
      expires: response['expires'] as int,
      id: response['instance_id'] as String? ?? '',
    );
    items.removeWhere((i) => i.url == base && i.username == instance.username);
    items.add(instance);
    selected = items.length - 1;
    await persist();
  }

  Future<void> remove(Instance instance) async {
    try {
      final client = Api(instance.url, instance.token);
      if (instance.deviceId.isNotEmpty) {
        await client.request('/devices/${instance.deviceId}', method: 'DELETE');
      }
      await client.request('/auth/logout', method: 'POST');
    } catch (e) {
      error = 'Local credentials removed. Remote revocation unavailable: $e';
    }
    await _storage.delete(key: 'cache:${instance.url}:${instance.username}');
    items.remove(instance);
    selected = 0;
    await persist();
  }

  Future<void> cache(Instance instance, Json data) => _storage.write(
    key: 'cache:${instance.url}:${instance.username}',
    value: jsonEncode({
      'saved_at': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    }),
  );
  Future<Json?> cached(Instance instance) async {
    final raw = await _storage.read(
      key: 'cache:${instance.url}:${instance.username}',
    );
    if (raw == null) return null;
    final value = object(jsonDecode(raw));
    if (DateTime.now().millisecondsSinceEpoch - (value['saved_at'] as int) >
        86400000) {
      return null;
    }
    return value;
  }
}
