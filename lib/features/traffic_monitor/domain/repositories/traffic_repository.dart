import '../entities/network_snapshot.dart';

abstract class TrafficRepository {
  Stream<NetworkSnapshot> watch();
}