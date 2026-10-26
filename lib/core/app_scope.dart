import 'package:flutter/widgets.dart';

import 'api_client.dart';

/// Cho mọi màn hình truy cập [ApiClient] bằng `AppScope.api(context)`.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.client, required super.child});

  final ApiClient client;

  static ApiClient api(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope chưa được bọc ở main.dart');
    return scope!.client;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => client != oldWidget.client;
}

/// Navigator gốc – dùng để quay về màn hình đầu khi đăng xuất.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
