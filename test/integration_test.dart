@Tags(['integration'])
library integration_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const appName = 'testapp';
late final String serverUri;

// Platforms to be tested are either coming from the CI env var or
// we test everything that is possible to test on this machine.
final testPlatforms = Platform.environment.containsKey('TEST_PLATFORM')
    ? [Platform.environment['TEST_PLATFORM']!]
    : [
        'apk',
        'appbundle',
        if (Platform.isMacOS) 'macos',
        if (Platform.isMacOS) 'macos-framework',
        if (Platform.isMacOS) 'ios',
        if (Platform.isMacOS) 'ios-framework',
        if (Platform.isMacOS) 'ipa',
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
  late Future<Iterable<String>> Function() stopServer;
  setUp(() async {
    // Start a dummy Sentry server that would listen to CLI requests.
    // Also, we collect the output so that we can check it in tests.
    // Note: we're using the python dummy sever because it was already available.
    // If we wanted, we could do all this in plain dart in the future.
    testServer = await Process.start('python3', ['test-server.py', serverUri],
        workingDirectory: '${repoRootDir.path}/test');

    // capture & forward streams
    final collector = _ProcessStreamCollector(testServer);

    stopServer = () async {
      await http.get(Uri.parse('$serverUri/STOP'));
      expect(await testServer.exitCode.timeout(const Duration(seconds: 5)), 0);
      final serverOutput = (await collector.output)
          .toString()
          .split(RegExp('\r?\n'))
          .where((v) => v.isNotEmpty);
      return serverOutput;
    };
  });

  uploadedDebugSymbols(Iterable<String> serverOutput) =>
      Map.fromEntries(serverOutput
          .skipWhile((v) => v != 'Upload stats:')
          .skip(1)
          .map((v) => v.trim())
          .map((v) {
        final pair = v.split(':');
        return MapEntry(
            pair[0], int.parse(pair[1].replaceFirst(' count=', '')));
      }));

  tearDown(() async {
    testServer.kill(ProcessSignal.sigkill);
  });

  for (var platform in testPlatforms) {
    test(platform, () async {
      final appDir = await _prepareTestApp(tempDir, platform);
      final pluginOutput = await _runPlugin(appDir);
      final serverOutput = await stopServer();
      final debugSymbols = uploadedDebugSymbols(serverOutput).keys;

      switch (platform) {
        case 'apk':
        case 'appbundle':
          expect(
              debugSymbols,
              containsAll([
                'app.android-arm.symbols',
                'app.android-arm64.symbols',
                'app.android-x64.symbols',
                'libflutter.so'
              ]));
          expect(debugSymbols, anyElement(matches(RegExp('^(lib)?app.so\$'))));
          break;
        case 'ios':
        case 'ipa':
          expect(debugSymbols, containsAll(['App', 'Flutter', 'Runner']));
          break;
        case 'ios-framework':
          expect(debugSymbols, containsAll(['App', 'Flutter']));
          break;
        case 'macos':
          expect(debugSymbols, containsAll(['App', 'FlutterMacOS', appName]));
          break;
        case 'macos-framework':
          expect(debugSymbols, containsAll(['App', 'FlutterMacOS']));
          break;
        case 'windows':
          expect(
              debugSymbols,
              containsAll([
                'app.so',
                'app.windows-x64.symbols',
                'flutter_windows.dll',
                'flutter_windows.dll.pdb',
              ]));
          break;
        case 'linux':
          expect(
              debugSymbols,
              containsAll([
                'app.linux-x64.symbols',
                'libapp.so',
                'libflutter_linux_gtk.so',
              ]));
          break;
        case 'web':
          expect(pluginOutput,
              anyElement(contains('sourcemap at main.dart.js.map, debug id')));
          expect(pluginOutput, anyElement(contains('☑ uploading source maps')));
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
Future<Iterable<String>> _exec(String executable, List<String> arguments,
    {String? cwd}) async {
  print(
      'executing "$executable ${arguments.join(' ')}"${cwd != null ? ' in $cwd' : ''}');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: cwd,
    runInShell: true,
  );

  final collector = _ProcessStreamCollector(process);

  int exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw Exception(
        "$executable ${arguments.join(' ')} failed with exit code $exitCode");
  }

  final output = await collector.output;
  return output.toString().split(RegExp('\r?\n'));
}

Future<Iterable<String>> _flutter(List<String> arguments, {String? cwd}) =>
    _exec('flutter', arguments, cwd: cwd);

Future<Iterable<String>> _runPlugin(Directory cwd) => _exec(
    'dart', ['run', 'sentry_dart_plugin', '--sentry-define=url=$serverUri'],
    cwd: cwd.path);

// e.g. Flutter 3.24.4 • channel stable • https://github.com/flutter/flutter.git
final _flutterVersionInfo =
    _flutter(['--version']).then((output) => output.first);

Future<Directory> _prepareTestApp(Directory tempDir, String platform) async {
  final appDir = Directory('${tempDir.path}/$appName-$platform');
  final pubspecFile = File('${appDir.path}/pubspec.yaml');
  Directory('${appDir.path}/build/web').createSync(recursive: true);
  File('${appDir.path}/build/web/main.dart.js')
      .writeAsStringSync('''//# sourceMappingURL=main.dart.js.map>
''');
  File('${appDir.path}/build/web/main.dart.js.map').writeAsStringSync('''{
  "version": 3,
  "sources": ["../lib/src/main.dart"],
  "names": ["Celebrate", "ReactDOM", "render", "document", "getElementById"],
  "mappings": "AAAA,MAAMA,SAAS,GAAG,MAAM;AACtB,sBAAO,oFAAP;AACD,CAFD;;AAIAC,QAAQ,CAACC,MAAT,eACE,oBAAC,SAAD,OADF,EAEEC,QAAQ,CAACC,cAAT,CAAwB,MAAxB,CAFF",
  "sourcesContent": [
    "const Celebrate = () => {\n  return <p>It's working! 🎉🎉🎉</p>;\n};\n\nReactDOM.render(\n  <Celebrate />,\n  document.getElementById('root'),\n);"
  ]
}''');

  final buildArgs = [
    platform,
    if (['ipa', 'ios'].contains(platform)) '--no-codesign',
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
  upload_source_maps: ${platform == 'web'}
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

class _ProcessStreamCollector {
  final _output = StringBuffer();
  final _futures = <Future>[];

  _ProcessStreamCollector(Process process) {
    _futures.add(process.stderr.forEach((_listen)));
    _futures.add(process.stdout.forEach((_listen)));
  }

  void _listen(List<int> data) {
    final str = utf8.decode(data);
    print(str.trim());
    _output.write(str);
  }

  Future<String> get output =>
      Future.wait(_futures).then((_) => _output.toString());
}
