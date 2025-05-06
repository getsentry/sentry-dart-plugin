import 'package:sentry_dart_plugin/src/utils/parent_dir_depth.dart';
import 'package:test/test.dart';

void main() {
  group(getLeadingParentDirDepths, () {
    test('should return empty list for an empty path', () {
      final sources = [''];

      expect(getLeadingParentDirDepths(sources), []);
    });

    test('should return empty list for a path without parent directories', () {
      final sources = ['file.dart'];

      expect(getLeadingParentDirDepths(sources), []);
    });

    test('should ignore non-string sources', () {
      final sources = [123];

      expect(getLeadingParentDirDepths(sources), []);
    });

    test(
        'should return empty list for a path with non-leading parent directories',
        () {
      final sources = ['test/../file.dart'];

      expect(getLeadingParentDirDepths(sources), []);
    });

    test(
        'should return a list with n for a path with leading n parent directories',
        () {
      // Pick a random value between 1 and 10 (inclusive).
      final sources = ['../file.dart', '../../../../file2.dart'];

      expect(getLeadingParentDirDepths(sources), [1, 4]);
    });

    test('should return a unique list when there are duplicate parent depths',
        () {
      final sources = ['../../file.dart', '../../file2.dart'];

      expect(getLeadingParentDirDepths(sources), [2]);
    });
  });
}
