# Integration test project

This is a test project which calls the plugin in that in turn calls sentry-cli and communicates with a [dummy server](integration-test-server.py).
The main goal is to check if an updated sentry-cli version would break anything, as the gh action fails if it goes down an unexpected path/endpoint that the dummy server does not implement.

Currently there is no verification, the whether the requests are actually sent and processed by the dummy server.
In other words, if a future code change to plugin makes it stop sending some information to the server, this integration would catch it.
Instead, there are unit tests in the plugin project itself that check whether it calls sentry CLI with the appropriate arguments.
Thus, depending on Sentry CLI itself being tested, we minimize the chance of a regression, while providing quick testing (through unit tests)

## Changes made

There were some changes made to this project after creating it with `flutter create`:

* added NDK support - cmakelist + native code (just called from the Android main activity) in order to generate debug symbols
* `main.dart` file was simplified to just show a simple stateless widget
* `sentry_dart_plugin` was added to pubspec with everything enabled
