import 'config_file_type.dart';

class ConfigFormatter {
  static String formatConfig(
      String config, ConfigFileType fileType, String? url) {
    // Add URL if provided
    if (url != null) {
      config = _addUrlPrefix(config, fileType, url);
    }

    // Format config based on file type
    switch (fileType) {
      case ConfigFileType.sentryProperties:
        return _formatSentryPropertiesConfig(config);
      case ConfigFileType.pubspecYaml:
        return _formatPubspecYamlConfig(config);
      default:
        throw Exception('Unknown config file type: $fileType');
    }
  }

  static String _addUrlPrefix(
      String config, ConfigFileType fileType, String url) {
    final urlLine =
        fileType == ConfigFileType.sentryProperties ? 'url=$url' : 'url: $url';
    return '$urlLine\n$config';
  }

  static String _formatSentryPropertiesConfig(String config) {
    return config
        .replaceAll(': ', '=')
        .split('\n')
        .map((line) => line.trim())
        .join('\n')
        .replaceAll('[', '')
        .replaceAll(']', ''); // support for arrays
  }

  static String _formatPubspecYamlConfig(String config) {
    return config.split('\n').map((line) => '  ${line.trim()}').join('\n');
  }
}
