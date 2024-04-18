class CLISource {
  final Uri downloadUrl;
  final String version;
  final String hash;

  CLISource(String downloadUrl, this.version, this.hash)
      : downloadUrl = Uri.parse(downloadUrl);

  CLISource from(String prefix) {
    final pathSegmentsLen = downloadUrl.pathSegments.length;
    final version = downloadUrl.pathSegments[pathSegmentsLen - 2];
    final name = downloadUrl.pathSegments[pathSegmentsLen - 1];

    final prefixUrl = Uri.parse(prefix);
    final newDownloadUrl = prefixUrl.replace(
      pathSegments: [...prefixUrl.pathSegments, version, name],
    ).toString();
    return CLISource(newDownloadUrl, version, hash);
  }
}

// TODO after increasing min dart SDK version to 2.13.0
// typedef CLISources = Map<HostPlatform, CLISource>;
