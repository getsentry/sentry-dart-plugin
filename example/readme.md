# Example of the 'pubspec.yaml' file

```yaml
name: sentry_example
description: Demonstrates how to use the sentry_dart_plugin plugin.
version: 0.1.2+3

publish_to: 'none'

environment:
  sdk: '>=2.12.0 <3.0.0'
  flutter: '>=2.0.0'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  sentry_dart_plugin: ^1.0.0-beta.1

sentry:
  # enabled by default
  #upload_native_symbols: true
  # disabled by default
  include_native_sources: true
  # disabled by default
  upload_source_maps: true
  project: sentry-flutter
  org: sentry-sdks

  # set by env. var. SENTRY_AUTH_TOKEN
  #auth_token:

  # disabled by default
  wait_for_processing: true

  # default 'warning'
  log_level: error

  # default to build/web
  #web_build_path: ...

  # default to name@version from pubspec
  #release: ...
  ```
  
