/// A single stored result from a completed speed test.
class SpeedTestRecord {
  const SpeedTestRecord({
    required this.timestamp,
    required this.downloadMbps,
    required this.uploadMbps,
    required this.pingMs,
    required this.jitterMs,
  });

  final DateTime timestamp;
  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;
  final double jitterMs;

  Map<String, dynamic> toJson() => {
        't': timestamp.toIso8601String(),
        'd': downloadMbps,
        'u': uploadMbps,
        'p': pingMs,
        'j': jitterMs,
      };

  factory SpeedTestRecord.fromJson(Map<String, dynamic> json) {
    return SpeedTestRecord(
      timestamp: DateTime.parse(json['t'] as String),
      downloadMbps: (json['d'] as num).toDouble(),
      uploadMbps: (json['u'] as num).toDouble(),
      pingMs: (json['p'] as num).toDouble(),
      jitterMs: (json['j'] as num).toDouble(),
    );
  }
}
