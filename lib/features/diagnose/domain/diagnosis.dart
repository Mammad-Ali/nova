/// The links between this device and the internet, checked in this order —
/// from the home outwards.
enum DiagnosisStep { wifi, router, dns, internet }

/// How one link did. [skipped] means it doesn't apply (no Wi-Fi on a cable)
/// or couldn't be measured (the router hides from probes).
enum LinkHealth { good, fair, bad, skipped }

/// What one step found. Only the fields of its own step are set.
class LinkFinding {
  const LinkFinding({
    required this.health,
    this.rssi,
    this.address,
    this.latencyMs,
    this.lossPercent,
  });

  final LinkHealth health;

  /// Wi-Fi signal in dBm.
  final int? rssi;

  /// The router's address.
  final String? address;

  final double? latencyMs;
  final double? lossPercent;

  /// Everything was lost: the link is down, not merely slow.
  bool get unreachable => lossPercent != null && lossPercent! >= 100;
}

/// Wi-Fi signal: −67 dBm is what voice and video need; below −75 most
/// connections start dropping.
LinkFinding judgeWifi(int? rssi) => LinkFinding(
      rssi: rssi,
      health: rssi == null
          ? LinkHealth.skipped
          : rssi >= -67
              ? LinkHealth.good
              : rssi >= -75
                  ? LinkHealth.fair
                  : LinkHealth.bad,
    );

/// The router is a few metres away: a healthy one answers in a few ms even
/// over Wi-Fi.
LinkFinding judgeRouter(String? address, List<double?> samples) {
  if (address == null) return const LinkFinding(health: LinkHealth.skipped);
  final (latency, loss) = _sum(samples);
  final health = latency == null || loss > 20 || latency > 30
      ? LinkHealth.bad
      : loss > 0 || latency > 10
          ? LinkHealth.fair
          : LinkHealth.good;
  return LinkFinding(health: health, address: address, latencyMs: latency, lossPercent: loss);
}

/// Name lookups: [slowestMs] is the slowest of a few; [failed] lookups got
/// no answer at all.
LinkFinding judgeDns(double? slowestMs, {required int failed, required int total}) {
  final loss = total == 0 ? 0.0 : failed * 100 / total;
  final health = slowestMs == null || failed > 0 || slowestMs > 300
      ? LinkHealth.bad
      : slowestMs > 100
          ? LinkHealth.fair
          : LinkHealth.good;
  return LinkFinding(health: health, latencyMs: slowestMs, lossPercent: loss);
}

/// The way out: round trips to a server close to everyone.
LinkFinding judgeInternet(List<double?> samples) {
  final (latency, loss) = _sum(samples);
  final health = latency == null || loss > 5 || latency > 150
      ? LinkHealth.bad
      : loss > 1 || latency > 80
          ? LinkHealth.fair
          : LinkHealth.good;
  return LinkFinding(health: health, latencyMs: latency, lossPercent: loss);
}

/// Median round trip and loss percentage of a run of probes (null = lost).
(double?, double) _sum(List<double?> samples) {
  final ok = [for (final s in samples) ?s]..sort();
  final latency = ok.isEmpty ? null : ok[ok.length ~/ 2];
  final loss = samples.isEmpty ? 0.0 : (samples.length - ok.length) * 100 / samples.length;
  return (latency, loss);
}

/// The verdict a diagnosis ends with.
enum Cause { wifi, router, dns, provider, offline, none }

/// The answer: the first weak link from the home outwards, since a problem
/// close to the device spoils everything behind it. A clearly bad link wins
/// over a merely fair one further in.
({Cause cause, bool serious}) findCause(Map<DiagnosisStep, LinkFinding> findings) {
  final internet = findings[DiagnosisStep.internet];
  final router = findings[DiagnosisStep.router];

  // Nothing gets out, but the home network answers: the outage is past it.
  if (internet != null && internet.unreachable) {
    final wifiBad = findings[DiagnosisStep.wifi]?.health == LinkHealth.bad;
    final routerDown = router != null && router.unreachable;
    if (wifiBad) return (cause: Cause.wifi, serious: true);
    if (routerDown) return (cause: Cause.router, serious: true);
    return (cause: Cause.offline, serious: true);
  }

  for (final health in [LinkHealth.bad, LinkHealth.fair]) {
    for (final step in DiagnosisStep.values) {
      if (findings[step]?.health != health) continue;
      final cause = switch (step) {
        DiagnosisStep.wifi => Cause.wifi,
        DiagnosisStep.router => Cause.router,
        DiagnosisStep.dns => Cause.dns,
        DiagnosisStep.internet => Cause.provider,
      };
      return (cause: cause, serious: health == LinkHealth.bad);
    }
  }
  return (cause: Cause.none, serious: false);
}
