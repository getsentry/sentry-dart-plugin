import 'package:sentry_dart_plugin/src/cli/sources.dart';

import 'host_platform.dart';

const _version = '2.6.0';
const _urlPrefix = 'https://downloads.sentry-cdn.com/sentry-cli/$_version';

final currentCLISources = {
  HostPlatform.darwinUniversal: CLISource(
      '$_urlPrefix/sentry-cli-Darwin-universal',
      '622822734d5933c1eb08b26ba284573587924821fa9848c3c5e8ec6cb97a93f0'),
  HostPlatform.linuxAarch64: CLISource('$_urlPrefix/sentry-cli-Linux-aarch64',
      '8cdbc148ff8a7620a45fa97dd2e25a4d56fe353583dd78c17aac3cc0978f09dc'),
  HostPlatform.linuxArmv7: CLISource('$_urlPrefix/sentry-cli-Linux-armv7',
      'fdcc026b011276f3e157cc87808130c2101945632e3561d39987718ff28b0c60'),
  HostPlatform.linux64bit: CLISource('$_urlPrefix/sentry-cli-Linux-x86_64',
      'e1ab2d6bf031e3ec632b3d336641615a65b0ffe81208e420a7f8010c2082574c'),
  HostPlatform.windows32bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-i686.exe',
      'f55cd640c7dd1928602be35c164472657645848f20a85e707dfaae56dd844d6d'),
  HostPlatform.windows64bit: CLISource(
      '$_urlPrefix/sentry-cli-Windows-x86_64.exe',
      '6027508acbeba1592a61a98e3029cb0e73b4d46280148b5c06197d1f2d2d72fa'),
};
