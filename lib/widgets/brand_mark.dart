import 'package:flutter/material.dart';

/// Biểu tượng HomeService: ngôi nhà + dấu tích (dịch vụ hoàn tất, tin cậy) + tia sáng (sạch sẽ, chất lượng).
/// [onLight] = true → nhà màu teal (đặt trên nền trắng); false → nhà trắng (đặt trên nền teal).
/// Cùng hình với icon ứng dụng và màn chờ Android.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size, this.onLight = false});

  final double size;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onLight
          ? 'assets/branding/logo_mark_teal.png'
          : 'assets/branding/logo_mark_white.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'HomeService',
    );
  }
}
