import 'package:demo_store/data/datasources/notification_remote_datasource.dart';
import 'package:demo_store/data/model/notification_model.dart';
import 'package:demo_store/data/model/order_model.dart';
import 'package:demo_store/services/push_notification_service.dart';
import 'package:flutter/foundation.dart';

class NotificationViewModel extends ChangeNotifier {
  final NotificationRemoteDataSource _dataSource =
  NotificationRemoteDataSource();

  final List<NotificationModel> _items = [];
  String? _token;
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationModel> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  NotificationViewModel() {
    // Tự động cập nhật danh sách khi có thông báo đẩy về lúc app đang mở
    PushNotificationService.instance.onForegroundMessageReceived = () {
      if (_token != null) {
        fetchNotifications();
      }
    };

    // Tự động đẩy token mới lên server nếu Firebase làm mới FCM Token
    PushNotificationService.instance.onTokenRefresh = (newFcmToken) {
      if (_token != null) {
        _syncDeviceToken(_token!, customFcmToken: newFcmToken);
      }
    };
  }

  /// Đồng bộ tự động với AuthViewModel (đăng nhập / đăng xuất)
  void syncAuth({required String? token}) {
    if (_token == token) return;

    final previousToken = _token;
    _token = token;

    if (token == null) {
      // Vừa đăng xuất -> gỡ FCM Token của máy này khỏi tài khoản cũ
      if (previousToken != null) {
        _unregisterDeviceToken(previousToken);
      }
      _items.clear();
      _unreadCount = 0;
      _errorMessage = null;
      Future.microtask(notifyListeners);
    } else {
      // Vừa đăng nhập / khôi phục phiên -> đăng ký FCM Token & tải lịch sử
      Future.microtask(() async {
        await _syncDeviceToken(token);
        await fetchNotifications();
      });
    }
  }

  Future<void> _syncDeviceToken(
      String authToken, {
        String? customFcmToken,
      }) async {
    try {
      final fcmToken =
          customFcmToken ?? await PushNotificationService.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      await _dataSource.registerDeviceToken(
        token: authToken,
        fcmToken: fcmToken,
        platform: PushNotificationService.instance.platformName,
      );
      debugPrint('=== ĐÃ ĐỒNG BỘ FCM TOKEN LÊN MYSQL ===');
    } catch (e) {
      debugPrint('=== LỖI ĐỒNG BỘ FCM TOKEN: $e ===');
    }
  }

  Future<void> _unregisterDeviceToken(String oldAuthToken) async {
    try {
      final fcmToken = await PushNotificationService.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      await _dataSource.removeDeviceToken(
        token: oldAuthToken,
        fcmToken: fcmToken,
      );
      debugPrint('=== ĐÃ GỠ FCM TOKEN KHI ĐĂNG XUẤT ===');
    } catch (e) {
      debugPrint('=== LỖI GỠ FCM TOKEN: $e ===');
    }
  }

  /// Tải lại toàn bộ lịch sử thông báo từ MySQL
  Future<void> fetchNotifications() async {
    final token = _token;
    if (token == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _dataSource.getNotifications(token);
      _items
        ..clear()
        ..addAll(result.items);
      _unreadCount = result.unreadCount;
    } catch (e) {
      debugPrint('=== FETCH NOTIFICATIONS ERROR: $e ===');
      _errorMessage = 'Không thể tải danh sách thông báo';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Đánh dấu 1 thông báo đã đọc (Optimistic UI)
  Future<void> markAsRead(NotificationModel item) async {
    final token = _token;
    if (token == null || item.isRead) return;

    item.isRead = true;
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();

    try {
      await _dataSource.markAsRead(token: token, notificationId: item.id);
    } catch (_) {
      item.isRead = false;
      _unreadCount++;
      notifyListeners();
    }
  }

  /// Đánh dấu tất cả đã đọc
  Future<void> markAllAsRead() async {
    final token = _token;
    if (token == null || _unreadCount == 0) return;

    for (final item in _items) {
      item.isRead = true;
    }
    _unreadCount = 0;
    notifyListeners();

    try {
      await _dataSource.markAllAsRead(token);
    } catch (_) {
      await fetchNotifications();
    }
  }

  /// Lấy chi tiết hóa đơn để mở màn hình PDF khi người dùng bấm vào thông báo
  Future<OrderModel?> fetchOrderDetail(int orderId) async {
    final token = _token;
    if (token == null) return null;

    try {
      return await _dataSource.getOrderDetail(token: token, orderId: orderId);
    } catch (e) {
      debugPrint('=== FETCH ORDER DETAIL ERROR: $e ===');
      return null;
    }
  }
}