import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../theme/app_theme.dart';

/// FR-31 – huy hiệu "Tasker xuất sắc tháng MM/yyyy".
class AwardBadgeChip extends StatelessWidget {
  const AwardBadgeChip({super.key, required this.label, this.rank = 1});

  final String label;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (rank) {
      1 => (const Color(0xFFFFF1C2), const Color(0xFF8A6000)),
      2 => (const Color(0xFFEEF1F4), const Color(0xFF55626B)),
      3 => (const Color(0xFFFBE3D2), const Color(0xFF9A4F1C)),
      _ => (AppColors.primarySoft, AppColors.primaryDark),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

String voucherSourceLabel(int source) => switch (source) {
  1 => 'Quà chào mừng',
  2 => 'Quà khách thân thiết',
  3 => 'Quà xin lỗi',
  _ => 'Khuyến mãi',
};

String voucherDiscountLabel(MyVoucher v) => v.isPercent
    ? 'Giảm ${v.discountValue.toStringAsFixed(0)}%${v.maxDiscount != null && v.maxDiscount! > 0 ? ', tối đa ${formatMoney(v.maxDiscount!)}' : ''}'
    : 'Giảm ${formatMoney(v.discountValue)}';

String voucherConditionLabel(MyVoucher v) => [
  v.minOrderValue > 0 ? 'Đơn từ ${formatMoney(v.minOrderValue)}' : 'Mọi giá trị đơn',
  v.serviceNames.isEmpty ? 'Mọi dịch vụ' : v.serviceNames.join(', '),
  'HSD ${formatDate(v.endsAt)}',
].join(' · ');

/// FR-32, FR-33 – thẻ ưu đãi (quà tặng / mã khuyến mãi).
class VoucherTile extends StatelessWidget {
  const VoucherTile({super.key, required this.voucher, this.trailing});

  final MyVoucher voucher;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final gift = v.isGift;
    final tint = gift ? const Color(0xFFB4561B) : AppColors.primaryDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gift ? AppColors.accentSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: gift ? const Color(0xFFFFD5B5) : AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: gift ? const Color(0xFFFFE2CC) : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(gift ? Icons.card_giftcard_rounded : Icons.confirmation_number_outlined, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voucherSourceLabel(v.source).toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: tint, letterSpacing: 0.4),
                ),
                const SizedBox(height: 2),
                Text(voucherDiscountLabel(v), style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                Text(v.name, style: AppText.small),
                const SizedBox(height: 2),
                Text(voucherConditionLabel(v), style: AppText.small),
                const SizedBox(height: 2),
                Text('Mã ${v.code}', style: AppText.small.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
