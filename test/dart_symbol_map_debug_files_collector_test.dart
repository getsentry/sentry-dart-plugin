import 'package:file/memory.dart';
import 'package:test/test.dart';

import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/symbol_maps/dart_symbol_map_debug_files_collector.dart';

void main() {
  group('collectDebugFilesForDartMap', () {
    test(
        'returns custom Android and iOS debug files from configured symbols path',
        () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRootDir = fs.directory('/work')..createSync(recursive: true);
      fs.currentDirectory = projectRootDir;

      final buildDir = '/work/build';
      final symbolsDir = '/work/symbols';

      // Android .symbols files
      fs
          .file('$symbolsDir/app.android-arm.symbols')
          .createSync(recursive: true);
      fs
          .file('$symbolsDir/app.android-arm64.symbols')
          .createSync(recursive: true);
      fs
          .file('$symbolsDir/app.android-x64.symbols')
          .createSync(recursive: true);

      // Apple App.framework.dSYM Mach-O under the configured symbols path.
      final appDsymMachO =
          '$symbolsDir/App.framework.dSYM/Contents/Resources/DWARF/App';
      fs.file(appDsymMachO).createSync(recursive: true);

      // Noise: other .dSYM bundles should be ignored
      fs
          .file(
              '$buildDir/ios/iphoneos/Runner.app.dSYM/Contents/Resources/DWARF/Runner')
          .createSync(recursive: true);
      fs
          .file(
              '$buildDir/macos/Build/Products/Release/FlutterMacOS.framework.dSYM/Contents/Resources/DWARF/FlutterMacOS')
          .createSync(recursive: true);

      final config = Configuration()
        ..buildFilesFolder = buildDir
        ..symbolsFolder = symbolsDir;

      final result = await collectDebugFilesForDartMap(
        fs: fs,
        config: config,
      );

      expect(
          result,
          containsAll(<String>[
            fs.path.normalize('/work/symbols/app.android-arm.symbols'),
            fs.path.normalize('/work/symbols/app.android-arm64.symbols'),
            fs.path.normalize('/work/symbols/app.android-x64.symbols'),
            fs.path.normalize(appDsymMachO),
          ]));

      // Ensure we did not include non-App.framework dSYMs
      expect(result.any((p) => p.endsWith('/Runner')), isFalse);
      expect(result.any((p) => p.endsWith('/FlutterMacOS')), isFalse);

      // Ensure absoluteness
      expect(result.length, 4);
      for (final p in result) {
        expect(p.startsWith('/'), isTrue,
            reason: 'path should be absolute: $p');
      }
    });

    test('uses symbols path for Android symbol discovery', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRootDir = fs.directory('/project')
        ..createSync(recursive: true);
      fs.currentDirectory = projectRootDir;

      final buildDir = '/project/out';
      final symbolsDir = '/project/build/symbols';
      final symbolsPath = '$symbolsDir/app.android-arm64.symbols';
      final outputsSymbols = '$buildDir/app/outputs/app.android-x64.symbols';
      fs.file(symbolsPath).createSync(recursive: true);
      fs.file(outputsSymbols).createSync(recursive: true);

      final config = Configuration()
        ..buildFilesFolder = buildDir
        ..symbolsFolder = symbolsDir;

      final result = await collectDebugFilesForDartMap(
        fs: fs,
        config: config,
      );

      expect(result, contains(fs.path.normalize(symbolsPath)));
      expect(result, isNot(contains(fs.path.normalize(outputsSymbols))));
    });

    test('uses focused iOS fallback roots for default symbols path', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRootDir = fs.directory('/project')
        ..createSync(recursive: true);
      fs.currentDirectory = projectRootDir;

      final buildDir = '/project/build';

      // Fastlane path
      final machO =
          '/project/ios/build/App.framework.dSYM/Contents/Resources/DWARF/App';
      fs.file(machO).createSync(recursive: true);

      // This should be ignored when using the default symbols path.
      final unrelatedProjectRootMachO =
          '/project/App.framework.dSYM/Contents/Resources/DWARF/App';
      fs.file(unrelatedProjectRootMachO).createSync(recursive: true);

      final config = Configuration()
        ..buildFilesFolder = buildDir
        ..symbolsFolder = Configuration.defaultSymbolsFolder;

      final result = await collectDebugFilesForDartMap(
        fs: fs,
        config: config,
      );

      expect(result, contains(fs.path.normalize(machO)));
      expect(result,
          isNot(contains(fs.path.normalize(unrelatedProjectRootMachO))));
    });

    test('finds App.framework.dSYM under configured symbols path', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRootDir = fs.directory('/ci-workspace')
        ..createSync(recursive: true);
      fs.currentDirectory = projectRootDir;

      final buildDir = '/ci-workspace/build';
      final symbolsDir = '/downloaded-symbols';

      final machO =
          '/downloaded-symbols/App.framework.dSYM/Contents/Resources/DWARF/App';
      fs.file(machO).createSync(recursive: true);

      final config = Configuration()
        ..buildFilesFolder = buildDir
        ..symbolsFolder = symbolsDir;

      final result = await collectDebugFilesForDartMap(
        fs: fs,
        config: config,
      );

      expect(result, contains(fs.path.normalize(machO)));
    });

    // macOS is not supported for Dart symbol map pairing.

    test('prefers configured symbols path over default Android build roots',
        () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRootDir = fs.directory('/project')
        ..createSync(recursive: true);
      fs.currentDirectory = projectRootDir;

      final buildDir = '/project/build';
      final symbolsDir = '/external-symbols';
      final symbolsPath = '/external-symbols/app.android-arm64.symbols';
      final defaultPath = '/project/build/app/outputs/app.android-x64.symbols';
      fs.file(symbolsPath).createSync(recursive: true);
      fs.file(defaultPath).createSync(recursive: true);

      final config = Configuration()
        ..buildFilesFolder = buildDir
        ..symbolsFolder = symbolsDir;

      final result = await collectDebugFilesForDartMap(
        fs: fs,
        config: config,
      );

      expect(result, contains(fs.path.normalize(symbolsPath)));
      expect(result, isNot(contains(fs.path.normalize(defaultPath))));
    });

    test('searches symbols path and default iOS build roots', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRootDir = fs.directory('/project')
        ..createSync(recursive: true);
      fs.currentDirectory = projectRootDir;

      final buildDir = '/project/build';
      final symbolsDir = '/external-symbols';
      final symbolsMachO =
          '/external-symbols/App.framework.dSYM/Contents/Resources/DWARF/App';
      final buildMachO =
          '/project/build/ios/Release-iphoneos/App.framework.dSYM/Contents/Resources/DWARF/App';
      final fastlaneMachO =
          '/project/ios/build/App.framework.dSYM/Contents/Resources/DWARF/App';
      fs.file(symbolsMachO).createSync(recursive: true);
      fs.file(buildMachO).createSync(recursive: true);
      fs.file(fastlaneMachO).createSync(recursive: true);

      final config = Configuration()
        ..buildFilesFolder = buildDir
        ..symbolsFolder = symbolsDir;

      final result = await collectDebugFilesForDartMap(
        fs: fs,
        config: config,
      );

      expect(result, contains(fs.path.normalize(symbolsMachO)));
      expect(result, contains(fs.path.normalize(buildMachO)));
      expect(result, contains(fs.path.normalize(fastlaneMachO)));
    });

    test('finds App.framework.dSYM inside iOS Xcode archive dSYMs', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRootDir = fs.directory('/iosproj')
        ..createSync(recursive: true);
      fs.currentDirectory = projectRootDir;

      final buildDir = '/iosproj/build';

      // iOS archive path
      final iosArchiveMachO =
          '$buildDir/ios/archive/Runner.xcarchive/dSYMs/App.framework.dSYM/Contents/Resources/DWARF/App';
      fs.file(iosArchiveMachO).createSync(recursive: true);

      final config = Configuration()
        ..buildFilesFolder = buildDir
        ..symbolsFolder = Configuration.defaultSymbolsFolder;

      final result = await collectDebugFilesForDartMap(
        fs: fs,
        config: config,
      );

      expect(result, contains(fs.path.normalize(iosArchiveMachO)));
    });

    // macOS archive is not supported for Dart symbol map pairing.

    test('returns empty set when no roots or symbols exist', () async {
      final fs = MemoryFileSystem(style: FileSystemStyle.posix);
      final projectRootDir = fs.directory('/empty')
        ..createSync(recursive: true);
      fs.currentDirectory = projectRootDir;

      final buildDir = '/empty/build';
      final symbolsDir = '/empty/symbols';

      final config = Configuration()
        ..buildFilesFolder = buildDir
        ..symbolsFolder = symbolsDir;

      final result = await collectDebugFilesForDartMap(
        fs: fs,
        config: config,
      );

      expect(result, isEmpty);
    });
  });
}
