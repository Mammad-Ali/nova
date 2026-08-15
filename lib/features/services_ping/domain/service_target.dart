/// A service we measure latency against.
class ServiceTarget {
  const ServiceTarget({required this.name, required this.url});

  final String name;

  /// A lightweight endpoint returning 204 or a tiny body, so we measure
  /// latency rather than download speed.
  final String url;
}

/// A measurement. [rttMs] == null means the service didn't answer.
class ServicePing {
  const ServicePing({required this.target, this.rttMs});

  final ServiceTarget target;
  final double? rttMs;

  bool get failed => rttMs == null;

  PingQuality get quality {
    final r = rttMs;
    if (r == null) return PingQuality.failed;
    if (r < 60) return PingQuality.great;
    if (r < 120) return PingQuality.good;
    if (r < 250) return PingQuality.fair;
    return PingQuality.poor;
  }
}

enum PingQuality { great, good, fair, poor, failed }

/// The service list. Every endpoint was verified to answer 200/204.
const List<ServiceTarget> kServiceTargets = [
  ServiceTarget(
      name: 'YouTube', url: 'https://www.youtube.com/generate_204'),
  ServiceTarget(name: 'Google', url: 'https://www.gstatic.com/generate_204'),
  ServiceTarget(
      name: 'Discord', url: 'https://discord.com/api/v9/gateway'),
  ServiceTarget(
      name: 'Steam',
      url: 'https://api.steampowered.com/ISteamWebAPIUtil/GetServerInfo/v1/'),
  ServiceTarget(
      name: 'Cloudflare', url: 'https://cloudflare.com/cdn-cgi/trace'),
  ServiceTarget(name: 'Telegram', url: 'https://core.telegram.org/'),
];
