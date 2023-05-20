# Changelog

## Unreleased

### Features

- Stream `sentry-cli` output ([#110](https://github.com/getsentry/sentry-dart-plugin/pull/110))

### Dependencies

- Bump CLI from v2.17.5 to v2.18.0 ([#121](https://github.com/getsentry/sentry-dart-plugin/pull/121))
  - [changelog](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#2180)
  - [diff](https://github.com/getsentry/sentry-cli/compare/2.17.5...2.18.0)

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
