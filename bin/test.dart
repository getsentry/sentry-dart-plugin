import 'dart:convert';
import 'dart:io';

import 'package:sentry_dart_plugin/src/utils/parent_dir_depth.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run bin/test.dart <path_to_sourcemap>');
    return;
  }

  final mapPath = args.first;
  final file = File(mapPath);
  if (!await file.exists()) {
    stderr.writeln('File not found: $mapPath');
    exitCode = 1;
    return;
  }

  late final Map<String, dynamic> sourceMap;
  try {
    final content = await file.readAsString();
    sourceMap = jsonDecode(content) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('Failed to read or parse source map $mapPath: $e');
    exitCode = 1;
    return;
  }

  final sources = sourceMap['sources'];
  if (sources is! List) {
    stderr.writeln('No valid "sources" array found in the map.');
    exitCode = 1;
    return;
  }

  final uniqueCounts = getLeadingParentDirDepths(sources);

  if (uniqueCounts.isEmpty) {
    print('No "../" occurrences found within the sources.');
  } else {
    final counts = uniqueCounts.toList()..sort();
    print('Unique "../" counts in sources: ${counts.join(', ')}');
  }
}
