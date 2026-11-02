import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/link_probes.dart';
import '../domain/diagnosis.dart';

/// Where a diagnosis is.
class DiagnosisState {
  const DiagnosisState({
    this.running = false,
    this.current,
    this.findings = const {},
  });

  final bool running;

  /// The step being measured right now.
  final DiagnosisStep? current;

  /// The steps measured so far.
  final Map<DiagnosisStep, LinkFinding> findings;

  bool get done => !running && findings.length == DiagnosisStep.values.length;
}

final diagnosisProvider =
    NotifierProvider.autoDispose<DiagnosisNotifier, DiagnosisState>(
        DiagnosisNotifier.new);

/// Walks the links one by one, outwards from the device, so each result can
/// appear as soon as it is known. About ten seconds in all.
class DiagnosisNotifier extends Notifier<DiagnosisState> {
  bool _disposed = false;

  @override
  DiagnosisState build() {
    ref.onDispose(() => _disposed = true);
    return const DiagnosisState();
  }

  Future<void> run() async {
    if (state.running) return;
    final findings = <DiagnosisStep, LinkFinding>{};

    Future<void> step(DiagnosisStep step, Future<LinkFinding> Function() measure) async {
      if (_disposed) return;
      state = DiagnosisState(running: true, current: step, findings: Map.of(findings));
      findings[step] = await measure();
    }

    await step(DiagnosisStep.wifi, () async => judgeWifi(await LinkProbes.wifiSignal()));
    await step(DiagnosisStep.router, () async {
      final (address, samples) = await LinkProbes.router();
      return judgeRouter(address, samples);
    });
    await step(DiagnosisStep.dns, () async {
      final (slowest, failed, total) = await LinkProbes.dns();
      return judgeDns(slowest, failed: failed, total: total);
    });
    await step(DiagnosisStep.internet, () async => judgeInternet(await LinkProbes.internet()));

    if (_disposed) return;
    state = DiagnosisState(findings: Map.unmodifiable(findings));
  }
}
