import '../entities/speedtest_record.dart';

abstract class SpeedTestHistoryRepository {
  Future<List<SpeedTestRecord>> loadAll();
  Future<void> saveAll(List<SpeedTestRecord> records);
}
