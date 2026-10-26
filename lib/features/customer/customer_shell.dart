import 'package:flutter/material.dart';

import '../../widgets/app_nav.dart';
import '../common/account_page.dart';
import '../common/notifications_page.dart';
import 'customer_home_page.dart';
import 'orders_page.dart';

/// Khung chính của Khách hàng: Trang chủ · Đơn hàng · Thông báo · Tài khoản.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final _ordersKey = GlobalKey<OrdersPageState>();
  final _homeKey = GlobalKey<CustomerHomePageState>();

  @override
  Widget build(BuildContext context) {
    return AppNavShell(
      items: const [
        NavItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Trang chủ',
        ),
        NavItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          label: 'Đơn hàng',
        ),
        NavItem(
          icon: Icons.notifications_none_rounded,
          selectedIcon: Icons.notifications_rounded,
          label: 'Thông báo',
          showsUnread: true,
        ),
        NavItem(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'Tài khoản',
        ),
      ],
      onTabChanged: (index) {
        if (index == 0) _homeKey.currentState?.reload();
        if (index == 1) _ordersKey.currentState?.reload();
      },
      pageBuilder: (context, index, shell) => switch (index) {
        0 => CustomerHomePage(
          key: _homeKey,
          onOpenOrders: () => shell.goTo(1),
        ),
        1 => OrdersPage(key: _ordersKey),
        2 => NotificationsPage(onUnreadChanged: shell.setUnread),
        _ => const AccountPage(),
      },
    );
  }
}
