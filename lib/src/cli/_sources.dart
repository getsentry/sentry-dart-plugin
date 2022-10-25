// FILE GENERATED BY scripts/update-cli.sh - DO NOT MODIFY BY HAND

import 'package:sentry_dart_plugin/src/cli/sources.dart';

import 'host_platform.dart';

const _version = '2.8.0';
const _urlPrefix = 'https://downloads.sentry-cdn.com/sentry-cli/$_version';

final currentCLISources = {
  HostPlatform.darwinUniversal: CLISource(
      '$_urlPrefix/sentry-cli-Darwin-universal',
      'a2aadaf804fad99ac70f52a32bf1f0ff53327ed52c2a723fea04bbe9cbde3485'),
  HostPlatform.linuxAarch64: CLISource('$_urlPrefix/sentry-cli-Linux-aarch64',
      '652b0a6fb992fac95b80bcc6d2f59868750ac22eb2ff4156d3c8bd646c934c3b'),
  HostPlatform.linuxArmv7: CLISource('$_urlPrefix/sentry-cli-Linux-armv7',
      '0c41f307f3f2a69270150b1b8fd41acbbcfbe8730610d3a7dd8bdd7aecac6613'),
  HostPlatform.linux64bit: CLISource('$_urlPrefix/sentry-cli-Linux-x86_64',
      'bbbd739afc0d8a6736ae45e5f6fcd6db87f7abf45de9fa76e5621834f2dfd15d'),
  HostPlatform.windows32bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-i686.exe',
      '760d313eddd0f1dd5b23301635dc7c4512b021d9dc01067eb7fa6b54e4789078'),
  HostPlatform.windows64bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-x86_64.exe',
      'a89a4ca913be1e5ff9ccb456b5bde221bb59128eb5ca2de0f6bcd09a119471ee'),
};
