// FILE GENERATED BY scripts/update-cli.sh - DO NOT MODIFY BY HAND

import 'package:sentry_dart_plugin/src/cli/sources.dart';

import 'host_platform.dart';

const _version = '2.25.2';
const _urlPrefix = 'https://downloads.sentry-cdn.com/sentry-cli/$_version';

final currentCLISources = {
  HostPlatform.darwinUniversal: CLISource(
      '$_urlPrefix/sentry-cli-Darwin-universal',
      'e723cbd3e5a058f15e66abcce4dead885f217c8270af5ca26b9809ee7669a9a1'),
  HostPlatform.linuxAarch64: CLISource('$_urlPrefix/sentry-cli-Linux-aarch64',
      '5461cf339976bc3f03ced7483ef63d81163b521c9aa17e0dd7bdf44f1f429ff4'),
  HostPlatform.linuxArmv7: CLISource('$_urlPrefix/sentry-cli-Linux-armv7',
      'd54cb179a04785740cde482275557f0db943170bd5810db918d9e4d20c12c646'),
  HostPlatform.linux64bit: CLISource('$_urlPrefix/sentry-cli-Linux-x86_64',
      'f9987b4420d3980cc3120d4e90d6fb9b5a400c0b881f326c61d373572abb4d7b'),
  HostPlatform.windows32bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-i686.exe',
      '81c23df87567e736fc70f106640e4ed837c79a7e53f10d0b01b3d7da4a94e9c6'),
  HostPlatform.windows64bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-x86_64.exe',
      'fdf051e6b70ae20939012b5a77746716c00d529cf6744556f37371e4cae25678'),
};
