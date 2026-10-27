# Release and push setup / 发布与推送

## Android

Application ID: `cn.sihuangtech.probelune_mobile`. Create a private upload keystore using the official Android signing guide. Copy `android/key.properties.example` to ignored `android/key.properties`, set its absolute keystore path, alias and passwords, then run `flutter build appbundle --release`.

No signing secrets are committed. Without `key.properties`, release output is not signed for publication. CI debug APKs are validation artifacts. Keep keystore recovery copies outside Git.

## iOS

Bundle ID: `cn.sihuangtech.probeluneMobile`; minimum iOS 15. Open `ios/Runner.xcworkspace`, select your signing team and correct profiles, then use `flutter build ipa`. `flutter build ios --no-codesign` only validates compilation.

Enable Push Notifications capability for a push-enabled distribution and configure APNs credentials in Firebase. The Runner entitlements use `APS_ENVIRONMENT`: development for Debug, production for Release/Profile. Verify this matches your actual provisioning profile. Keychain access is scoped to the app identifier.

## Optional Firebase

Register the platform app IDs in your own Firebase project. Create a local ignored `firebase-config.json` with the appropriate platform's Firebase app ID:

```json
{
  "FIREBASE_ENABLED": "true",
  "FIREBASE_API_KEY": "YOUR_PUBLIC_FIREBASE_API_KEY",
  "FIREBASE_APP_ID": "YOUR_PLATFORM_APP_ID",
  "FIREBASE_SENDER_ID": "YOUR_MESSAGING_SENDER_ID",
  "FIREBASE_PROJECT_ID": "YOUR_PROJECT_ID"
}
```

```sh
flutter run --dart-define-from-file=firebase-config.json
flutter build appbundle --release --dart-define-from-file=firebase-config.json
flutter build ipa --dart-define-from-file=firebase-config.json
```

The dashboard needs a service-account file from the same project via `GOOGLE_APPLICATION_CREDENTIALS`. Never embed that private file in the app. Messaging 17 uses registration/installation-ID APIs; the server addresses `message.fid`. Analytics and automatic messaging initialization are disabled; the user explicitly opts into notifications.

面板创建 push 渠道并绑定监测，移动端为每个实例开启通知。设备注册按实例保存，退出时撤销。FCM 只接收事件 ID、实例地址、事件类型和通用提示。详情从自己的面板读取，内网可能需 VPN。没有 Google 服务或无法连接 FCM 的 Android 环境不承诺原生推送，可改用 SMTP/Webhook。

## Release verification

On signed real Android/iOS devices verify: permissions denied/granted, foreground/background/terminated delivery, correct instance/event navigation, offline panel/VPN behavior, registration refresh, logout and revocation. Exercise actual failure and recovery notifications. Store privacy declarations must match the actual deployment.

Local validation covers static analysis, Android debug build/emulator connection and unsigned iOS compilation. Provider delivery, maintainer signing and store submission require external credentials and are recorded separately in the shared acceptance document.

References: [Flutter Android](https://docs.flutter.dev/deployment/android), [Flutter iOS](https://docs.flutter.dev/deployment/ios), [Firebase Flutter setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
