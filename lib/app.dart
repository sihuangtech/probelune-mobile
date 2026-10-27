import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/instances.dart';
import 'screens/home.dart';

class ProbeluneApp extends StatelessWidget {
  const ProbeluneApp({super.key, required this.instances});
  final Instances instances;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Probelune · 巡汐',
    debugShowCheckedModeBanner: false,
    supportedLocales: const [Locale('en'), Locale('zh')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f73)),
      scaffoldBackgroundColor: const Color(0xfff5f7f3),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfff5f7f3),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    home: HomeScreen(instances),
  );
}
