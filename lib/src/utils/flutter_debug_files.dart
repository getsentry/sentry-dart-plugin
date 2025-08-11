import 'package:file/file.dart';

import '../configuration.dart';

/// Finds Flutter-relevant debug file paths for Android and Apple (iOS/macOS).
/// TODO(buenaflor): in the follow-up PR this should be coupled together with the dart symbol map
Future<Set<String>> findFlutterRelevantDebugFilePaths({
  required FileSystem fs,
  required Configuration config,
}) async {
  final Set<String> foundPaths = <String>{};

  Future<void> collectAndroidSymbolsUnder(String rootPath) async {
    if (rootPath.isEmpty) return;

    final directory = fs.directory(rootPath);
    if (await directory.exists()) {
      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final String basename = fs.path.basename(entity.path);
        if (basename.startsWith('app') &&
            basename.endsWith('.symbols') &&
            !basename.contains('darwin')) {
          foundPaths.add(fs.file(entity.path).absolute.path);
        }
      }
      return;
    }

    final file = fs.file(rootPath);
    if (await file.exists()) {
      final String basename = fs.path.basename(file.path);
      if (basename.startsWith('app') &&
          basename.endsWith('.symbols') &&
          !basename.contains('darwin')) {
        foundPaths.add(file.absolute.path);
      }
    }
  }

  // First, scan the configured symbols folder (if any)
  if (config.symbolsFolder.isNotEmpty) {
    await collectAndroidSymbolsUnder(config.symbolsFolder);
  }

  // Backward compatibility: also scan build folder if different
  if (config.buildFilesFolder != config.symbolsFolder) {
    await collectAndroidSymbolsUnder(config.buildFilesFolder);
  }

  // Then, scan all current search roots used by the plugin
  await for (final root in enumerateDebugSearchRoots(fs: fs, config: config)) {
    await collectAndroidSymbolsUnder(root);
  }

  Future<void> collectAppleMachOUnder(String rootPath) async {
    if (rootPath.isEmpty) return;
    final dir = fs.directory(rootPath);
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! Directory) continue;
      final String basename = fs.path.basename(entity.path);
      if (basename == 'App.framework.dSYM') {
        final String machOPath = fs.path.join(
          entity.path,
          'Contents',
          'Resources',
          'DWARF',
          'App',
        );
        final File machOFile = fs.file(machOPath);
        if (await machOFile.exists()) {
          foundPaths.add(machOFile.absolute.path);
        }
      }
    }
  }

  // Search under the build directory directly to catch common iOS layouts
  await collectAppleMachOUnder(config.buildFilesFolder);

  // Search all known roots (includes Fastlane ios/build)
  await for (final root in enumerateDebugSearchRoots(fs: fs, config: config)) {
    await collectAppleMachOUnder(root);
  }

  return foundPaths;
}

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
