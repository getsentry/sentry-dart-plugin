import 'package:file/file.dart';

/// Checks if the given String == null
extension StringValidations on String? {
  bool get isNull => this == null;
}

extension DirectorySearch on Directory {
  Stream<FileSystemEntity> find(RegExp regexp) async* {
    await for (final entity in list(recursive: true)) {
      if (regexp.hasMatch(entity.path)) {
        yield entity;
      }
    }
  }
}
