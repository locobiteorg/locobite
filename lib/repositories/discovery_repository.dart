import '../shared/models/models.dart';

/// Abstract contract for "what food/train data exists".
/// Screens depend on THIS interface only — never on Mock or Real directly.
/// The single swap point is `LocoBiteApp.repo` in main.dart.
abstract class DiscoveryRepository {
  /// Loads/reloads vendor data. Call before reading vendors; the getters
  /// below are synchronous reads of what the last refresh loaded.
  /// Throws if the backend can't be reached.
  Future<void> refresh();

  TrainInfo getCurrentTrain();
  List<Station> getUpcomingStations();
  List<Vendor> getVendorsForStation(int stationId);

  /// Name of a vendor by backend id (for order history), or null if unknown.
  String? vendorNameFor(String vendorId);
}
