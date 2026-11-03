import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization.dart';
import '../widgets/brand_icon.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final info = PackageInfo.fromPlatform();
  @override
  Widget build(BuildContext context) {
    final name = message(context, 'mProbelune972d');
    return Scaffold(
      appBar: AppBar(title: Text(message(context, 'aboutApp'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(child: BrandIcon(size: 76)),
            const SizedBox(height: 16),
            Text(
              name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            FutureBuilder<PackageInfo>(
              future: info,
              builder: (_, snapshot) {
                final value = snapshot.data;
                return Text(
                  value == null
                      ? ''
                      : 'v${value.version} (${value.buildNumber})',
                  textAlign: TextAlign.center,
                );
              },
            ),
            Center(
              child: IconButton(
                tooltip: 'GitHub',
                icon: const FaIcon(FontAwesomeIcons.github),
                onPressed: () async {
                  final uri = Uri.https(
                    'github.com',
                    '/sihuangtech/probelune-mobile',
                  );
                  try {
                    if (await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    )) {
                      return;
                    }
                  } catch (_) {}
                  if (context.mounted) {
                    showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('GitHub'),
                        content: SelectableText(uri.toString()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: Text(message(c, 'mDone4bc2')),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('GPL-3.0-or-later'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final license = await rootBundle.loadString('LICENSE');
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('GPL-3.0-or-later')),
                        body: SafeArea(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: SelectableText(license),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              title: Text(MaterialLocalizations.of(context).licensesPageTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  showLicensePage(context: context, applicationName: name),
            ),
          ],
        ),
      ),
    );
  }
}
