# Sentry Dart Plugin

[![Sentry Dart Plugin](https://github.com/getsentry/sentry-dart-plugin/actions/workflows/dart_plugin.yml/badge.svg)](https://github.com/getsentry/sentry-dart-plugin/actions/workflows/dart_plugin.yml)
[![pub package](https://img.shields.io/pub/v/sentry_dart_plugin.svg)](https://pub.dev/packages/sentry_dart_plugin)
[![pub points](https://img.shields.io/pub/points/sentry_dart_plugin)](https://pub.dev/packages/sentry_dart_plugin/score)

A Dart Build Plugin that uploads debug symbols for Android, iOS/macOS and source maps for Web to Sentry via [sentry-cli](https://docs.sentry.io/product/cli/).

## Installation and Usage

Please refer to [Sentry Dart Plugin's documentation page](https://docs.sentry.io/platforms/dart/guides/flutter/debug-symbols/).

## Custom sentry-cli binary

Set `SENTRY_CLI_BIN_PATH=/path/to/sentry-cli` to use a pre-installed
`sentry-cli` binary instead of downloading one.

The `bin_path` setting in `pubspec.yaml` remains supported for backwards
compatibility, but it is an arbitrary executable override. Only use it with
trusted project configuration.
