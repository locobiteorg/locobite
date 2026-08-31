import 'dart:convert';
import 'package:http/http.dart' as http;
import '../shared/models/models.dart';
import '../shared/models/order.dart' as model;

class ApiService {
  static const String baseUrl = 'http://localhost:8080';
  
  // Active session customer details
  static Customer? currentCustomer;
  
  // Cache of the most recently placed/active order for testing
  static model.Order? currentOrder;

  // Maps frontend mock integer IDs to database UUID strings
  static String mapVendorId(int id) {
    if (id == 1) return '11111111-1111-1111-1111-111111111111';
    if (id == 2) return '22222222-2222-2222-2222-222222222222';
    if (id == 3) return '33333333-3333-3333-3333-333333333333';
    return '11111111-1111-1111-1111-111111111111';
  }

  static String mapMenuItemId(int id) {
    if (id == 1) return '11111111-1111-1111-1111-111111111001';
    if (id == 2) return '11111111-1111-1111-1111-111111111002';
    if (id == 3) return '11111111-1111-1111-1111-111111111003';
    if (id == 4) return '11111111-1111-1111-1111-111111111004';
    if (id == 5) return '22222222-2222-2222-2222-222222222005';
    if (id == 6) return '22222222-2222-2222-2222-222222222006';
    if (id == 7) return '22222222-2222-2222-2222-222222222007';
    if (id == 8) return '22222222-2222-2222-2222-222222222008';
    if (id == 9) return '33333333-3333-3333-3333-333333333009';
    if (id == 10) return '33333333-3333-3333-3333-333333333010';
    if (id == 11) return '33333333-3333-3333-3333-333333333011';
    return '11111111-1111-1111-1111-111111111001';
  }

  // Log in using phone number (and auto-register)
  static Future<Customer> login(String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/customers/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final customer = Customer.fromJson(data);
      currentCustomer = customer;
      return customer;
    } else {
      throw _parseError(response);
    }
  }

  // Soft delete customer account
  static Future<void> deleteAccount(String customerId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/customers/$customerId'),
    );

    if (response.statusCode == 200) {
      currentCustomer = null;
    } else {
      throw _parseError(response);
    }
  }

  // Refresh customer details (dues, block status)
  static Future<Customer> refreshCustomer(String customerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/customers/$customerId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final customer = Customer.fromJson(data);
      currentCustomer = customer;
      return customer;
    } else {
      throw _parseError(response);
    }
  }

  // Standalone endpoint to clear outstanding dues
  static Future<Map<String, dynamic>> clearDues(String customerId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/customers/$customerId/clear-dues'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (currentCustomer != null && currentCustomer!.id == customerId) {
        currentCustomer!.duesBalancePaise = 0;
        currentCustomer!.isBlockedForDues = false;
      }
      return data;
    } else {
      throw _parseError(response);
    }
  }

  // Record vendor card tap view
  static Future<void> recordVendorTap(String vendorId, String customerId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/vendors/$vendorId/tap'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'customer_id': customerId}),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Fail silently on analytics view count to prevent breaking UI
    }
  }

  // Place order
  static Future<model.Order> placeOrder({
    required String customerId,
    required String vendorId,
    required String trainNumber,
    required String direction,
    required String seatCoach,
    required String scheduledArrival,
    required List<Map<String, dynamic>> items,
  }) async {
    final body = {
      'customer_id': customerId,
      'vendor_id': vendorId,
      'train_number': trainNumber,
      'direction': direction,
      'seat_coach': seatCoach,
      'scheduled_arrival': scheduledArrival,
      'items': items,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final order = model.Order.fromJson(data);
      currentOrder = order;
      // Refresh customer dues state after placing order
      await refreshCustomer(customerId);
      return order;
    } else {
      throw _parseError(response);
    }
  }

  // Retrieve customer orders history
  static Future<List<model.Order>> getOrders(String customerId, {int limit = 20, int offset = 0}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/customers/$customerId/orders?limit=$limit&offset=$offset'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = data['orders'] as List? ?? [];
      return list.map((e) => model.Order.fromJson(e)).toList();
    } else {
      throw _parseError(response);
    }
  }

  // Cancel order (customer-initiated)
  static Future<model.Order> cancelOrder(String orderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/cancel'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final order = model.Order.fromJson(data);
      currentOrder = order;
      return order;
    } else {
      throw _parseError(response);
    }
  }

  // Accept order (simulated vendor advance)
  static Future<model.Order> acceptOrder(String orderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/accept'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final order = model.Order.fromJson(data);
      currentOrder = order;
      return order;
    } else {
      throw _parseError(response);
    }
  }

  // Reject order (simulated vendor advance)
  static Future<model.Order> rejectOrder(String orderId, String reason) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/reject'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'reason': reason}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final order = model.Order.fromJson(data);
      currentOrder = order;
      if (currentCustomer != null) {
        await refreshCustomer(currentCustomer!.id);
      }
      return order;
    } else {
      throw _parseError(response);
    }
  }

  // Advance order status (preparing/ready/out-for-delivery/delivered)
  static Future<model.Order> advanceOrder(String orderId, String step) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/$step'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final order = model.Order.fromJson(data);
      currentOrder = order;
      return order;
    } else {
      throw _parseError(response);
    }
  }

  // Set order delay chip (+15, +30, on-time)
  static Future<Map<String, dynamic>> delayOrder(String orderId, String chip) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/orders/$orderId/delay'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'chip': chip}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (currentOrder != null && currentOrder!.id == orderId) {
        currentOrder!.delayUpdatedAt = data['delay_updated_at'];
      }
      return data;
    } else {
      throw _parseError(response);
    }
  }

  // Generate payment QR (collect-payment)
  static Future<Map<String, dynamic>> collectPayment(String orderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/collect-payment'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw _parseError(response);
    }
  }

  // Record cash payment
  static Future<Map<String, dynamic>> recordCashReceived(String orderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/cash-received'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (currentOrder != null && currentOrder!.id == orderId) {
        currentOrder!.paymentVerified = false;
      }
      return data;
    } else {
      throw _parseError(response);
    }
  }

  // Simulate payment webhook UPI confirmation
  static Future<Map<String, dynamic>> simulatePaymentWebhook({
    required String eventId,
    required String providerRef,
    required String status,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/webhooks/payment'),
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Signature': 'dev-signed', // Matches dev webhook stub
      },
      body: jsonEncode({
        'event_id': eventId,
        'provider_ref': providerRef,
        'status': status,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (currentOrder != null) {
        currentOrder!.paymentVerified = true;
      }
      return data;
    } else {
      throw _parseError(response);
    }
  }

  // File dispute
  static Future<Map<String, dynamic>> fileDispute(String orderId, String disputeType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/dispute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'type': disputeType}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (currentCustomer != null) {
        await refreshCustomer(currentCustomer!.id);
      }
      return data;
    } else {
      throw _parseError(response);
    }
  }

  // Parse server error body
  static Exception _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      final errorMsg = data['error'] ?? 'API request failed';
      final errorCode = data['code'] ?? 'api_error';
      return Exception('$errorMsg ($errorCode)');
    } catch (_) {
      return Exception('HTTP error ${response.statusCode}: ${response.reasonPhrase}');
    }
  }
}
