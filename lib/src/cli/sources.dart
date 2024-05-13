class CLISource {
  final String name;
  final String version;
  final String hash;

  CLISource(this.name, this.version, this.hash);

  Uri formatDownloadUrl(String prefix) {
    if (prefix.endsWith('/')) {
      prefix = prefix.substring(0, prefix.length - 2);
    }

    final parsed = Uri.parse(prefix);
    final fullUrl = parsed.replace(
      pathSegments: [...parsed.pathSegments, version, name],
    );
    return fullUrl;
  }
}

// TODO after increasing min dart SDK version to 2.13.0
// typedef CLISources = Map<HostPlatform, CLISource>;
