import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'generated/l10n/app_localizations.dart';
import 'localization.dart';
import 'services/locale.dart';

import 'services/instances.dart';
import 'screens/home.dart';

class ProbeluneApp extends StatelessWidget {
  const ProbeluneApp({super.key, required this.instances});
  final Instances instances;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale?>(
    valueListenable: preferredLocale,
    builder: (context, locale, _) => ValueListenableBuilder<ThemeMode>(
      valueListenable: preferredTheme,
      builder: (context, themeMode, _) => MaterialApp(
        themeMode: themeMode,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff52c5a5),
            brightness: Brightness.dark,
          ),
        ),
        locale: locale,
        localeListResolutionCallback: (locales, supported) =>
            resolveDeviceLocale(locales?.firstOrNull ?? const Locale('en')),
        builder: (context, child) {
          Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
          return child!;
        },
        onGenerateTitle: (context) => message(context, 'mProbelune972d'),
        debugShowCheckedModeBanner: false,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        home: HomeScreen(instances),
      ),
    ),
  );
}
