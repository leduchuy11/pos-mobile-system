import 'package:demo_store/ui/main/account/account_screen.dart';
import 'package:demo_store/ui/main/cart/cart_screen.dart';
import 'package:demo_store/ui/main/home/home_screen.dart';
import 'package:demo_store/ui/main/notification/notification_screen.dart';
import 'package:demo_store/viewmodel/cart_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo_store/services/push_notification_service.dart';
import 'package:demo_store/viewmodel/notification_viewmodel.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CartScreen(),
    NotificationScreen(),
    AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.checkInitialMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
              if (index == 2) {
                context.read<NotificationViewModel>().fetchNotifications();
              }
            },
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            enableFeedback: false,
            backgroundColor: Colors.white,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey.shade600,
            iconSize: 28,
            selectedFontSize: 13,
            unselectedFontSize: 13,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            items: [
              const BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Icon(Icons.home_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Icon(Icons.home),
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _CartNavIcon(isActive: false),
                ),
                activeIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _CartNavIcon(isActive: true),
                ),
                label: 'Giỏ hàng',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _NotificationNavIcon(isActive: false),
                ),
                activeIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _NotificationNavIcon(isActive: true),
                ),
                label: 'Thông báo',
              ),
              const BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Icon(Icons.person_outline),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Icon(Icons.person),
                ),
                label: 'Tài khoản',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartNavIcon extends StatelessWidget {
  final bool isActive;

  const _CartNavIcon({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Selector<CartViewModel, int>(
      selector: (_, cartVm) => cartVm.totalQuantity,
      builder: (_, totalQty, _) {
        return Badge(
          isLabelVisible: totalQty > 0,
          label: Text('$totalQty'),
          child: Icon(
            isActive ? Icons.shopping_cart : Icons.shopping_cart_outlined,
          ),
        );
      },
    );
  }
}

class _NotificationNavIcon extends StatelessWidget {
  final bool isActive;

  const _NotificationNavIcon({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Selector<NotificationViewModel, int>(
      selector: (_, notifyVm) => notifyVm.unreadCount,
      builder: (_, unreadCount, __) {
        return Badge(
          isLabelVisible: unreadCount > 0,
          label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
          child: Icon(
            isActive ? Icons.notifications : Icons.notifications_outlined,
          ),
        );
      },
    );
  }
}
