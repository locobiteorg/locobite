import '../shared/models/models.dart';
import 'discovery_repository.dart';

/// Hardcoded data so the app flow can be demoed before the backend exists.
/// Later: create RealDiscoveryRepository implementing the same interface,
/// backed by http calls to the Rust API, and use that instead — screens
/// stay untouched.
class MockDiscoveryRepository implements DiscoveryRepository {
  final TrainInfo _train = TrainInfo(
    number: '12259', coach: 'B2', seat: '34', arrival: '14:35',
  );

  final List<Station> _stations = const [
    Station(id: 1, name: 'Nagpur Jn',  code: 'NGP',  eta: '14:35', minsAway: 12,  platform: 3, vendorCount: 8),
    Station(id: 2, name: 'Wardha Jn',  code: 'WR',   eta: '15:42', minsAway: 79,  platform: 1, vendorCount: 3),
    Station(id: 3, name: 'Sevagram',   code: 'SEGM', eta: '16:05', minsAway: 102, platform: 2, vendorCount: 1),
    Station(id: 4, name: 'Gondia Jn',  code: 'G',    eta: '17:20', minsAway: 165, platform: 2, vendorCount: 5),
    Station(id: 5, name: 'Raipur Jn',  code: 'R',    eta: '19:40', minsAway: 265, platform: 4, vendorCount: 12),
  ];

  final List<Vendor> _vendors = const [
    Vendor(
      id: 1, stationId: 1, name: 'Saoji Kitchen',
      imageUrl: 'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a?w=600&h=280&fit=crop',
      cuisineTags: ['Saoji', 'Spicy', 'Non-Veg'],
      priceRange: '₹80–₹250', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.7, reviewCount: 892,
      menu: [
        MenuItem(id: 1, name: 'Saoji Chicken Curry + Rice', price: 180, isVeg: false, desc: 'Authentic Nagpur-style spicy chicken'),
        MenuItem(id: 2, name: 'Saoji Mutton',               price: 240, isVeg: false, desc: 'Slow-cooked in 12-spice masala'),
        MenuItem(id: 3, name: 'Plain Rice',                 price: 60,  isVeg: true,  desc: 'Steamed basmati rice'),
        MenuItem(id: 4, name: 'Dal Fry',                    price: 80,  isVeg: true,  desc: 'Yellow dal with tempering'),
      ],
    ),
    Vendor(
      id: 2, stationId: 1, name: 'Nagpur Orange Bites',
      imageUrl: 'https://images.unsplash.com/photo-1600628421066-f6bda6a7b976?w=600&h=280&fit=crop',
      cuisineTags: ['Snacks', 'Beverages', 'Veg'],
      priceRange: '₹30–₹120', isOpen: true, trusted: true, fssai: true, zeroCommission: false,
      rating: 4.3, reviewCount: 1204,
      menu: [
        MenuItem(id: 5, name: 'Poha',               price: 40, isVeg: true, desc: 'Flattened rice with onion & spices'),
        MenuItem(id: 6, name: 'Vada Pav',            price: 30, isVeg: true, desc: 'Spiced potato fritter in a bun'),
        MenuItem(id: 7, name: 'Fresh Orange Juice',  price: 60, isVeg: true, desc: '100% Nagpur oranges'),
        MenuItem(id: 8, name: 'Samosa (2 pcs)',      price: 40, isVeg: true, desc: 'Crispy with tamarind chutney'),
      ],
    ),
    Vendor(
      id: 3, stationId: 1, name: 'Punjab Da Dhaba',
      imageUrl: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&h=280&fit=crop',
      cuisineTags: ['North Indian', 'Punjabi', 'Thali'],
      priceRange: '₹120–₹300', isOpen: false, trusted: false, fssai: true, zeroCommission: true,
      rating: 4.1, reviewCount: 456,
      menu: [
        MenuItem(id: 9,  name: 'Veg Thali',                     price: 150, isVeg: true,  desc: 'Dal, 2 sabzi, roti, rice, salad'),
        MenuItem(id: 10, name: 'Paneer Butter Masala + 2 Rotis', price: 180, isVeg: true, desc: 'Rich tomato-cream gravy'),
        MenuItem(id: 11, name: 'Chicken Curry + Rice',           price: 200, isVeg: false, desc: 'Punjabi home-style'),
      ],
    ),
  ];

  @override
  TrainInfo getCurrentTrain() => _train;

  @override
  List<Station> getUpcomingStations() => _stations;

  @override
  List<Vendor> getVendorsForStation(int stationId) =>
      _vendors.where((v) => v.stationId == stationId).toList();
}
