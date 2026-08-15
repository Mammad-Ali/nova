import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/network_snapshot.dart';
import '../../data/repositories/traffic_repository_impl.dart'
    show trafficRepositoryProvider;

final trafficStreamProvider = StreamProvider<NetworkSnapshot>((ref) {
  final repo = ref.watch(trafficRepositoryProvider);
  return repo.watch();
});

class TrafficHistory {
  const TrafficHistory({
    required this.snapshots,
    required this.peakRxPerSec,
    required this.peakTxPerSec,
    required this.sessionRxBytes,
    required this.sessionTxBytes,
  });

  const TrafficHistory.empty()
      : snapshots = const <NetworkSnapshot>[],
        peakRxPerSec = 0,
        peakTxPerSec = 0,
        sessionRxBytes = 0,
        sessionTxBytes = 0;

  final List<NetworkSnapshot> snapshots;
  final int peakRxPerSec;
  final int peakTxPerSec;
  final int sessionRxBytes;
  final int sessionTxBytes;

  NetworkSnapshot? get latest => snapshots.isEmpty ? null : snapshots.last;
  int get currentRxPerSec => latest?.rxPerSec ?? 0;
  int get currentTxPerSec => latest?.txPerSec ?? 0;
}

final trafficHistoryProvider =
    NotifierProvider<TrafficHistoryNotifier, TrafficHistory>(
        TrafficHistoryNotifier.new);

class TrafficHistoryNotifier extends Notifier<TrafficHistory> {
  static const int capacity = 120;
  final ListQueue<NetworkSnapshot> _buffer = ListQueue<NetworkSnapshot>(capacity);

  @override
  TrafficHistory build() {
    ref.listen<AsyncValue<NetworkSnapshot>>(trafficStreamProvider, (_, next) {
      // Works across Riverpod versions.
      next.whenOrNull(
        data: (snapshot) => _append(snapshot),
      );
    });
    return const TrafficHistory.empty();
  }

  void _append(NetworkSnapshot s) {
    if (_buffer.length >= capacity) _buffer.removeFirst();
    _buffer.addLast(s);

    state = TrafficHistory(
      snapshots: List<NetworkSnapshot>.unmodifiable(_buffer),
      peakRxPerSec:
          s.rxPerSec > state.peakRxPerSec ? s.rxPerSec : state.peakRxPerSec,
      peakTxPerSec:
          s.txPerSec > state.peakTxPerSec ? s.txPerSec : state.peakTxPerSec,
      sessionRxBytes: state.sessionRxBytes + s.rxPerSec,
      sessionTxBytes: state.sessionTxBytes + s.txPerSec,
    );
  }

  void reset() {
    _buffer.clear();
    state = const TrafficHistory.empty();
  }
}