# Sentry Dart Plugin

[![Sentry Dart Plugin](https://github.com/getsentry/sentry-dart-plugin/actions/workflows/dart_plugin.yml/badge.svg)](https://github.com/getsentry/sentry-dart-plugin/actions/workflows/dart_plugin.yml)
[![pub package](https://img.shields.io/pub/v/sentry_dart_plugin.svg)](https://pub.dev/packages/sentry_dart_plugin)
[![pub points](https://img.shields.io/pub/points/sentry_dart_plugin)](https://pub.dev/packages/sentry_dart_plugin/score)

A Dart Build Plugin that uploads debug symbols for Android, iOS/macOS and source maps for Web to Sentry via [sentry-cli](https://docs.sentry.io/product/cli/).

For doing it manually, please follow our [docs](https://docs.sentry.io/platforms/flutter/upload-debug/).

## :clipboard: Install

In your `pubspec.yaml`, add `sentry_dart_plugin` as a new dev dependency.

```yaml
dev_dependencies:
  sentry_dart_plugin: ^1.0.0
```

## Build App

The `flutter build apk`, `flutter build ios` (or _macos_) or `flutter build web` is required before executing the `sentry_dart_plugin` plugin, because the build spits out the debug symbols and source maps.

## Run

### Dart

```bash
dart run sentry_dart_plugin
```

### Flutter

```bash
flutter packages pub run sentry_dart_plugin
```

## Configuration (Optional)

This tool comes with a default configuration. You can configure it to suit your needs.
By default the plugin will look for the Sentry configuration in the `pubspec.yaml` file.
If the configuration doesn't exist, the plugin will look for a `sentry.properties` file.
If the `sentry.properties` file doesn't exist, the plugin will look for environment variables.

### pubspec.yaml

Add `sentry:` configuration at the end of your `pubspec.yaml` file:

```yaml
sentry:
  upload_debug_symbols: true
  upload_source_maps: false
  upload_sources: false
  project: ...
  org: ...
  auth_token: ...
  url: ...
  wait_for_processing: false
  log_level: error # possible values: trace, debug, info, warn, error
  release: ...
  dist: ...
  web_build_path: ...
  commits: auto
  ignore_missing: true
```

You can also override or extend your file based configuration by passing the parameters as arguments
in the format `--sentry-define=<KEY>=<VALUE>`. They take precedence over your file based parameters,
but not over the alternative environment variables.

```bash
flutter packages pub run sentry_dart_plugin --sentry-define=release=app-internal-test@0.0.1
```

### sentry.properties

Create a `sentry.properties` file at the root of your project:

```properties
upload_debug_symbols=true
upload_source_maps=false
upload_sources=false
project=...
org=...
auth_token=...
url=...
wait_for_processing=false
log_level=error # possible values: trace, debug, info, warn, error
release=...
dist=...
web_build_path=...
commits=auto
ignore_missing=true
```

### Available Configuration Fields

| Configuration Name | Description | Default Value And Type | Required | Alternative Environment variable |
| - | - | - | - | - |
| upload_debug_symbols | Enables or disables the automatic upload of debug symbols | true (boolean) | no | - |
| upload_source_maps | Enables or disables the automatic upload of source maps | false (boolean) | no | - |
| upload_sources | Does or doesn't include the source code of native code | false (boolean) | no | - |
| project | Project's name | e.g. sentry-flutter (string) | yes | SENTRY_PROJECT |
| org | Organization's slug | e.g. sentry-sdks (string) | yes | SENTRY_ORG |
| auth_token | Auth Token | e.g. 64 random characteres (string)  | yes | SENTRY_AUTH_TOKEN |
| url | URL | e.g. https<area>://mysentry.invalid/ (string)  | no | SENTRY_URL |
| wait_for_processing | Wait for server-side processing of uploaded files | false (boolean)  | no | - |
| log_level | Configures the log level for sentry-cli | warn (string)  | no | SENTRY_LOG_LEVEL |
| release | The release version for source maps, it should match the release set by the SDK | name@version from pubspec (string)  | no | SENTRY_RELEASE |
| dist | The dist/build number for source maps, it should match the dist set by the SDK | the number after the '+' char from 'version' pubspec (string)  | no | SENTRY_DIST |
| build_path | The build folder of debug files for upload | `.` current folder (string) | no | - |
| web_build_path | The web build folder of debug files for upload | `build/web` relative to build_path (string)  | no | - |
| commits | Release commits integration | auto (string) | no | - |
| ignore_missing | Ignore missing commits previously used in the release | false (boolean) | no | - |
| bin_dir | The folder where the plugin downloads the sentry-cli binary | .dart_tool/pub/bin/sentry_dart_plugin (string) | no | - |
| bin_path | Path to the sentry-cli binary to use instead of downloading. Make sure to use the correct version. | null (string) | no | - |
| sentry_cli_cdn_url | Alternative place to download sentry-cli | https://downloads.sentry-cdn.com/sentry-cli (string) | no | SENTRYCLI_CDNURL |
| sentry_cli_version | Override the sentry-cli version that should be downloaded. | (string) | no | - |

## Release

Per default, the release is build from pubspec.yaml's name, version & build: `name@version+build`. The build number, if present, is used as the `dist` parameter.

You can override these values by providing a `release` and `dist` through the plugin config, or through environmental values. The latter have precedence over the former.
A custom `dist` value will also be used as the build number.

If provided, the plugin will take your `release` and `dist` values without further mutating them. Make sure you configure everything as outlined in the [release docs](https://docs.sentry.io/product/cli/releases/) of `sentry-cli`.

## Troubleshooting

Sentry's `auth_token` requires the `project:releases` or `project:write` scope, See [docs](https://docs.sentry.io/product/cli/dif/#permissions).

For the `commits` feature, Sentry's `auth_token` also requires the `org:read` scope, See [docs](https://docs.sentry.io/api/permissions/#releases).

Dart's `--obfuscate` option is required to be paired with `--split-debug-info` to generate a symbol map, See [docs](https://github.com/flutter/flutter/wiki/Obfuscating-Dart-Code).

The `--split-debug-info` option requires setting a output directory, the directory must be an inner folder of the project's folder, See [docs](https://flutter.dev/docs/deployment/obfuscate#obfuscating-your-app).

Flutter's `build web` command requires setting the `--source-maps` parameter to generate source maps, See [Issue](https://github.com/flutter/flutter/issues/72150#issuecomment-755541599)

If a previous release could not be found in the git history, please make sure you set `ignore_missing: true` in the configuration if you want to ignore such errors, See [Issue](https://github.com/getsentry/sentry-dart-plugin/issues/153)
