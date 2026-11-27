import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Hàm top-level bắt buộc để nhận Push Notification khi app chạy ngầm hoặc tắt hẳn
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('=== [FCM BACKGROUND] ${message.notification?.title} ===');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  /// Khớp chính xác với channelId ở Node.js (notification.service.js)
  static const AndroidNotificationChannel _orderChannel =
  AndroidNotificationChannel(
    'order_notifications',
    'Thông báo đơn hàng',
    description: 'Hiển thị thông báo khi thanh toán đơn hàng thành công',
    importance: Importance.max,
    playSound: true,
  );

  /// Callback sẽ được Bước 4 gắn vào để đồng bộ danh sách thông báo & mở hóa đơn
  void Function(Map<String, dynamic> data)? onNotificationTap;
  VoidCallback? onForegroundMessageReceived;
  void Function(String newToken)? onTokenRefresh;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Xin quyền hiển thị thông báo (hỗ trợ cả iOS và Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('=== [FCM PERMISSION] ${settings.authorizationStatus} ===');

    // 2. Cho phép iOS tự hiện banner + âm thanh ngay cả khi app đang mở
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Khởi tạo flutter_local_notifications (để Android hiện banner nổi khi app đang mở)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            onNotificationTap?.call(data);
          } catch (_) {}
        }
      },
    );

    // 4. Đăng ký kênh thông báo ưu tiên cao trên Android
    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_orderChannel);
    }

    // 5. Lắng nghe thông báo khi app ĐANG MỞ (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '=== [FCM FOREGROUND] ${message.notification?.title}: ${message.notification?.body} ===',
      );
      onForegroundMessageReceived?.call();

      // Trên Android, mặc định ẩn banner khi app đang mở -> dùng Local Notifications kéo banner xuống
      // Trên iOS đã bật setForegroundNotificationPresentationOptions nên không gọi show() tránh bị hiện 2 lần
      final notification = message.notification;
      if (!kIsWeb && Platform.isAndroid && notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _orderChannel.id,
              _orderChannel.name,
              channelDescription: _orderChannel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // 6. Lắng nghe khi người dùng BẤM VÀO thông báo lúc app đang chạy ngầm
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('=== [FCM OPENED FROM BACKGROUND] ${message.data} ===');
      onNotificationTap?.call(message.data);
    });

    // 7. Lắng nghe nếu Firebase tự làm mới FCM Token
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('=== [FCM TOKEN REFRESHED] $newToken ===');
      onTokenRefresh?.call(newToken);
    });

    // In token ra log để kiểm tra ở Bước 3
    final token = await getToken();
    debugPrint('=== [FCM TOKEN] $token ===');
  }

  /// Kiểm tra xem app có được mở lên từ việc bấm vào thông báo lúc đang tắt hẳn không
  Future<void> checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('=== [FCM OPENED FROM TERMINATED] ${initialMessage.data} ===');
      onNotificationTap?.call(initialMessage.data);
    }
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('=== [FCM GET TOKEN ERROR] $e ===');
      return null;
    }
  }

  String get platformName {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }
}