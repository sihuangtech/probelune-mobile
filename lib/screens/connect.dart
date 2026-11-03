import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../localization.dart';
import '../widgets/brand_icon.dart';
import '../models.dart';
import '../services/instances.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen(this.instances, {super.key});
  final Instances instances;
  @override
  State<ConnectScreen> createState() => _ConnectState();
}

class _ConnectState extends State<ConnectScreen> {
  final url = TextEditingController(),
      username = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController();
  bool busy = false, allowHttp = false;
  String error = '';
  @override
  void dispose() {
    url.dispose();
    username.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.instances.connect(
        url.text,
        username.text,
        password.text,
        code: code.text,
        allowHttp: allowHttp,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (value == null || !mounted) return;
    try {
      final data = object(jsonDecode(value));
      if (data['type'] != 'probelune-pair' || data['version'] != 1) {
        throw const FormatException();
      }
      url.text = data['url'] as String;
      code.text = data['code'] as String;
    } catch (e) {
      if (mounted) {
        setState(() => error = message(context, 'clientInvalidPairingCode'));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(message(context, 'mConnectInstance7db6'))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const BrandIcon(size: 54),
            const SizedBox(height: 20),
            Text(
              message(context, 'mYourNetworkInViewa101'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: message(context, 'mDashboardURL0f42'),
                hintText: 'https://monitor.example.com',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: username,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(
                labelText: message(context, 'mUsernamede33'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: message(context, 'mPasswordb160'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: code,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: message(context, 'mOrOneTimePairingCode68ce'),
              ),
            ),
            TextButton.icon(
              onPressed: busy ? null : scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(message(context, 'mScanPairingQR0a98')),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: allowHttp,
              onChanged: (v) => setState(() => allowHttp = v ?? false),
              title: Text(message(context, 'mAllowHTTPOnATrustedLocal2703')),
              subtitle: Text(
                message(context, 'mCredentialsAreUnencryptedOverHTTPf9d2'),
              ),
            ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(
                busy
                    ? message(context, 'mConnecting9426')
                    : message(context, 'mConnect6a42'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanState();
}

class _ScanState extends State<ScanScreen> {
  final controller = MobileScannerController();
  bool captured = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(message(context, 'mScanPairingQR0a98'))),
    body: MobileScanner(
      controller: controller,
      onDetect: (capture) {
        if (captured) return;
        for (final b in capture.barcodes) {
          if (b.rawValue != null) {
            captured = true;
            Navigator.pop(context, b.rawValue);
            break;
          }
        }
      },
    ),
  );
}
