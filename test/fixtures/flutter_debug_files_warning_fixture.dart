import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sentry_dart_plugin/src/configuration.dart';
import 'package:sentry_dart_plugin/src/utils/flutter_debug_files.dart';
import 'package:sentry_dart_plugin/src/utils/injector.dart';

Future<void> main() async {
  final fs = MemoryFileSystem.test();
  injector.registerSingleton<FileSystem>(() => fs, override: true);

  fs.directory('build/macos/Build/Products/Release-dev').createSync(
        recursive: true,
      );
  fs.directory('build/macos/Build/Products/Release-prod').createSync(
        recursive: true,
      );

  final config = Configuration()
    ..buildFilesFolder = 'build'
    ..flavor = null;

  await enumerateDebugSearchRoots(fs: fs, config: config).drain();
}
