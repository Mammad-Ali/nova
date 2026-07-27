/// Один замер задержки. [rttMs] == null означает, что ответа не было —
/// то есть пакет потерян / связь на мгновение пропала.
class PingSample {
  const PingSample({required this.timestamp, this.rttMs});

  final DateTime timestamp;
  final double? rttMs;

  bool get lost => rttMs == null;
}
