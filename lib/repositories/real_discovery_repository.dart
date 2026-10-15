import '../services/api_service.dart';
import '../shared/models/models.dart';
import 'discovery_repository.dart';
import 'stations.dart';

/// Vendors and menus come live from the shared Go/Postgres backend — the
/// same data the merchant app writes. Only the route (stations/train) is
/// still demo data.
class RealDiscoveryRepository implements DiscoveryRepository {
  final TrainInfo _train = TrainInfo(number: '12619', coach: 'S4', seat: '41', arrival: '14:18');
  Map<String, List<Vendor>> _byStationCode = {};

  @override
  Future<void> refresh() async {
    final raw = await ApiService.getVendors();
    final byCode = <String, List<Vendor>>{};
    for (final j in raw) {
      final v = _vendorFromJson(j);
      byCode.putIfAbsent(j['station_code'] as String, () => []).add(v);
    }
    _byStationCode = byCode;
  }

  @override
  TrainInfo getCurrentTrain() => _train;

  @override
  List<Station> getUpcomingStations() => [
        for (final s in kStations)
          Station(
            id: s.id, name: s.name, code: s.code, eta: s.eta, minsAway: s.minsAway,
            platform: s.platform, vendorCount: _byStationCode[s.code]?.length ?? 0,
          ),
      ];

  @override
  List<Vendor> getVendorsForStation(int stationId) {
    final code = kStations.firstWhere((s) => s.id == stationId).code;
    return _byStationCode[code] ?? const [];
  }

  @override
  String? vendorNameFor(String vendorId) {
    for (final list in _byStationCode.values) {
      for (final v in list) {
        if (v.id == vendorId) return v.name;
      }
    }
    return null;
  }

  Vendor _vendorFromJson(Map<String, dynamic> j) {
    final station = kStations.firstWhere((s) => s.code == j['station_code'], orElse: () => kStations.first);
    final menu = [
      for (final m in (j['menu_items'] as List? ?? const []))
        MenuItem(
          id: m['id'] as String,
          name: m['name'] as String,
          price: ((m['price_paise'] as num) / 100).round(),
          isVeg: m['diet_type'] != 'non_veg',
          desc: '',
          imageUrl: m['photo_url'] as String?,
        ),
    ];
    final prices = menu.map((m) => m.price);
    final allVeg = menu.isNotEmpty && menu.every((m) => m.isVeg);
    final anyNonVeg = menu.any((m) => !m.isVeg);
    final fssai = j['fssai_status'];
    return Vendor(
      id: j['id'] as String,
      stationId: station.id,
      name: j['name'] as String,
      imageUrl: (j['stall_image_url'] as String?) ?? '',
      cuisineTags: [if (allVeg) 'Veg', if (anyNonVeg) 'Non-Veg'],
      priceRange: prices.isEmpty ? '' : '₹${prices.reduce((a, b) => a < b ? a : b)}–₹${prices.reduce((a, b) => a > b ? a : b)}',
      isOpen: j['is_active'] as bool? ?? true,
      trusted: j['trusted'] as bool? ?? false,
      fssai: fssai == 'registered' || fssai == 'valid',
      zeroCommission: false,
      rating: 0,
      reviewCount: 0,
      menu: menu,
    );
  }
}
