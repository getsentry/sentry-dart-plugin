@Tags(['integration'])
library integration_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

const appName = 'testapp';
late final String serverUri;

// Platforms to be tested are either coming from the CI env var or
// we test everything that is possible to test on this machine.
final testPlatforms = Platform.environment.containsKey('TEST_PLATFORM')
    ? [Platform.environment['TEST_PLATFORM']!]
    : [
        'android',
        if (Platform.isMacOS) 'macos',
        if (Platform.isMacOS) 'ios',
        if (Platform.isWindows) 'windows',
        if (Platform.isLinux) 'linux',
        'web'
      ];

// NOTE: Don't run/debug this main(), it likely won't work.
// You can use main() in `sentry_native_test.dart`.
void main() async {
  serverUri = 'http://127.0.0.1:${await _serverPort}';
  final repoRootDir = Directory.current.path.endsWith('/test')
      ? Directory.current.parent
      : Directory.current;
  final tempDir = Directory('${repoRootDir.path}/temp');

  late Process testServer;
  late Future<Map<String, int>> Function() stopServer;
  setUp(() async {
    // Start a dummy Sentry server that would listen to CLI requests.
    // Also, we collect the output so that we can check it in tests.
    // Note: we're using the python dummy sever because it was already available.
    // If we wanted, we could do all this in plain dart in the future.
    testServer = await Process.start('python3', ['test-server.py', serverUri],
        workingDirectory: '${repoRootDir.path}/test');

    final testServerOutput = StringBuffer();
    final testServerOutputFutures = <Future>[];

    // capture & forward streams
    listener(List<int> data) {
      stdout.add(data);
      stdout.flush();
      testServerOutput.write(utf8.decode(data));
    }

    testServerOutputFutures.clear();
    testServerOutputFutures.add(testServer.stderr.forEach(listener));
    testServerOutputFutures.add(testServer.stdout.forEach(listener));

    stopServer = () async {
      await http.get(Uri.parse('$serverUri/STOP'));
      for (var future in testServerOutputFutures) {
        await future;
      }
      expect(await testServer.exitCode.timeout(const Duration(seconds: 5)), 0);
      final serverOutput = testServerOutput
          .toString()
          .split(RegExp('\r?\n'))
          .where((v) => v.isNotEmpty);

      final debugSymbols = serverOutput
          .skipWhile((v) => v != 'Upload stats:')
          .skip(1)
          .map((v) => v.trim())
          .map((v) {
        final pair = v.split(':');
        return MapEntry(
            pair[0], int.parse(pair[1].replaceFirst(' count=', '')));
      });

      return Map.fromEntries(debugSymbols);
    };
  });

  tearDown(() async {
    testServer.kill(ProcessSignal.sigkill);
  });

  for (var platform in testPlatforms) {
    test(platform, () async {
      final appDir = await _prepareTestApp(tempDir, platform);
      await _runPlugin(appDir);
      final serverOutput = await stopServer();

      switch (platform) {
        case 'android':
        case 'windows':
        case 'ios':
        case 'macos':
        case 'web':
          expect(serverOutput, isNotEmpty);
          break;
        default:
          fail('Platform "$platform" missing from tests');
      }
    }, timeout: Timeout(const Duration(minutes: 5)));
  }
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
  final outputFuture = process.stdout.forEach((data) {
    stdout.add(data);
    output.write(utf8.decode(data));
  });

  int exitCode = await process.exitCode;
  await outputFuture;
  if (exitCode != 0) {
    throw Exception(
        "$executable ${arguments.join(' ')} failed with exit code $exitCode");
  }

  return output.toString();
}

Future<String> _flutter(List<String> arguments, {String? cwd}) =>
    _exec('flutter', arguments, cwd: cwd);

Future<void> _runPlugin(Directory cwd) => _exec(
    'dart', ['run', 'sentry_dart_plugin', '--sentry-define=url=$serverUri'],
    cwd: cwd.path);

// e.g. Flutter 3.24.4 • channel stable • https://github.com/flutter/flutter.git
final _flutterVersionInfo =
    _flutter(['--version']).then((output) => output.split('\n').first);

Future<Directory> _prepareTestApp(Directory tempDir, String platform) async {
  final appDir = Directory('${tempDir.path}/$appName-$platform');
  final pubspecFile = File('${appDir.path}/pubspec.yaml');

  final buildArgs = [
    if (platform == 'ios')
      'ipa'
    else if (platform == 'android')
      'apk'
    else
      platform,
    if (platform == 'ios') '--no-codesign',
    if (platform == 'web') '--source-maps',
    if (platform != 'web') '--split-debug-info=symbols',
    if (platform != 'web') '--obfuscate'
  ];

  // In order to not run the build on every test execution, we store a hash.
  final hashFile = File('${appDir.path}/.hash');
  final hash = md5
      .convert(utf8.encode(await _flutterVersionInfo + buildArgs.toString()))
      .toString();

  if (await hashFile.exists()) {
    if (await hashFile.readAsString() != hash) {
      await appDir.delete(recursive: true);
    }
  } else if (await appDir.exists()) {
    await appDir.delete(recursive: true);
  }

  if (!await hashFile.exists()) {
    await _flutter(['create', appDir.path, '--project-name', appName]);

    await _flutter(['build', ...buildArgs], cwd: appDir.path);

    var pubspec = await pubspecFile.readAsString();
    // Remove the plus symbol from the version. Current python sever has trouble
    // parsing requests with this.
    pubspec = pubspec.replaceFirst('version: 1.0.0+1', 'version: 1.0.0');
    pubspec = pubspec.replaceFirst('dev_dependencies:',
        'dev_dependencies:\n  sentry_dart_plugin:\n    path: ../../');
    pubspec = '''
$pubspec
sentry:
  upload_debug_symbols: true
  upload_sources: true
  upload_source_maps: true
  auth_token: auth-token
  project: sentry-dart-plugin
  org: sentry-sdks
  log_level: debug
  commits: false
''';
    await pubspecFile.writeAsString(pubspec);

    // Store the hash so that we don't need to rebuild the app.
    await hashFile.writeAsString(hash);
  }

  return appDir;
}

// Unused port for the server
final _serverPort =
    ServerSocket.bind(InternetAddress.loopbackIPv4, 0).then((socket) {
  var port = socket.port;
  socket.close();
  return port;
});
