class OrderItem {
  final String menuItemId;
  final String name;
  final int quantity;
  final int unitPricePaise;
  final bool isTenMin;

  OrderItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPricePaise,
    required this.isTenMin,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      menuItemId: json['menu_item_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPricePaise: json['unit_price_paise'] ?? 0,
      isTenMin: json['is_ten_min'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_item_id': menuItemId,
      'name': name,
      'quantity': quantity,
      'unit_price_paise': unitPricePaise,
      'is_ten_min': isTenMin,
    };
  }
}

class Order {
  final String id;
  final String customerId;
  final String vendorId;
  String status;
  int amountPaise;
  final String trainNumber;
  final String direction;
  final String seatCoach;
  final String scheduledArrival;
  String? delayUpdatedAt;
  String? rejectionReason;
  String pickupStatus;
  final bool hasTenMinItem;
  bool paymentVerified;
  final String createdAt;
  final String updatedAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.status,
    required this.amountPaise,
    required this.trainNumber,
    required this.direction,
    required this.seatCoach,
    required this.scheduledArrival,
    this.delayUpdatedAt,
    this.rejectionReason,
    required this.pickupStatus,
    required this.hasTenMinItem,
    required this.paymentVerified,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List? ?? [];
    List<OrderItem> itemList = rawItems.map((e) => OrderItem.fromJson(e)).toList();

    return Order(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      status: json['status'] ?? '',
      amountPaise: json['amount_paise'] ?? 0,
      trainNumber: json['train_number'] ?? '',
      direction: json['direction'] ?? '',
      seatCoach: json['seat_coach'] ?? '',
      scheduledArrival: json['scheduled_arrival'] ?? '',
      delayUpdatedAt: json['delay_updated_at'],
      rejectionReason: json['rejection_reason'],
      pickupStatus: json['pickup_status'] ?? 'pending',
      hasTenMinItem: json['has_ten_min_item'] ?? false,
      paymentVerified: json['payment_verified'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      items: itemList,
    );
  }
}