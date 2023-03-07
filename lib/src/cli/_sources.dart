// FILE GENERATED BY scripts/update-cli.sh - DO NOT MODIFY BY HAND

import 'package:sentry_dart_plugin/src/cli/sources.dart';

import 'host_platform.dart';

const _version = '2.14.4';
const _urlPrefix = 'https://downloads.sentry-cdn.com/sentry-cli/$_version';

final currentCLISources = {
  HostPlatform.darwinUniversal: CLISource(
      '$_urlPrefix/sentry-cli-Darwin-universal',
      'af6a30deefe29037947f55bcf7903499f28b6c505ab4a63efa59b3a41abb9ace'),
  HostPlatform.linuxAarch64: CLISource('$_urlPrefix/sentry-cli-Linux-aarch64',
      '7e3b5a5b458818dbc60f4cb78b1c7f51e8a0e4b62451e14a8a3c854496b216e5'),
  HostPlatform.linuxArmv7: CLISource('$_urlPrefix/sentry-cli-Linux-armv7',
      'ac58c881567f1de0fc347f07ef80a21ad0b15fa5cea7c856a36ae60ba3d89f3b'),
  HostPlatform.linux64bit: CLISource('$_urlPrefix/sentry-cli-Linux-x86_64',
      '61d1c1a34555920d48f2b3439a34b1825403a2f818d7b698159a7df6f7986b45'),
  HostPlatform.windows32bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-i686.exe',
      '61a0b5bc17421c1d1e21fe1af979475c214c93f514014b1c43c13da235d4e295'),
  HostPlatform.windows64bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-x86_64.exe',
      '78295ed9b00f782050c259eae2abf7c9017b19ad01c1445f885a4e6228d811ec'),
};
