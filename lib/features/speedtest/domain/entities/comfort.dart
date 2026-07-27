/// Насколько комфортно конкретное занятие при измеренной скорости.
enum ComfortLevel { poor, ok, good, great }

/// Вид активности, для которого оцениваем комфорт.
enum ComfortActivity {
  browsing,
  hdVideo,
  video4k,
  gaming,
  videoCalls,
  streaming,
  bigDownloads,
}

class ComfortItem {
  const ComfortItem(this.activity, this.level);
  final ComfortActivity activity;
  final ComfortLevel level;
}

/// Оценивает список активностей по download/upload (Мбит/с) и ping (мс).
///
/// Пороги ориентированы на типичные требования сервисов (YouTube/Netflix,
/// Zoom, облачный гейминг и т.п.). Для игр и звонков учитываем и задержку —
/// там она важнее пропускной способности.
List<ComfortItem> evaluateComfort({
  required double download,
  required double upload,
  required double ping,
}) {
  return [
    ComfortItem(ComfortActivity.browsing, _byThresholds(download, 5, 1.5, 0.5)),
    ComfortItem(ComfortActivity.hdVideo, _byThresholds(download, 12, 5, 2.5)),
    ComfortItem(ComfortActivity.video4k, _byThresholds(download, 40, 25, 15)),
    ComfortItem(ComfortActivity.gaming, _gaming(download, ping)),
    ComfortItem(ComfortActivity.videoCalls, _calls(download, upload, ping)),
    ComfortItem(ComfortActivity.streaming, _byThresholds(upload, 10, 6, 3)),
    ComfortItem(
        ComfortActivity.bigDownloads, _byThresholds(download, 100, 50, 15)),
  ];
}

/// great ≥ [great], good ≥ [good], ok ≥ [ok], иначе poor.
ComfortLevel _byThresholds(double v, double great, double good, double ok) {
  if (v >= great) return ComfortLevel.great;
  if (v >= good) return ComfortLevel.good;
  if (v >= ok) return ComfortLevel.ok;
  return ComfortLevel.poor;
}

ComfortLevel _gaming(double download, double ping) {
  if (download < 3) return ComfortLevel.poor;
  if (ping <= 30) return ComfortLevel.great;
  if (ping <= 60) return ComfortLevel.good;
  if (ping <= 120) return ComfortLevel.ok;
  return ComfortLevel.poor;
}

ComfortLevel _calls(double download, double upload, double ping) {
  final bw = download < upload ? download : upload; // ограничивает слабейшая
  final byBw = _byThresholds(bw, 8, 3, 1.2);
  // Высокий пинг снижает оценку на одну ступень.
  if (ping > 150 && byBw.index > 0) {
    return ComfortLevel.values[byBw.index - 1];
  }
  return byBw;
}
