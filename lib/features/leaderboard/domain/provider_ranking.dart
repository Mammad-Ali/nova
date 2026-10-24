import 'leaderboard_models.dart';

/// How one provider's users do, summarised.
class ProviderStat {
  const ProviderStat({
    required this.provider,
    required this.results,
    required this.downloadMbps,
    required this.uploadMbps,
    required this.pingMs,
  });

  final String provider;

  /// How many people's best results the figures are drawn from.
  final int results;
  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;
}

/// Ranks providers by the median of their users' best results, fastest
/// download first.
///
/// Median rather than mean: one record-breaking fibre line should not lift a
/// whole provider, and one user on bad Wi-Fi should not sink it.
List<ProviderStat> rankProviders(Iterable<LeaderboardEntry> entries) {
  final byProvider = <String, List<LeaderboardEntry>>{};
  for (final e in entries) {
    byProvider.putIfAbsent(e.provider, () => []).add(e);
  }

  final stats = [
    for (final group in byProvider.entries)
      ProviderStat(
        provider: group.key,
        results: group.value.length,
        downloadMbps: _median(group.value.map((e) => e.downloadMbps)),
        uploadMbps: _median(group.value.map((e) => e.uploadMbps)),
        pingMs: _median(group.value.map((e) => e.pingMs)),
      ),
  ];
  stats.sort((a, b) => b.downloadMbps.compareTo(a.downloadMbps));
  return stats;
}

double _median(Iterable<double> values) {
  final sorted = values.toList()..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}
