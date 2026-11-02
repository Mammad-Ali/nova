import 'dart:convert';

import 'package:http/http.dart' as http;

/// GitHub's description of the newest published release — drafts and
/// pre-releases are never "latest".
const kLatestReleaseApi =
    'https://api.github.com/repos/Mammad-Ali/nova/releases/latest';

/// A release on GitHub that is newer than the running build.
class AvailableUpdate {
  const AvailableUpdate({required this.version, required this.pageUrl});

  /// "1.3.1" — the tag without its "v".
  final String version;

  /// The release page, with its notes.
  final String pageUrl;
}

/// "v1.3.0" or "1.3.0+4" → [1, 3, 0]; null when it isn't a version number.
List<int>? parseVersion(String text) {
  var core = text.trim();
  if (core.startsWith('v') || core.startsWith('V')) core = core.substring(1);
  // Build numbers and pre-release tags don't decide which version is newer.
  core = core.split(RegExp(r'[+\-]')).first;
  final parts = core.split('.');
  if (parts.isEmpty || parts.length > 4) return null;
  final numbers = parts.map(int.tryParse).toList();
  if (numbers.any((n) => n == null || n < 0)) return null;
  return [for (final n in numbers) n!];
}

/// Whether [candidate] is a later version than [current]. Anything that
/// doesn't parse is never newer, so a malformed tag can't nag anyone.
bool isNewerVersion(String candidate, String current) {
  final a = parseVersion(candidate);
  final b = parseVersion(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 4; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// The newest release when it is newer than [current], otherwise null.
/// Throws on network trouble; the caller just tries again later.
Future<AvailableUpdate?> fetchUpdate(String current) async {
  final response = await http.get(
    Uri.parse(kLatestReleaseApi),
    headers: const {'Accept': 'application/vnd.github+json'},
  ).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) return null;

  final release = jsonDecode(response.body) as Map<String, dynamic>;
  final tag = release['tag_name'] as String?;
  if (tag == null || !isNewerVersion(tag, current)) return null;
  return AvailableUpdate(
    version: tag.startsWith('v') ? tag.substring(1) : tag,
    pageUrl: release['html_url'] as String? ??
        'https://github.com/Mammad-Ali/nova/releases/latest',
  );
}
