import 'package:flutter_test/flutter_test.dart';

import 'package:net_pulse/features/leaderboard/domain/leaderboard_models.dart';
import 'package:net_pulse/features/leaderboard/domain/provider_ranking.dart';

LeaderboardEntry result(String provider, double down, {double up = 10, double ping = 20}) =>
    LeaderboardEntry(
      id: '$provider-$down',
      nickname: 'n',
      country: 'Azerbaijan',
      provider: provider,
      downloadMbps: down,
      uploadMbps: up,
      pingMs: ping,
      measuredAt: DateTime(2026),
    );

void main() {
  test('ranks providers by the median of their results, fastest first', () {
    final stats = rankProviders([
      result('Slow ISP', 20),
      result('Fast ISP', 100),
      result('Fast ISP', 300),
      result('Fast ISP', 120),
    ]);
    expect(stats.map((s) => s.provider), ['Fast ISP', 'Slow ISP']);
    expect(stats.first.results, 3);
    expect(stats.first.downloadMbps, 120); // median of 100, 120, 300
  });

  test('one record-breaking line does not lift its provider', () {
    final stats = rankProviders([
      result('A', 50),
      result('A', 55),
      result('A', 900), // an outlier the mean would reward
      result('B', 80),
      result('B', 85),
    ]);
    expect(stats.first.provider, 'B');
  });

  test('an even count takes the middle pair', () {
    final stats = rankProviders([
      result('A', 10, ping: 30),
      result('A', 20, ping: 10),
    ]);
    expect(stats.single.downloadMbps, 15);
    expect(stats.single.pingMs, 20);
  });

  test('no results, no providers', () {
    expect(rankProviders(const []), isEmpty);
  });
}
