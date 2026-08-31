class TrainInfo {
  String number;
  String coach;
  String seat;
  String arrival;
  bool delayed;
  int delayMins;

  TrainInfo({
    required this.number,
    required this.coach,
    required this.seat,
    required this.arrival,
    this.delayed = false,
    this.delayMins = 0,
  });
}

class Station {
  final int id;
  final String name;
  final String code;
  final String eta;
  final int minsAway;
  final int platform;
  final int vendorCount;

  const Station({
    required this.id, required this.name, required this.code,
    required this.eta, required this.minsAway, required this.platform,
    required this.vendorCount,
  });
}

class MenuItem {
  final int id;
  final String name;
  final int price;
  final bool isVeg;
  final String desc;

  const MenuItem({
    required this.id, required this.name, required this.price,
    required this.isVeg, required this.desc,
  });
}

class Vendor {
  final int id;
  final int stationId;
  final String name;
  final String imageUrl;
  final List<String> cuisineTags;
  final String priceRange;
  final bool isOpen;
  final bool trusted;
  final bool fssai;
  final bool zeroCommission;
  final double rating;
  final int reviewCount;
  final List<MenuItem> menu;

  const Vendor({
    required this.id, required this.stationId, required this.name,
    required this.imageUrl, required this.cuisineTags, required this.priceRange,
    required this.isOpen, required this.trusted, required this.fssai,
    required this.zeroCommission, required this.rating, required this.reviewCount,
    required this.menu,
  });
}

class CartItem {
  final int menuItemId;
  final int vendorId;
  final String name;
  final int price;
  int qty;

  CartItem({
    required this.menuItemId, required this.vendorId,
    required this.name, required this.price, required this.qty,
  });
}

class Customer {
  final String id;
  final String phone;
  final String name;
  int duesBalancePaise;
  bool isBlockedForDues;
  String? deletedAt;

  Customer({
    required this.id,
    required this.phone,
    required this.name,
    this.duesBalancePaise = 0,
    this.isBlockedForDues = false,
    this.deletedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? json['customer_id'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      duesBalancePaise: json['dues_balance_paise'] ?? 0,
      isBlockedForDues: json['is_blocked_for_dues'] ?? false,
      deletedAt: json['deleted_at'],
    );
  }
}
