import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('warns when multiple flavored outputs are found without flavor',
      () async {
    final result = await Process.run(
      Platform.resolvedExecutable,
      ['run', 'test/fixtures/flutter_debug_files_warning_fixture.dart'],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
    expect(
      result.stdout as String,
      contains(
        'Multiple release directories found for native debug symbols. Consider setting `flavor` to restrict uploads to one flavor.',
      ),
    );
  });
}
