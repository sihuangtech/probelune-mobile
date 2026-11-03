import 'dart:convert';

import 'package:flutter/material.dart';

import '../models.dart';
import '../l10n.dart';
import '../services/api.dart';

class EditField {
  const EditField(
    this.key,
    this.en,
    this.zh, {
    this.options,
    this.kind = 'text',
  });
  final String key, en, zh, kind;
  final List<String>? options;
}

class ResourceEditor extends StatefulWidget {
  const ResourceEditor({
    super.key,
    required this.instance,
    required this.title,
    required this.value,
    required this.fields,
    required this.path,
    this.method = 'POST',
    this.choices = const {},
  });
  final Instance instance;
  final String title, path, method;
  final Json value;
  final List<EditField> fields;
  final Map<String, Map<String, String>> choices;
  @override
  State<ResourceEditor> createState() => _ResourceEditorState();
}

class _ResourceEditorState extends State<ResourceEditor> {
  late Json value;
  final controllers = <String, TextEditingController>{};
  String error = '';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    value = object(jsonDecode(jsonEncode(widget.value)));
    for (final field in widget.fields) {
      final v = read(field.key);
      controllers[field.key] = TextEditingController(
        text: field.kind == 'list'
            ? (v as List? ?? []).join('\n')
            : field.kind == 'json'
            ? (v == null ? '' : jsonEncode(v))
            : '${v ?? ''}',
      );
    }
  }

  dynamic read(String key) {
    dynamic v = value;
    for (final part in key.split('.')) {
      v = v is Map ? v[part] : null;
    }
    return v;
  }

  void write(String key, dynamic v) {
    final parts = key.split('.');
    Json parent = value;
    for (final part in parts.take(parts.length - 1)) {
      parent[part] ??= <String, dynamic>{};
      parent = parent[part] as Json;
    }
    parent[parts.last] = v;
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> dateTime(EditField field) async {
    final initial = DateTime.fromMillisecondsSinceEpoch(
      ((read(field.key) as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch ~/ 1000) *
          1000,
    );
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(
      () => write(
        field.key,
        DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            ).millisecondsSinceEpoch ~/
            1000,
      ),
    );
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      for (final f in widget.fields.where(visible)) {
        if (f.options != null || ['bool', 'date'].contains(f.kind)) continue;
        final text = controllers[f.key]!.text;
        if (f.kind == 'json' && text.trim().isEmpty) {
          continue;
        }
        write(f.key, switch (f.kind) {
          'int' => int.parse(text),
          'list' =>
            text
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
          'json' => jsonDecode(text),
          _ => text,
        });
      }
      final result = await Api(
        widget.instance.url,
        widget.instance.token,
      ).request(widget.path, method: widget.method, body: value);
      if (!mounted) return;
      final response = object(result);
      final secret =
          response['registration_token'] ?? response['signing_secret'];
      if (secret is String && secret.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(tr(c, 'Save this credential', '请保存凭据')),
            content: SelectableText(secret),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(tr(c, 'Done', '完成')),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool visible(EditField field) {
    if (widget.path.startsWith('/channels')) {
      final type = read('type');
      if ([
        'smtp_host',
        'smtp_port',
        'tls_mode',
        'username',
        'password',
        'from',
        'to',
      ].contains(field.key)) {
        return type == 'smtp';
      }
      if (field.key == 'url') return type == 'webhook';
      if (field.key == 'policy.allow_cidrs') return type != 'push';
    }
    if (!field.key.startsWith('check.')) return true;
    final type = read('check.type');
    final key = field.key;
    if ([
      'check.type',
      'check.target',
      'check.timeout',
      'check.family',
      'check.retries',
    ].contains(key)) {
      return true;
    }
    if (key == 'check.port') return ['tcp', 'udp'].contains(type);
    if (key.startsWith('check.udp_')) return type == 'udp';
    if ([
      'check.dns_record',
      'check.resolver',
      'check.expected_dns',
    ].contains(key)) {
      return type == 'dns';
    }
    if (['check.count', 'check.max_loss'].contains(key)) {
      return ['ping', 'mtr'].contains(type);
    }
    if (key == 'check.size') return type == 'ping';
    return type == 'http';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final f in widget.fields.where(visible))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: widget.choices.containsKey(f.key)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(context, f.en, f.zh)),
                        for (final entry in widget.choices[f.key]!.entries)
                          CheckboxListTile(
                            title: Text(entry.value),
                            value: (read(f.key) as List? ?? []).contains(
                              entry.key,
                            ),
                            onChanged: busy
                                ? null
                                : (checked) => setState(() {
                                    final ids = List<String>.from(
                                      read(f.key) as List? ?? [],
                                    );
                                    if (checked == true) {
                                      ids.add(entry.key);
                                    } else {
                                      ids.remove(entry.key);
                                    }
                                    write(f.key, ids);
                                    controllers[f.key]!.text = ids.join('\n');
                                  }),
                          ),
                      ],
                    )
                  : f.kind == 'bool'
                  ? SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr(context, f.en, f.zh)),
                      value: read(f.key) == true,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => write(f.key, v)),
                    )
                  : f.kind == 'date'
                  ? ListTile(
                      title: Text(tr(context, f.en, f.zh)),
                      subtitle: Text(timeText(read(f.key))),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: busy ? null : () => dateTime(f),
                    )
                  : f.options != null
                  ? DropdownButtonFormField<String>(
                      initialValue: f.options!.contains(read(f.key))
                          ? read(f.key) as String
                          : f.options!.first,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr(context, f.en, f.zh),
                      ),
                      items: f.options!
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (v) => setState(() => write(f.key, v)),
                    )
                  : TextFormField(
                      controller: controllers[f.key],
                      enabled: !busy,
                      obscureText: f.kind == 'secret',
                      autocorrect: f.kind != 'secret',
                      keyboardType: f.kind == 'int'
                          ? TextInputType.number
                          : TextInputType.text,
                      maxLines: ['list', 'json'].contains(f.kind) ? 3 : 1,
                      decoration: InputDecoration(
                        labelText: tr(context, f.en, f.zh),
                      ),
                    ),
            ),
          if (error.isNotEmpty)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(
              tr(context, busy ? 'Saving…' : 'Save', busy ? '正在保存…' : '保存'),
            ),
          ),
        ],
      ),
    ),
  );
}
