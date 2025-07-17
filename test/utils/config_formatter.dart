import 'config_file_type.dart';

class ConfigFormatter {
  static String formatConfig(
    String config,
    ConfigFileType fileType,
    String? url,
  ) {
    if (url?.isNotEmpty == true) {
      config = _addUrlPrefix(config, fileType, url!);
    }

    switch (fileType) {
      case ConfigFileType.sentryProperties:
        return _formatSentryPropertiesConfig(config);
      case ConfigFileType.pubspecYaml:
        return _formatPubspecYamlConfig(config);
    }
  }

  static String _addUrlPrefix(
    String config,
    ConfigFileType fileType,
    String url,
  ) {
    final urlLine =
        fileType == ConfigFileType.sentryProperties ? 'url=$url' : 'url: $url';
    return '$urlLine\n$config';
  }

  static String _formatSentryPropertiesConfig(String config) {
    final lines = config.split('\n');
    final out = StringBuffer();

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;

      // 1) normalise key/value separator once
      line = line.replaceFirstMapped(
          RegExp(r'^([^=:\s]+):\s*'), (m) => '${m.group(1)}=');

      // 2) inline array
      final mInline = RegExp(r'(.*)=\[(.*)\]').firstMatch(line);
      if (mInline != null) {
        final key = mInline.group(1)!.trim();
        final values =
            mInline.group(2)!.split(',').map((v) => v.trim()).join(',');
        out.writeln('$key=$values');
        continue;
      }

      // 3) block-array start
      if (RegExp(r'.*=').hasMatch(line) && line.endsWith('=')) {
        final key = line.substring(0, line.length - 1).trim();
        final values = <String>[];

        while (i + 1 < lines.length) {
          final next = lines[i + 1].trim();
          if (next.startsWith('- ')) {
            values.add(next.substring(2).trim());
            i++; // consume
          } else if (next.isEmpty) {
            i++; // skip blank
          } else {
            break;
          }
        }

        out.writeln('$key=${values.join(',')}');
        continue;
      }

      // 4) plain key=value line
      out.writeln(line);
    }

    return out.toString().trimRight();
  }

  static String _formatPubspecYamlConfig(String config) {
    return config
        .split('\n')
        .map((l) =>
            l.trim().startsWith('- ') ? '    ${l.trim()}' : '  ${l.trim()}')
        .join('\n')
        .trimRight();
  }
}
