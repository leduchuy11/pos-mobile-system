import 'dart:convert';
import 'package:demo_store/data/datasources/api_config.dart';
import 'package:demo_store/data/model/notification_model.dart';
import 'package:demo_store/data/model/order_model.dart';
import 'package:http/http.dart' as http;

class NotificationRemoteDataSource {
  static String get _baseUrl => '${ApiConfig.baseUrl}/notifications';
  static String get _ordersUrl => '${ApiConfig.baseUrl}/orders';

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// 1. Đăng ký / cập nhật FCM Token lên bảng user_devices
  Future<void> registerDeviceToken({
    required String token,
    required String fcmToken,
    required String platform,
  }) async {
    final res = await http
        .post(
      Uri.parse('$_baseUrl/token'),
      headers: _headers(token),
      body: jsonEncode({
        'fcm_token': fcmToken,
        'platform': platform,
      }),
    )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Không thể lưu FCM token');
    }
  }

  /// 2. Gỡ FCM Token khi người dùng đăng xuất
  Future<void> removeDeviceToken({
    required String token,
    required String fcmToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/token').replace(
      queryParameters: {'fcm_token': fcmToken},
    );
    await http
        .delete(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 10));
  }

  /// 3. Lấy danh sách thông báo & số lượng chưa đọc
  Future<({int unreadCount, List<NotificationModel> items})> getNotifications(
      String token,
      ) async {
    final res = await http
        .get(Uri.parse(_baseUrl), headers: _headers(token))
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      final rawItems = (data['items'] as List<dynamic>? ?? []);
      return (
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      items: rawItems
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      );
    }
    throw Exception(body['message'] ?? 'Không tải được thông báo');
  }

  /// 4. Đánh dấu 1 thông báo đã đọc
  Future<void> markAsRead({
    required String token,
    required int notificationId,
  }) async {
    await http
        .patch(
      Uri.parse('$_baseUrl/$notificationId/read'),
      headers: _headers(token),
    )
        .timeout(const Duration(seconds: 10));
  }

  /// 5. Đánh dấu tất cả đã đọc
  Future<void> markAllAsRead(String token) async {
    await http
        .patch(
      Uri.parse('$_baseUrl/read-all'),
      headers: _headers(token),
    )
        .timeout(const Duration(seconds: 10));
  }

  /// 6. Lấy chi tiết hóa đơn theo order_id khi bấm vào thông báo
  Future<OrderModel> getOrderDetail({
    required String token,
    required int orderId,
  }) async {
    final res = await http
        .get(Uri.parse('$_ordersUrl/$orderId'), headers: _headers(token))
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && body['success'] == true) {
      return OrderModel.fromJson(body['data'] as Map<String, dynamic>);
    }
    throw Exception(body['message'] ?? 'Không tìm thấy hóa đơn');
  }
}