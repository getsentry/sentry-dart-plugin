import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:process/process.dart';
import 'package:sentry_dart_plugin/sentry_dart_plugin.dart';
import 'package:sentry_dart_plugin/src/cli/host_platform.dart';
import 'package:sentry_dart_plugin/src/cli/setup.dart';
import 'package:sentry_dart_plugin/src/proguard/proguard_mapping.dart';
import 'package:sentry_dart_plugin/src/proguard/proguard_uuid.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';
import 'package:test/test.dart';

import 'utils/capture_stdout.dart';
import 'utils/config_file_type.dart';
import 'utils/config_formatter.dart';
import 'utils/config_writer.dart';
import 'utils/zip_builder.dart';

void main() {
  final plugin = SentryDartPlugin();
  late ConfigWriter configWriter;
  late MockProcessManager pm;
  late FileSystem fs;

  const cli = MockCLI.name;
  const orgAndProject = '--org o --project p';
  const name = 'name';
  const buildDir = 'build';

  /// File types from which we can read configs.
  const fileTypes = [
    ConfigFileType.pubspecYaml,
    ConfigFileType.sentryProperties,
  ];

  setUp(() {
    // override dependencies for testing
    pm = MockProcessManager();
    injector.registerSingleton<ProcessManager>(() => pm, override: true);
    fs = MemoryFileSystem.test();
    fs.directory('$buildDir/app/outputs').createSync(recursive: true);
    injector.registerSingleton<FileSystem>(() => fs, override: true);
    injector.registerSingleton<CLISetup>(() => MockCLI(), override: true);
    configWriter = ConfigWriter(fs, name);
  });

  void createJsFilesForTesting() {
    // create a temp dir that has the fake js files that we use to inject
    // the debug id into
    fs.directory('$buildDir/web').createSync(recursive: true);
    fs.file('$buildDir/web/file.js').createSync();
    fs.file('$buildDir/web/file.js.map').writeAsStringSync('''{
  "mappings": "AAAAA,SAASC,cAAc,WAAWC, ...",
  "sources": ["../../lib/something.dart", "../lib/foo.dart", "../../../../lib/main.dart", "../../Documents/flutter/packages/flutter/lib/src/widgets/icon_data.dart"],
  "sourcesContent": ["document.querySelector('button')"],
  "names": ["document","querySelector"],
  "version": 3,
  "file": "example.min.js.map"
}''');
  }

  for (final url in const ['http://127.0.0.1', null]) {
    for (var fileType in fileTypes) {
      group('url: $url', () {
        final commonArgs =
            '${url == null ? '' : '--url http://127.0.0.1 '}--auth-token t';

        Future<Iterable<String>> runWith(String version, String config,
            {String? customCli}) async {
          final formattedConfig =
              ConfigFormatter.formatConfig(config, fileType, url);
          configWriter.write(version, fileType, formattedConfig);

          final exitCode = await plugin.run([]);
          expect(exitCode, 0);

          final cliToUse = customCli ?? cli;
          final commonCommands = [
            if (!Platform.isWindows && customCli == null) 'chmod +x $cliToUse',
            '$cliToUse help'
          ];

          expect(pm.commandLog.take(commonCommands.length), commonCommands);
          return pm.commandLog.skip(commonCommands.length);
        }

        setUp(() {
          createJsFilesForTesting();
        });
        test('works with all configuration files', () async {
          const version = '1.0.0';
          final config = '''
            upload_debug_symbols: true
            upload_sources: true
            upload_source_maps: true
            log_level: debug
            ignore_missing: true
            ignore_web_source_paths: [testdir/**/*.js]
          ''';
          final commandLog = await runWith(version, config);
          const release = '$name@$version';

          final args = '$commonArgs --log-level debug';
          expect(commandLog, [
            '$cli $args debug-files upload $orgAndProject --include-sources $buildDir/app/outputs',
            '$cli $args releases $orgAndProject new $release',
            '$cli sourcemaps inject $buildDir/web/file.js $orgAndProject',
            '$cli $args sourcemaps upload --release $release $buildDir/web --ext js --ext map --strip-prefix ../../Documents --strip-prefix ../../../../ --strip-prefix ../../ --strip-prefix ../ ./ --ext dart --ignore testdir/**/*.js $orgAndProject',
            '$cli $args releases $orgAndProject set-commits $release --auto --ignore-missing',
            '$cli $args releases $orgAndProject finalize $release'
          ]);
        });

        test('ignores sourcemaps upload if no js files found', () async {
          const version = '1.0.0';
          final config = '''
            upload_source_maps: true
            web_build_path: not/existing
            log_level: debug
            ignore_missing: true
          ''';
          final commandLog = await runWith(version, config);
          const release = '$name@$version';

          final args = '$commonArgs --log-level debug';
          expect(commandLog, [
            '$cli $args debug-files upload $orgAndProject build/app/outputs',
            '$cli $args releases $orgAndProject new $release',
            '$cli $args releases $orgAndProject set-commits $release --auto --ignore-missing',
            '$cli $args releases $orgAndProject finalize $release'
          ]);
        });

        test('fails without args and pubspec', () async {
          final exitCode = await plugin.run([]);
          expect(exitCode, 1);

          final commonCommands = [
            if (!Platform.isWindows) 'chmod +x $cli',
            '$cli help'
          ];
          expect(pm.commandLog, commonCommands);
        });

        test('defaults', () async {
          const version = '1.0.0';
          final commandLog = await runWith(version, '');
          const release = '$name@$version';

          expect(commandLog, [
            '$cli $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
            '$cli $commonArgs releases $orgAndProject new $release',
            '$cli $commonArgs releases $orgAndProject set-commits $release --auto',
            '$cli $commonArgs releases $orgAndProject finalize $release'
          ]);
        });

        group('proguard', () {
          const uuid = 'c9fb2840-1f9c-4f08-81fe-6880753f345b';
          const mapping = '$buildDir/app/outputs/mapping/release/mapping.txt';
          const version = '1.0.0';
          const release = '$name@$version';

          setUp(() {
            fs.file(mapping).createSync(recursive: true);
          });

          // The release build that wrote [mapping]: without one, a mapping
          // can't be told from a leftover and isn't uploaded.
          void writeReleaseBuild() =>
              fs.file('$buildDir/app/outputs/flutter-apk/app-release.apk')
                ..createSync(recursive: true)
                ..writeAsBytesSync(buildZip({'AndroidManifest.xml': ''}));

          test('uploads the mapping under proguard_uuid', () async {
            writeReleaseBuild();
            final commandLog = await runWith(version, 'proguard_uuid: $uuid');

            expect(commandLog, [
              '$cli $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
              '$cli $commonArgs upload-proguard $orgAndProject --uuid $uuid $mapping',
              '$cli $commonArgs releases $orgAndProject new $release',
              '$cli $commonArgs releases $orgAndProject set-commits $release --auto',
              '$cli $commonArgs releases $orgAndProject finalize $release'
            ]);
          });

          test('a failed mapping upload does not abort the run', () async {
            writeReleaseBuild();
            pm.failingCommands.add('upload-proguard');
            final commandLog = await runWith(version, 'proguard_uuid: $uuid');

            expect(commandLog, [
              '$cli $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
              '$cli $commonArgs upload-proguard $orgAndProject --uuid $uuid $mapping',
              '$cli $commonArgs releases $orgAndProject new $release',
              '$cli $commonArgs releases $orgAndProject set-commits $release --auto',
              '$cli $commonArgs releases $orgAndProject finalize $release'
            ]);
          });

          test('uploads the mapping at proguard_mapping_path', () async {
            fs.file('custom/mapping.txt').createSync(recursive: true);
            final commandLog = await runWith(version, '''
              proguard_uuid: $uuid
              proguard_mapping_path: custom/mapping.txt
            ''');

            expect(
              commandLog,
              contains(
                  '$cli $commonArgs upload-proguard $orgAndProject --uuid $uuid custom/mapping.txt'),
            );
          });

          test('uploads the mapping even if upload_debug_symbols is disabled',
              () async {
            writeReleaseBuild();
            final commandLog = await runWith(version, '''
              proguard_uuid: $uuid
              upload_debug_symbols: false
            ''');

            expect(commandLog.first,
                '$cli $commonArgs upload-proguard $orgAndProject --uuid $uuid $mapping');
          });

          for (final config in [
            '',
            'proguard_uuid: not-a-uuid',
            'proguard_uuid: $uuid\nupload_proguard: false',
          ]) {
            test('skips the upload with config "$config"', () async {
              final commandLog = await runWith(version, config);

              expect(commandLog.where((c) => c.contains('upload-proguard')),
                  isEmpty);
            });
          }

          group('built app', () {
            const builtUuid = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
            const apk = '$buildDir/app/outputs/flutter-apk/app-release.apk';

            // Explicit times: the injected file is only removed once an
            // APK/AAB newer than it exists.
            final injectedAt = DateTime(2026, 1, 2);

            // The minified build (writing the mapping) runs after the inject.
            setUp(() =>
                fs.file(mapping).setLastModifiedSync(DateTime(2026, 1, 3)));

            void writeApk({String? debugMeta, DateTime? builtAt}) =>
                fs.file(apk)
                  ..createSync(recursive: true)
                  ..writeAsBytesSync(buildZip({
                    'AndroidManifest.xml': '',
                    if (debugMeta != null)
                      'assets/sentry-debug-meta.properties': debugMeta,
                  }))
                  ..setLastModifiedSync(builtAt ?? DateTime(2026, 1, 3));

            var injectCommands = <String>[];

            Future<String> injectUuid() async {
              configWriter.write(
                version,
                fileType,
                ConfigFormatter.formatConfig('', fileType, url),
              );
              fs.directory('android/app').createSync(recursive: true);
              expect(await plugin.run(['--inject-uuid']), 0);
              // Keep the later `runWith` log free of the inject's commands.
              injectCommands = List.of(pm.commandLog);
              pm.commandLog.clear();
              pm.commandEnvironmentLog.clear();
              final file = fs.file(debugMetaAssetPath);
              expect(file.existsSync(), isTrue);
              file.setLastModifiedSync(injectedAt);
              return file.readAsStringSync();
            }

            test('--inject-uuid writes a UUID without calling sentry-cli',
                () async {
              final debugMeta = await injectUuid();

              // Only git is asked (about .gitignore), never sentry-cli.
              expect(
                  injectCommands, ['git check-ignore -q $debugMetaAssetPath']);
              expect(pm.commandLog, isEmpty);
              expect(
                  isValidProguardUuid(parseProguardUuid(debugMeta)!), isTrue);
            });

            test('uploads under the injected UUID and removes the file',
                () async {
              final debugMeta = await injectUuid();
              final injected = parseProguardUuid(debugMeta)!;
              // `flutter build` packages the asset into the app.
              writeApk(debugMeta: debugMeta);

              final commandLog = await runWith(version, '');

              expect(
                commandLog,
                contains(
                    '$cli $commonArgs upload-proguard $orgAndProject --uuid $injected $mapping'),
              );
              expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
            });

            test('skips the upload if the app was built before --inject-uuid',
                () async {
              fs.file(mapping).setLastModifiedSync(DateTime(2026, 1, 1));
              writeApk(builtAt: DateTime(2026, 1, 1));
              await injectUuid();

              final commandLog = await runWith(version, '');

              expect(commandLog.where((c) => c.contains('upload-proguard')),
                  isEmpty);
              // Kept for the next build, which will package it.
              expect(fs.file(debugMetaAssetPath).existsSync(), isTrue);
            });

            test('keeps the injected file on runs without an Android build',
                () async {
              await injectUuid();
              fs.directory('$buildDir/app/outputs').deleteSync(recursive: true);

              await runWith(version, '');

              expect(fs.file(debugMetaAssetPath).existsSync(), isTrue);
            });

            test('removes the consumed file even if the run fails', () async {
              final debugMeta = await injectUuid();
              writeApk(debugMeta: debugMeta);
              // No auth token: validation fails before any upload.
              if (fs.file('sentry.properties').existsSync()) {
                fs.file('sentry.properties').deleteSync();
              }
              fs
                  .file('pubspec.yaml')
                  .writeAsStringSync('name: $name\nversion: $version\n');

              expect(await plugin.run([]), 1);

              expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
            });

            test(
                'skips the upload when several variants were built after one '
                '--inject-uuid', () async {
              final debugMeta = await injectUuid();
              for (final variant in ['free', 'paid']) {
                fs.file(
                    '$buildDir/app/outputs/mapping/${variant}Release/mapping.txt')
                  ..createSync(recursive: true)
                  ..setLastModifiedSync(DateTime(2026, 1, 3));
                fs.file(
                    '$buildDir/app/outputs/flutter-apk/app-$variant-release.apk')
                  ..createSync(recursive: true)
                  ..writeAsBytesSync(buildZip(
                      {'assets/sentry-debug-meta.properties': debugMeta}))
                  ..setLastModifiedSync(DateTime(2026, 1, 3));
              }

              final commandLog = await runWith(version, '');

              expect(commandLog.where((c) => c.contains('upload-proguard')),
                  isEmpty);
              // The first run removed the injected file as consumed.
              expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);

              // A retry without rebuilding still sees the shared UUID.
              final retryLog = await runWith(version, '');
              expect(retryLog.where((c) => c.contains('upload-proguard')),
                  isEmpty);

              // So does a configured proguard_uuid that both apps contain.
              final configuredLog = await runWith(
                  version, 'proguard_uuid: ${parseProguardUuid(debugMeta)}');
              expect(configuredLog.where((c) => c.contains('upload-proguard')),
                  isEmpty);
            });

            void writeBuilt(String path, String debugMeta, DateTime at) => fs
                .file('$buildDir/app/outputs/$path')
              ..createSync(recursive: true)
              ..writeAsBytesSync(
                  buildZip({'assets/sentry-debug-meta.properties': debugMeta}))
              ..setLastModifiedSync(at);

            test('uploads once for the ABI splits of one variant', () async {
              final debugMeta = await injectUuid();
              final injected = parseProguardUuid(debugMeta)!;
              for (final abi in ['armeabi-v7a', 'arm64-v8a', 'x86_64']) {
                writeBuilt('flutter-apk/app-$abi-release.apk', debugMeta,
                    DateTime(2026, 1, 3));
                writeBuilt('apk/release/app-$abi-release.apk', debugMeta,
                    DateTime(2026, 1, 3));
              }

              final commandLog = await runWith(version, '');

              expect(
                commandLog,
                contains(
                    '$cli $commonArgs upload-proguard $orgAndProject --uuid $injected $mapping'),
              );
              expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
            });

            test('uploads once for an output renamed by Gradle', () async {
              final debugMeta = await injectUuid();
              final injected = parseProguardUuid(debugMeta)!;
              writeBuilt('apk/release/myapp-1.0-release.apk', debugMeta,
                  DateTime(2026, 1, 3));
              writeBuilt('flutter-apk/app-release.apk', debugMeta,
                  DateTime(2026, 1, 3));

              final commandLog = await runWith(version, '');

              expect(
                commandLog.where((c) => c.contains('upload-proguard')),
                [
                  '$cli $commonArgs upload-proguard $orgAndProject --uuid $injected $mapping'
                ],
              );
              expect(fs.file(debugMetaAssetPath).existsSync(), isFalse);
            });

            test('uploads once for an unsigned release build', () async {
              final debugMeta = await injectUuid();
              final injected = parseProguardUuid(debugMeta)!;
              writeBuilt('apk/release/app-release-unsigned.apk', debugMeta,
                  DateTime(2026, 1, 3));
              writeBuilt('flutter-apk/app-release.apk', debugMeta,
                  DateTime(2026, 1, 3));

              final commandLog = await runWith(version, '');

              expect(
                commandLog,
                contains(
                    '$cli $commonArgs upload-proguard $orgAndProject --uuid $injected $mapping'),
              );
            });

            test(
                'uploads the mapping of the built flavor, not the newest one '
                '(R8 was up to date for it)', () async {
              final debugMeta = await injectUuid();
              final injected = parseProguardUuid(debugMeta)!;
              const freeMapping =
                  '$buildDir/app/outputs/mapping/freeRelease/mapping.txt';
              fs.file(freeMapping)
                ..createSync(recursive: true)
                ..setLastModifiedSync(DateTime(2026, 1, 3));
              fs.file('$buildDir/app/outputs/mapping/paidRelease/mapping.txt')
                ..createSync(recursive: true)
                ..setLastModifiedSync(DateTime(2026, 1, 4));
              // The free flavor was rebuilt last, with its mapping unchanged.
              writeBuilt('flutter-apk/app-free-release.apk', debugMeta,
                  DateTime(2026, 1, 5));

              final commandLog = await runWith(version, '');

              expect(
                commandLog,
                contains(
                    '$cli $commonArgs upload-proguard $orgAndProject --uuid $injected $freeMapping'),
              );
              expect(commandLog.where((c) => c.contains('upload-proguard')),
                  hasLength(1));
            });

            test('a later debug build does not consume the injected file',
                () async {
              final debugMeta = await injectUuid();
              // `flutter run` packages the asset too, but isn't minified.
              fs.file('$buildDir/app/outputs/flutter-apk/app-debug.apk')
                ..createSync(recursive: true)
                ..writeAsBytesSync(buildZip(
                    {'assets/sentry-debug-meta.properties': debugMeta}))
                ..setLastModifiedSync(DateTime(2026, 1, 3));

              await runWith(version, '');

              expect(fs.file(debugMetaAssetPath).existsSync(), isTrue);
            });

            test('reads the UUID from the build that wrote the mapping',
                () async {
              final debugMeta = await injectUuid();
              final injected = parseProguardUuid(debugMeta)!;
              fs.file(mapping).setLastModifiedSync(DateTime(2026, 1, 3));
              writeApk(debugMeta: debugMeta, builtAt: DateTime(2026, 1, 4));
              // A later, non-minified debug build without the UUID.
              fs.file('$buildDir/app/outputs/flutter-apk/app-debug.apk')
                ..createSync(recursive: true)
                ..writeAsBytesSync(buildZip({'AndroidManifest.xml': ''}))
                ..setLastModifiedSync(DateTime(2026, 1, 5));

              final commandLog = await runWith(version, '');

              expect(
                commandLog,
                contains(
                    '$cli $commonArgs upload-proguard $orgAndProject --uuid $injected $mapping'),
              );
            });

            test('uses the UUID packaged by other tools', () async {
              writeApk(debugMeta: 'io.sentry.ProguardUuids=$builtUuid\n');

              final commandLog = await runWith(version, '');

              expect(
                commandLog,
                contains(
                    '$cli $commonArgs upload-proguard $orgAndProject --uuid $builtUuid $mapping'),
              );
            });

            group('reused build dir with flavors', () {
              const freeMapping =
                  '$buildDir/app/outputs/mapping/freeRelease/mapping.txt';
              const paidMapping =
                  '$buildDir/app/outputs/mapping/paidRelease/mapping.txt';

              void writeMapping(String path, DateTime at) => fs.file(path)
                ..createSync(recursive: true)
                ..setLastModifiedSync(at);

              void writeFlavorApk(String flavor, DateTime at,
                      {String? debugMeta}) =>
                  fs.file(
                      '$buildDir/app/outputs/flutter-apk/app-$flavor-release.apk')
                    ..createSync(recursive: true)
                    ..writeAsBytesSync(buildZip({
                      'AndroidManifest.xml': '',
                      if (debugMeta != null)
                        'assets/sentry-debug-meta.properties': debugMeta,
                    }))
                    ..setLastModifiedSync(at);

              setUp(() => fs.file(mapping).deleteSync());

              Iterable<String> uploads(Iterable<String> log) =>
                  log.where((c) => c.contains('upload-proguard'));

              test(
                  'with proguard_uuid, uploads the mapping of the flavor just '
                  'built, not of an older APK with a UUID', () async {
                writeMapping(freeMapping, DateTime(2026, 1, 1));
                writeFlavorApk('free', DateTime(2026, 1, 2),
                    debugMeta: 'io.sentry.ProguardUuids=$builtUuid\n');
                // R8 was up to date for paid: its mapping is older.
                writeMapping(paidMapping, DateTime(2026, 1, 1));
                writeFlavorApk('paid', DateTime(2026, 1, 5));

                final commandLog =
                    await runWith(version, 'proguard_uuid: $uuid');

                expect(uploads(commandLog), [
                  '$cli $commonArgs upload-proguard $orgAndProject --uuid $uuid $paidMapping'
                ]);
              });

              test(
                  'with proguard_uuid, skips when the flavor just built has no '
                  'mapping', () async {
                writeMapping(freeMapping, DateTime(2026, 1, 3));
                writeFlavorApk('free', DateTime(2026, 1, 3),
                    debugMeta: 'io.sentry.ProguardUuids=$builtUuid\n');
                writeMapping(
                    '$buildDir/app/outputs/mapping/demoRelease/mapping.txt',
                    DateTime(2026, 1, 4));
                writeFlavorApk('paid', DateTime(2026, 1, 5));

                final commandLog =
                    await runWith(version, 'proguard_uuid: $uuid');

                expect(uploads(commandLog), isEmpty);
              });

              test(
                  'skips a single leftover mapping of another flavor '
                  '(minify off)', () async {
                writeMapping(freeMapping, DateTime(2026, 1, 1));
                writeFlavorApk('paid', DateTime(2026, 1, 5));

                final commandLog =
                    await runWith(version, 'proguard_uuid: $uuid');

                expect(uploads(commandLog), isEmpty);
              });

              test('skips several mappings without a release APK/AAB',
                  () async {
                writeMapping(freeMapping, DateTime(2026, 1, 1));
                writeMapping(paidMapping, DateTime(2026, 1, 2));
                fs.file(apk).parent.createSync(recursive: true);

                final commandLog =
                    await runWith(version, 'proguard_uuid: $uuid');

                expect(uploads(commandLog), isEmpty);
              });

              test(
                  'skips several variants sharing the injected UUID even '
                  'with proguard_mapping_path', () async {
                final debugMeta = await injectUuid();
                for (final flavor in ['free', 'paid']) {
                  writeMapping(
                      '$buildDir/app/outputs/mapping/${flavor}Release/mapping.txt',
                      DateTime(2026, 1, 3));
                  writeFlavorApk(flavor, DateTime(2026, 1, 3),
                      debugMeta: debugMeta);
                }

                final commandLog = await runWith(
                    version, 'proguard_mapping_path: $freeMapping');

                expect(uploads(commandLog), isEmpty);
              });

              test(
                  'proguard_mapping_path of a flavor reads the UUID of that '
                  'flavor, not of the last build', () async {
                writeMapping(freeMapping, DateTime(2026, 1, 1));
                writeMapping(paidMapping, DateTime(2026, 1, 1));
                writeFlavorApk('free', DateTime(2026, 1, 2),
                    debugMeta: 'io.sentry.ProguardUuids=$builtUuid\n');
                writeFlavorApk('paid', DateTime(2026, 1, 5),
                    debugMeta: 'io.sentry.ProguardUuids=$uuid\n');

                final commandLog = await runWith(
                    version, 'proguard_mapping_path: $freeMapping');

                expect(uploads(commandLog), [
                  '$cli $commonArgs upload-proguard $orgAndProject --uuid $builtUuid $freeMapping'
                ]);
              });

              test('skips a single mapping without a release APK/AAB',
                  () async {
                writeMapping(freeMapping, DateTime(2026, 1, 1));
                fs.file(apk).parent.createSync(recursive: true);

                final commandLog =
                    await runWith(version, 'proguard_uuid: $uuid');

                expect(uploads(commandLog), isEmpty);
              });

              test('says when the mapping was rewritten after the build',
                  () async {
                writeFlavorApk('free', DateTime(2026, 1, 2),
                    debugMeta: 'io.sentry.ProguardUuids=$builtUuid\n');
                writeMapping(freeMapping, DateTime(2026, 1, 3));

                late Iterable<String> commandLog;
                final output = await captureStdout(
                    () async => commandLog = await runWith(version, ''));

                expect(uploads(commandLog), isEmpty);
                expect(output, contains('was rewritten after'));
              });

              test('says so when there is no release APK/AAB', () async {
                writeMapping(freeMapping, DateTime(2026, 1, 1));
                fs.file(apk).parent.createSync(recursive: true);

                late Iterable<String> commandLog;
                final output = await captureStdout(
                    () async => commandLog = await runWith(version, ''));

                expect(uploads(commandLog), isEmpty);
                expect(output, contains('no release APK/AAB under'));
              });

              test('proguard_mapping_path overrides the check', () async {
                writeMapping(freeMapping, DateTime(2026, 1, 1));
                writeFlavorApk('paid', DateTime(2026, 1, 5));

                final commandLog = await runWith(version, '''
                  proguard_uuid: $uuid
                  proguard_mapping_path: $freeMapping
                ''');

                expect(uploads(commandLog), [
                  '$cli $commonArgs upload-proguard $orgAndProject --uuid $uuid $freeMapping'
                ]);
              });
            });

            test('prefers the configured proguard_uuid', () async {
              writeApk(debugMeta: 'io.sentry.ProguardUuids=$builtUuid\n');

              final commandLog = await runWith(version, 'proguard_uuid: $uuid');

              expect(
                commandLog,
                contains(
                    '$cli $commonArgs upload-proguard $orgAndProject --uuid $uuid $mapping'),
              );
            });
          });
        });

        test('takes cli-path from binPath arg', () async {
          const version = '1.0.0';
          const customCliPath = './custom/path/sentry-local-cli';
          final config = '''
            bin_path: $customCliPath
          ''';
          final commandLog = await runWith(
            version,
            config,
            customCli: customCliPath,
          );
          const release = '$name@$version';

          expect(commandLog, [
            '$customCliPath $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
            '$customCliPath $commonArgs releases $orgAndProject new $release',
            '$customCliPath $commonArgs releases $orgAndProject set-commits $release --auto',
            '$customCliPath $commonArgs releases $orgAndProject finalize $release'
          ]);
        });

        group('commits', () {
          // https://docs.sentry.io/product/cli/releases/#sentry-cli-commit-integration
          for (final value in const [
            null, // test the implicit default
            'true',
            'auto',
            'repo_name@293ea41d67225d27a8c212f901637e771d73c0f7',
            'repo_name@293ea41d67225d27a8c212f901637e771d73c0f7..1e248e5e6c24b79a5c46a2e8be12cef0e41bd58d',
          ]) {
            test(value, () async {
              const version = '1.0.0';
              final config = value == null ? '' : 'commits: $value';
              final commandLog = await runWith(version, config);
              final expectedArgs =
                  (value == null || value == 'auto' || value == 'true')
                      ? '--auto'
                      : '--commit $value';

              const release = '$name@$version';

              expect(commandLog, [
                '$cli $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
                '$cli $commonArgs releases $orgAndProject new $release',
                '$cli $commonArgs releases $orgAndProject set-commits $release $expectedArgs',
                '$cli $commonArgs releases $orgAndProject finalize $release'
              ]);
            });
          }

          // if explicitly disabled
          test('false', () async {
            const version = '1.0.0';
            final commandLog = await runWith(version, 'commits: false');
            const release = '$name@$version';

            expect(commandLog, [
              '$cli $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
              '$cli $commonArgs releases $orgAndProject new $release',
              '$cli $commonArgs releases $orgAndProject finalize $release'
            ]);
          });
        });

        test('skips finalize when finalize_release is false', () async {
          const version = '1.0.0';
          final commandLog = await runWith(version, 'finalize_release: false');
          const release = '$name@$version';

          expect(commandLog, [
            '$cli $commonArgs debug-files upload $orgAndProject $buildDir/app/outputs',
            '$cli $commonArgs releases $orgAndProject new $release',
            '$cli $commonArgs releases $orgAndProject set-commits $release --auto',
          ]);
        });

        test('emits dart-symbol-map upload command', () async {
          const version = '1.0.0';
          // Create Android symbols and a fake Dart symbol map
          final androidSymbolsDir = fs.directory('$buildDir/app/outputs')
            ..createSync(recursive: true);
          fs
              .file('${androidSymbolsDir.path}/app-release.symbols')
              .writeAsStringSync('fake');
          final mapFile = fs.file('obfuscation.map.json')
            ..writeAsStringSync('[]');

          final config = '''
            upload_debug_symbols: true
            log_level: debug
            dart_symbol_map_path: ${mapFile.path}
          ''';

          final commandLog = await runWith(version, config);
          const release = '$name@$version';

          final uploadIndex = pm.commandLog.indexWhere(
            (e) => e.contains('dart-symbol-map upload '),
          );
          expect(uploadIndex, isNonNegative);
          final uploadCommand = pm.commandLog[uploadIndex];
          const dartSymbolMapArgs = '--auth-token t --log-level debug ';
          final relStart =
              '$cli ${dartSymbolMapArgs}dart-symbol-map upload $orgAndProject ${mapFile.path} ';
          final absStart =
              '$cli ${dartSymbolMapArgs}dart-symbol-map upload $orgAndProject ${fs.file(mapFile.path).absolute.path} ';
          expect(
            (uploadCommand.startsWith(relStart) ||
                    uploadCommand.startsWith(absStart)) &&
                uploadCommand
                    .endsWith('$buildDir/app/outputs/app-release.symbols'),
            isTrue,
          );
          expect(uploadCommand.contains('--url'), isFalse);
          expect(
            pm.commandEnvironmentLog[uploadIndex],
            url == null ? isNull : {'SENTRY_URL': url},
          );

          // Ensure other expected commands still present
          expect(
              commandLog,
              contains(
                  '$cli $commonArgs --log-level debug debug-files upload $orgAndProject $buildDir/app/outputs'));
          expect(
              commandLog,
              contains(
                  '$cli $commonArgs --log-level debug releases $orgAndProject new $release'));
          expect(
              commandLog,
              contains(
                  '$cli $commonArgs --log-level debug releases $orgAndProject set-commits $release --auto'));
          expect(
              commandLog,
              contains(
                  '$cli $commonArgs --log-level debug releases $orgAndProject finalize $release'));
        });

        group('release', () {
          test('default from name and version', () async {
            const version = '1.0.0';
            final release = '$name@$version';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $release',
              '$cli sourcemaps inject build/web/file.js $orgAndProject',
              '$cli $args sourcemaps upload --release $release $buildDir/web --ext js --ext map --strip-prefix ../../Documents --strip-prefix ../../../../ --strip-prefix ../../ --strip-prefix ../ $orgAndProject',
              '$cli $args releases $orgAndProject set-commits $release --auto',
              '$cli $args releases $orgAndProject finalize $release'
            ]);
          });

          test('release from config overrides default', () async {
            const version = '1.0.0';
            final configRelease = 'fixture-configRelease';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $configRelease
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $configRelease',
              '$cli sourcemaps inject build/web/file.js $orgAndProject',
              '$cli $args sourcemaps upload --release $configRelease $buildDir/web --ext js --ext map --strip-prefix ../../Documents --strip-prefix ../../../../ --strip-prefix ../../ --strip-prefix ../ $orgAndProject',
              '$cli $args releases $orgAndProject set-commits $configRelease --auto',
              '$cli $args releases $orgAndProject finalize $configRelease'
            ]);
          });
        });

        group('dist', () {
          test('read from pubspec version', () async {
            const build = '1';
            const versionWithBuild = '1.0.0+$build';
            final release = '$name@$versionWithBuild';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
            ''';
            final commandLog = await runWith(versionWithBuild, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $release',
              '$cli sourcemaps inject build/web/file.js $orgAndProject',
              '$cli $args sourcemaps upload --release $release --dist $build $buildDir/web --ext js --ext map --strip-prefix ../../Documents --strip-prefix ../../../../ --strip-prefix ../../ --strip-prefix ../ $orgAndProject',
              '$cli $args releases $orgAndProject set-commits $release --auto',
              '$cli $args releases $orgAndProject finalize $release'
            ]);
          });

          test('read from config release', () async {
            const version = '1.0.0';
            const build = '1';
            final configRelease = 'custom+$build';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $configRelease
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $configRelease',
              '$cli sourcemaps inject build/web/file.js $orgAndProject',
              '$cli $args sourcemaps upload --release $configRelease $buildDir/web --ext js --ext map --strip-prefix ../../Documents --strip-prefix ../../../../ --strip-prefix ../../ --strip-prefix ../ $orgAndProject',
              '$cli $args releases $orgAndProject set-commits $configRelease --auto',
              '$cli $args releases $orgAndProject finalize $configRelease'
            ]);
          });

          test('used from config and appended to release', () async {
            const version = '1.0.0';
            final configDist = 'configDist';
            final release = '$name@$version+$configDist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              dist: $configDist
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $release',
              '$cli sourcemaps inject build/web/file.js $orgAndProject',
              '$cli $args sourcemaps upload --release $release --dist $configDist $buildDir/web --ext js --ext map --strip-prefix ../../Documents --strip-prefix ../../../../ --strip-prefix ../../ --strip-prefix ../ $orgAndProject',
              '$cli $args releases $orgAndProject set-commits $release --auto',
              '$cli $args releases $orgAndProject finalize $release'
            ]);
          });

          test(
              'used from config and overriding build number from pubspec version',
              () async {
            const version = '1.0.0';
            const versionWithBuild = '$version+1';
            final configDist = 'configDist';
            final release = '$name@$version+$configDist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              dist: $configDist
            ''';
            final commandLog = await runWith(versionWithBuild, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $release',
              '$cli sourcemaps inject build/web/file.js $orgAndProject',
              '$cli $args sourcemaps upload --release $release --dist $configDist $buildDir/web --ext js --ext map --strip-prefix ../../Documents --strip-prefix ../../../../ --strip-prefix ../../ --strip-prefix ../ $orgAndProject',
              '$cli $args releases $orgAndProject set-commits $release --auto',
              '$cli $args releases $orgAndProject finalize $release'
            ]);
          });

          test('used from config but not appended to config release', () async {
            const version = '1.0.0';
            final configRelease = 'fixture-configRelease';
            final configDist = 'configDist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $configRelease
              dist: $configDist
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $configRelease',
              '$cli sourcemaps inject build/web/file.js $orgAndProject',
              '$cli $args sourcemaps upload --release $configRelease --dist $configDist $buildDir/web --ext js --ext map --strip-prefix ../../Documents --strip-prefix ../../../../ --strip-prefix ../../ --strip-prefix ../ $orgAndProject',
              '$cli $args releases $orgAndProject set-commits $configRelease --auto',
              '$cli $args releases $orgAndProject finalize $configRelease'
            ]);
          });

          test(
              'used from config but not replacing build/dist in config release',
              () async {
            createJsFilesForTesting();

            const version = '1.0.0';
            final configRelease = 'fixture-configRelease+configDist';
            final configDist = 'configDist';

            final config = '''
              upload_debug_symbols: false
              upload_source_maps: true
              release: $configRelease
              dist: $configDist
              url_prefix: ~/app/
            ''';
            final commandLog = await runWith(version, config);

            final args = commonArgs;
            expect(commandLog, [
              '$cli $args releases $orgAndProject new $configRelease',
              '$cli sourcemaps inject build/web/file.js $orgAndProject',
              '$cli $args sourcemaps upload --release $configRelease --dist $configDist --url-prefix ~/app/ $buildDir/web --ext js --ext map --strip-prefix ../../Documents --strip-prefix ../../../../ --strip-prefix ../../ --strip-prefix ../ $orgAndProject',
              '$cli $args releases $orgAndProject set-commits $configRelease --auto',
              '$cli $args releases $orgAndProject finalize $configRelease'
            ]);
          });

          test('uploads debug symbols from all known paths', () async {
            const version = '1.0.0';
            final config = 'upload_debug_symbols: true';

            // Default output directories in build/
            final outputDirectories = [
              'app/outputs',
              'app/intermediates',
              'windows/runner/Release',
              'windows/x64/runner/Release',
              'windows/arm64/runner/Release',
              'linux/x64/release/bundle',
              'linux/arm64/release/bundle',
              'macos/Build/Products/Release',
              'macos/Build/Products/Release-anyrandomflavor',
              'macos/framework/Release',
              'macos/framework/Release-anyrandomflavor',
              'ios/iphoneos/Runner.app',
              'ios/Release-iphoneos',
              'ios/Release-anyrandomflavor-iphoneos',
              'ios/archive',
              'ios/framework/Release',
              'ios/framework/Release-anyrandomflavor',
            ];
            // Alternative output directories from 'root'
            final alternativeOutputDirectories = ['ios/build'];
            for (final dir in outputDirectories) {
              fs
                  .directory(buildDir)
                  .childDirectory(dir)
                  .createSync(recursive: true);
            }
            for (final dir in alternativeOutputDirectories) {
              fs.directory(dir).createSync(recursive: true);
            }

            final commandLog = await runWith(version, config);

            for (final dir in outputDirectories) {
              expect(
                  commandLog,
                  contains(
                      '$cli $commonArgs debug-files upload $orgAndProject $buildDir/$dir'));
            }

            for (final dir in alternativeOutputDirectories) {
              expect(
                  commandLog,
                  contains(
                      '$cli $commonArgs debug-files upload $orgAndProject $dir'));
            }
          });
        });
      });
    }
  }
}

class MockProcessManager implements ProcessManager {
  final commandLog = <String>[];

  /// Commands containing one of these exit with code 1.
  final failingCommands = <String>{};
  final commandEnvironmentLog = <Map<String, String>?>[];

  @override
  bool canRun(executable, {String? workingDirectory}) => true;

  @override
  bool killPid(int pid, [ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  Future<ProcessResult> run(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      covariant Encoding? stdoutEncoding = systemEncoding,
      covariant Encoding? stderrEncoding = systemEncoding}) {
    return Future.value(runSync(command));
  }

  @override
  ProcessResult runSync(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      covariant Encoding? stdoutEncoding = systemEncoding,
      covariant Encoding? stderrEncoding = systemEncoding}) {
    commandLog.add(command.join(' '));
    commandEnvironmentLog.add(
        environment == null ? null : Map<String, String>.from(environment));
    return ProcessResult(-1, 0, null, null);
  }

  @override
  Future<Process> start(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      ProcessStartMode mode = ProcessStartMode.normal}) {
    commandLog.add(command.join(' '));
    commandEnvironmentLog.add(
        environment == null ? null : Map<String, String>.from(environment));
    final joined = command.join(' ');
    final fails = failingCommands.any(joined.contains);
    return Future.value(MockProcess(exitCode: fails ? 1 : 0));
  }
}

class MockProcess implements Process {
  MockProcess({int exitCode = 0}) : _exitCode = exitCode;

  final int _exitCode;

  @override
  Future<int> get exitCode => Future.value(_exitCode);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    throw UnimplementedError();
  }

  @override
  int get pid => throw UnimplementedError();

  @override
  Stream<List<int>> get stderr => Stream.value([]);

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => Stream.value([]);
}

class MockCLI implements CLISetup {
  static const name = 'mock-cli';

  @override
  Future<String> download(
    HostPlatform platform,
    String directory,
    String cdnUrl,
    String? overrideVersion,
  ) =>
      Future.value(name);

  @override
  Future<void> check(
    HostPlatform platform,
    String path,
    String cdnUrl,
    String? overrideVersion,
  ) =>
      Future.value();
}
