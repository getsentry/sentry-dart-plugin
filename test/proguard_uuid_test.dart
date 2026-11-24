import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/proguard/proguard_mapping.dart';
import 'package:sentry_dart_plugin/src/proguard/proguard_uuid.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';
import 'package:test/test.dart';

import 'utils/capture_stdout.dart';
import 'utils/fake_git_process_manager.dart';
import 'utils/zip_builder.dart';

void main() {
  const uuid = 'c9fb2840-1f9c-4f08-81fe-6880753f345b';
  late FileSystem fs;
  late Configuration config;
  late FakeGitProcessManager git;

  setUp(() {
    fs = MemoryFileSystem.test();
    git = FakeGitProcessManager(); // exit 1: not ignored
    injector.registerSingleton<FileSystem>(() => fs, override: true);
    config = Configuration()
      ..buildFilesFolder = 'build'
      ..uploadProguard = true
      ..proguardUuid = null
      ..proguardMappingPath = null;
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
    test('accepts a whitespace separator', () {
      expect(parseProguardUuid('io.sentry.ProguardUuids $uuid'), uuid);
    });

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
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          0);
      final injected = injectedUuid();
      expect(injected, isNotNull);
      expect(isValidProguardUuid(injected!), isTrue);
      expect(await hasInjectedProguardUuid(fs), isTrue);
    });

    test('warns to add the injected file to .gitignore', () async {
      final output = await captureStdout(() async {
        expect(
            await injectProguardUuid(
                fs: fs, config: config, processManager: git),
            0);
      });
      expect(output, contains('to your .gitignore'));
      expect(output, contains(debugMetaAssetPath));
    });

    test('asks git whether the injected file is ignored', () async {
      await injectProguardUuid(fs: fs, config: config, processManager: git);
      expect(git.commands, ['git check-ignore -q $debugMetaAssetPath']);
    });

    for (final entry in {
      'is already ignored': FakeGitProcessManager(exitCode: 0),
      'is not a git repository': FakeGitProcessManager(exitCode: 128),
      'is not installed': FakeGitProcessManager(missing: true),
    }.entries) {
      test('does not warn about .gitignore when git ${entry.key}', () async {
        final output = await captureStdout(() async {
          expect(
              await injectProguardUuid(
                  fs: fs, config: config, processManager: entry.value),
              0);
        });
        expect(output, isNot(contains('.gitignore')));
        expect(injectedUuid(), isNotNull);
      });
    }

    test('does not ask git when nothing was injected', () async {
      fs.directory('android').deleteSync(recursive: true);
      final output = await captureStdout(() async {
        expect(
            await injectProguardUuid(
                fs: fs, config: config, processManager: git),
            0);
      });
      expect(output, isNot(contains('.gitignore')));
      expect(git.commands, isEmpty);
    });

    test('generates a new UUID on every run', () async {
      await injectProguardUuid(fs: fs, config: config, processManager: git);
      final first = injectedUuid();
      await injectProguardUuid(fs: fs, config: config, processManager: git);
      expect(injectedUuid(), isNot(first));
    });

    test('uses the configured proguard_uuid', () async {
      config.proguardUuid = uuid;
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          0);
      expect(injectedUuid(), uuid);
    });

    test('fails on an invalid configured proguard_uuid', () async {
      config.proguardUuid = 'not-a-uuid';
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          1);
      expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
    });

    test('does nothing without an Android app', () async {
      fs.directory('android').deleteSync(recursive: true);
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          0);
      expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
    });

    test('does nothing when upload_proguard is disabled', () async {
      config.uploadProguard = false;
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          0);
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
        expect(
            await injectProguardUuid(
                fs: fs, config: config, processManager: git),
            0);
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
        expect(
            await injectProguardUuid(
                fs: fs, config: config, processManager: git),
            0);
        expect(injectedUuid(), isNotNull);
      });
    }

    test('leaves a debug-meta file it did not create untouched', () async {
      const content = 'io.sentry.ProguardUuids=$uuid\n';
      fs.file(debugMetaAssetPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          0);
      expect(fs.file(debugMetaAssetPath).readAsStringSync(), content);
      expect(await hasInjectedProguardUuid(fs), isFalse);
    });

    test('detects the Gradle plugin applied via a version catalog alias',
        () async {
      fs.file('android/gradle/libs.versions.toml')
        ..createSync(recursive: true)
        ..writeAsStringSync('[plugins]\n'
            'sentry-android = { id = "io.sentry.android.gradle", version = "5.0.0" }\n');
      fs.file('android/app/build.gradle.kts')
        ..createSync(recursive: true)
        ..writeAsStringSync(
            'plugins {\n  alias(libs.plugins.sentry.android)\n}');
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          0);
      expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
    });

    test('detects the Gradle plugin after a string containing /*', () async {
      fs.file('android/app/build.gradle.kts')
        ..createSync(recursive: true)
        ..writeAsStringSync('val sources = "src/*.kt"\n'
            'plugins { id("io.sentry.android.gradle") }\n'
            '/* end */');
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          0);
      expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
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
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          0);
      expect(fs.file(debugMetaAssetPath).readAsBytesSync(), bytes);
      expect(await hasInjectedProguardUuid(fs), isFalse);
    });

    test('fails when proguard_uuid differs from a file it did not create',
        () async {
      fs.file(debugMetaAssetPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('io.sentry.ProguardUuids=$uuid\n');
      config.proguardUuid = generateUuid();
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          1);
      expect(injectedUuid(), uuid);
    });

    test('accepts proguard_uuid matching a file it did not create', () async {
      fs.file(debugMetaAssetPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('io.sentry.ProguardUuids=$uuid\n');
      config.proguardUuid = uuid.toUpperCase();
      expect(
          await injectProguardUuid(fs: fs, config: config, processManager: git),
          0);
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
      final built = await readBuiltAppProguardUuid(fs: fs, config: config);
      expect(built?.artifactPath,
          'build/app/outputs/bundle/release/app-release.aab');
      expect(built?.uuid, isNull);
    });

    test('skips later debug and instrumentation test builds', () async {
      writeArtifact(
        'build/app/outputs/flutter-apk/app-release.apk',
        {
          'assets/sentry-debug-meta.properties': 'io.sentry.ProguardUuids=$uuid'
        },
        modified: DateTime(2026, 1, 1),
      );
      writeArtifact('build/app/outputs/flutter-apk/app-debug.apk',
          {'AndroidManifest.xml': ''},
          modified: DateTime(2026, 1, 2));
      writeArtifact(
          'build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk',
          {'AndroidManifest.xml': ''},
          modified: DateTime(2026, 1, 3));
      final built = await readBuiltAppProguardUuid(fs: fs, config: config);
      expect(built?.uuid, uuid);
    });

    test('with a mapping path of a variant, reads that variant only', () async {
      writeArtifact(
        'build/app/outputs/flutter-apk/app-free-release.apk',
        {
          'assets/sentry-debug-meta.properties': 'io.sentry.ProguardUuids=$uuid'
        },
        modified: DateTime(2026, 1, 1),
      );
      writeArtifact('build/app/outputs/flutter-apk/app-paid-release.apk',
          {'AndroidManifest.xml': ''},
          modified: DateTime(2026, 1, 2));
      Future<String?> read(String path) async =>
          (await readBuiltAppProguardUuid(
                  fs: fs, config: config, mappingPath: path))
              ?.artifactPath;
      expect(await read('build/app/outputs/mapping/freeRelease/mapping.txt'),
          'build/app/outputs/flutter-apk/app-free-release.apk');
      // Anywhere else: the last release build.
      expect(await read('custom/mapping.txt'),
          'build/app/outputs/flutter-apk/app-paid-release.apk');
    });

    test('returns null without build outputs or artifacts', () async {
      expect(await readBuiltAppProguardUuid(fs: fs, config: config), isNull);
      fs.directory('build/app/outputs/mapping').createSync(recursive: true);
      expect(await readBuiltAppProguardUuid(fs: fs, config: config), isNull);
    });
  });

  group('removeConsumedInjectedProguardUuid', () {
    Future<String> inject({required DateTime at}) async {
      fs.directory('android/app').createSync(recursive: true);
      await injectProguardUuid(fs: fs, config: config, processManager: git);
      fs.file(debugMetaAssetPath).setLastModifiedSync(at);
      return injectedUuid()!;
    }

    void build(String name, {required DateTime at, String? uuid}) =>
        fs.file('build/app/outputs/flutter-apk/$name')
          ..createSync(recursive: true)
          ..writeAsBytesSync(buildZip({
            if (uuid != null)
              'assets/sentry-debug-meta.properties':
                  'io.sentry.ProguardUuids=$uuid',
          }))
          ..setLastModifiedSync(at);

    Future<bool> removed() async {
      await removeConsumedInjectedProguardUuid(fs: fs, config: config);
      return !fs.file(debugMetaAssetPath).existsSync();
    }

    test('removes the file once a release build packaged it', () async {
      final injected = await inject(at: DateTime(2026, 1, 1));
      build('app-release.apk', at: DateTime(2026, 1, 2), uuid: injected);
      expect(await removed(), isTrue);
    });

    test('keeps the file without an Android build (other platforms)', () async {
      await inject(at: DateTime(2026, 1, 1));
      expect(await removed(), isFalse);
    });

    test('keeps the file after a debug or profile build', () async {
      final injected = await inject(at: DateTime(2026, 1, 1));
      build('app-debug.apk', at: DateTime(2026, 1, 2), uuid: injected);
      build('app-free-profile.apk', at: DateTime(2026, 1, 2), uuid: injected);
      expect(await removed(), isFalse);
    });

    test('keeps the file when the release build predates it', () async {
      build('app-release.apk', at: DateTime(2026, 1, 1));
      await inject(at: DateTime(2026, 1, 2));
      expect(await removed(), isFalse);
    });

    test('keeps a debug-meta file it did not create', () async {
      fs.file(debugMetaAssetPath)
        ..createSync(recursive: true)
        ..writeAsStringSync('io.sentry.ProguardUuids=$uuid\n')
        ..setLastModifiedSync(DateTime(2026, 1, 1));
      build('app-release.apk', at: DateTime(2026, 1, 2), uuid: uuid);
      expect(await removed(), isFalse);
    });
  });

  group('variantsBuiltWithInjectedUuid', () {
    test('lists each release variant once (APK and AAB)', () async {
      fs.directory('android/app').createSync(recursive: true);
      await injectProguardUuid(fs: fs, config: config, processManager: git);
      fs.file(debugMetaAssetPath).setLastModifiedSync(DateTime(2026, 1, 1));
      final meta = {
        'assets/sentry-debug-meta.properties':
            fs.file(debugMetaAssetPath).readAsStringSync()
      };
      for (final path in [
        'flutter-apk/app-free-release.apk',
        'apk/free/release/app-free-release.apk',
        'flutter-apk/app-paid-release.apk',
        'flutter-apk/app-paid-debug.apk',
      ]) {
        fs.file('build/app/outputs/$path')
          ..createSync(recursive: true)
          ..writeAsBytesSync(buildZip(meta))
          ..setLastModifiedSync(DateTime(2026, 1, 2));
      }
      expect(await variantsBuiltWithInjectedUuid(fs: fs, config: config),
          {'freeRelease', 'paidRelease'});
    });

    test('counts renamed outputs and test APKs of a variant once', () async {
      fs.directory('android/app').createSync(recursive: true);
      await injectProguardUuid(fs: fs, config: config, processManager: git);
      fs.file(debugMetaAssetPath).setLastModifiedSync(DateTime(2026, 1, 1));
      final meta = {
        'assets/sentry-debug-meta.properties':
            fs.file(debugMetaAssetPath).readAsStringSync()
      };
      for (final path in [
        'flutter-apk/app-release.apk',
        'apk/release/myapp-1.0-release.apk',
        'apk/androidTest/debug/app-debug-androidTest.apk',
      ]) {
        fs.file('build/app/outputs/$path')
          ..createSync(recursive: true)
          ..writeAsBytesSync(buildZip(meta))
          ..setLastModifiedSync(DateTime(2026, 1, 2));
      }
      expect(await variantsBuiltWithInjectedUuid(fs: fs, config: config),
          {'release'});
    });

    test('is empty when the injected file has no UUID any more', () async {
      fs.directory('android/app').createSync(recursive: true);
      await injectProguardUuid(fs: fs, config: config, processManager: git);
      final file = fs.file(debugMetaAssetPath);
      // Edited by hand: marker kept, UUID line removed.
      file
        ..writeAsStringSync(file.readAsLinesSync().first)
        ..setLastModifiedSync(DateTime(2026, 1, 1));
      for (final path in [
        'flutter-apk/app-free-release.apk',
        'flutter-apk/app-paid-release.apk',
      ]) {
        fs.file('build/app/outputs/$path')
          ..createSync(recursive: true)
          ..writeAsBytesSync(buildZip({'AndroidManifest.xml': ''}))
          ..setLastModifiedSync(DateTime(2026, 1, 2));
      }
      expect(
          await variantsBuiltWithInjectedUuid(fs: fs, config: config), isEmpty);
    });

    test('counts the ABI splits and the unsigned build of a variant once',
        () async {
      fs.directory('android/app').createSync(recursive: true);
      await injectProguardUuid(fs: fs, config: config, processManager: git);
      fs.file(debugMetaAssetPath).setLastModifiedSync(DateTime(2026, 1, 1));
      final meta = {
        'assets/sentry-debug-meta.properties':
            fs.file(debugMetaAssetPath).readAsStringSync()
      };
      for (final path in [
        'flutter-apk/app-armeabi-v7a-release.apk',
        'flutter-apk/app-arm64-v8a-release.apk',
        'apk/release/app-x86_64-release.apk',
        'apk/release/app-x86-release.apk',
        'apk/release/app-release-unsigned.apk',
        'flutter-apk/app-release.apk',
        // Flavors: the ABI sits between the app and the flavor.
        'flutter-apk/app-arm64-v8a-free-release.apk',
        'apk/free/release/app-free-release-unsigned.apk',
      ]) {
        fs.file('build/app/outputs/$path')
          ..createSync(recursive: true)
          ..writeAsBytesSync(buildZip(meta))
          ..setLastModifiedSync(DateTime(2026, 1, 2));
      }
      expect(await variantsBuiltWithInjectedUuid(fs: fs, config: config),
          {'release', 'freeRelease'});
    });
  });

  group('findLastReleaseBuild', () {
    ProguardMapping mapping(String variant, DateTime at) => ProguardMapping(
        'build/app/outputs/mapping/$variant/mapping.txt', at, variant);

    void writeArtifact(String path, DateTime at, {String? withUuid}) {
      final entry = path.endsWith('.aab')
          ? 'base/assets/sentry-debug-meta.properties'
          : 'assets/sentry-debug-meta.properties';
      fs.file('build/app/outputs/$path')
        ..createSync(recursive: true)
        ..writeAsBytesSync(buildZip({
          'AndroidManifest.xml': '',
          if (withUuid != null) entry: 'io.sentry.ProguardUuids=$withUuid',
        }))
        ..setLastModifiedSync(at);
    }

    Future<LastReleaseBuild?> find(List<ProguardMapping> mappings) =>
        findLastReleaseBuild(fs: fs, config: config, mappings: mappings);

    test('returns the last release build, its UUID and mapping', () async {
      writeArtifact('flutter-apk/app-release.apk', DateTime(2026, 1, 2),
          withUuid: uuid);
      writeArtifact('flutter-apk/app-debug.apk', DateTime(2026, 1, 3));
      final built = await find([mapping('release', DateTime(2026, 1, 1))]);
      expect(
          built?.artifactPath, 'build/app/outputs/flutter-apk/app-release.apk');
      expect(built?.uuid, uuid);
      expect(built?.mapping?.variant, 'release');
    });

    test('returns the mapping even without a UUID (proguard_uuid)', () async {
      writeArtifact('flutter-apk/app-release.apk', DateTime(2026, 1, 2));
      final built = await find([mapping('release', DateTime(2026, 1, 1))]);
      expect(built?.uuid, isNull);
      expect(built?.mapping?.variant, 'release');
    });

    test('has no mapping when it is newer than the build', () async {
      writeArtifact('flutter-apk/app-release.apk', DateTime(2026, 1, 1),
          withUuid: uuid);
      final built = await find([mapping('release', DateTime(2026, 1, 2))]);
      expect(built, isNotNull);
      expect(built?.mapping, isNull);
      expect(built?.staleMapping?.variant, 'release');
    });

    test('matches the mapping of the artifact variant, not the newest',
        () async {
      writeArtifact('flutter-apk/app-free-release.apk', DateTime(2026, 1, 5),
          withUuid: uuid);
      final built = await find([
        mapping('paidRelease', DateTime(2026, 1, 4)),
        mapping('freeRelease', DateTime(2026, 1, 3)),
      ]);
      expect(built?.mapping?.variant, 'freeRelease');
    });

    test('matches ABI splits, unsigned builds and AABs to their mapping',
        () async {
      final mappings = [
        mapping('paidRelease', DateTime(2026, 1, 4)),
        mapping('freeRelease', DateTime(2026, 1, 3)),
      ];
      for (final path in [
        'flutter-apk/app-arm64-v8a-free-release.apk',
        'apk/free/release/app-free-release-unsigned.apk',
        'bundle/freeRelease/app-free-release.aab',
      ]) {
        if (fs.directory('build/app/outputs').existsSync()) {
          fs.directory('build/app/outputs').deleteSync(recursive: true);
        }
        writeArtifact(path, DateTime(2026, 1, 5), withUuid: uuid);
        final built = await find(mappings);
        expect(built?.mapping?.variant, 'freeRelease', reason: path);
        expect(built?.uuid, uuid, reason: path);
      }
    });

    test('has no mapping for a variant without one, even a single other one',
        () async {
      writeArtifact('flutter-apk/app-paid-release.apk', DateTime(2026, 1, 5));
      for (final mappings in [
        [mapping('freeRelease', DateTime(2026, 1, 1))],
        [
          mapping('freeRelease', DateTime(2026, 1, 1)),
          mapping('demoRelease', DateTime(2026, 1, 1)),
        ],
      ]) {
        final built = await find(mappings);
        expect(built?.artifactPath,
            'build/app/outputs/flutter-apk/app-paid-release.apk');
        expect(built?.mapping, isNull);
      }
    });

    test('does not fall back to an older build of another variant', () async {
      writeArtifact('flutter-apk/app-free-release.apk', DateTime(2026, 1, 2),
          withUuid: uuid);
      writeArtifact('flutter-apk/app-paid-release.apk', DateTime(2026, 1, 5));
      final built = await find([mapping('freeRelease', DateTime(2026, 1, 1))]);
      expect(built?.artifactPath,
          'build/app/outputs/flutter-apk/app-paid-release.apk');
      expect(built?.mapping, isNull);
    });

    test('matches renamed outputs by their directory', () async {
      final mappings = [
        mapping('release', DateTime(2026, 1, 1)),
        mapping('freeStagingRelease', DateTime(2026, 1, 1)),
      ];
      for (final entry in {
        'bundle/release/myapp-1.0-release.aab': 'release',
        'apk/release/myapp-1.0.apk': 'release',
        'apk/freeStaging/release/myapp-free.apk': 'freeStagingRelease',
        'bundle/freeStagingRelease/custom.aab': 'freeStagingRelease',
      }.entries) {
        if (fs.directory('build/app/outputs').existsSync()) {
          fs.directory('build/app/outputs').deleteSync(recursive: true);
        }
        writeArtifact(entry.key, DateTime(2026, 1, 5), withUuid: uuid);
        expect((await find(mappings))?.mapping?.variant, entry.value,
            reason: entry.key);
      }
    });

    test('ignores instrumentation test APKs', () async {
      writeArtifact('flutter-apk/app-release.apk', DateTime(2026, 1, 2),
          withUuid: uuid);
      writeArtifact('apk/androidTest/debug/app-debug-androidTest.apk',
          DateTime(2026, 1, 3));
      writeArtifact(
          'apk/androidTest/free/release/app-free-release-androidTest.apk',
          DateTime(2026, 1, 4));
      final built = await find([mapping('release', DateTime(2026, 1, 1))]);
      expect(
          built?.artifactPath, 'build/app/outputs/flutter-apk/app-release.apk');
      expect(built?.mapping?.variant, 'release');
    });

    test('ignores APKs whose variant cannot be told', () async {
      writeArtifact('flutter-apk/app-release.apk', DateTime(2026, 1, 2),
          withUuid: uuid);
      writeArtifact('flutter-apk/app.apk', DateTime(2026, 1, 3));
      writeArtifact('apk/app.apk', DateTime(2026, 1, 3));
      writeArtifact('flutter-apk/myapp-release.apk', DateTime(2026, 1, 3));
      final built = await find([mapping('release', DateTime(2026, 1, 1))]);
      expect(
          built?.artifactPath, 'build/app/outputs/flutter-apk/app-release.apk');
      expect(built?.mapping?.variant, 'release');
    });

    test('ignores debug and profile builds', () async {
      writeArtifact('flutter-apk/app-debug.apk', DateTime(2026, 1, 2),
          withUuid: uuid);
      writeArtifact('flutter-apk/app-profile.apk', DateTime(2026, 1, 2),
          withUuid: uuid);
      expect(await find([mapping('release', DateTime(2026, 1, 1))]), isNull);
    });
  });
}
