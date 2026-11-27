import 'dart:convert';
import 'package:demo_store/data/datasources/api_config.dart';
import 'package:demo_store/data/model/cart_item_model.dart';
import 'package:demo_store/data/model/order_model.dart';
import 'package:http/http.dart' as http;

class CartRemoteDataSource {
  static String get _cartUrl => '${ApiConfig.baseUrl}/cart';
  static String get _ordersUrl => '${ApiConfig.baseUrl}/orders';

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Lấy giỏ hàng hiện tại từ MySQL
  Future<List<CartItemModel>> getCart(String token) async {
    final res = await http
        .get(Uri.parse(_cartUrl), headers: _headers(token))
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && body['success'] == true) {
      final rawList = body['data'] as List<dynamic>;
      return rawList
          .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(body['message'] ?? 'Không tải được giỏ hàng');
  }

  /// Thêm sản phẩm vào giỏ (hoặc cộng dồn nếu đã có)
  Future<List<CartItemModel>> addToCart({
    required String token,
    required int productId,
    required int quantity,
  }) async {
    final res = await http
        .post(
      Uri.parse('$_cartUrl/items'),
      headers: _headers(token),
      body: jsonEncode({
        'product_id': productId,
        'quantity': quantity,
      }),
    )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && body['success'] == true) {
      final rawList = body['data'] as List<dynamic>;
      return rawList
          .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(body['message'] ?? 'Không thể thêm vào giỏ hàng');
  }

  /// Cập nhật số lượng hoặc trạng thái tích chọn của 1 sản phẩm
  Future<void> updateCartItem({
    required String token,
    required int productId,
    int? quantity,
    bool? isSelected,
  }) async {
    final payload = <String, dynamic>{};
    if (quantity != null) payload['quantity'] = quantity;
    if (isSelected != null) payload['is_selected'] = isSelected;

    final res = await http
        .patch(
      Uri.parse('$_cartUrl/items/$productId'),
      headers: _headers(token),
      body: jsonEncode(payload),
    )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Không thể cập nhật giỏ hàng');
    }
  }

  /// Chọn tất cả / bỏ chọn tất cả
  Future<void> toggleSelectAll({
    required String token,
    required bool isSelected,
  }) async {
    final res = await http
        .patch(
      Uri.parse('$_cartUrl/select-all'),
      headers: _headers(token),
      body: jsonEncode({'is_selected': isSelected}),
    )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Không thể cập nhật chọn tất cả');
    }
  }

  /// Xóa 1 sản phẩm khỏi giỏ
  Future<void> removeCartItem({
    required String token,
    required int productId,
  }) async {
    final res = await http
        .delete(
      Uri.parse('$_cartUrl/items/$productId'),
      headers: _headers(token),
    )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Không thể xóa sản phẩm');
    }
  }

  /// Thanh toán: tạo hóa đơn & xóa các món đã chọn trên DB (Transaction)
  Future<OrderModel> createOrder({
    required String token,
    required String paymentMethod,
    required String note,
    required String staffName,
  }) async {
    final res = await http
        .post(
      Uri.parse(_ordersUrl),
      headers: _headers(token),
      body: jsonEncode({
        'payment_method': paymentMethod,
        'note': note,
        'staff_name': staffName,
      }),
    )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if ((res.statusCode == 200 || res.statusCode == 201) &&
        body['success'] == true) {
      return OrderModel.fromJson(body['data'] as Map<String, dynamic>);
    }
    throw Exception(body['message'] ?? 'Thanh toán thất bại');
  }
}