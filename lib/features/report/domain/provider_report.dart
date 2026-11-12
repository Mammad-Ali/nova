import '../../speedtest/domain/entities/speedtest_record.dart';

/// How far back a report looks.
enum ReportPeriod { week, month, all }

/// Quarters of the day, for "evenings are slowest".
enum DayPart {
  night(0),
  morning(6),
  afternoon(12),
  evening(18);

  const DayPart(this.startHour);
  final int startHour;

  static DayPart of(DateTime time) => values.lastWhere((p) => time.hour >= p.startHour);
}

/// What a report to the internet provider says, worked out from the test
/// history: the figures are plain averages, so the provider can check them
/// against the list of tests that comes with them.
class ProviderReport {
  ProviderReport._({
    required this.from,
    required this.to,
    required this.tests,
    required this.planMbps,
  });

  /// The tests in [period] up to [now], oldest first.
  factory ProviderReport.build(
    List<SpeedTestRecord> history,
    ReportPeriod period, {
    double? planMbps,
    DateTime? now,
  }) {
    final end = now ?? DateTime.now();
    final start = switch (period) {
      ReportPeriod.week => end.subtract(const Duration(days: 7)),
      ReportPeriod.month => end.subtract(const Duration(days: 30)),
      ReportPeriod.all => history.isEmpty ? end : history.map((r) => r.timestamp).reduce((a, b) => a.isBefore(b) ? a : b),
    };
    final tests = [
      for (final r in history)
        if (!r.timestamp.isBefore(start) && !r.timestamp.isAfter(end)) r,
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return ProviderReport._(from: start, to: end, tests: tests, planMbps: planMbps);
  }

  final DateTime from;
  final DateTime to;
  final List<SpeedTestRecord> tests;
  final double? planMbps;

  bool get isEmpty => tests.isEmpty;

  static double _mean(Iterable<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  double get avgDown => _mean(tests.map((t) => t.downloadMbps));
  double get avgUp => _mean(tests.map((t) => t.uploadMbps));
  double get avgPing => _mean(tests.map((t) => t.pingMs));

  SpeedTestRecord? get slowest =>
      tests.isEmpty ? null : tests.reduce((a, b) => a.downloadMbps <= b.downloadMbps ? a : b);
  SpeedTestRecord? get fastest =>
      tests.isEmpty ? null : tests.reduce((a, b) => a.downloadMbps >= b.downloadMbps ? a : b);

  /// The average download as a share of the plan, 0–1+; null without one.
  double? get shareOfPlan => planMbps == null || planMbps == 0 ? null : avgDown / planMbps!;

  /// How many tests came in under half the plan.
  int? get underHalf =>
      planMbps == null ? null : tests.where((t) => t.downloadMbps < planMbps! / 2).length;

  /// Average download per part of the day, for the parts with tests.
  Map<DayPart, ({double avgDown, int count})> get byDayPart {
    final groups = <DayPart, List<double>>{};
    for (final t in tests) {
      groups.putIfAbsent(DayPart.of(t.timestamp), () => []).add(t.downloadMbps);
    }
    return {
      for (final part in DayPart.values)
        if (groups[part] case final speeds?) part: (avgDown: _mean(speeds), count: speeds.length),
    };
  }

  /// The part of the day that is clearly slowest — a fifth below the
  /// average, with at least three tests — or null when none stands out.
  DayPart? get slowestPart {
    final parts = byDayPart.entries.where((e) => e.value.count >= 3).toList();
    if (parts.length < 2) return null;
    parts.sort((a, b) => a.value.avgDown.compareTo(b.value.avgDown));
    return parts.first.value.avgDown < avgDown * 0.8 ? parts.first.key : null;
  }
}
