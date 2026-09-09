import '../shared/models/models.dart';
import 'discovery_repository.dart';

/// Hardcoded Konkan / coastal Karnataka demo catalog.
/// Nearest halt is Udupi Junction; other stops are real nearby stations.
class MockDiscoveryRepository implements DiscoveryRepository {
  final TrainInfo _train = TrainInfo(
    number: '12619', coach: 'S4', seat: '41', arrival: '14:18',
  );

  final List<Station> _stations = const [
    Station(id: 1,  name: 'Udupi Junction',     code: 'UD',   eta: '14:18', minsAway: 8,   platform: 1, vendorCount: 3),
    Station(id: 2,  name: 'Padubidri',          code: 'PDD',  eta: '13:52', minsAway: 22,  platform: 1, vendorCount: 1),
    Station(id: 3,  name: 'Barkur',             code: 'BKJ',  eta: '14:36', minsAway: 28,  platform: 1, vendorCount: 1),
    Station(id: 4,  name: 'Mulki',              code: 'MULK', eta: '13:38', minsAway: 38,  platform: 1, vendorCount: 1),
    Station(id: 5,  name: 'Surathkal',          code: 'SL',   eta: '13:28', minsAway: 48,  platform: 1, vendorCount: 1),
    Station(id: 7,  name: 'Kundapura',          code: 'KUDA', eta: '15:02', minsAway: 58,  platform: 1, vendorCount: 1),
    Station(id: 6,  name: 'Mangalore Jn',       code: 'MAJN', eta: '13:05', minsAway: 72,  platform: 2, vendorCount: 2),
    Station(id: 12, name: 'Mangalore Central',  code: 'MAQ',  eta: '12:50', minsAway: 85,  platform: 1, vendorCount: 1),
    Station(id: 8,  name: 'Byndoor',            code: 'BYNR', eta: '15:48', minsAway: 98,  platform: 1, vendorCount: 1),
    Station(id: 10, name: 'Bhatkal',            code: 'BTJL', eta: '16:18', minsAway: 128, platform: 1, vendorCount: 1),
    Station(id: 11, name: 'Murdeshwar',         code: 'MRDW', eta: '16:42', minsAway: 148, platform: 1, vendorCount: 1),
    Station(id: 9,  name: 'Gokarna Road',       code: 'GOK',  eta: '17:22', minsAway: 186, platform: 1, vendorCount: 2),
  ];

  final List<Vendor> _vendors = const [
    Vendor(
      id: 1, stationId: 1, name: 'Sri Krishna Bhavan',
      imageUrl: 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=600&h=280&fit=crop',
      cuisineTags: ['Udupi', 'Dosa', 'Veg'],
      priceRange: '₹40–₹140', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.8, reviewCount: 2104,
      menu: [
        MenuItem(id: 1, name: 'Masala Dosa',           price: 70,  isVeg: true, desc: 'Crisp dosa with potato palya & chutney'),
        MenuItem(id: 2, name: 'Idli Vada Combo',        price: 55,  isVeg: true, desc: 'Two idlis, one vada, sambar'),
        MenuItem(id: 3, name: 'Filter Coffee',           price: 25,  isVeg: true, desc: 'Temple-town strong decoction'),
        MenuItem(id: 4, name: 'Sambar Rice',            price: 80,  isVeg: true, desc: 'Udupi sambar over hot rice'),
      ],
    ),
    Vendor(
      id: 2, stationId: 1, name: 'Malpe Harbour Kitchen',
      imageUrl: 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=600&h=280&fit=crop',
      cuisineTags: ['Coastal', 'Fish', 'Non-Veg'],
      priceRange: '₹90–₹280', isOpen: true, trusted: true, fssai: true, zeroCommission: false,
      rating: 4.6, reviewCount: 867,
      menu: [
        MenuItem(id: 5, name: 'Bangda Fry + Neer Dosa', price: 180, isVeg: false, desc: 'Mackerel fry with lacy neer dosa'),
        MenuItem(id: 6, name: 'Fish Curry Rice',        price: 160, isVeg: false, desc: 'Tangy coconut-fish curry'),
        MenuItem(id: 7, name: 'Anjal Tawa Fry',          price: 260, isVeg: false, desc: 'Seer fish, Malpe style'),
        MenuItem(id: 8, name: 'Neer Dosa (3 pcs)',       price: 50,  isVeg: true,  desc: 'Plain rice crepes'),
      ],
    ),
    Vendor(
      id: 3, stationId: 1, name: 'Car Street Snacks',
      imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&h=280&fit=crop',
      cuisineTags: ['Snacks', 'Tea', 'Veg'],
      priceRange: '₹20–₹80', isOpen: true, trusted: false, fssai: true, zeroCommission: true,
      rating: 4.4, reviewCount: 640,
      menu: [
        MenuItem(id: 9,  name: 'Goli Baje (6 pcs)',   price: 40, isVeg: true, desc: 'Udupi maida bajji with coconut chutney'),
        MenuItem(id: 10, name: 'Mangalore Buns (2)',  price: 45, isVeg: true, desc: 'Sweet banana buns'),
        MenuItem(id: 11, name: 'Cutting Chai',        price: 20, isVeg: true, desc: 'Platform tea'),
      ],
    ),
    Vendor(
      id: 4, stationId: 2, name: 'Padubidri Platform Tea',
      imageUrl: 'https://images.unsplash.com/photo-1571934811356-5cc061b6821f?w=600&h=280&fit=crop',
      cuisineTags: ['Tea', 'Snacks', 'Veg'],
      priceRange: '₹20–₹60', isOpen: true, trusted: false, fssai: true, zeroCommission: true,
      rating: 4.1, reviewCount: 94,
      menu: [
        MenuItem(id: 12, name: 'Ginger Tea',     price: 20, isVeg: true, desc: 'Strong chai for the halt'),
        MenuItem(id: 13, name: 'Bonda (4 pcs)',  price: 35, isVeg: true, desc: 'Potato bonda'),
        MenuItem(id: 14, name: 'Banana Chips',   price: 40, isVeg: true, desc: 'Kerala-style thin chips'),
      ],
    ),
    Vendor(
      id: 5, stationId: 6, name: 'Ghee Roast House',
      imageUrl: 'https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a?w=600&h=280&fit=crop',
      cuisineTags: ['Mangalorean', 'Ghee Roast', 'Non-Veg'],
      priceRange: '₹120–₹320', isOpen: true, trusted: true, fssai: true, zeroCommission: false,
      rating: 4.7, reviewCount: 1540,
      menu: [
        MenuItem(id: 15, name: 'Chicken Ghee Roast', price: 260, isVeg: false, desc: 'Bunt-style kori gassi roast'),
        MenuItem(id: 16, name: 'Prawn Ghee Roast',  price: 320, isVeg: false, desc: 'Byadgi chilli & ghee'),
        MenuItem(id: 17, name: 'Neer Dosa (4 pcs)', price: 60,  isVeg: true,  desc: 'To scoop the roast'),
      ],
    ),
    Vendor(
      id: 6, stationId: 6, name: 'Hampankatta Buns & Ice Cream',
      imageUrl: 'https://images.unsplash.com/photo-1570197788417-0e28382f621d?w=600&h=280&fit=crop',
      cuisineTags: ['Ice cream', 'Buns', 'Veg'],
      priceRange: '₹40–₹150', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.5, reviewCount: 980,
      menu: [
        MenuItem(id: 18, name: 'Gadbad Ice Cream',   price: 120, isVeg: true, desc: 'Mangalore classic tall glass'),
        MenuItem(id: 19, name: 'Mangalore Buns',     price: 50,  isVeg: true, desc: 'Soft banana buns with chutney'),
        MenuItem(id: 20, name: 'Tender Coconut',    price: 60,  isVeg: true, desc: 'Chilled, from the coast'),
      ],
    ),
    Vendor(
      id: 7, stationId: 7, name: 'Kundapur Kori Rotti',
      imageUrl: 'https://images.unsplash.com/photo-1600628421066-f6bda6a7b976?w=600&h=280&fit=crop',
      cuisineTags: ['Kundapur', 'Kori Rotti', 'Non-Veg'],
      priceRange: '₹90–₹220', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.6, reviewCount: 412,
      menu: [
        MenuItem(id: 21, name: 'Kori Rotti Meal', price: 180, isVeg: false, desc: 'Crisp rice rotti with chicken curry'),
        MenuItem(id: 22, name: 'Kori Gassi + Rice', price: 160, isVeg: false, desc: 'Coconut chicken curry'),
        MenuItem(id: 23, name: 'Veg Saaru Rice',    price: 90,  isVeg: true,  desc: 'Pepper rasam rice'),
      ],
    ),
    Vendor(
      id: 8, stationId: 5, name: 'Surathkal NITK Snacks',
      imageUrl: 'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&h=280&fit=crop',
      cuisineTags: ['Snacks', 'Coastal', 'Veg'],
      priceRange: '₹30–₹100', isOpen: true, trusted: false, fssai: true, zeroCommission: false,
      rating: 4.2, reviewCount: 221,
      menu: [
        MenuItem(id: 24, name: 'Pundi (3 pcs)',   price: 40, isVeg: true, desc: 'Steamed rice dumplings'),
        MenuItem(id: 25, name: 'Goli Baje',      price: 35, isVeg: true, desc: 'Hot with coconut chutney'),
        MenuItem(id: 26, name: 'Filter Coffee',   price: 30, isVeg: true, desc: 'South Indian decoction'),
      ],
    ),
    Vendor(
      id: 9, stationId: 9, name: 'Gokarna Beach Shack',
      imageUrl: 'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=600&h=280&fit=crop',
      cuisineTags: ['Beach', 'Konkan', 'Non-Veg'],
      priceRange: '₹80–₹240', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.3, reviewCount: 356,
      menu: [
        MenuItem(id: 27, name: 'Fish Thali',      price: 200, isVeg: false, desc: 'Rice, fry, curry, sol kadhi'),
        MenuItem(id: 28, name: 'Veg Konkani Thali', price: 140, isVeg: true,  desc: 'Rice, valval, pickle, buttermilk'),
        MenuItem(id: 29, name: 'Sol Kadhi',       price: 50,  isVeg: true,  desc: 'Kokum + coconut cooler'),
      ],
    ),
    Vendor(
      id: 10, stationId: 3, name: 'Barkur Temple Canteen',
      imageUrl: 'https://images.unsplash.com/photo-1567188040759-fb8a803d0272?w=600&h=280&fit=crop',
      cuisineTags: ['Temple', 'Meals', 'Veg'],
      priceRange: '₹25–₹90', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.4, reviewCount: 178,
      menu: [
        MenuItem(id: 30, name: 'Holige (2 pcs)', price: 50, isVeg: true, desc: 'Jaggery-coconut obbattu'),
        MenuItem(id: 31, name: 'Rice Bath',     price: 70, isVeg: true, desc: 'Temple-style vegetable rice'),
        MenuItem(id: 32, name: 'Buttermilk',    price: 25, isVeg: true, desc: 'Spiced majjige'),
      ],
    ),
    Vendor(
      id: 11, stationId: 4, name: 'Mulki River Catch',
      imageUrl: 'https://images.unsplash.com/photo-1559847844-5315695dadae?w=600&h=280&fit=crop',
      cuisineTags: ['Fish', 'Coastal', 'Non-Veg'],
      priceRange: '₹80–₹220', isOpen: true, trusted: false, fssai: true, zeroCommission: true,
      rating: 4.3, reviewCount: 156,
      menu: [
        MenuItem(id: 33, name: 'Prawn Fry Rice',   price: 180, isVeg: false, desc: 'River-mouth prawns, red masala'),
        MenuItem(id: 34, name: 'Kane Rava Fry',    price: 220, isVeg: false, desc: 'Ladyfish with rava crust'),
        MenuItem(id: 35, name: 'Coconut Rice',     price: 80,  isVeg: true,  desc: 'Tempered with curry leaves'),
      ],
    ),
    Vendor(
      id: 12, stationId: 8, name: 'Byndoor Beach Meals',
      imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&h=280&fit=crop',
      cuisineTags: ['Meals', 'Konkan', 'Non-Veg'],
      priceRange: '₹70–₹180', isOpen: true, trusted: true, fssai: true, zeroCommission: false,
      rating: 4.2, reviewCount: 203,
      menu: [
        MenuItem(id: 36, name: 'Byndoor Fish Curry Meal', price: 170, isVeg: false, desc: 'Tamarind-coconut curry, rice, pickle'),
        MenuItem(id: 37, name: 'Crab Sukka',              price: 180, isVeg: false, desc: 'Dry roast with Byadgi chilli'),
        MenuItem(id: 38, name: 'Veg Meals',               price: 90,  isVeg: true,  desc: 'Rice, sambar, palya, curd'),
      ],
    ),
    Vendor(
      id: 13, stationId: 10, name: 'Bhatkal Biryani House',
      imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&h=280&fit=crop',
      cuisineTags: ['Biryani', 'Navayath', 'Non-Veg'],
      priceRange: '₹100–₹260', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.7, reviewCount: 891,
      menu: [
        MenuItem(id: 39, name: 'Bhatkali Chicken Biryani', price: 220, isVeg: false, desc: 'Navayath spice, short-grain rice'),
        MenuItem(id: 40, name: 'Mutton Biryani',           price: 260, isVeg: false, desc: 'Slow-cooked, limited pots'),
        MenuItem(id: 41, name: 'Egg Biryani',              price: 140, isVeg: false, desc: 'Two eggs, raita'),
        MenuItem(id: 42, name: 'Veg Dum Biryani',          price: 120, isVeg: true,  desc: 'Saffron rice, mixed veg'),
      ],
    ),
    Vendor(
      id: 14, stationId: 11, name: 'Murdeshwar Temple Kitchen',
      imageUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=600&h=280&fit=crop',
      cuisineTags: ['Temple', 'Coastal', 'Veg'],
      priceRange: '₹40–₹130', isOpen: true, trusted: true, fssai: true, zeroCommission: true,
      rating: 4.5, reviewCount: 640,
      menu: [
        MenuItem(id: 43, name: 'Temple Meals',     price: 90,  isVeg: true, desc: 'Rice, sambar, kosambari, payasa'),
        MenuItem(id: 44, name: 'Poha + Coffee',    price: 50,  isVeg: true, desc: 'Coastal avalakki with filter coffee'),
        MenuItem(id: 45, name: 'Coconut Payasa',   price: 40,  isVeg: true, desc: 'Jaggery kheer in a cup'),
      ],
    ),
    Vendor(
      id: 15, stationId: 12, name: 'Central Station Tiffin',
      imageUrl: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&h=280&fit=crop',
      cuisineTags: ['Tiffin', 'Mangalorean', 'Veg'],
      priceRange: '₹30–₹110', isOpen: true, trusted: false, fssai: true, zeroCommission: true,
      rating: 4.3, reviewCount: 512,
      menu: [
        MenuItem(id: 46, name: 'Rava Idli (4 pcs)', price: 55, isVeg: true, desc: 'Soft, with sambar & chutney'),
        MenuItem(id: 47, name: 'Buns + Chutney',    price: 50, isVeg: true, desc: 'Sweet banana buns'),
        MenuItem(id: 48, name: 'Kesari Bath',       price: 40, isVeg: true, desc: 'Saffron rava sweet'),
        MenuItem(id: 49, name: 'Filter Coffee',     price: 30, isVeg: true, desc: 'MAQ platform decoction'),
      ],
    ),
    Vendor(
      id: 16, stationId: 9, name: 'Kumta Kokum Cafe',
      imageUrl: 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&h=280&fit=crop',
      cuisineTags: ['Cafe', 'Konkan', 'Veg'],
      priceRange: '₹40–₹120', isOpen: true, trusted: false, fssai: true, zeroCommission: false,
      rating: 4.1, reviewCount: 188,
      menu: [
        MenuItem(id: 50, name: 'Kokum Sherbet',  price: 40,  isVeg: true, desc: 'Chilled agal, cumin'),
        MenuItem(id: 51, name: 'Pathrado (4 pcs)', price: 80, isVeg: true, desc: 'Colocasia leaf rolls'),
        MenuItem(id: 52, name: 'Upkari Rice',     price: 110, isVeg: true, desc: 'Beans upkari over steamed rice'),
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
