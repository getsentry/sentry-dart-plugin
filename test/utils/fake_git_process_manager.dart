import 'dart:convert';
import 'dart:io';

import 'package:process/process.dart';

/// A [ProcessManager] answering every command with [exitCode], or throwing a
/// [ProcessException] (like a missing executable) when [missing] is set.
class FakeGitProcessManager implements ProcessManager {
  FakeGitProcessManager({this.exitCode = 1, this.missing = false});

  final int exitCode;
  final bool missing;
  final commands = <String>[];

  @override
  Future<ProcessResult> run(List<Object> command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      covariant Encoding? stdoutEncoding = systemEncoding,
      covariant Encoding? stderrEncoding = systemEncoding}) async {
    commands.add(command.join(' '));
    if (missing) {
      throw ProcessException(command.first.toString(), const []);
    }
    return ProcessResult(0, exitCode, '', '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
