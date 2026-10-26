import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'login_page.dart';
import 'register_page.dart';

/// Màn hình chào (chưa đăng nhập): 3 trang giới thiệu có hình minh họa chuyển động,
/// nút Tạo tài khoản / Đăng nhập và lối vào cho Tasker.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _Slide {
  const _Slide(this.title, this.text, this.art);

  final String title;
  final String text;
  final Widget art;
}

class _WelcomePageState extends State<WelcomePage> {
  final _pages = PageController();
  int _index = 0;
  Timer? _auto;

  static const _slides = [
    _Slide(
      'Việc nhà có người lo',
      'Đặt Tasker dọn dẹp, giặt ủi, nấu ăn, sửa điện nước chỉ trong vài chạm. Giá niêm yết, không phụ thu.',
      _BookingArt(),
    ),
    _Slide(
      'Thấy Tasker đang đến',
      'Khi Tasker nhận đơn, bạn theo dõi vị trí trên bản đồ và gọi điện ngay trong ứng dụng.',
      _MapArt(),
    ),
    _Slide(
      'Hài lòng rồi mới trả',
      'Tiền được HomeService tạm giữ và chỉ chuyển cho Tasker khi bạn xác nhận công việc đã xong.',
      _EscrowArt(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  void _startAuto() {
    _auto?.cancel();
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pages.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _open(Widget page) {
    _auto?.cancel();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page))
        .then((_) => _startAuto());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            // Nền chuyển màu nhạt + vệt màu trôi (giống phần đầu website)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE6F7F4), AppColors.bg],
                  ),
                ),
              ),
            ),
            const Positioned(
              top: -120,
              right: -100,
              child: FloatingBob(
                amplitude: 18,
                period: Duration(seconds: 7),
                child: _Blob(size: 320, color: Color(0x559FE6DC)),
              ),
            ),
            const Positioned(
              top: 260,
              left: -120,
              child: FloatingBob(
                amplitude: 14,
                period: Duration(seconds: 8),
                phase: 0.4,
                child: _Blob(size: 240, color: Color(0x44FFD9BD)),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                    child: Row(
                      children: [
                        const AppLogo(),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _open(const LoginPage()),
                          child: const Text('Đăng nhập'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: NotificationListener<ScrollStartNotification>(
                      // Người dùng tự vuốt => dừng tự chuyển trang một lúc
                      onNotification: (n) {
                        if (n.dragDetails != null) _startAuto();
                        return false;
                      },
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: _slides.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => _SlideView(
                          slide: _slides[i],
                          active: i == _index,
                        ),
                      ),
                    ),
                  ),
                  _Dots(count: _slides.length, index: _index),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                    child: Column(
                      children: [
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 250),
                          child: PrimaryButton(
                            label: 'Tạo tài khoản miễn phí',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () => _open(const RegisterPage()),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 330),
                          child: SecondaryButton(
                            label: 'Tôi đã có tài khoản',
                            onPressed: () => _open(const LoginPage()),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () =>
                              _open(const RegisterPage(initialRole: 1)),
                          icon: const Icon(Icons.handyman_rounded, size: 18),
                          label: const Text(
                            'Muốn kiếm thêm thu nhập? Đăng ký làm Tasker',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.active});

  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedScale(
              scale: active ? 1 : 0.9,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: active ? 1 : 0.4,
                duration: const Duration(milliseconds: 450),
                // Màn hình thấp: tự thu nhỏ hình minh họa thay vì bị tràn
                child: Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: slide.art),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppText.display.copyWith(fontSize: 28, letterSpacing: -0.6),
          ),
          const SizedBox(height: 10),
          Text(
            slide.text,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(
              color: AppColors.inkSoft,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 26 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? AppColors.primary : AppColors.line,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ------------------------------------------------------------- Hình minh họa

/// Khung minh họa chung: thẻ trắng bo góc lớn có bóng.
class _ArtFrame extends StatelessWidget {
  const _ArtFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A3C38).withValues(alpha: 0.16),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Thẻ thông báo nhỏ nổi trên hình minh họa.
class _FloatChip extends StatelessWidget {
  const _FloatChip({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A3C38).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.soft(color),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (subtitle != null)
                Text(subtitle!, style: AppText.small.copyWith(fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingArt extends StatelessWidget {
  const _BookingArt();

  static const _names = [
    'Dọn dẹp nhà',
    'Giặt ủi',
    'Nấu ăn',
    'Sửa điện nước',
    'Chăm sóc cây',
    'Máy lạnh',
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _ArtFrame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đơn sắp tới',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Dọn dẹp nhà · 2 giờ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Mai, 09:00 · 300.000 đ',
                      style: TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.05,
                children: [
                  for (final name in _names)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ServiceIconBadge(name: name, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            name.split(' ').take(2).join(' '),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Positioned(
          top: -18,
          right: -6,
          child: FloatingBob(
            child: _FloatChip(
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              title: 'Tasker Lan đã nhận đơn',
              subtitle: '4,9 ★ · 120 đơn',
            ),
          ),
        ),
      ],
    );
  }
}

class _MapArt extends StatelessWidget {
  const _MapArt();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _ArtFrame(child: AnimatedRoute(height: 230)),
        Positioned(
          bottom: -16,
          left: 0,
          child: FloatingBob(
            phase: 0.3,
            child: _FloatChip(
              icon: Icons.near_me_rounded,
              color: AppColors.primary,
              title: 'Đang đến',
              subtitle: 'Cách nhà bạn 1,2 km',
            ),
          ),
        ),
        Positioned(
          top: -16,
          right: 0,
          child: FloatingBob(
            phase: 0.7,
            child: _FloatChip(
              icon: Icons.call_rounded,
              color: AppColors.accent,
              title: 'Gọi Tasker',
            ),
          ),
        ),
      ],
    );
  }
}

class _EscrowArt extends StatelessWidget {
  const _EscrowArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _ArtFrame(
          child: SizedBox(
            width: 264,
            height: 230,
            child: Center(
              child: PulseRings(
                size: 200,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          top: -14,
          left: 0,
          child: FloatingBob(
            child: _FloatChip(
              icon: Icons.lock_clock_rounded,
              color: AppColors.primary,
              title: '300.000 đ đang tạm giữ',
            ),
          ),
        ),
        const Positioned(
          bottom: -14,
          right: 0,
          child: FloatingBob(
            phase: 0.5,
            child: _FloatChip(
              icon: Icons.task_alt_rounded,
              color: AppColors.success,
              title: 'Bạn xác nhận',
              subtitle: 'Tiền chuyển cho Tasker',
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo chữ + biểu tượng ngôi nhà.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: light ? Colors.white : AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.home_rounded,
            color: light ? AppColors.primary : Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Home',
                style: TextStyle(fontWeight: FontWeight.w600, color: fg),
              ),
              TextSpan(
                text: 'Service',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: light ? Colors.white : AppColors.primaryDark,
                ),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 20, letterSpacing: -0.3),
        ),
      ],
    );
  }
}
