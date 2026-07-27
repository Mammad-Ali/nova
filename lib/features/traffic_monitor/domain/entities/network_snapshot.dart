class NetworkSnapshot {
  const NetworkSnapshot({
    required this.rxPerSec,
    required this.txPerSec,
    required this.totalRx,
    required this.totalTx,
    required this.timestamp,
  });
  final int rxPerSec, txPerSec, totalRx, totalTx;
  final DateTime timestamp;
}