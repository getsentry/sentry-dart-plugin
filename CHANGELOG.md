# Changelog

## Unreleased

### Dependencies

- Bump CLI from v2.52.0 to v3.1.0 ([#354](https://github.com/getsentry/sentry-dart-plugin/pull/354))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#310)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.52.0...3.1.0)

## 3.2.1

### Fixes

- Log level not respected when configured via env variables ([#370](https://github.com/getsentry/sentry-dart-plugin/pull/370))

## 3.2.0

### Features

- Upload Dart symbol mapping file ([#347](https://github.com/getsentry/sentry-dart-plugin/pull/347))
    - Enables symbolication of Flutter issue titles for obfuscated builds.
    - Supported: Android and iOS
    - Not supported (yet): macOS, Linux and Windows.
    - Generate the mapping file: Add `--extra-gen-snapshot-options=--save-obfuscation-map=<path>` when building. Example: `flutter build apk --obfuscate --split-debug-info=build/symbols --extra-gen-snapshot-options=--save-obfuscation-map=build/mapping.json`
    - Configure the plugin: Set `dart_symbol_map_path: build/mapping.json`
    - Important: `dart_symbol_map_path` must point directly to the mapping file (absolute or relative path), not a directory.

## 3.2.0-beta.1

### Features

- Upload Dart symbol mapping file ([#347](https://github.com/getsentry/sentry-dart-plugin/pull/347))
    - Enables symbolication of Flutter issue titles for obfuscated builds.
    - Supported: Android and iOS
    - Not supported (yet): macOS, Linux and Windows.
    - Generate the mapping file: Add `--extra-gen-snapshot-options=--save-obfuscation-map=<path>` when building. Example: `flutter build apk --obfuscate --split-debug-info=build/symbols --extra-gen-snapshot-options=--save-obfuscation-map=build/mapping.json`
    - Configure the plugin: Set `dart_symbol_map_path: build/mapping.json`
    - Important: `dart_symbol_map_path` must point directly to the mapping file (absolute or relative path), not a directory.

## 3.1.1

### Fixes

- Add additional path to check for iOS debug symbols ([#342](https://github.com/getsentry/sentry-dart-plugin/pull/342))

## 3.1.0

### Features

- Add release and dist to sourcemaps upload command ([#333](https://github.com/getsentry/sentry-dart-plugin/pull/333))
  - This enables the uploaded bundle to be associated with the release for informational purposes

### Fixes

- Should not exit program when web build path is not found ([#337](https://github.com/getsentry/sentry-dart-plugin/pull/337))

## 3.0.0

Version 3.0.0 marks a major release of the Sentry Dart Plugin containing breaking changes for Flutter Web.

### Breaking Changes

1. Automatic Debug-ID Injection
   - **What’s new:** By default, the plugin now embeds [Debug IDs](https://docs.sentry.io/platforms/javascript/sourcemaps/troubleshooting_js/debug-ids/) into your generated source maps.
   - **Why it matters:** Debug IDs make symbolication of Flutter Web stack traces far more stable and reliable.
2. **Minimum Flutter SDK Requirement**
   - The Debug-ID feature **only works** with **Sentry Flutter SDK 9.1.0 or newer**.
   - If you’re on **9.0.0** (or below), you **won’t** get Debug IDs automatically.
3. **Legacy Symbolication Mode**
   - If you **cannot upgrade** to Flutter SDK ≥ 9.1.0 **yet**, add this flag to your Sentry Dart Plugin config:
       ```yaml
       sentry:
         dart_plugin:
           legacy_web_symbolication: true
       ```
     * This switches back to the “classic” source-map symbolication method you’ve been using.

### Features

- Support injecting debug ids for Flutter Web ([#319](https://github.com/getsentry/sentry-dart-plugin/pull/319))
  - Debug id loading will be the default symbolication in v3
  - We have added the new field `legacy_web_symbolication` which you can set to `true` if you want to keep using the old symbolication. It is set to `false` by default.

### Enhancements

- Improve Flutter Web stacktraces by stripping verbose source prefixes ([#320](https://github.com/getsentry/sentry-dart-plugin/pull/320))
  - This is only applied if you use the debug id symbolication which is enabled by default.
  - This will not work with the legacy web symbolication.

## 2.4.1

### Fixes

- Add missing prefix to source file upload ([#306](https://github.com/getsentry/sentry-dart-plugin/pull/306))

## 2.4.0

### Enhancements

- Merge `pubspec.yaml` and `sentry.properties` values ([#295](https://github.com/getsentry/sentry-dart-plugin/pull/295))

### Dependencies

- Bump CLI from v2.39.1 to v2.41.1 ([#290](https://github.com/getsentry/sentry-dart-plugin/pull/290))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2411)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.39.1...2.41.1)

## 2.3.0

### Features

- Support flavors in iOS symbol upload ([#292](https://github.com/getsentry/sentry-dart-plugin/pull/292))

### Dependencies

- Bump CLI from v2.38.1 to v2.39.1 ([#282](https://github.com/getsentry/sentry-dart-plugin/pull/282))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2391)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.38.1...2.39.1)

## 2.2.1

### Fixes

- Dart source context on web missing ([#285](https://github.com/getsentry/sentry-dart-plugin/pull/285))

## 2.2.0

### Changes

- Upload debug symbols for known release build paths and the configured `symbols_path` ([#277](https://github.com/getsentry/sentry-dart-plugin/pull/277))
  Previously, all debug symbols recognized by Sentry CLI were uploaded (starting in the current directory by default).
  Now, the plugin checks the paths where `flutter build` outputs debug symbols for release builds and only uploads those.

### Features

- Add urlPrefix to sentry configuration ([#253](https://github.com/getsentry/sentry-dart-plugin/pull/253))

### Fixes

- Only upload `.dart` files with `upload-sourcemaps` when `upload_sources` is enabled ([#247](https://github.com/getsentry/sentry-dart-plugin/pull/247))
  - Enable `upload_sources` to opt in to Flutter web source context

### Dependencies

- Bump CLI from v2.27.0 to v2.38.1 ([#273](https://github.com/getsentry/sentry-dart-plugin/pull/273))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2381)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.27.0...2.38.1)

## 2.1.0

### Features

- Add support for build files folder parameter ([#235](https://github.com/getsentry/sentry-dart-plugin/pull/235))
- Support SENTRYCLI_CDNURL env ([#230](https://github.com/getsentry/sentry-dart-plugin/pull/230))
- Add `sentry_cli_version` parameter ([#243](https://github.com/getsentry/sentry-dart-plugin/pull/243))

### Fixes

- Revert sentry-cli to v2.27.0 ([#241](https://github.com/getsentry/sentry-dart-plugin/pull/241))

## 2.0.0

### Breaking Changes

- Update env/config `release` and `dist` behaviour ([#217](https://github.com/getsentry/sentry-dart-plugin/pull/217))
  - Default release: automatically constructs the release identifier from pubspec.yaml using the format: `name@version`.
    If a build number is included in the version, it is utilized as dist.
  - Custom release can be specified via an environment variable or plugin configuration. Once set, it is used as is without further modification.
  - Custom dist can also be set via environment variables or plugin configuration. It replaces or adds to the build number in the default release.
  - Environment variables: `SENTRY_RELEASE` and `SENTRY_DIST `environment variables take precedence over plugin config values.

### Features

- Custom `dist` overrides version build number ([#216](https://github.com/getsentry/sentry-dart-plugin/pull/216))
  - For instance, if the initial release version is `release@1.0.0+1`, specifying a custom dist value of 2 will update the version to `release@1.0.0+2`.
- Add option to provide alternative binary directory ([#214](https://github.com/getsentry/sentry-dart-plugin/pull/214))
- Support configuration arguments via `--sentry-define` ([#198](https://github.com/getsentry/sentry-dart-plugin/pull/198))
- Provide path to local `sentry-cli` ([#224](https://github.com/getsentry/sentry-dart-plugin/pull/224))

### Dependencies

- Bump CLI from v2.27.0 to v2.31.0 ([#219](https://github.com/getsentry/sentry-dart-plugin/pull/219))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2310)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.27.0...2.31.0)

## 1.7.1

### Fixes

- Updated the `process` dependency range to `>=4.2.4 <6.0.0` ([#202](https://github.com/getsentry/sentry-dart-plugin/pull/202)).
  - This update resolves a version conflict issue when using the `integration_test` package with Flutter version `3.19.0`

## 1.7.0

### Features

- Support reading config from sentry.properties file ([#191](https://github.com/getsentry/sentry-dart-plugin/pull/191))

### Dependencies

- Bump CLI from v2.21.2 to v2.27.0 ([#180](https://github.com/getsentry/sentry-dart-plugin/pull/180), [#195](https://github.com/getsentry/sentry-dart-plugin/pull/195), [#196](https://github.com/getsentry/sentry-dart-plugin/pull/196))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2270)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.21.2...2.27.0)

## 1.6.3

### Fixes

- Fixes org auth tokens with no URL not supported by bumping CLI to v2.21.2 ([#169](https://github.com/getsentry/sentry-dart-plugin/pull/169))

### Dependencies

- Bump CLI from v2.20.6 to v2.21.2 ([#169](https://github.com/getsentry/sentry-dart-plugin/pull/169))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2212)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.20.6...2.21.2)

## 1.6.2

### Dependencies

- Revert [process](https://github.com/google/process.dart) from 5.0.0 to 4.2.4 ([#160](https://github.com/getsentry/sentry-dart-plugin/pull/160))

## 1.6.0

### Dependencies

- Bumps [process](https://github.com/google/process.dart) from 4.2.4 to 5.0.0.
  - [Release notes](https://github.com/google/process.dart/releases)
  - [Changelog](https://github.com/google/process.dart/blob/master/CHANGELOG.md)
  - [Commits](https://github.com/google/process.dart/commits)
- Bump CLI from v2.19.4 to v2.20.6 ([#152](https://github.com/getsentry/sentry-dart-plugin/pull/152))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2206)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.19.4...2.20.6)

## 1.5.0

### Fixes

- Support custom `dist` and `release` has precedence over the pubspec's `name` ([#139](https://github.com/getsentry/sentry-dart-plugin/pull/139))

### Dependencies

- Bump CLI from v2.19.1 to v2.19.4 ([#133](https://github.com/getsentry/sentry-dart-plugin/pull/133))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2194)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.19.1...2.19.4)

## 1.4.0

### Enhancements

- Replace `upload-dif` to `debug-files upload` ([#127](https://github.com/getsentry/sentry-dart-plugin/pull/127))

### Dependencies

- Bump CLI from v2.17.5 to v2.19.1 ([#123](https://github.com/getsentry/sentry-dart-plugin/pull/123), [#130](https://github.com/getsentry/sentry-dart-plugin/pull/130))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2191)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.17.5...2.19.1)

## 1.3.0

### Features

- Stream `sentry-cli` output ([#110](https://github.com/getsentry/sentry-dart-plugin/pull/110))
- Support `http` >= v1, `system_info2` >= v4, `file` >= v7 ([#125](https://github.com/getsentry/sentry-dart-plugin/pull/125))

## 1.2.0

### Features

- Dart v3 support ([#112](https://github.com/getsentry/sentry-dart/pull/112))

### Breaking Changes

- Bump Dart min to 2.17.0 ([#112](https://github.com/getsentry/sentry-dart/pull/112))

### Dependencies

* Bump CLI from v2.13.0 to v2.17.5 ([#86](https://github.com/getsentry/sentry-dart-plugin/pull/86), [#89](https://github.com/getsentry/sentry-dart-plugin/pull/89), [#90](https://github.com/getsentry/sentry-dart-plugin/pull/90), [#101](https://github.com/getsentry/sentry-dart-plugin/pull/101), [#103](https://github.com/getsentry/sentry-dart-plugin/pull/103), [#107](https://github.com/getsentry/sentry-dart-plugin/pull/107), [#114](https://github.com/getsentry/sentry-dart-plugin/pull/114))
  * [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2175)
  * [diff](https://github.com/getsentry/sentry-cli/compare/2.13.0...2.17.5)

## 1.1.0

### Features

* Add configuration `ignore_missing` ([#85](https://github.com/getsentry/sentry-dart-plugin/pull/85))

## 1.0.0

### Dependencies

* Bump CLI from v2.12.0 to v2.13.0 ([#80](https://github.com/getsentry/sentry-dart-plugin/pull/80))
  * [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2130)
  * [diff](https://github.com/getsentry/sentry-cli/compare/2.12.0...2.13.0)

## 1.0.0-RC.1

### Changes

* Rename configuration `include_native_sources` to `upload_sources` ([#78](https://github.com/getsentry/sentry-dart-plugin/pull/78))
* Rename configuration `upload_native_symbols` to `upload_debug_symbols` ([#78](https://github.com/getsentry/sentry-dart-plugin/pull/78))

### Dependencies

* Bump CLI from v2.11.0 to v2.12.0 ([#79](https://github.com/getsentry/sentry-dart-plugin/pull/79))
  * [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2120)
  * [diff](https://github.com/getsentry/sentry-cli/compare/2.11.0...2.12.0)

## 1.0.0-beta.5

### Dependencies

* Bump CLI from v2.7.0 to v2.11.0 ([#65](https://github.com/getsentry/sentry-dart-plugin/pull/65), [#67](https://github.com/getsentry/sentry-dart-plugin/pull/67), [#69](https://github.com/getsentry/sentry-dart-plugin/pull/69), [#72](https://github.com/getsentry/sentry-dart-plugin/pull/72), [#74](https://github.com/getsentry/sentry-dart-plugin/pull/74))
  * [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2110)
  * [diff](https://github.com/getsentry/sentry-cli/compare/2.7.0...2.11.0)
* Bump system_info2 to ^3.0.1 ([#77](https://github.com/getsentry/sentry-dart-plugin/pull/77))

## 1.0.0-beta.4

### Features

* Support release commits ([#62](https://github.com/getsentry/sentry-dart-plugin/pull/62))

## 1.0.0-beta.3

### Features

* Add support to load release variable from environment ([#40](https://github.com/getsentry/sentry-dart-plugin/pull/40))
* Download Sentry CLI on first run ([#49](https://github.com/getsentry/sentry-dart-plugin/pull/49))

### Dependencies

* Bump CLI from v2.6.0 to v2.7.0 ([#57](https://github.com/getsentry/sentry-dart-plugin/pull/57))
  * [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#270)
  * [diff](https://github.com/getsentry/sentry-cli/compare/2.6.0...2.7.0)

## 1.0.0-beta.2

### Fixes

* Early exit when providing lower log level ([#31](https://github.com/getsentry/sentry-dart-plugin/pull/31))

## 1.0.0-beta.1

### Features

* Ability to configure url for on-premise server ([#17](https://github.com/getsentry/sentry-dart-plugin/pull/17))

## 1.0.0-alpha.4

### Fixes

* Log real exitCode, stdout and stdout if available ([#13](https://github.com/getsentry/sentry-dart-plugin/pull/13))

## 1.0.0-alpha.3

### Dependencies

* Bump sentry-cli 1.69.1 which includes a fix for Dart debug symbols ([#8](https://github.com/getsentry/sentry-dart-plugin/pull/8))

## 1.0.0-alpha.2

### Fixes

* Add org and project when creating releases ([#2](https://github.com/getsentry/sentry-dart-plugin/pull/2))

## 1.0.0-alpha.1

### Features

* Sentry Dart Plugin
