#!/usr/bin/env bash
set -euo pipefail

cd $(dirname "$0")/../

file='lib/src/cli/_sources.dart'

case $1 in
get-version)
    content=$(cat $file)
    regex="const _version *= *'([0-9\.]+)'"
    if ! [[ $content =~ $regex ]]; then
        echo "Failed to find the current Sentry CLI version in $file"
        exit 1
    fi
    echo ${BASH_REMATCH[1]}
    ;;
get-repo)
    echo "https://github.com/getsentry/sentry-cli"
    ;;
set-version)
    newVersion=$2
    conf=$(curl -s https://raw.githubusercontent.com/getsentry/sentry-release-registry/master/apps/sentry-cli/$newVersion.json)
    echo "Downloaded configuration for v$newVersion:"
    # echo $conf | jq .

    hashFor() {
        echo $conf | jq '.files["sentry-cli-'$1'"].checksums["sha256-hex"]' -r
    }

    echo "Updating $file"
    cat >$file <<EOF
// FILE GENERATED BY scripts/update-cli.sh - DO NOT MODIFY BY HAND

import 'package:sentry_dart_plugin/src/cli/sources.dart';

import 'host_platform.dart';

const _version = '$newVersion';
const _urlPrefix = 'https://downloads.sentry-cdn.com/sentry-cli/';

final currentCLISources = {
  HostPlatform.darwinUniversal: CLISource(
    _urlPrefix,
    'sentry-cli-Darwin-universal',
    _version,
    '$(hashFor Darwin-universal)',
  ),
  HostPlatform.linuxAarch64: CLISource(
    _urlPrefix,
    'sentry-cli-Linux-aarch64',
    _version,
    '$(hashFor Linux-aarch64)',
  ),
  HostPlatform.linuxArmv7: CLISource(
    _urlPrefix,
    'sentry-cli-Linux-armv7',
    _version,
    '$(hashFor Linux-armv7)'),
  HostPlatform.linux64bit: CLISource(
    _urlPrefix,
    'sentry-cli-Linux-x86_64',
    _version,
    '$(hashFor Linux-x86_64)',
  ),
  HostPlatform.windows32bit: CLISource(
    _urlPrefix,
    'sentry-cli-Windows-i686.exe',
    _version,
    '$(hashFor Windows-i686.exe)',
  ),
  HostPlatform.windows64bit: CLISource(
    _urlPrefix,
    'sentry-cli-Windows-x86_64.exe',
    _version,
    '$(hashFor Windows-x86_64.exe)',
  ),
};
EOF
    ;;
*)
    echo "Unknown argument $1"
    exit 1
    ;;
esac
