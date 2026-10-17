import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/models/models.dart';
import '../shared/models/order.dart' as model;

class ApiService {
  /// Test-only panel that lets the customer act as the merchant (accept,
  /// advance, reject). OFF in real builds — the merchant app does this now.
  /// Enable with --dart-define=DEMO_CONTROLS=true.
  static const bool showDemoControls = bool.fromEnvironment('DEMO_CONTROLS');

  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://locobite.onrender.com');
  
  // Active session customer details
  static Customer? currentCustomer;
  
  // Cache of the most recently placed/active order for testing
  static model.Order? currentOrder;

  /// Live vendors with their available menus (GET /vendors). The server
  /// already orders them by tier and trust.
  static Future<List<Map<String, dynamic>>> getVendors() async {
    final response = await http.get(Uri.parse('$baseUrl/vendors')).timeout(const Duration(seconds: 60));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['vendors'] as List).cast<Map<String, dynamic>>();
    }
    throw _parseError(response);
  }

  /// Remembered login: Supabase keeps the session on the device and refreshes
  /// it until the user signs out, so returning users skip the OTP. Returns
  /// false when there is no saved session. Throws if the backend can't be
  /// reached (the session is kept, so the next launch simply tries again).
  static Future<bool> restoreSession() async {
    String? email;
    try {
      email = Supabase.instance.client.auth.currentSession?.user.email;
    } catch (_) {
      return false; // Supabase not initialised (e.g. in tests)
    }
    if (email == null) return false;
    await login(email).timeout(const Duration(seconds: 70));
    return true;
  }

  /// Ends the remembered session. Call on sign-out / account deletion, or the
  /// next launch would sign the user straight back in.
  static Future<void> endSession() async {
    currentCustomer = null;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  static Future<Customer> login(String phone, {String? name}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/customers/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final customer = Customer.fromJson(data);
      final typed = name?.trim();
      if (typed != null && typed.isNotEmpty) {
        customer.name = typed;
      }
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
