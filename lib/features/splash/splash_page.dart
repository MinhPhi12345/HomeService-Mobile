import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/motion.dart';

/// Màn hình chờ có hiệu ứng, hiện trong lúc app khởi động (đọc phiên đăng nhập, định dạng ngày…).
/// Nối tiếp màn chờ gốc của Android (cùng nền teal + logo) nên chuyển cảnh liền mạch.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.error, this.onRetry});

  /// Lỗi khởi động (nếu có) – hiện nút Thử lại thay vì vòng chờ.
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late final Animation<double> _logoScale = Tween<double>(begin: 0.72, end: 1)
      .animate(
        CurvedAnimation(
          parent: _intro,
          curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
        ),
      );
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
  );
  late final Animation<double> _footFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.6, 1, curve: Curves.easeOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.status == AnimationStatus.dismissed) {
      if (motionEnabled(context)) {
        _intro.forward();
      } else {
        _intro.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Stack(
          children: [
            // Hình tròn trang trí trôi nhẹ
            const Positioned(
              top: -90,
              right: -70,
              child: FloatingBob(
                amplitude: 14,
                period: Duration(milliseconds: 6000),
                child: _Bubble(size: 260, alpha: 0.10),
              ),
            ),
            const Positioned(
              bottom: -60,
              left: -60,
              child: FloatingBob(
                amplitude: 10,
                period: Duration(milliseconds: 5200),
                phase: 0.5,
                child: _Bubble(size: 200, alpha: 0.08),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _logoScale,
                    child: PulseRings(
                      color: Colors.white,
                      size: 190,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.home_rounded,
                          size: 54,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(_textFade),
                      child: Column(
                        children: [
                          const Text(
                            'HomeService',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Việc nhà có người lo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: FadeTransition(
                    opacity: _footFade,
                    child: widget.error == null
                        ? const _LoadingDots()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primaryDark,
                                ),
                                onPressed: widget.onRetry,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

/// Ba chấm sáng lần lượt – báo app đang tải.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: _dotAlpha((_controller.value - i * 0.18) % 1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _dotAlpha(double t) => t < 0.5 ? 0.35 + 1.3 * t : 1.65 - 1.3 * t;
}
