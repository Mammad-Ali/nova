/// A single latency sample. [rttMs] == null means no reply arrived — the
/// packet was lost or the link dropped for a moment.
class PingSample {
  const PingSample({required this.timestamp, this.rttMs});

  final DateTime timestamp;
  final double? rttMs;

  bool get lost => rttMs == null;
}
