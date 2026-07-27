/// Сервис, до которого меряем задержку.
class ServiceTarget {
  const ServiceTarget({required this.name, required this.url});

  final String name;

  /// Лёгкий эндпоинт: отдаёт 204 или крошечный ответ, чтобы измерять именно
  /// задержку, а не скорость скачивания.
  final String url;
}

/// Результат замера. [rttMs] == null — сервис не ответил.
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

/// Набор сервисов. Эндпоинты проверены вживую — все отвечают 200/204.
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
