import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Có nên chạy hiệu ứng không (tắt khi người dùng bật "Giảm chuyển động" / "Xóa hoạt ảnh").
bool motionEnabled(BuildContext context) =>
    !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

/// Hiện dần + trượt lên khi phần tử xuất hiện lần đầu. Dùng [delay] để các phần tử hiện lần lượt.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.offset = 18,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Khoảng trượt lên (pixel).
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!motionEnabled(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Thu nhỏ nhẹ khi ngón tay chạm vào – phản hồi chạm cho thẻ, nút lớn.
/// Dùng [Listener] nên không tranh chấp cử chỉ với InkWell bên trong.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Nhấp nhô lên xuống liên tục (thẻ minh họa nổi).
class FloatingBob extends StatefulWidget {
  const FloatingBob({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.period = const Duration(milliseconds: 3600),
    this.phase = 0,
  });

  final Widget child;
  final double amplitude;
  final Duration period;

  /// Lệch pha (0..1) để nhiều thẻ không nhấp nhô cùng lúc.
  final double phase;

  @override
  State<FloatingBob> createState() => _FloatingBobState();
}

class _FloatingBobState extends State<FloatingBob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionEnabled(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = (_controller.value + widget.phase) * 2 * math.pi;
        return Transform.translate(
          offset: Offset(0, -widget.amplitude * (0.5 - 0.5 * math.cos(t))),
          child: child,
        );
      },
    );
  }
}

/// Các vòng tròn lan tỏa quanh [child] (radar chờ lời mời, chấm "đang hoạt động").
class PulseRings extends StatefulWidget {
  const PulseRings({
    super.key,
    required this.child,
    this.color = AppColors.primary,
    this.size = 140,
    this.rings = 3,
  });

  final Widget child;
  final Color color;
  final double size;
  final int rings;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionEnabled(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < widget.rings; i++)
              _ring((_controller.value + i / widget.rings) % 1),
            child!,
          ],
        ),
        child: widget.child,
      ),
    );
  }

  Widget _ring(double t) {
    final d = widget.size * (0.35 + 0.65 * t);
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.color.withValues(alpha: (1 - t) * 0.45),
          width: 2,
        ),
      ),
    );
  }
}

/// Bản đồ minh họa: đường đi được vẽ dần và chấm Tasker chạy về nhà.
class AnimatedRoute extends StatefulWidget {
  const AnimatedRoute({
    super.key,
    this.height = 150,
    this.dark = false,
  });

  final double height;

  /// Nền tối (dùng trong thẻ màu đậm) hoặc nền sáng.
  final bool dark;

  @override
  State<AnimatedRoute> createState() => _AnimatedRouteState();
}

class _AnimatedRouteState extends State<AnimatedRoute>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionEnabled(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.value = 0.85;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _RoutePainter(
              // 0..0.8: chạy; 0.8..1: dừng ở nhà
              progress: Curves.easeInOut.transform(
                (_controller.value / 0.8).clamp(0.0, 1.0),
              ),
              dark: widget.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.progress, required this.dark});

  final double progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = dark ? const Color(0xFF173E3B) : const Color(0xFFF1F6F4);
    final grid = dark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE3EBE9);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.80)
      ..cubicTo(w * 0.30, h * 0.80, w * 0.30, h * 0.30, w * 0.50, h * 0.38)
      ..cubicTo(w * 0.70, h * 0.46, w * 0.72, h * 0.82, w * 0.86, h * 0.24);

    canvas.drawPath(
      path,
      Paint()
        ..color = (dark
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFFD0DCD9))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final length = metric.length * progress;
    canvas.drawPath(
      metric.extractPath(0, length),
      Paint()
        ..color = (dark ? const Color(0xFF8FF0E4) : AppColors.primary)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Nhà (điểm đến)
    final end = Offset(w * 0.86, h * 0.24);
    canvas.drawCircle(
      end,
      16,
      Paint()..color = AppColors.primary.withValues(alpha: 0.22),
    );
    canvas.drawCircle(end, 10, Paint()..color = AppColors.primary);
    canvas.drawCircle(end, 4, Paint()..color = Colors.white);

    // Tasker đang chạy
    final tangent = metric.getTangentForOffset(length);
    if (tangent != null) {
      canvas.drawCircle(
        tangent.position,
        12,
        Paint()..color = AppColors.accent.withValues(alpha: 0.25),
      );
      canvas.drawCircle(tangent.position, 8, Paint()..color = Colors.white);
      canvas.drawCircle(tangent.position, 6, Paint()..color = AppColors.accent);
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.progress != progress || old.dark != dark;
}

/// Đầu trang có nền chuyển màu + hình tròn trang trí (dùng ở trang chủ Khách hàng / Tasker).
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.child,
    this.colors = const [AppColors.primary, AppColors.primaryDark],
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 24),
  });

  final Widget child;
  final List<Color> colors;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Chữ/biểu tượng thanh trạng thái màu trắng trên nền đậm
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -50,
              child: _circle(200, 0.10),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: _circle(150, 0.07),
            ),
            SafeArea(
              bottom: false,
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _circle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}
