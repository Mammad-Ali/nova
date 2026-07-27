/// Способ запросить у сервера кусок данных нужного размера.
enum ChunkMode {
  /// Размер задаётся query-параметром: `?bytes=N` (Cloudflare).
  bytesParam,

  /// Статичный файл + HTTP-заголовок `Range: bytes=0-(N-1)`.
  range,
}

/// Публичный источник данных для замера скорости.
class SpeedTestServer {
  const SpeedTestServer({
    required this.name,
    required this.downloadUrl,
    required this.mode,
    this.uploadUrl,
    this.chunkBytes = 5000000,
  });

  final String name;
  final String downloadUrl;
  final ChunkMode mode;

  /// Эндпоинт для отдачи (POST). Есть не у всех серверов.
  final String? uploadUrl;

  /// Размер одного куска. У Cloudflare запросы крупнее ~5 МБ отдают HTTP 429,
  /// поэтому 5 МБ — безопасный потолок для всех источников.
  final int chunkBytes;

  /// URL для скачивания одного куска.
  String chunkUrl() => mode == ChunkMode.bytesParam
      ? '$downloadUrl?bytes=$chunkBytes'
      : downloadUrl;

  /// URL для крошечного запроса — замер задержки.
  String probeUrl() =>
      mode == ChunkMode.bytesParam ? '$downloadUrl?bytes=0' : downloadUrl;

  /// Заголовок Range для куска (null, если сервер его не использует).
  String? rangeHeader() =>
      mode == ChunkMode.range ? 'bytes=0-${chunkBytes - 1}' : null;

  /// Заголовок Range для пробы задержки.
  String? probeRangeHeader() => mode == ChunkMode.range ? 'bytes=0-0' : null;
}

/// Источники по приоритету. Если первый недоступен или лимитирует запросы,
/// движок автоматически переключается на следующий.
///
/// Проверено вживую: все три отдают данные стабильно; отдачу (POST) among них
/// поддерживает только Cloudflare.
const List<SpeedTestServer> kSpeedTestServers = [
  SpeedTestServer(
    name: 'Cloudflare',
    downloadUrl: 'https://speed.cloudflare.com/__down',
    uploadUrl: 'https://speed.cloudflare.com/__up',
    mode: ChunkMode.bytesParam,
  ),
  SpeedTestServer(
    name: 'Cachefly',
    downloadUrl: 'https://cachefly.cachefly.net/10mb.test',
    mode: ChunkMode.range,
  ),
  SpeedTestServer(
    name: 'Hetzner',
    downloadUrl: 'https://nbg1-speed.hetzner.com/100MB.bin',
    mode: ChunkMode.range,
  ),
];
