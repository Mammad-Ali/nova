/// Phases of an active speed test.
enum TestPhase { idle, ping, download, upload, done, error }

extension TestPhaseX on TestPhase {
  // Localised phase names come from AppStrings in the UI layer.
  bool get isRunning =>
      this == TestPhase.ping ||
      this == TestPhase.download ||
      this == TestPhase.upload;
}

/// A single progress event sent from the background isolate to the UI.
///
/// A plain data class of primitives, so it copies safely between isolates.
class SpeedTestProgress {
  const SpeedTestProgress({
    required this.phase,
    this.displayMbps = 0,
    this.phaseProgress = 0,
    this.pingMs,
    this.jitterMs,
    this.downloadMbps,
    this.uploadMbps,
    this.loadedPingMs,
    this.serverName,
    this.error,
  });

  /// Current phase.
  final TestPhase phase;

  /// EWMA-smoothed current speed in Mbps, used to drive the gauge.
  final double displayMbps;

  /// Progress within the current phase, 0..1.
  final double phaseProgress;

  /// Final metrics, filled in as they become available.
  final double? pingMs;
  final double? jitterMs;
  final double? downloadMbps;
  final double? uploadMbps;

  /// Median ping measured UNDER LOAD (while downloading). The gap against
  /// the idle [pingMs] is the bufferbloat.
  final double? loadedPingMs;

  /// Name of the server the measurement ran against.
  final String? serverName;

  /// Error text when the phase is error.
  final String? error;
}
