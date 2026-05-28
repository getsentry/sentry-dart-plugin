# Contributing to sentry-dart-plugin

We love pull requests from everyone. 
We suggest opening an issue to discuss bigger changes before investing on a big PR.

# Pull Requests

If a PR should notify a linked issue after release, use a GitHub closing keyword in the PR
description, such as `Fixes #123`, `Closes #123`, or `Resolves #123`. Release notification
automation only comments on issues GitHub recognizes as closed by the released PR; mentioning an
issue without a closing keyword is not enough.

# Requirements

The project currently requires you run Dart version >= `2.12.0`.

# Run

To build:

```shell
dart compile aot-snapshot bin/sentry_dart_plugin.dart
```

To run:

```shell
dart run

// or

dartaotruntime bin/sentry_dart_plugin.aot
```

# CI

Build is automatically run against branches and pull requests via GH Actions.
