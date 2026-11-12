/// A data centre where online games run. Game servers themselves don't
/// answer pings, so Nova times Amazon's endpoint in the same city — the
/// same distance, near enough.
class GameRegion {
  const GameRegion(this.id, this.awsRegion, this.games);

  /// Names the city in the strings: "frankfurt" → gamingCityFrankfurt.
  final String id;
  final String awsRegion;

  /// Games known to have servers there; empty when Nova isn't sure.
  final List<String> games;

  String get url => 'https://dynamodb.$awsRegion.amazonaws.com/ping';
}

/// Closest to Nova's users first. Bahrain, the Middle East's usual gaming
/// region, is left out: Amazon keeps it closed to anyone who hasn't opted
/// in, so it can't be timed.
const gameRegions = [
  GameRegion('frankfurt', 'eu-central-1', ['CS2', 'Valorant', 'Fortnite']),
  GameRegion('stockholm', 'eu-north-1', ['CS2', 'Valorant']),
  GameRegion('london', 'eu-west-2', ['Valorant', 'Fortnite']),
  GameRegion('paris', 'eu-west-3', ['Valorant']),
  GameRegion('telAviv', 'il-central-1', []),
  GameRegion('uae', 'me-central-1', ['CS2']),
  GameRegion('mumbai', 'ap-south-1', ['CS2', 'Valorant']),
];

class RegionResult {
  const RegionResult({required this.pingMs, required this.jitterMs, required this.lossPercent});

  /// Median round trip; null when nothing came back.
  final double? pingMs;

  /// Average jump between consecutive round trips.
  final double? jitterMs;
  final double lossPercent;

  /// From the samples of one run, in the order taken; null for lost ones.
  factory RegionResult.from(List<double?> samples) {
    final got = [for (final s in samples) ?s];
    final loss = samples.isEmpty ? 100.0 : (samples.length - got.length) * 100 / samples.length;
    if (got.isEmpty) return RegionResult(pingMs: null, jitterMs: null, lossPercent: loss);
    final sorted = [...got]..sort();
    var jumps = 0.0;
    for (var i = 1; i < got.length; i++) {
      jumps += (got[i] - got[i - 1]).abs();
    }
    return RegionResult(
      pingMs: sorted[sorted.length ~/ 2],
      jitterMs: got.length < 2 ? 0 : jumps / (got.length - 1),
      lossPercent: loss,
    );
  }

  GamingVerdict get verdict {
    final ping = pingMs;
    if (ping == null || lossPercent >= 30) return GamingVerdict.lost;
    final jitter = jitterMs ?? 0;
    if (ping <= 50 && jitter <= 10 && lossPercent < 5) return GamingVerdict.great;
    if (ping <= 90 && jitter <= 20 && lossPercent < 10) return GamingVerdict.good;
    if (ping <= 150) return GamingVerdict.slow;
    return GamingVerdict.far;
  }
}

enum GamingVerdict {
  /// Fast shooters feel right.
  great,

  /// Most games, and shooters with a little lag.
  good,

  /// Strategy and slower games; shooters suffer.
  slow,

  /// Too far for anything fast.
  far,

  /// Nothing came back.
  lost,
}
