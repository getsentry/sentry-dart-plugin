import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/proguard/proguard_mapping.dart';
import 'package:sentry_dart_plugin/src/proguard/proguard_uuid.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';
import 'package:test/test.dart';

import 'utils/zip_builder.dart';

void main() {
  const uuid = 'c9fb2840-1f9c-4f08-81fe-6880753f345b';
  late FileSystem fs;
  late Configuration config;

  setUp(() {
    fs = MemoryFileSystem.test();
    injector.registerSingleton<FileSystem>(() => fs, override: true);
    config = Configuration()
      ..buildFilesFolder = 'build'
      ..uploadProguard = true
      ..proguardUuid = null;
  });

  String? injectedUuid() {
    final file = fs.file(debugMetaAssetPath);
    return file.existsSync()
        ? parseProguardUuid(file.readAsStringSync())
        : null;
  }

  group('generateUuid', () {
    test('generates valid, distinct version 4 UUIDs', () {
      final uuids = List.generate(50, (_) => generateUuid());
      for (final u in uuids) {
        expect(isValidProguardUuid(u), isTrue, reason: u);
        expect(u[14], '4', reason: 'version nibble of $u');
        expect('89ab'.contains(u[19]), isTrue, reason: 'variant of $u');
      }
      expect(uuids.toSet().length, uuids.length);
    });
  });

  group('parseProguardUuid', () {
    test('reads the value, ignoring comments and other keys', () {
      expect(
        parseProguardUuid('# comment\n'
            'io.sentry.build-tool=gradle\n'
            'io.sentry.ProguardUuids=$uuid\n'),
        uuid,
      );
    });

    test('supports ":" separators and surrounding whitespace', () {
      expect(parseProguardUuid('  io.sentry.ProguardUuids : $uuid  '), uuid);
    });

    test('takes the first of several "|"-separated UUIDs', () {
      expect(
        parseProguardUuid('io.sentry.ProguardUuids=$uuid|${generateUuid()}'),
        uuid,
      );
    });

    test('returns null without the key or with an empty value', () {
      expect(parseProguardUuid('io.sentry.bundle-ids=x'), isNull);
      expect(parseProguardUuid('io.sentry.ProguardUuids='), isNull);
    });
  });

  group('injectProguardUuid', () {
    setUp(() => fs.directory('android/app').createSync(recursive: true));

    test('writes a generated UUID into the Android assets', () async {
      expect(await injectProguardUuid(fs: fs, config: config), 0);
      final injected = injectedUuid();
      expect(injected, isNotNull);
      expect(isValidProguardUuid(injected!), isTrue);
      expect(await hasInjectedProguardUuid(fs), isTrue);
    });

    test('generates a new UUID on every run', () async {
      await injectProguardUuid(fs: fs, config: config);
      final first = injectedUuid();
      await injectProguardUuid(fs: fs, config: config);
      expect(injectedUuid(), isNot(first));
    });

    test('uses the configured proguard_uuid', () async {
      config.proguardUuid = uuid;
      expect(await injectProguardUuid(fs: fs, config: config), 0);
      expect(injectedUuid(), uuid);
    });

    test('fails on an invalid configured proguard_uuid', () async {
      config.proguardUuid = 'not-a-uuid';
      expect(await injectProguardUuid(fs: fs, config: config), 1);
      expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
    });

    test('does nothing without an Android app', () async {
      fs.directory('android').deleteSync(recursive: true);
      expect(await injectProguardUuid(fs: fs, config: config), 0);
      expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
    });

    test('does nothing when upload_proguard is disabled', () async {
      config.uploadProguard = false;
      expect(await injectProguardUuid(fs: fs, config: config), 0);
      expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
    });

    for (final gradleFile in [
      'android/app/build.gradle',
      'android/app/build.gradle.kts',
      'android/settings.gradle.kts',
    ]) {
      test('does nothing when the Sentry Gradle plugin is in $gradleFile',
          () async {
        fs.file(gradleFile)
          ..createSync(recursive: true)
          ..writeAsStringSync('plugins { id("io.sentry.android.gradle") }');
        expect(await injectProguardUuid(fs: fs, config: config), 0);
        expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
      });
    }

    test('leaves a debug-meta file it did not create untouched', () async {
      const content = 'io.sentry.ProguardUuids=$uuid\n';
      fs.file(debugMetaAssetPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
      expect(await injectProguardUuid(fs: fs, config: config), 0);
      expect(fs.file(debugMetaAssetPath).readAsStringSync(), content);
      expect(await hasInjectedProguardUuid(fs), isFalse);
    });
  });

  group('readBuiltAppProguardUuid', () {
    void writeArtifact(String path, Map<String, String> entries,
        {DateTime? modified}) {
      final file = fs.file(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(buildZip(entries));
      if (modified != null) {
        file.setLastModifiedSync(modified);
      }
    }

    test('reads the UUID from an APK', () async {
      writeArtifact('build/app/outputs/flutter-apk/app-release.apk', {
        'assets/sentry-debug-meta.properties': 'io.sentry.ProguardUuids=$uuid',
      });
      final built = await readBuiltAppProguardUuid(fs: fs, config: config);
      expect(built?.uuid, uuid);
      expect(
          built?.artifactPath, 'build/app/outputs/flutter-apk/app-release.apk');
    });

    test('reads the UUID from an AAB', () async {
      writeArtifact('build/app/outputs/bundle/release/app-release.aab', {
        'base/assets/sentry-debug-meta.properties':
            'io.sentry.ProguardUuids=$uuid',
      });
      expect(
          (await readBuiltAppProguardUuid(fs: fs, config: config))?.uuid, uuid);
    });

    test('only considers the newest artifact', () async {
      writeArtifact(
        'build/app/outputs/flutter-apk/app-release.apk',
        {
          'assets/sentry-debug-meta.properties': 'io.sentry.ProguardUuids=$uuid'
        },
        modified: DateTime(2026, 1, 1),
      );
      writeArtifact(
        'build/app/outputs/bundle/release/app-release.aab',
        {'base/manifest/AndroidManifest.xml': ''},
        modified: DateTime(2026, 1, 2),
      );
      expect(await readBuiltAppProguardUuid(fs: fs, config: config), isNull);
    });

    test('returns null without build outputs or artifacts', () async {
      expect(await readBuiltAppProguardUuid(fs: fs, config: config), isNull);
      fs.directory('build/app/outputs/mapping').createSync(recursive: true);
      expect(await readBuiltAppProguardUuid(fs: fs, config: config), isNull);
    });
  });

  group('removeInjectedProguardUuid', () {
    test('removes the file written by --inject-uuid', () async {
      fs.directory('android/app').createSync(recursive: true);
      await injectProguardUuid(fs: fs, config: config);
      await removeInjectedProguardUuid(fs);
      expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
    });

    test('keeps a debug-meta file it did not create', () async {
      fs.file(debugMetaAssetPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('io.sentry.ProguardUuids=$uuid\n');
      await removeInjectedProguardUuid(fs);
      expect(fs.file(debugMetaAssetPath).existsSync(), isTrue);
    });
  });
}
