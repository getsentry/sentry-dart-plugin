import 'package:injector/injector.dart';

import '../configuration.dart';

/// Injector singleton instance
final injector = Injector.appInstance;

/// Register and inits the [Configuration] class as a Singleton
void initInjector() {
  injector.registerSingleton<Configuration>(() => Configuration());
}
