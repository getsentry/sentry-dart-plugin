// Source partly borrowed from: https://github.com/YehudaKremer/msix/blob/main/lib/src/utils/log.dart
// MIT License

// Copyright (c) 2022 Yehuda Kremer

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'dart:io';
import 'package:ansicolor/ansicolor.dart';

int _numberOfAllTasks = 11;

class Log {
  static final _red = AnsiPen()..red(bold: true);
  static final _yellow = AnsiPen()..yellow(bold: true);
  static final _green = AnsiPen()..green(bold: true);
  static final _blue = AnsiPen()..blue(bold: true);
  static final _gray05 = AnsiPen()..gray(level: 0.5);
  static final _gray09 = AnsiPen()..gray(level: 0.9);
  static int _numberOfTasksCompleted = 0;
  static int _lastMessageLength = 0;

  /// Log with colors.
  Log();

  /// Information log with `white` color
  static void info(String message) => _write(message, withColor: _gray09);

  /// Error log with `red` color
  static void error(String message) => _write(message, withColor: _red);

  /// Warning log with `yellow` color
  static void warn(String message) => _write(message, withColor: _yellow);

  /// Success log with `green` color
  static void success(String message) => _write(message, withColor: _green);

  /// Link log with `blue` color
  static void link(String message) => _write(message, withColor: _blue);

  static void _write(String message, {required AnsiPen withColor}) {
    stdout.writeln();
    stdout.writeln(withColor(message));
  }

  static void _renderProgressBar() {
    stdout.writeCharCode(13);

    stdout.write(_gray09('['));
    var blueBars = '';
    for (var z = _numberOfTasksCompleted; z > 0; z--) {
      blueBars += '❚❚';
    }
    stdout.write(_blue(blueBars));
    var grayBars = '';
    for (var z = _numberOfAllTasks - _numberOfTasksCompleted; z > 0; z--) {
      grayBars += '❚❚';
    }
    stdout.write(_gray05(grayBars));

    stdout.write(_gray09(']'));
    stdout.write(_gray09(
        ' ${(_numberOfTasksCompleted * 100 / _numberOfAllTasks).floor()}%'));
  }

  /// Info log on a new task
  static void startingTask(String name) {
    final emptyStr = _getlastMessageemptyStringLength();
    _lastMessageLength = name.length;
    _renderProgressBar();
    stdout.write(_gray09(' $name..$emptyStr'));
  }

  /// Info log on a completed task
  static void taskCompleted(String name) {
    _numberOfTasksCompleted++;
    stdout.writeCharCode(13);
    stdout.write(_green('☑ '));
    stdout.writeln(
        '$name                                                             ');
    if (_numberOfTasksCompleted >= _numberOfAllTasks) {
      final emptyStr = _getlastMessageemptyStringLength();
      _renderProgressBar();
      stdout.writeln(emptyStr);
    }
  }

  static String _getlastMessageemptyStringLength() {
    var emptyStr = '';
    for (var i = 0; i < _lastMessageLength + 8; i++) {
      emptyStr += ' ';
    }
    return emptyStr;
  }

  /// Logs the Process exitCode depending if it's an error
  static void processExitCode(int exitCode) {
    if (exitCode != 0) {
      Log.error('exitCode: $exitCode');
      throw ExitError(exitCode);
    }
  }
}

// Thrown instead of exit() for testability.
class ExitError {
  final int code;

  ExitError(this.code);
}
