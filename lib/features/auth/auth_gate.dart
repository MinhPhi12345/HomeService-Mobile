import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../customer/customer_shell.dart';
import '../tasker/tasker_shell.dart';
import 'welcome_page.dart';

/// Màn hình gốc: chưa đăng nhập => Welcome; role 0 => Khách hàng; role 1 => Tasker.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.api});

  final ApiClient api;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  int? _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.api.currentUser?.userId;
    widget.api.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.api.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final userId = widget.api.currentUser?.userId;
    if (userId != _userId) {
      _userId = userId;
      // Đăng nhập / đăng xuất: đóng các màn hình đang mở để về màn hình gốc mới.
      rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.api.currentUser;
    if (user == null) return const WelcomePage();
    if (user.isTasker) return TaskerShell(key: ValueKey('tasker-${user.userId}'));
    return CustomerShell(key: ValueKey('customer-${user.userId}'));
  }
}
