import 'package:flutter/material.dart';

import 'app.dart';
import 'services/locale.dart';
import 'services/instances.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadLanguage();
  await loadTheme();
  final instances = Instances();
  await instances.load();
  runApp(ProbeluneApp(instances: instances));
}
