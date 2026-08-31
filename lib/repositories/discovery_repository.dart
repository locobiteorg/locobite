import '../shared/models/models.dart';

/// Abstract contract for "what food/train data exists".
/// Screens depend on THIS interface only — never on Mock or Real directly.
/// Swap the implementation in main.dart / a provider once the Rust backend
/// is ready; no screen file needs to change.
abstract class DiscoveryRepository {
  TrainInfo getCurrentTrain();
  List<Station> getUpcomingStations();
  List<Vendor> getVendorsForStation(int stationId);
}
