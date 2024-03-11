// FILE GENERATED BY scripts/update-cli.sh - DO NOT MODIFY BY HAND

import 'package:sentry_dart_plugin/src/cli/sources.dart';

import 'host_platform.dart';

const _version = '2.30.0';
const _urlPrefix = 'https://downloads.sentry-cdn.com/sentry-cli/$_version';

final currentCLISources = {
  HostPlatform.darwinUniversal: CLISource(
      '$_urlPrefix/sentry-cli-Darwin-universal',
      '8ede3324bd7a7f66f1d05020a95c2b538584c9cde54e40e250f96c1d065454cc'),
  HostPlatform.linuxAarch64: CLISource('$_urlPrefix/sentry-cli-Linux-aarch64',
      'ddfac08ce0396513d5a0a88933c747e9abfba24de6b299956bc89db05671b09c'),
  HostPlatform.linuxArmv7: CLISource('$_urlPrefix/sentry-cli-Linux-armv7',
      'b2640ba81fd2d683b3e0eea079125ab4786c1ceaa97916b8440414ad56fe4f36'),
  HostPlatform.linux64bit: CLISource('$_urlPrefix/sentry-cli-Linux-x86_64',
      '7f1a2e2786c6d94d0c9b6560a9ff73801b64c7ba78831cf6aa502f183968fbd0'),
  HostPlatform.windows32bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-i686.exe',
      'addf2c649822bb48de4310ff166df7507254f4f0331c31b0558644cdf32f358e'),
  HostPlatform.windows64bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-x86_64.exe',
      '84e43178fb21feb37e08d0f5223c764e07c414d9cacd6be2454e7f020b7ee2c5'),
};
