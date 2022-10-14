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
  sentry_dart_plugin: ^1.0.0-beta.1
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

Add `sentry:` configuration at the end of your `pubspec.yaml` file:

```yaml
sentry:
  upload_native_symbols: true
  upload_source_maps: false
  include_native_sources: false
  project: ...
  org: ...
  auth_token: ...
  url: ...
  wait_for_processing: false
  log_level: error # possible values: trace, debug, info, warn, error
  release: ...
  web_build_path: ...
  commits: auto
```

### Available Configuration Fields

| Configuration Name | Description | Default Value And Type | Required | Alternative Environment variable |
| - | - | - | - | - |
| upload_native_symbols | Enables or disables the automatic upload of debug symbols | true (boolean) | no | - |
| upload_source_maps | Enables or disables the automatic upload of source maps | false (boolean) | no | - |
| include_native_sources | Does or doesn't include the source code of native code | false (boolean) | no | - |
| project | Project's name | e.g. sentry-flutter (string) | yes | SENTRY_PROJECT |
| org | Organization's slug | e.g. sentry-sdks (string) | yes | SENTRY_ORG |
| auth_token | Auth Token | e.g. 64 random characteres (string)  | yes | SENTRY_AUTH_TOKEN |
| url | URL | e.g. https<area>://mysentry.invalid/ (string)  | no | SENTRY_URL |
| wait_for_processing | Wait for server-side processing of uploaded files | false (boolean)  | no | - |
| log_level | Configures the log level for sentry-cli | warn (string)  | no | SENTRY_LOG_LEVEL |
| release | The release version for source maps, it should match the release set by the SDK | default: name@version from pubspec (string)  | no | SENTRY_RELEASE |
| web_build_path | The web build folder | default: build/web (string)  | no | - |
| commits | Release commits integration | default: auto | no | - |

## Troubleshooting

Sentry's `auth_token` requires the `project:releases` or `project:write` scope, See [docs](https://docs.sentry.io/product/cli/dif/#permissions).

Dart's `--obfuscate` option is required to be paired with `--split-debug-info` to generate a symbol map, See [docs](https://github.com/flutter/flutter/wiki/Obfuscating-Dart-Code).

The `--split-debug-info` option requires setting a output directory, the directory must be an inner folder of the project's folder, See [docs](https://flutter.dev/docs/deployment/obfuscate#obfuscating-your-app).

Flutter's `build web` command requires setting the `--source-maps` parameter to generate source maps, See [Issue](https://github.com/flutter/flutter/issues/72150#issuecomment-755541599)
