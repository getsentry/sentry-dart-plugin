// FILE GENERATED BY scripts/update-cli.sh - DO NOT MODIFY BY HAND

import 'package:sentry_dart_plugin/src/cli/sources.dart';

import 'host_platform.dart';

const _version = '2.30.1';
const _urlPrefix = 'https://downloads.sentry-cdn.com/sentry-cli/$_version';

final currentCLISources = {
  HostPlatform.darwinUniversal: CLISource(
      '$_urlPrefix/sentry-cli-Darwin-universal',
      '56aaaa929871511923115c93a16074fa48efea94be80f0e6ffe56ee65b905599'),
  HostPlatform.linuxAarch64: CLISource('$_urlPrefix/sentry-cli-Linux-aarch64',
      '11dee7f6459245d8cedbce4139342b89d24759bba7a90205be4e4b9cbdd2b7e5'),
  HostPlatform.linuxArmv7: CLISource('$_urlPrefix/sentry-cli-Linux-armv7',
      '044fd1dd9c5fde9c04156f0cce1476b861bc1a96270a08eba58ab642a1d9edff'),
  HostPlatform.linux64bit: CLISource('$_urlPrefix/sentry-cli-Linux-x86_64',
      '35ccca7cf53e2b7cd5f76311b43315f3267ee123af0184671cca6746c7499b10'),
  HostPlatform.windows32bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-i686.exe',
      'ec8404b973616ae9b1d92f5e7b064da2273c6290bd2393123081c7ba4b6d7e2b'),
  HostPlatform.windows64bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-x86_64.exe',
      'e2f9de1144b3d66617c70d817c0a77bfc097d817fd66e7dd0429b6034fef85c4'),
};
