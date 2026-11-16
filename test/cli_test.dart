import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:sentry_dart_plugin/src/utils/injector.dart';
import 'package:sentry_dart_plugin/src/cli/_sources.dart';
import 'package:sentry_dart_plugin/src/cli/host_platform.dart';
import 'package:sentry_dart_plugin/src/cli/setup.dart';
import 'package:sentry_dart_plugin/src/cli/sources.dart';

void main() {
  final sources = currentCLISources;
  final platforms = HostPlatform.values;
  // These tests download the real binaries to verify the generated URLs and
  // checksums. The Darwin universal binary alone takes close to 30s on CI.
  const downloadTimeout = Timeout(Duration(minutes: 2));

  for (var platform in platforms) {
    test(platform.name, () async {
      final fs = MemoryFileSystem.test();
      injector.registerSingleton<FileSystem>(() => fs, override: true);
      final cliSetup = CLISetup(sources);
      final file = await cliSetup.download(
        platform,
        '.dart_tool/pub/bin/sentry_dart_plugin',
        'https://downloads.sentry-cdn.com/sentry-cli',
        null,
      );
      final suffix = platform.name.startsWith('windows') ? '.exe' : '';
      expect(file, '.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli$suffix');
      expect(fs.file(file).existsSync(), isTrue);
    }, timeout: downloadTimeout);

    test('version override', () async {
      final fs = MemoryFileSystem.test();
      injector.registerSingleton<FileSystem>(() => fs, override: true);
      final cliSetup = CLISetup(sources);
      final file = await cliSetup.download(
        platform,
        '.dart_tool/pub/bin/sentry_dart_plugin',
        'https://downloads.sentry-cdn.com/sentry-cli',
        '2.0.0',
      );
      final suffix = platform.name.startsWith('windows') ? '.exe' : '';
      expect(file, '.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli$suffix');
      expect(fs.file(file).existsSync(), isTrue);
    }, timeout: downloadTimeout);
  }

  group('download failures', () {
    const platform = HostPlatform.linux64bit;
    const directory = '.dart_tool/pub/bin/sentry_dart_plugin';
    final body = utf8.encode('sentry-cli');
    late MemoryFileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test();
      injector.registerSingleton<FileSystem>(() => fs, override: true);
    });

    CLISetup setupWith(http.Response response, {required String hash}) {
      return CLISetup(
        {platform: CLISource('sentry-cli-Linux-x86_64', '1.0.0', hash)},
        httpClientFactory: () => MockClient((_) async => response),
      );
    }

    test('throws on non-2xx response', () async {
      final cliSetup = setupWith(
        http.Response('not found', 404),
        hash: sha256.convert(body).toString(),
      );

      await expectLater(
        cliSetup.download(platform, directory, 'https://example.com', null),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'message', contains('HTTP 404'))),
      );
      expect(fs.file('$directory/sentry-cli').existsSync(), isFalse);
    });

    test('throws and deletes the file on checksum mismatch', () async {
      final cliSetup = setupWith(
        http.Response.bytes(body, 200),
        hash: sha256.convert(utf8.encode('something else')).toString(),
      );

      await expectLater(
        cliSetup.download(platform, directory, 'https://example.com', null),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'message', contains('checksum'))),
      );
      expect(fs.file('$directory/sentry-cli').existsSync(), isFalse);
    });

    test('succeeds when the checksum matches', () async {
      final cliSetup = setupWith(
        http.Response.bytes(body, 200),
        hash: sha256.convert(body).toString(),
      );

      final file = await cliSetup.download(
          platform, directory, 'https://example.com', null);
      expect(fs.file(file).readAsBytesSync(), body);
    });
  });
}
