import 'dart:io';

Future<void> main() async {
  final result = await Process.run('dart', ['run', 'flutter_launcher_icons']);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    exitCode = result.exitCode;
    return;
  }

  // flutter_launcher_icons 0.14.4 also rewrites this unrelated Xcode boolean.
  // Restore it so regenerating icons does not change Swift asset generation.
  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  final contents = await project.readAsString();
  await project.writeAsString(
    contents.replaceAll(
      'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon;',
      'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;',
    ),
  );
}
