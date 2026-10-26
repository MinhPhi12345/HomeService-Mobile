import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'welcome_page.dart';

/// Đầu trang Đăng nhập / Đăng ký: nền teal, logo, tiêu đề lớn (giống khung trái của website).
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.showServices = true,
  });

  final String title;
  final String subtitle;

  /// Hiện hàng icon dịch vụ dưới tiêu đề.
  final bool showServices;

  static const _services = ['Dọn dẹp nhà', 'Giặt ủi', 'Nấu ăn', 'Sửa điện nước'];

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return BrandHeader(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                if (canPop)
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                    tooltip: 'Quay lại',
                  )
                else
                  const SizedBox(width: 4),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const FadeSlideIn(child: AppLogo(light: true)),
          const SizedBox(height: 22),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
          if (showServices) ...[
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Row(
                children: [
                  for (final name in _services) ...[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        ServiceVisual.of(name).icon,
                        color: ServiceVisual.of(name).color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
