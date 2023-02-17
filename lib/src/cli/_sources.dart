// FILE GENERATED BY scripts/update-cli.sh - DO NOT MODIFY BY HAND

import 'package:sentry_dart_plugin/src/cli/sources.dart';

import 'host_platform.dart';

const _version = '2.13.0';
const _urlPrefix = 'https://downloads.sentry-cdn.com/sentry-cli/$_version';

final currentCLISources = {
  HostPlatform.darwinUniversal: CLISource(
      '$_urlPrefix/sentry-cli-Darwin-universal',
      '549400349cddc29122373c2a166f3ea3723e309eac3690c66543924d9d638bd3'),
  HostPlatform.linuxAarch64: CLISource('$_urlPrefix/sentry-cli-Linux-aarch64',
      '01b39b3dd502d532846b741e612a1796ce727b79bb69cbab45b23126507717f8'),
  HostPlatform.linuxArmv7: CLISource('$_urlPrefix/sentry-cli-Linux-armv7',
      '85750995d28f7a0771f6f6a9fe23197dc35512047afc3c78bb042613d41aea8f'),
  HostPlatform.linux64bit: CLISource('$_urlPrefix/sentry-cli-Linux-x86_64',
      '217bcb4e5fd74b189be5a834ba835828eb6f7d97d3f676ef2da26f4de3df1729'),
  HostPlatform.windows32bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-i686.exe',
      '5d0a4c3c6a49ca7cd65b685aff0d56a2e79a29e841380ca493c6bc3656ebd8cb'),
  HostPlatform.windows64bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-x86_64.exe',
      '753d0f2cb65bfb5ab95d74d034c2d58451d5dcae1136e16b3e1aa0683ee1af95'),
};
