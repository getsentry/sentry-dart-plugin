@TestOn('!windows')
library bump_version_test;

import 'dart:io';

import 'package:test/test.dart';

/// Tests for scripts/bump-version.sh, which craft runs as the pre-release
/// command after it has written the new version's CHANGELOG.md section.
void main() {
  const note = '> [!IMPORTANT]\n> Read this before upgrading.\n';
  const changelog = '# Changelog\n'
      '\n'
      '## 3.6.0\n'
      '\n'
      '### Fixes\n'
      '\n'
      '- A fix\n'
      '\n'
      '## 3.5.0\n'
      '\n'
      '### Features\n'
      '\n'
      '- A feature\n';

  late Directory repo;

  File file(String path) => File('${repo.path}/$path');
  File noteFile() => file('.github/release-note.md');
  File changelogFile() => file('CHANGELOG.md');

  Future<ProcessResult> bump(String oldVersion, String newVersion) =>
      Process.run(
        'bash',
        ['scripts/bump-version.sh', oldVersion, newVersion],
        workingDirectory: repo.path,
      );

  setUp(() async {
    repo = await Directory.systemTemp.createTemp('bump_version_test');
    await Directory('${repo.path}/scripts').create();
    await Directory('${repo.path}/.github').create();
    await File('scripts/bump-version.sh')
        .copy('${repo.path}/scripts/bump-version.sh');
    await file('pubspec.yaml').writeAsString('name: x\nversion: 3.5.0\n');
    await changelogFile().writeAsString(changelog);
  });

  tearDown(() => repo.delete(recursive: true));

  test('bumps the pubspec version', () async {
    final result = await bump('3.5.0', '3.6.0');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
        file('pubspec.yaml').readAsStringSync(), 'name: x\nversion: 3.6.0\n');
  });

  test('without a release note, leaves CHANGELOG.md unchanged', () async {
    final result = await bump('3.5.0', '3.6.0');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(changelogFile().readAsStringSync(), changelog);
    expect(file('CHANGELOG.md.tmp').existsSync(), isFalse);
  });

  test('with an empty release note, leaves CHANGELOG.md unchanged', () async {
    await noteFile().writeAsString('');

    final result = await bump('3.5.0', '3.6.0');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(changelogFile().readAsStringSync(), changelog);
  });

  test('inserts the release note under the new version and deletes it',
      () async {
    await noteFile().writeAsString(note);

    final result = await bump('3.5.0', '3.6.0');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      changelogFile().readAsStringSync(),
      '# Changelog\n'
      '\n'
      '## 3.6.0\n'
      '\n'
      '> [!IMPORTANT]\n'
      '> Read this before upgrading.\n'
      '\n'
      '### Fixes\n'
      '\n'
      '- A fix\n'
      '\n'
      '## 3.5.0\n'
      '\n'
      '### Features\n'
      '\n'
      '- A feature\n',
    );
    expect(noteFile().existsSync(), isFalse);
    expect(file('CHANGELOG.md.tmp').existsSync(), isFalse);
  });

  test('keeps a multi-paragraph release note intact', () async {
    const multi = '> [!IMPORTANT]\n> First.\n\n> [!WARNING]\n> Second.\n';
    await noteFile().writeAsString(multi);

    final result = await bump('3.5.0', '3.6.0');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(changelogFile().readAsStringSync(),
        contains('## 3.6.0\n\n$multi\n### Fixes\n'));
  });

  test('only matches the exact version heading', () async {
    await changelogFile().writeAsString('# Changelog\n'
        '\n'
        '## 3.6.10\n'
        '\n'
        '- Newer\n'
        '\n'
        '## 3.6.1\n'
        '\n'
        '- Target\n');
    await noteFile().writeAsString(note);

    final result = await bump('3.6.0', '3.6.1');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      changelogFile().readAsStringSync(),
      '# Changelog\n'
      '\n'
      '## 3.6.10\n'
      '\n'
      '- Newer\n'
      '\n'
      '## 3.6.1\n'
      '\n'
      '> [!IMPORTANT]\n'
      '> Read this before upgrading.\n'
      '\n'
      '- Target\n',
    );
  });

  test('fails and keeps the release note when the heading is missing',
      () async {
    await noteFile().writeAsString(note);

    final result = await bump('3.6.0', '3.7.0');

    expect(result.exitCode, 1);
    expect(result.stderr, contains("Could not find '## 3.7.0'"));
    expect(changelogFile().readAsStringSync(), changelog);
    expect(noteFile().readAsStringSync(), note);
    expect(file('CHANGELOG.md.tmp').existsSync(), isFalse);
  });
}
