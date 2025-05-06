/// Returns a list with the distinct number of leading "../" segments
/// (parent-directory traversals) that appear at the **beginning** of each
/// path provided.
///
/// Only the prefix of the path is examined.
/// Occurrences of "../" that appear later in the string are ignored.
///
/// For example:
///   * "../../bar/baz.dart"    → 2 (included)
///   * "lib/src/../foo.dart"   → 0 (ignored; "../" is not at the start)
///   * "baz.dart"              → 0 (ignored)
///
/// The function therefore returns a list with the unique counts of leading
/// traversals across all `sources`.
///
/// `sources`  A list of path strings that may include one or more
///            parent-directory segments.
///
/// Returns a list of the **distinct** counts of leading `"../"` occurrences
/// found across all `sources`.
///
/// The order of the returned list is unspecified.
List<int> getLeadingParentDirDepths(List<dynamic> sources) {
  final uniqueCounts = <int>{};
  final pattern = RegExp(r'^(?:\.\./)+');
  for (final entry in sources) {
    if (entry is! String) {
      continue;
    }
    final match = pattern.firstMatch(entry);
    if (match != null) {
      final prefix = match.group(0)!;
      // Each "../" segment is 3 characters long.
      final matchCount = prefix.length ~/ 3;
      uniqueCounts.add(matchCount);
    }
  }
  return uniqueCounts.toList();
}
