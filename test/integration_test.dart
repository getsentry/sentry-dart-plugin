import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

const appName = 'testapp';

// NOTE: Don't run/debug this main(), it likely won't work.
// You can use main() in `sentry_native_test.dart`.
void main() {
  final repoRootDir = Directory.current.path.endsWith('/test')
      ? Directory.current.parent.path
      : Directory.current.path;

  final testPlatforms = bool.hasEnvironment('TEST_PLATFORM')
      ? [String.fromEnvironment('TEST_PLATFORM')]
      : [
          if (Platform.isWindows) 'windows',
          if (Platform.isMacOS) 'macos',
          if (Platform.isMacOS) 'ios',
          if (Platform.isLinux) 'linux',
          if (Platform.isLinux) 'android',
        ];

  late final File pubspecFile;
  late final String pubspecOriginal;

  setUpAll(() async {
    // Sanity check that we're running on a platform that's configured to run these tests.
    expect(testPlatforms, isNotEmpty);

    final tempDir = '$repoRootDir/temp';
    final appDir = Directory('$tempDir/$appName');
    pubspecFile = File('${appDir.path}/pubspec.yaml');
    final pubspecBackupFile = File('${pubspecFile.path}.bak');

    // In order to not run the build on every test execution, we store a hash.
    final hashFile = File('${appDir.path}/.hash');
    final hash = md5
        .convert(utf8
            .encode(await _flutter(['--version']) + testPlatforms.toString()))
        .toString();

    if (await hashFile.exists()) {
      if (await hashFile.readAsString() != hash) {
        await appDir.delete(recursive: true);
      }
    } else if (await appDir.exists()) {
      await appDir.delete(recursive: true);
    }

    if (!await hashFile.exists()) {
      await _flutter(['create', appName], cwd: tempDir);

      for (var buildPlatform in testPlatforms) {
        await _flutter([
          'build',
          buildPlatform,
          '--split-debug-info=symbols',
          '--obfuscate'
        ], cwd: appDir.path);
      }

      final pubspec = await pubspecFile.readAsString();
      await pubspecFile.writeAsString(pubspec.replaceFirst('dev_dependencies:',
          'dev_dependencies:\n  sentry_dart_plugin:\n    path: ../../'));

      // Store a pubspec backup so that we can restore it after each test.
      await pubspecBackupFile.writeAsString(await pubspecFile.readAsString());

      // Store the hash so that we don't need to rebuild the app.
      await hashFile.writeAsString(hash);
    }

    pubspecOriginal = await pubspecBackupFile.readAsString();
  });

  setUp(() async {
    await pubspecFile.writeAsString(pubspecOriginal);
  });

  test('simple', () {});
}

/// Runs [command] with command's stdout and stderr being forwrarded to
/// test runner's respective streams. It buffers stdout and returns it.
///
/// Returns [_CommandResult] with exitCode and stdout as a single sting
Future<String> _exec(String executable, List<String> arguments,
    {String? cwd}) async {
  print(
      'executing "$executable ${arguments.join(' ')}"${cwd != null ? ' in $cwd' : ''}');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: cwd,
    runInShell: true,
  );

  // forward standard streams
  unawaited(stderr.addStream(process.stderr));

  final output = StringBuffer();
  unawaited(stdout.addStream(process.stdout
      .transform(StreamTransformer.fromHandlers(handleData: (data, sink) {
    output.write(utf8.decode(data));
    sink.add(data);
  }))));

  int exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw Exception(
        "$executable ${arguments.join(' ')} failed with exit code $exitCode");
  }

  return output.toString();
}

Future<String> _flutter(List<String> arguments, {String? cwd}) =>
    _exec('flutter', arguments, cwd: cwd);
