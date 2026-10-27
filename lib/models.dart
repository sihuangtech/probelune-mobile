typedef Json = Map<String, dynamic>;

List<Json> objects(dynamic value) => (value is List ? value : <dynamic>[])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();
Json object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

class Instance {
  Instance({
    required this.url,
    required this.username,
    required this.role,
    required this.token,
    required this.expires,
    this.deviceId = '',
    this.id = '',
  });
  final String url, username, role, token;
  final int expires;
  String deviceId;
  String id;
  bool get canEdit => role == 'admin' || role == 'operator';
  factory Instance.fromJson(Json v) => Instance(
    url: v['url'] as String,
    username: v['username'] as String,
    role: v['role'] as String,
    token: v['token'] as String,
    expires: v['expires'] as int,
    deviceId: v['device_id'] as String? ?? '',
    id: v['instance_id'] as String? ?? '',
  );
  Json toJson() => {
    'url': url,
    'username': username,
    'role': role,
    'token': token,
    'expires': expires,
    'device_id': deviceId,
    'instance_id': id,
  };
}

class ApiException implements Exception {
  ApiException(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}
