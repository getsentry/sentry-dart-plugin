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

    for (final applied in [
      [
        'android/app/build.gradle',
        "plugins {\n  id 'io.sentry.android.gradle'\n}"
      ],
      [
        'android/app/build.gradle.kts',
        'plugins {\n  id("io.sentry.android.gradle") version "5.0.0"\n}'
      ],
      ['android/app/build.gradle', "apply plugin: 'io.sentry.android.gradle'"],
    ]) {
      test('does nothing when the Gradle plugin is applied: ${applied[1]}',
          () async {
        fs.file(applied[0])
          ..createSync(recursive: true)
          ..writeAsStringSync(applied[1]);
        expect(await injectProguardUuid(fs: fs, config: config), 0);
        expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
      });
    }

    for (final entry in {
      'android/settings.gradle':
          "plugins {\n  id 'io.sentry.android.gradle' version '5.0.0' apply false\n}",
      'android/app/build.gradle.kts':
          'plugins {\n  id("io.sentry.android.gradle") version "5.0.0" apply false\n}',
      'android/app/build.gradle':
          "// id 'io.sentry.android.gradle'\n/* apply plugin: 'io.sentry.android.gradle' */",
    }.entries) {
      test('injects when ${entry.key} only declares or mentions the plugin',
          () async {
        fs.file(entry.key)
          ..createSync(recursive: true)
          ..writeAsStringSync(entry.value);
        expect(await injectProguardUuid(fs: fs, config: config), 0);
        expect(injectedUuid(), isNotNull);
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

    test('handles a non-UTF-8 debug-meta file it did not create', () async {
      // 0xE9 is "é" in ISO-8859-1, the encoding of .properties files.
      final bytes = [
        ...'# caf'.codeUnits,
        0xE9,
        ...'\nio.sentry.ProguardUuids=$uuid\n'.codeUnits,
      ];
      fs.file(debugMetaAssetPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      expect(await injectProguardUuid(fs: fs, config: config), 0);
      expect(fs.file(debugMetaAssetPath).readAsBytesSync(), bytes);
      expect(await hasInjectedProguardUuid(fs), isFalse);
    });

    test('fails when proguard_uuid differs from a file it did not create',
        () async {
      fs.file(debugMetaAssetPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('io.sentry.ProguardUuids=$uuid\n');
      config.proguardUuid = generateUuid();
      expect(await injectProguardUuid(fs: fs, config: config), 1);
      expect(injectedUuid(), uuid);
    });

    test('accepts proguard_uuid matching a file it did not create', () async {
      fs.file(debugMetaAssetPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('io.sentry.ProguardUuids=$uuid\n');
      config.proguardUuid = uuid.toUpperCase();
      expect(await injectProguardUuid(fs: fs, config: config), 0);
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

  group('removeConsumedInjectedProguardUuid', () {
    const apk = 'build/app/outputs/flutter-apk/app-release.apk';

    Future<void> inject({required DateTime at}) async {
      fs.directory('android/app').createSync(recursive: true);
      await injectProguardUuid(fs: fs, config: config);
      fs.file(debugMetaAssetPath).setLastModifiedSync(at);
    }

    void build({required DateTime at}) => fs.file(apk)
      ..createSync(recursive: true)
      ..writeAsBytesSync(buildZip({'AndroidManifest.xml': ''}))
      ..setLastModifiedSync(at);

    Future<bool> removed() async {
      await removeConsumedInjectedProguardUuid(fs: fs, config: config);
      return !fs.file(debugMetaAssetPath).existsSync();
    }

    test('removes the file once a newer APK/AAB exists', () async {
      await inject(at: DateTime(2026, 1, 1));
      build(at: DateTime(2026, 1, 2));
      expect(await removed(), isTrue);
    });

    test('keeps the file without an Android build (other platforms)', () async {
      await inject(at: DateTime(2026, 1, 1));
      expect(await removed(), isFalse);
    });

    test('keeps the file when the newest APK/AAB predates it', () async {
      build(at: DateTime(2026, 1, 1));
      await inject(at: DateTime(2026, 1, 2));
      expect(await removed(), isFalse);
    });

    test('keeps a debug-meta file it did not create', () async {
      fs.file(debugMetaAssetPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('io.sentry.ProguardUuids=$uuid\n')
        ..setLastModifiedSync(DateTime(2026, 1, 1));
      build(at: DateTime(2026, 1, 2));
      expect(await removed(), isFalse);
    });
  });
}
