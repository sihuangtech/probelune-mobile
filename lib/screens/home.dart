import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../localization.dart';
import '../services/locale.dart';
import '../widgets/brand_icon.dart';
import '../services/api.dart';
import '../services/instances.dart';
import '../services/push.dart';
import '../widgets/home_feed.dart';
import 'connect.dart';
import 'incident.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen(this.instances, {super.key});
  final Instances instances;
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> with WidgetsBindingObserver {
  Json data = {};
  List<Json> incidents = [];
  bool offline = false, busy = false;
  String error = '';
  int tab = 0, savedAt = 0;
  Timer? timer;
  String identity = '';
  final push = PushService();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.instances.addListener(changed);
    changed();
    timer = Timer.periodic(const Duration(seconds: 8), (_) => refresh());
    push
        .initialize(widget.instances, openNotification, (text) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(text)));
          }
        })
        .catchError((Object e) {
          if (mounted) setState(() => error = e.toString());
        });
  }

  @override
  void dispose() {
    timer?.cancel();
    push.dispose();
    widget.instances.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  void changed() {
    final i = widget.instances.current;
    final key = i == null ? '' : '${i.url}:${i.token}';
    if (key != identity) {
      identity = key;
      data = {};
      incidents = [];
      error = '';
      savedAt = 0;
      offline = false;
      refresh();
    }
    if (mounted) setState(() {});
  }

  Future<void> refresh() async {
    final instance = widget.instances.current;
    if (instance == null || busy) return;
    busy = true;
    final key = identity;
    try {
      final client = Api(instance.url, instance.token);
      final values = await Future.wait([
        client.request('/overview'),
        client.request('/incidents'),
      ]);
      final next = object(values[0]);
      next['all_incidents'] = values[1];
      if (!mounted ||
          identity != key ||
          !widget.instances.items.contains(instance)) {
        return;
      }
      if (instance.id.isEmpty && next['instance_id'] is String) {
        instance.id = next['instance_id'] as String;
        await widget.instances.persist();
      }
      await widget.instances.cache(instance, next);
      if (mounted && identity == key) {
        setState(() {
          data = next;
          incidents = objects(values[1]);
          offline = false;
          error = '';
          savedAt = DateTime.now().millisecondsSinceEpoch;
        });
      }
    } catch (e) {
      final cached = await widget.instances.cached(instance);
      if (mounted && identity == key) {
        setState(() {
          error = e.toString();
          offline = true;
          if (cached != null) {
            data = object(cached['data']);
            incidents = objects(data['all_incidents']);
            savedAt = cached['saved_at'] as int;
          }
        });
      }
    } finally {
      busy = false;
      if (identity != key) refresh();
    }
  }

  void openNotification(Json payload) {
    final index = widget.instances.items.indexWhere(
      (i) =>
          (i.id.isNotEmpty && i.id == payload['instance_id']) ||
          i.url == payload['instance_url'],
    );
    if (index < 0) return;
    widget.instances.select(index);
    final id = payload['event_id'];
    if (id is String && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              IncidentScreen(instance: widget.instances.current!, id: id),
        ),
      );
    }
  }

  Future<void> connect() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => ConnectScreen(widget.instances)),
  );
  @override
  Widget build(BuildContext context) {
    final instance = widget.instances.current;
    return Scaffold(
      appBar: AppBar(
        title: Text(message(context, 'mProbelune972d')),
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_6_outlined),
            tooltip: message(context, 'theme'),
            onSelected: setTheme,
            itemBuilder: (_) => [
              for (final mode in ThemeMode.values)
                PopupMenuItem(
                  value: mode,
                  child: Text(
                    message(
                      context,
                      'theme${mode.name[0].toUpperCase()}${mode.name.substring(1)}',
                    ),
                  ),
                ),
            ],
          ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: message(context, 'mLanguagee66f'),
            onSelected: (value) => setLanguage(value),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: '',
                child: Text(message(context, 'mSystemLanguagee429')),
              ),
              for (final entry in languageNames.entries)
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
            ],
          ),

          if (instance != null)
            PopupMenuButton<int>(
              icon: const Icon(Icons.dns_outlined),
              tooltip: message(context, 'mSwitchInstancefd32'),
              onSelected: (index) {
                if (index < 0) {
                  connect();
                } else {
                  widget.instances.select(index);
                }
              },
              itemBuilder: (_) => [
                for (final entry in widget.instances.items.indexed)
                  CheckedPopupMenuItem(
                    value: entry.$1,
                    checked: entry.$2 == instance,
                    child: Text(
                      '${Uri.parse(entry.$2.url).host} - ${entry.$2.username}',
                    ),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: -1,
                  child: Text(message(context, 'mConnectInstance7db6')),
                ),
              ],
            )
          else
            IconButton(
              onPressed: connect,
              icon: const Icon(Icons.add),
              tooltip: message(context, 'mConnectInstance7db6'),
            ),
        ],
      ),
      body: instance == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandIcon(size: 70),
                    const SizedBox(height: 24),
                    Text(
                      message(context, 'mEveryLocationOneClearViewd8d9'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    if (widget.instances.error.isNotEmpty)
                      Text(widget.instances.error),
                    FilledButton(
                      onPressed: connect,
                      child: Text(
                        message(context, 'mConnectYourDashboard68b1'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (offline)
                  MaterialBanner(
                    content: Text(
                      '${message(context, 'mOfflineLastSnapshot32f8')}: ${timeText(savedAt ~/ 1000)}\n$error',
                    ),
                    actions: [
                      TextButton(
                        onPressed: refresh,
                        child: Text(message(context, 'mRetrye880')),
                      ),
                    ],
                  ),
                Expanded(
                  child: tab == 4
                      ? SettingsScreen(widget.instances, push)
                      : RefreshIndicator(
                          onRefresh: refresh,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            children: [
                              Text(
                                Uri.parse(instance.url).host,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              if (!offline && error.isNotEmpty) Text(error),
                              HomeFeed(
                                key: ValueKey(identity),
                                data: data,
                                incidents: incidents,
                                instance: instance,
                                offline: offline,
                                tab: [4, 0, 1, 2, 3][tab],
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: instance == null
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() => tab = v),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  label: message(context, 'mOverviewe4c2'),
                ),

                NavigationDestination(
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: message(context, 'mMonitors0045'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.notifications_outlined),
                  label: message(context, 'mIncidentsd2aa'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.hub_outlined),
                  label: message(context, 'mNodesc654'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  label: message(context, 'mSettings4d92'),
                ),
              ],
            ),
    );
  }
}
