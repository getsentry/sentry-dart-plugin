import 'package:file/file.dart';

import 'config_file_type.dart';

class ConfigWriter {
  final FileSystem fs;
  final String name;
  final String version;

  ConfigWriter(this.fs, this.name, this.version);

  void write(ConfigFileType configFile, String config) {
    // Write the basic options to pubspec.yaml which is needed for all configs
    fs.file('pubspec.yaml').writeAsStringSync('''
name: $name
version: $version
''');

    if (configFile == ConfigFileType.pubspecYaml) {
      fs.file('pubspec.yaml').writeAsStringSync(
        '''
sentry:
  auth_token: t
  project: p
  org: o
''',
        mode: FileMode.append,
      );
      fs.file('pubspec.yaml').writeAsStringSync(config, mode: FileMode.append);
    } else if (configFile == ConfigFileType.sentryProperties) {
      fs.file('sentry.properties').writeAsStringSync('''
auth_token=t
project=p
org=o
''');
      fs
          .file('sentry.properties')
          .writeAsStringSync(config, mode: FileMode.append);
    }
  }
}
