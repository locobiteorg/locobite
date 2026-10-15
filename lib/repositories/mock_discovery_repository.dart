import '../shared/models/models.dart';
import 'discovery_repository.dart';
import 'stations.dart';

/// Hardcoded Konkan / coastal Karnataka demo catalog.
/// Nearest halt is Udupi Junction; other stops are real nearby stations.
class MockDiscoveryRepository implements DiscoveryRepository {
  final TrainInfo _train = TrainInfo(
    number: '12619', coach: 'S4', seat: '41', arrival: '14:18',
  );


  final List<Vendor> _vendors = const [
    Vendor(
      id: '11111111-1111-1111-1111-111111111111', stationId: 1, name: 'Sri Krishna Bhavan',
      imageUrl: 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=600&h=280&fit=crop',
      cuisineTags: ['Udupi', 'Dosa', 'Veg'],
      priceRange: '₹40–₹140', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.8, reviewCount: 2104,
      menu: [
        MenuItem(id: '11111111-1111-1111-1111-111111111001', name: 'Masala Dosa',           price: 70,  isVeg: true, desc: 'Crisp dosa with potato palya & chutney'),
        MenuItem(id: '11111111-1111-1111-1111-111111111002', name: 'Idli Vada Combo',        price: 55,  isVeg: true, desc: 'Two idlis, one vada, sambar'),
        MenuItem(id: '11111111-1111-1111-1111-111111111003', name: 'Filter Coffee',           price: 25,  isVeg: true, desc: 'Temple-town strong decoction'),
        MenuItem(id: '11111111-1111-1111-1111-111111111004', name: 'Sambar Rice',            price: 80,  isVeg: true, desc: 'Udupi sambar over hot rice'),
      ],
    ),
    Vendor(
      id: '22222222-2222-2222-2222-222222222222', stationId: 1, name: 'Malpe Harbour Kitchen',
      imageUrl: 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=600&h=280&fit=crop',
      cuisineTags: ['Coastal', 'Fish', 'Non-Veg'],
      priceRange: '₹90–₹280', isOpen: true, trusted: true, fssai: true, zeroCommission: false,
      rating: 4.6, reviewCount: 867,
      menu: [
        MenuItem(id: '22222222-2222-2222-2222-222222222005', name: 'Bangda Fry + Neer Dosa', price: 180, isVeg: false, desc: 'Mackerel fry with lacy neer dosa'),
        MenuItem(id: '22222222-2222-2222-2222-222222222006', name: 'Fish Curry Rice',        price: 160, isVeg: false, desc: 'Tangy coconut-fish curry'),
        MenuItem(id: '22222222-2222-2222-2222-222222222007', name: 'Anjal Tawa Fry',          price: 260, isVeg: false, desc: 'Seer fish, Malpe style'),
        MenuItem(id: '22222222-2222-2222-2222-222222222008', name: 'Neer Dosa (3 pcs)',       price: 50,  isVeg: true,  desc: 'Plain rice crepes'),
      ],
    ),
    Vendor(
      id: '33333333-3333-3333-3333-333333333333', stationId: 1, name: 'Car Street Snacks',
      imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&h=280&fit=crop',
      cuisineTags: ['Snacks', 'Tea', 'Veg'],
      priceRange: '₹20–₹80', isOpen: true, trusted: false, fssai: true, zeroCommission: true,
      rating: 4.4, reviewCount: 640,
      menu: [
        MenuItem(id: '33333333-3333-3333-3333-333333333009',  name: 'Goli Baje (6 pcs)',   price: 40, isVeg: true, desc: 'Udupi maida bajji with coconut chutney'),
        MenuItem(id: '33333333-3333-3333-3333-333333333010', name: 'Mangalore Buns (2)',  price: 45, isVeg: true, desc: 'Sweet banana buns'),
        MenuItem(id: '33333333-3333-3333-3333-333333333011', name: 'Cutting Chai',        price: 20, isVeg: true, desc: 'Platform tea'),
      ],
    ),
    Vendor(
      id: '44444444-4444-4444-4444-444444444444', stationId: 2, name: 'Padubidri Platform Tea',
      imageUrl: 'https://images.unsplash.com/photo-1571934811356-5cc061b6821f?w=600&h=280&fit=crop',
      cuisineTags: ['Tea', 'Snacks', 'Veg'],
      priceRange: '₹20–₹60', isOpen: true, trusted: false, fssai: true, zeroCommission: true,
      rating: 4.1, reviewCount: 94,
      menu: [
        MenuItem(id: '44444444-4444-4444-4444-444444444012', name: 'Ginger Tea',     price: 20, isVeg: true, desc: 'Strong chai for the halt'),
        MenuItem(id: '44444444-4444-4444-4444-444444444013', name: 'Bonda (4 pcs)',  price: 35, isVeg: true, desc: 'Potato bonda'),
        MenuItem(id: '44444444-4444-4444-4444-444444444014', name: 'Banana Chips',   price: 40, isVeg: true, desc: 'Kerala-style thin chips'),
      ],
    ),
    Vendor(
      id: '55555555-5555-5555-5555-555555555555', stationId: 6, name: 'Ghee Roast House',
      imageUrl: 'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a?w=600&h=280&fit=crop',
      cuisineTags: ['Mangalorean', 'Ghee Roast', 'Non-Veg'],
      priceRange: '₹120–₹320', isOpen: true, trusted: true, fssai: true, zeroCommission: false,
      rating: 4.7, reviewCount: 1540,
      menu: [
        MenuItem(id: '55555555-5555-5555-5555-555555555015', name: 'Chicken Ghee Roast', price: 260, isVeg: false, desc: 'Bunt-style kori gassi roast'),
        MenuItem(id: '55555555-5555-5555-5555-555555555016', name: 'Prawn Ghee Roast',  price: 320, isVeg: false, desc: 'Byadgi chilli & ghee'),
        MenuItem(id: '55555555-5555-5555-5555-555555555017', name: 'Neer Dosa (4 pcs)', price: 60,  isVeg: true,  desc: 'To scoop the roast'),
      ],
    ),
    Vendor(
      id: '66666666-6666-6666-6666-666666666666', stationId: 6, name: 'Hampankatta Buns & Ice Cream',
      imageUrl: 'https://images.unsplash.com/photo-1570197788417-0e28382f621d?w=600&h=280&fit=crop',
      cuisineTags: ['Ice cream', 'Buns', 'Veg'],
      priceRange: '₹40–₹150', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.5, reviewCount: 980,
      menu: [
        MenuItem(id: '66666666-6666-6666-6666-666666666018', name: 'Gadbad Ice Cream',   price: 120, isVeg: true, desc: 'Mangalore classic tall glass'),
        MenuItem(id: '66666666-6666-6666-6666-666666666019', name: 'Mangalore Buns',     price: 50,  isVeg: true, desc: 'Soft banana buns with chutney'),
        MenuItem(id: '66666666-6666-6666-6666-666666666020', name: 'Tender Coconut',    price: 60,  isVeg: true, desc: 'Chilled, from the coast'),
      ],
    ),
    Vendor(
      id: '77777777-7777-7777-7777-777777777777', stationId: 7, name: 'Kundapur Kori Rotti',
      imageUrl: 'https://images.unsplash.com/photo-1600628421066-f6bda6a7b976?w=600&h=280&fit=crop',
      cuisineTags: ['Kundapur', 'Kori Rotti', 'Non-Veg'],
      priceRange: '₹90–₹220', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.6, reviewCount: 412,
      menu: [
        MenuItem(id: '77777777-7777-7777-7777-777777777021', name: 'Kori Rotti Meal', price: 180, isVeg: false, desc: 'Crisp rice rotti with chicken curry'),
        MenuItem(id: '77777777-7777-7777-7777-777777777022', name: 'Kori Gassi + Rice', price: 160, isVeg: false, desc: 'Coconut chicken curry'),
        MenuItem(id: '77777777-7777-7777-7777-777777777023', name: 'Veg Saaru Rice',    price: 90,  isVeg: true,  desc: 'Pepper rasam rice'),
      ],
    ),
    Vendor(
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', stationId: 5, name: 'Surathkal NITK Snacks',
      imageUrl: 'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&h=280&fit=crop',
      cuisineTags: ['Snacks', 'Coastal', 'Veg'],
      priceRange: '₹30–₹100', isOpen: true, trusted: false, fssai: true, zeroCommission: false,
      rating: 4.2, reviewCount: 221,
      menu: [
        MenuItem(id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa024', name: 'Pundi (3 pcs)',   price: 40, isVeg: true, desc: 'Steamed rice dumplings'),
        MenuItem(id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa025', name: 'Goli Baje',      price: 35, isVeg: true, desc: 'Hot with coconut chutney'),
        MenuItem(id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa026', name: 'Filter Coffee',   price: 30, isVeg: true, desc: 'South Indian decoction'),
      ],
    ),
    Vendor(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', stationId: 9, name: 'Gokarna Beach Shack',
      imageUrl: 'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=600&h=280&fit=crop',
      cuisineTags: ['Beach', 'Konkan', 'Non-Veg'],
      priceRange: '₹80–₹240', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.3, reviewCount: 356,
      menu: [
        MenuItem(id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb027', name: 'Fish Thali',      price: 200, isVeg: false, desc: 'Rice, fry, curry, sol kadhi'),
        MenuItem(id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb028', name: 'Veg Konkani Thali', price: 140, isVeg: true,  desc: 'Rice, valval, pickle, buttermilk'),
        MenuItem(id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb029', name: 'Sol Kadhi',       price: 50,  isVeg: true,  desc: 'Kokum + coconut cooler'),
      ],
    ),
    Vendor(
      id: 'cccccccc-cccc-cccc-cccc-cccccccccccc', stationId: 3, name: 'Barkur Temple Canteen',
      imageUrl: 'https://images.unsplash.com/photo-1567188040759-fb8a803d0272?w=600&h=280&fit=crop',
      cuisineTags: ['Temple', 'Meals', 'Veg'],
      priceRange: '₹25–₹90', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.4, reviewCount: 178,
      menu: [
        MenuItem(id: 'cccccccc-cccc-cccc-cccc-ccccccccc030', name: 'Holige (2 pcs)', price: 50, isVeg: true, desc: 'Jaggery-coconut obbattu'),
        MenuItem(id: 'cccccccc-cccc-cccc-cccc-ccccccccc031', name: 'Rice Bath',     price: 70, isVeg: true, desc: 'Temple-style vegetable rice'),
        MenuItem(id: 'cccccccc-cccc-cccc-cccc-ccccccccc032', name: 'Buttermilk',    price: 25, isVeg: true, desc: 'Spiced majjige'),
      ],
    ),
    Vendor(
      id: 'dddddddd-dddd-dddd-dddd-dddddddddddd', stationId: 4, name: 'Mulki River Catch',
      imageUrl: 'https://images.unsplash.com/photo-1559847844-5315695dadae?w=600&h=280&fit=crop',
      cuisineTags: ['Fish', 'Coastal', 'Non-Veg'],
      priceRange: '₹80–₹220', isOpen: true, trusted: false, fssai: true, zeroCommission: true,
      rating: 4.3, reviewCount: 156,
      menu: [
        MenuItem(id: 'dddddddd-dddd-dddd-dddd-ddddddddd033', name: 'Prawn Fry Rice',   price: 180, isVeg: false, desc: 'River-mouth prawns, red masala'),
        MenuItem(id: 'dddddddd-dddd-dddd-dddd-ddddddddd034', name: 'Kane Rava Fry',    price: 220, isVeg: false, desc: 'Ladyfish with rava crust'),
        MenuItem(id: 'dddddddd-dddd-dddd-dddd-ddddddddd035', name: 'Coconut Rice',     price: 80,  isVeg: true,  desc: 'Tempered with curry leaves'),
      ],
    ),
    Vendor(
      id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', stationId: 8, name: 'Byndoor Beach Meals',
      imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&h=280&fit=crop',
      cuisineTags: ['Meals', 'Konkan', 'Non-Veg'],
      priceRange: '₹70–₹180', isOpen: true, trusted: true, fssai: true, zeroCommission: false,
      rating: 4.2, reviewCount: 203,
      menu: [
        MenuItem(id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeee036', name: 'Byndoor Fish Curry Meal', price: 170, isVeg: false, desc: 'Tamarind-coconut curry, rice, pickle'),
        MenuItem(id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeee037', name: 'Crab Sukka',              price: 180, isVeg: false, desc: 'Dry roast with Byadgi chilli'),
        MenuItem(id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeee038', name: 'Veg Meals',               price: 90,  isVeg: true,  desc: 'Rice, sambar, palya, curd'),
      ],
    ),
    Vendor(
      id: '10101010-1010-1010-1010-101010101010', stationId: 10, name: 'Bhatkal Biryani House',
      imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&h=280&fit=crop',
      cuisineTags: ['Biryani', 'Navayath', 'Non-Veg'],
      priceRange: '₹100–₹260', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.7, reviewCount: 891,
      menu: [
        MenuItem(id: '10101010-1010-1010-1010-101010101039', name: 'Bhatkali Chicken Biryani', price: 220, isVeg: false, desc: 'Navayath spice, short-grain rice'),
        MenuItem(id: '10101010-1010-1010-1010-101010101040', name: 'Mutton Biryani',           price: 260, isVeg: false, desc: 'Slow-cooked, limited pots'),
        MenuItem(id: '10101010-1010-1010-1010-101010101041', name: 'Egg Biryani',              price: 140, isVeg: false, desc: 'Two eggs, raita'),
        MenuItem(id: '10101010-1010-1010-1010-101010101042', name: 'Veg Dum Biryani',          price: 120, isVeg: true,  desc: 'Saffron rice, mixed veg'),
      ],
    ),
    Vendor(
      id: '14141414-1414-1414-1414-141414141414', stationId: 11, name: 'Murdeshwar Temple Kitchen',
      imageUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=600&h=280&fit=crop',
      cuisineTags: ['Temple', 'Coastal', 'Veg'],
      priceRange: '₹40–₹130', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.5, reviewCount: 640,
      menu: [
        MenuItem(id: '14141414-1414-1414-1414-141414141043', name: 'Temple Meals',     price: 90,  isVeg: true, desc: 'Rice, sambar, kosambari, payasa'),
        MenuItem(id: '14141414-1414-1414-1414-141414141044', name: 'Poha + Coffee',    price: 50,  isVeg: true, desc: 'Coastal avalakki with filter coffee'),
        MenuItem(id: '14141414-1414-1414-1414-141414141045', name: 'Coconut Payasa',   price: 40,  isVeg: true, desc: 'Jaggery kheer in a cup'),
      ],
    ),
    Vendor(
      id: '15151515-1515-1515-1515-151515151515', stationId: 12, name: 'Central Station Tiffin',
      imageUrl: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&h=280&fit=crop',
      cuisineTags: ['Tiffin', 'Mangalorean', 'Veg'],
      priceRange: '₹30–₹110', isOpen: true, trusted: false, fssai: true, zeroCommission: true,
      rating: 4.3, reviewCount: 512,
      menu: [
        MenuItem(id: '15151515-1515-1515-1515-151515151046', name: 'Rava Idli (4 pcs)', price: 55, isVeg: true, desc: 'Soft, with sambar & chutney'),
        MenuItem(id: '15151515-1515-1515-1515-151515151047', name: 'Buns + Chutney',    price: 50, isVeg: true, desc: 'Sweet banana buns'),
        MenuItem(id: '15151515-1515-1515-1515-151515151048', name: 'Kesari Bath',       price: 40, isVeg: true, desc: 'Saffron rava sweet'),
        MenuItem(id: '15151515-1515-1515-1515-151515151049', name: 'Filter Coffee',     price: 30, isVeg: true, desc: 'MAQ platform decoction'),
      ],
    ),
    Vendor(
      id: '16161616-1616-1616-1616-161616161616', stationId: 9, name: 'Kumta Kokum Cafe',
      imageUrl: 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&h=280&fit=crop',
      cuisineTags: ['Cafe', 'Konkan', 'Veg'],
      priceRange: '₹40–₹120', isOpen: true, trusted: false, fssai: true, zeroCommission: false,
      rating: 4.1, reviewCount: 188,
      menu: [
        MenuItem(id: '16161616-1616-1616-1616-161616161050', name: 'Kokum Sherbet',  price: 40,  isVeg: true, desc: 'Chilled agal, cumin'),
        MenuItem(id: '16161616-1616-1616-1616-161616161051', name: 'Pathrado (4 pcs)', price: 80, isVeg: true, desc: 'Colocasia leaf rolls'),
        MenuItem(id: '16161616-1616-1616-1616-161616161052', name: 'Upkari Rice',     price: 110, isVeg: true, desc: 'Beans upkari over steamed rice'),
      ],
    ),
  ];

  @override
  Future<void> refresh() async {}

  @override
  String? vendorNameFor(String vendorId) {
    for (final v in _vendors) {
      if (v.id == vendorId) return v.name;
    }
    return null;
  }

  @override
  TrainInfo getCurrentTrain() => _train;

  @override
  List<Station> getUpcomingStations() => kStations;

  @override
  List<Vendor> getVendorsForStation(int stationId) =>
      _vendors.where((v) => v.stationId == stationId).toList();
}
