import 'package:flutter_test/flutter_test.dart';
import 'package:locobite/repositories/real_discovery_repository.dart';

// Runs against a live backend; set API to a running server to enable.
void main() {
  test('real discovery loads vendors/menus grouped by station', () async {
    final repo = RealDiscoveryRepository();
    await repo.refresh();
    final stations = repo.getUpcomingStations();
    final ud = stations.firstWhere((s) => s.code == 'UD');
    final vendors = repo.getVendorsForStation(ud.id);
    expect(vendors, isNotEmpty);
    expect(ud.vendorCount, vendors.length);
    expect(vendors.first.menu, isNotEmpty);
    expect(vendors.first.id.length, 36); // a real UUID
  }, skip: const bool.fromEnvironment('LIVE') ? false : 'set --dart-define=LIVE=true');
}
