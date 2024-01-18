# Changelog

## Unreleased

### Features

- Support reading config from sentry.properties file ([#191](https://github.com/getsentry/sentry-dart-plugin/pull/191))

### Dependencies

- Bump CLI from v2.21.2 to v2.22.3 ([#180](https://github.com/getsentry/sentry-dart-plugin/pull/180))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2223)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.21.2...2.22.3)

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
