/// How to ask a server for a chunk of a given size.
enum ChunkMode {
  /// Size is set through a query parameter: `?bytes=N` (Cloudflare).
  bytesParam,

  /// A static file plus the HTTP header `Range: bytes=0-(N-1)`.
  range,

  /// The servers internet providers run for the Speedtest network:
  /// `/download?size=N`, `/upload` (POST) and `/hello`, each with a
  /// throwaway `nocache` value so no cache in between answers.
  sizeParam,
}

/// A public data source used for measuring throughput.
class SpeedTestServer {
  const SpeedTestServer({
    required this.name,
    required this.downloadUrl,
    required this.mode,
    this.uploadUrl,
    this.chunkBytes = 5000000,
    this.id,
    this.city,
    this.helloUrl,
    this.pingHost,
  });

  /// One of the servers an internet provider runs for the Speedtest
  /// network, at [host] ("speedtest.aztelekom.az:8080"). These take any
  /// size in one request, so chunks are larger: fewer requests at gigabit
  /// speeds.
  const SpeedTestServer.provider({
    required int id,
    required String sponsor,
    required String city,
    required String host,
  }) : this(
          name: sponsor,
          downloadUrl: 'https://$host/download',
          uploadUrl: 'https://$host/upload',
          helloUrl: 'https://$host/hello',
          mode: ChunkMode.sizeParam,
          chunkBytes: 25000000,
          id: id,
          city: city,
          pingHost: host,
        );

  /// The company running it: "Cloudflare", "Aztelekom".
  final String name;
  final String downloadUrl;
  final ChunkMode mode;

  /// Upload endpoint (POST). Not every server offers one.
  final String? uploadUrl;

  /// Chunk size. Cloudflare answers HTTP 429 to requests larger than ~5 MB,
  /// so 5 MB is a safe ceiling across all sources.
  final int chunkBytes;

  /// The Speedtest network's number for a provider server; null for the
  /// built-in ones.
  final int? id;

  /// Where a provider server stands, in English ("Baku"); see
  /// azerbaijan_servers.dart for the names in other languages.
  final String? city;

  /// A tiny answer over HTTP (provider servers).
  final String? helloUrl;

  /// Where a provider server answers "PING" (provider_ping.dart): its host
  /// and port.
  final String? pingHost;

  /// "Aztelekom · Baku", or just "Cloudflare".
  String get label => city == null ? name : '$name · $city';

  /// URL for downloading a single chunk.
  String chunkUrl() => switch (mode) {
        ChunkMode.bytesParam => '$downloadUrl?bytes=$chunkBytes',
        ChunkMode.range => downloadUrl,
        ChunkMode.sizeParam => '$downloadUrl?nocache=${_nonce()}&size=$chunkBytes',
      };

  /// URL for a tiny request used to measure latency.
  String probeUrl() => switch (mode) {
        ChunkMode.bytesParam => '$downloadUrl?bytes=0',
        ChunkMode.range => downloadUrl,
        ChunkMode.sizeParam => '$helloUrl?nocache=${_nonce()}',
      };

  /// Where uploads go; null where they can't.
  String? uploadTarget() => uploadUrl == null
      ? null
      : mode == ChunkMode.sizeParam
          ? '$uploadUrl?nocache=${_nonce()}'
          : uploadUrl;

  static int _counter = 0;
  static String _nonce() => '${DateTime.now().microsecondsSinceEpoch}${_counter++}';

  /// Range header for a chunk (null if the server doesn't use one).
  String? rangeHeader() =>
      mode == ChunkMode.range ? 'bytes=0-${chunkBytes - 1}' : null;

  /// Range header for the latency probe.
  String? probeRangeHeader() => mode == ChunkMode.range ? 'bytes=0-0' : null;
}

/// Sources in priority order, for "Automatic". If the first is unreachable
/// or rate-limits us, the engine falls through to the next one. Cloudflare
/// answers from its nearest data centre — from Azerbaijan, the one in Baku.
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
