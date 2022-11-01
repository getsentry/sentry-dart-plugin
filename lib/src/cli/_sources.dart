// FILE GENERATED BY scripts/update-cli.sh - DO NOT MODIFY BY HAND

import 'package:sentry_dart_plugin/src/cli/sources.dart';

import 'host_platform.dart';

const _version = '2.8.1';
const _urlPrefix = 'https://downloads.sentry-cdn.com/sentry-cli/$_version';

final currentCLISources = {
  HostPlatform.darwinUniversal: CLISource(
      '$_urlPrefix/sentry-cli-Darwin-universal',
      'aded269c5e6448bdc18fefdd8bb2e3aafc14d7b62f786f224f1a005320d10fc6'),
  HostPlatform.linuxAarch64: CLISource('$_urlPrefix/sentry-cli-Linux-aarch64',
      '8607277dd4e672abec3d1f65a7b108e7f76c506467392141ce7b727f85e8a648'),
  HostPlatform.linuxArmv7: CLISource('$_urlPrefix/sentry-cli-Linux-armv7',
      'd472cfe971606d824ec03fb6950e3a7807a55933deaa91199c2b5e8dad59f495'),
  HostPlatform.linux64bit: CLISource('$_urlPrefix/sentry-cli-Linux-x86_64',
      '517e07749123f3b30c388a6e9347c6e7f99ed86808110e916c27d6a5638032ad'),
  HostPlatform.windows32bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-i686.exe',
      '4eaa6c3d40dc5924b51b05f5a9831cb1136dd8abe51ce45ba921f1d07d32d450'),
  HostPlatform.windows64bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-x86_64.exe',
      'e9b90852b0120f00f3462fecf870d8872ec5ee8fa263ba075abd8fcd573c58fb'),
};
