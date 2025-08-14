import 'package:file/file.dart';

import '../configuration.dart';

/// Enumerates the search roots used to discover native debug files, matching
/// the existing behavior used by the plugin when uploading debug files.
///
/// This preserves current directories and files probed for:
/// - Android (apk, appbundle)
/// - Windows
/// - Linux
/// - macOS (app and framework)
/// - iOS (Runner.app, Release-*-iphoneos folders, archive, framework)
/// - iOS in Fastlane (ios/build)
Stream<String> enumerateDebugSearchRoots({
  required FileSystem fs,
  required Configuration config,
}) async* {
  final String buildDir = config.buildFilesFolder;
  final String projectRoot = fs.currentDirectory.path;

  // Android (apk, appbundle)
  yield '$buildDir/app/outputs';
  yield '$buildDir/app/intermediates';

  // Windows
  for (final subdir in ['', '/x64', '/arm64']) {
    yield '$buildDir/windows$subdir/runner/Release';
  }
  // TODO: Consider removing once Windows symbols are collected automatically.
  // Related to https://github.com/getsentry/sentry-dart-plugin/issues/173
  yield 'windows/flutter/ephemeral/flutter_windows.dll.pdb';

  // Linux
  for (final subdir in ['/x64', '/arm64']) {
    yield '$buildDir/linux$subdir/release/bundle';
  }

  // macOS
  yield '$buildDir/macos/Build/Products/Release';

  // macOS (macOS-framework)
  yield '$buildDir/macos/framework/Release';

  // iOS
  yield '$buildDir/ios/iphoneos/Runner.app';
  final iosDir = fs.directory('$buildDir/ios');
  if (await iosDir.exists()) {
    final regexp = RegExp(r'^Release(-.*)?-iphoneos$');
    yield* iosDir
        .list()
        .where((entity) => regexp.hasMatch(fs.path.basename(entity.path)))
        .map((entity) => entity.path);
  }

  // iOS (ipa)
  yield '$buildDir/ios/archive';

  // iOS (ios-framework)
  yield '$buildDir/ios/framework/Release';

  // iOS in Fastlane
  if (projectRoot == '/') {
    yield 'ios/build';
  } else {
    yield '$projectRoot/ios/build';
  }
}
