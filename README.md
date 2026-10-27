# Probelune Mobile

[简体中文](README.zh-CN.md) · [Dashboard](https://github.com/sihuangtech/probelune-dashboard) · [Product / PRD](https://github.com/sihuangtech/probelune)

The Flutter Android/iOS companion for **Probelune (巡汐)**. Connect to your dashboards, compare observations, investigate incidents and start remote rechecks from your phone. The app does not run a background probe.

## Features

- Multiple self-hosted instances; password login or short-lived, single-use pairing QR codes.
- Monitor overview, node health, per-location evidence, availability/coverage and historical charts.
- Incident timelines, acknowledgement, notes and one-hour silence, subject to server roles.
- Immediate rechecks with per-node results, progress and cancellation inside the app.
- Secure sessions and last-known overview cache (up to 24 hours), clearly marked offline.
- English and Simplified Chinese following the system locale.
- Optional native push using the deployer's Firebase/APNs setup.

## Run and build

Use stable Flutter (validated with Flutter 3.47.8 / Dart 3.13.7), Android SDK/JDK or Xcode for the target platform.

```sh
git clone https://github.com/sihuangtech/probelune-mobile.git
cd probelune-mobile
flutter pub get
flutter analyze
flutter run
flutter build apk --debug
flutter build ios --no-codesign
```

Connect to the HTTPS origin of a running dashboard. An explicit checkbox permits HTTP for controlled local networks. Android emulators reach the host via `10.0.2.2`; physical phones need a LAN/VPN hostname. The phone's localhost is not your server.

Pairing: in dashboard Settings choose Pair mobile device, then scan within two minutes. Codes contain no passwords or permanent tokens. Mobile sessions last 30 days and are revocable. Removing an instance attempts remote device/session revocation and clears local data.

The build commands produce an Android debug APK and an unsigned iOS app. Neither proves production signing or store readiness. See [release and push setup](docs/RELEASE.md). Release builds never silently use a debug signing key.

## Development

`lib/screens` contains pages; `widgets` contains reusable presentation; `services` owns HTTP, secure storage and push. `models.dart` and `l10n.dart` are shared helpers. No embedded backend or adjacent repository is needed. Use official `flutter pub add/remove/upgrade` commands for dependencies and commit `pubspec.lock`.

[Privacy](docs/PRIVACY.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Acceptance](https://github.com/sihuangtech/probelune/blob/main/docs/acceptance.md)

[GPL-3.0-or-later](LICENSE). Actual native push, signed installations and store publication require deployer credentials and real-device validation.
