/// A DNS service to compare.
class DnsResolver {
  const DnsResolver(this.name, this.address, {this.current = false});

  /// "Cloudflare"; empty for the one in use now, which the sheet names.
  final String name;
  final String address;

  /// The server the system uses today.
  final bool current;
}

const publicResolvers = [
  DnsResolver('Cloudflare', '1.1.1.1'),
  DnsResolver('Google', '8.8.8.8'),
  DnsResolver('Quad9', '9.9.9.9'),
  DnsResolver('AdGuard', '94.140.14.14'),
  DnsResolver('OpenDNS', '208.67.222.222'),
];

/// Sites people open every day: what a DNS server answers most often.
const testNames = [
  'google.com',
  'youtube.com',
  'instagram.com',
  'whatsapp.net',
  'wikipedia.org',
  'tiktok.com',
  'telegram.org',
  'microsoft.com',
];

class DnsResult {
  const DnsResult({required this.medianMs, required this.answered, required this.asked});

  /// Middle of the answer times; null when nothing came back.
  final double? medianMs;
  final int answered;
  final int asked;

  factory DnsResult.from(List<double?> times) {
    final got = [for (final t in times) ?t]..sort();
    return DnsResult(
      medianMs: got.isEmpty ? null : got[got.length ~/ 2],
      answered: got.length,
      asked: times.length,
    );
  }

  /// Answered at least most of the questions.
  bool get works => medianMs != null && answered * 4 >= asked * 3;
}

/// Whether switching is worth it: the fastest public server must beat the
/// current one clearly — by a fifth and by 8 ms — or a reshuffle of
/// network noise would be "advice".
bool worthSwitching(DnsResult current, DnsResult best) {
  final now = current.medianMs;
  final then = best.medianMs;
  if (!best.works) return false;
  if (now == null || !current.works) return true;
  return then! < now * 0.8 && now - then >= 8;
}
