import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/environment_configuration.dart';
import 'package:sentry_dart_plugin/src/utils/config-reader/config_reader.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';
import 'package:test/test.dart';

import 'utils/config_file_type.dart';
import 'utils/config_formatter.dart';
import 'utils/config_writer.dart';

void main() {
  group('loadConfiguration', () {

    late Fixture fixture;

    setUp(() {
      final fs = MemoryFileSystem.test();
      fs.currentDirectory = fs.directory('/subdir')..createSync();
      injector.registerSingleton<FileSystem>(() => fs, override: true);

      fixture = Fixture(fs);
    });

    test("takes `version` from env config", () {
      final envConfig = EnvironmentConfiguration(
          version: 'version-env-config',
      );

      final sut = fixture.getSut('', envConfig);
      expect(sut.version, 'version-env-config');
    });

    test("takes `name` from env config", () {
      final envConfig = EnvironmentConfiguration(
        name: 'name-env-config',
      );

      final sut = fixture.getSut('', envConfig);
      expect(sut.name, 'name-env-config');
    });
  });
}

class Fixture {
  Fixture(this.fs);

  FileSystem fs;

  Configuration getSut(
      String config,
      EnvironmentConfiguration envConfig,
  ) {
    final formattedConfig = ConfigFormatter.formatConfig(
      config,
      ConfigFileType.pubspecYaml,
      null,
    );

    final writer = ConfigWriter(fs, 'name-config', 'version-config',);
    writer.write(ConfigFileType.pubspecYaml, formattedConfig);

    final reader = ConfigReader();
    final configuration = Configuration();
    configuration.loadConfig(reader, envConfig);
    return configuration;
  }
}
