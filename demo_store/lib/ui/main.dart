import 'package:demo_store/data/datasources/product_remote_datasource.dart';
import 'package:demo_store/ui/auth/login_screen.dart';
import 'package:demo_store/ui/main/main_screen.dart';
import 'package:demo_store/viewmodel/auth_viewmodel.dart';
import 'package:demo_store/viewmodel/cart_viewmodel.dart';
import 'package:demo_store/viewmodel/home_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo_store/services/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:demo_store/ui/main/invoice/invoice_preview_screen.dart';
import 'package:demo_store/viewmodel/notification_viewmodel.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.instance.init();
  PushNotificationService.instance.onNotificationTap = (data) async {
    final rawOrderId = data['order_id']?.toString() ?? '';
    final orderId = int.tryParse(rawOrderId);
    if (orderId == null) return;

    // Chờ frame đầu dựng xong nếu app vừa được mở từ trạng thái tắt hẳn
    await Future.delayed(const Duration(milliseconds: 400));
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    final notifyVm = ctx.read<NotificationViewModel>();
    final order = await notifyVm.fetchOrderDetail(orderId);
    if (order != null && rootNavigatorKey.currentState != null) {
      rootNavigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => InvoicePreviewScreen(order: order),
        ),
      );
    }
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel()..checkAuthStatus(),
        ),
        Provider<ProductRemoteDataSource>(
          create: (_) => ProductRemoteDataSource(),
        ),
        ChangeNotifierProvider<HomeViewModel>(
          create: (context) => HomeViewModel(
            context.read<ProductRemoteDataSource>(),
          ),
        ),
        ChangeNotifierProxyProvider<AuthViewModel, CartViewModel>(
          create: (_) => CartViewModel(),
          update: (_, authVm, cartVm) {
            final vm = cartVm ?? CartViewModel();
            vm.syncAuth(
              token: authVm.token,
              staffName: authVm.currentUser?.fullName,
            );
            return vm;
          },
        ),
        ChangeNotifierProxyProvider<AuthViewModel, NotificationViewModel>(
          create: (_) => NotificationViewModel(),
          update: (_, authVm, notifyVm) {
            final vm = notifyVm ?? NotificationViewModel();
            vm.syncAuth(token: authVm.token);
            return vm;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Flutter Demo Project',
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authVm, _) {
        if (authVm.isCheckingAuth) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return authVm.isLoggedIn ? const MainScreen() : const LoginScreen();
      },
    );
  }
}