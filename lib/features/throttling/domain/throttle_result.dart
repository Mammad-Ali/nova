/// Verdict from comparing a neutral CDN against a video CDN.
enum ThrottleVerdict {
  /// Video is no slower than ordinary traffic.
  none,

  /// Video is noticeably slower — streaming looks throttled.
  suspected,

  /// Video is far slower — the ISP is almost certainly throttling it.
  likely,

  /// Video is FASTER: the ISP hosts a local cache of the video service.
  localCache,
}

/// Result of the throttling check.
class ThrottleResult {
  const ThrottleResult({
    required this.neutralMbps,
    required this.videoMbps,
    required this.verdict,
    this.videoHost,
  });

  /// Throughput against the neutral CDN (Cloudflare/Cachefly).
  final double neutralMbps;

  /// Throughput against the video CDN (Netflix Open Connect).
  final double videoMbps;

  final ThrottleVerdict verdict;

  /// Video CDN host — reveals whether the cache sits inside the ISP network.
  final String? videoHost;

  /// Video speed as a fraction of the neutral one: 1.0 means identical.
  double get ratio => neutralMbps <= 0 ? 0 : videoMbps / neutralMbps;
}

/// Classifies the result from the ratio between the two speeds.
ThrottleVerdict verdictFor(double neutralMbps, double videoMbps) {
  if (neutralMbps <= 0.01) return ThrottleVerdict.none;
  final r = videoMbps / neutralMbps;
  if (r >= 1.25) return ThrottleVerdict.localCache;
  if (r >= 0.85) return ThrottleVerdict.none;
  if (r >= 0.55) return ThrottleVerdict.suspected;
  return ThrottleVerdict.likely;
}
