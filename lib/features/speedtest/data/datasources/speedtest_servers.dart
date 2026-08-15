/// How to ask a server for a chunk of a given size.
enum ChunkMode {
  /// Size is set through a query parameter: `?bytes=N` (Cloudflare).
  bytesParam,

  /// A static file plus the HTTP header `Range: bytes=0-(N-1)`.
  range,
}

/// A public data source used for measuring throughput.
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

  /// Upload endpoint (POST). Not every server offers one.
  final String? uploadUrl;

  /// Chunk size. Cloudflare answers HTTP 429 to requests larger than ~5 MB,
  /// so 5 MB is a safe ceiling across all sources.
  final int chunkBytes;

  /// URL for downloading a single chunk.
  String chunkUrl() => mode == ChunkMode.bytesParam
      ? '$downloadUrl?bytes=$chunkBytes'
      : downloadUrl;

  /// URL for a tiny request used to measure latency.
  String probeUrl() =>
      mode == ChunkMode.bytesParam ? '$downloadUrl?bytes=0' : downloadUrl;

  /// Range header for a chunk (null if the server doesn't use one).
  String? rangeHeader() =>
      mode == ChunkMode.range ? 'bytes=0-${chunkBytes - 1}' : null;

  /// Range header for the latency probe.
  String? probeRangeHeader() => mode == ChunkMode.range ? 'bytes=0-0' : null;
}

/// Sources in priority order. If the first is unreachable or rate-limits us,
/// the engine falls through to the next one automatically.
///
/// Verified in practice: all three serve data reliably; of the three only
/// Cloudflare accepts uploads (POST).
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
