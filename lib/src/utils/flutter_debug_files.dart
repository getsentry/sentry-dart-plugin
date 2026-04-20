import 'package:file/file.dart';

import '../configuration.dart';
import 'log.dart';

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
  final String? flavor = config.flavor;

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

  // Apple

  final RegExp appleReleaseDirPattern = RegExp(r'^Release(?:-.+)?$');
  final RegExp iosReleaseDirPattern = RegExp(r'^Release(?:-.+)?-iphoneos$');

  // macOS
  yield* _enumerateReleaseDirectories(
    fs: fs,
    basePath: '$buildDir/macos/Build/Products',
    releaseDirPattern: appleReleaseDirPattern,
    exactName: flavor == null ? null : 'Release-$flavor',
  );

  // macOS (macOS-framework)
  yield* _enumerateReleaseDirectories(
    fs: fs,
    basePath: '$buildDir/macos/framework',
    releaseDirPattern: appleReleaseDirPattern,
    exactName: flavor == null ? null : 'Release-$flavor',
  );

  // iOS
  yield '$buildDir/ios/iphoneos/Runner.app';
  yield* _enumerateReleaseDirectories(
    fs: fs,
    basePath: '$buildDir/ios',
    releaseDirPattern: iosReleaseDirPattern,
    exactName: flavor == null ? null : 'Release-$flavor-iphoneos',
  );

  // iOS (ipa)
  yield '$buildDir/ios/archive';

  // iOS (ios-framework)
  yield* _enumerateReleaseDirectories(
    fs: fs,
    basePath: '$buildDir/ios/framework',
    releaseDirPattern: appleReleaseDirPattern,
    exactName: flavor == null ? null : 'Release-$flavor',
  );

  // iOS in Fastlane
  if (projectRoot == '/') {
    yield 'ios/build';
  } else {
    yield '$projectRoot/ios/build';
  }
}

Stream<String> _enumerateReleaseDirectories({
  required FileSystem fs,
  required String basePath,
  required RegExp releaseDirPattern,
  String? exactName,
}) async* {
  final baseDir = fs.directory(basePath);
  if (!await baseDir.exists()) {
    return;
  }

  final matchingPaths = <String>[];

  await for (final entity in baseDir.list()) {
    if (entity is! Directory) {
      continue;
    }

    final basename = fs.path.basename(entity.path);
    if (exactName != null) {
      if (basename == exactName) {
        matchingPaths.add(entity.path);
      }
      continue;
    }

    if (releaseDirPattern.hasMatch(basename)) {
      matchingPaths.add(entity.path);
    }
  }

  if (exactName == null && matchingPaths.length > 1) {
    Log.warn(
      'Multiple release directories found for native debug symbols. Consider setting `flavor` to restrict uploads to one flavor.',
    );
  }

  yield* Stream<String>.fromIterable(matchingPaths);
}
