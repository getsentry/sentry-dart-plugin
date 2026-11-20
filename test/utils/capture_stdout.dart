import 'dart:io';

/// Runs [body] and returns everything it wrote to [stdout] (e.g. via `Log`).
Future<String> captureStdout(Future<void> Function() body) async {
  final buffer = StringBuffer();
  await IOOverrides.runZoned(body, stdout: () => _CapturedStdout(buffer));
  return buffer.toString();
}

class _CapturedStdout implements Stdout {
  _CapturedStdout(this._buffer);

  final StringBuffer _buffer;

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
