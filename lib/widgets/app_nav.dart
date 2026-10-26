import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/config.dart';
import '../theme/app_theme.dart';

class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.showsUnread = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Hiện số thông báo chưa đọc trên icon.
  final bool showsUnread;
}

/// Khung có thanh điều hướng dưới, giữ trạng thái từng tab (IndexedStack)
/// và tự cập nhật số thông báo chưa đọc mỗi 30 giây.
class AppNavShell extends StatefulWidget {
  const AppNavShell({
    super.key,
    required this.items,
    required this.pageBuilder,
    this.onTabChanged,
  });

  final List<NavItem> items;

  /// Dựng trang thứ [index]; [state] cho phép trang con đổi tab hoặc cập nhật badge.
  final Widget Function(BuildContext context, int index, AppNavShellState state)
  pageBuilder;
  final ValueChanged<int>? onTabChanged;

  @override
  State<AppNavShell> createState() => AppNavShellState();
}

class AppNavShellState extends State<AppNavShell> {
  int _index = 0;
  int _unread = 0;
  Timer? _timer;
  late final List<Widget?> _pages = List<Widget?>.filled(
    widget.items.length,
    null,
  );

  int get index => _index;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refreshUnread());
    _timer = Timer.periodic(AppConfig.badgeRefresh, (_) => refreshUnread());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refreshUnread() async {
    if (!mounted) return;
    final api = AppScope.api(context);
    if (!api.isAuthenticated) return;
    try {
      final count = await api.getUnreadCount();
      if (mounted && count != _unread) setState(() => _unread = count);
    } catch (_) {
      // Bỏ qua: lần sau sẽ thử lại.
    }
  }

  void setUnread(int value) {
    if (mounted && value != _unread) setState(() => _unread = value);
  }

  void goTo(int index) {
    if (index == _index) {
      widget.onTabChanged?.call(index);
      return;
    }
    setState(() => _index = index);
    widget.onTabChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    // Chỉ dựng trang khi người dùng mở tab lần đầu (tránh gọi API thừa).
    _pages[_index] ??= widget.pageBuilder(context, _index, this);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (final page in _pages) page ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goTo,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final item in widget.items)
            NavigationDestination(
              icon: _badged(item, Icon(item.icon, color: AppColors.inkSoft)),
              selectedIcon: _badged(
                item,
                Icon(item.selectedIcon, color: AppColors.primaryDark),
              ),
              label: item.label,
            ),
        ],
      ),
    );
  }

  Widget _badged(NavItem item, Widget icon) {
    if (!item.showsUnread || _unread == 0) return icon;
    return Badge(
      backgroundColor: AppColors.accent,
      label: Text(_unread > 99 ? '99+' : '$_unread'),
      child: icon,
    );
  }
}
