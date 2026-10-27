import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/api_client.dart';
import 'core/app_scope.dart';
import 'core/trusted_roots.dart';
import 'features/auth/auth_gate.dart';
import 'features/splash/splash_page.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installExtraRootCertificates(); // HTTPS Let's Encrypt chạy được cả trên Android đời cũ
  runApp(const HomeServiceRoot());
}

/// Gốc ứng dụng: hiện màn chờ trong lúc khởi động, xong thì chuyển (mờ dần) sang app chính.
class HomeServiceRoot extends StatefulWidget {
  const HomeServiceRoot({super.key});

  @override
  State<HomeServiceRoot> createState() => _HomeServiceRootState();
}

class _HomeServiceRootState extends State<HomeServiceRoot> {
  /// Màn chờ hiện tối thiểu chừng này để hiệu ứng logo chạy trọn vẹn.
  static const _minimumSplash = Duration(milliseconds: 1700);

  ApiClient? _api;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_error != null) setState(() => _error = null);
    final started = DateTime.now();
    try {
      await initializeDateFormatting('vi');
      final api = await ApiClient.create();
      final wait = _minimumSplash - DateTime.now().difference(started);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (mounted) setState(() => _api = api);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không khởi động được ứng dụng. Vui lòng thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: api == null
          ? MaterialApp(
              key: const ValueKey('splash'),
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
              home: SplashPage(error: _error, onRetry: _start),
            )
          : HomeServiceApp(key: const ValueKey('app'), api: api),
    );
  }
}

class HomeServiceApp extends StatelessWidget {
  const HomeServiceApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      client: api,
      child: MaterialApp(
        title: 'HomeService',
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AuthGate(api: api),
      ),
    );
  }
}
