import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/labels.dart';
import '../core/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Thẻ đơn hàng dùng cho danh sách đơn của Khách hàng và lịch làm của Tasker.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
    this.forTasker = false,
  });

  final Booking booking;
  final VoidCallback onTap;
  final bool forTasker;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final statusColor = BookingStatus.color(b.status);
    final person = forTasker ? b.customerName : b.taskerName;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ServiceIconBadge(name: b.serviceCategoryName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.serviceCategoryName,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Mã đơn #${b.id}', style: AppText.small),
                  ],
                ),
              ),
              StatusChip(
                label: b.isTaskerNoShow
                    ? 'Tasker chưa đến'
                    : BookingStatus.label(b.status),
                color: b.isTaskerNoShow ? AppColors.danger : statusColor,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow(
            icon: Icons.event_rounded,
            text: formatSchedule(b.scheduledTime),
          ),
          InfoRow(icon: Icons.place_rounded, text: b.address),
          if (person != null && person.isNotEmpty)
            InfoRow(
              icon: forTasker ? Icons.person_rounded : Icons.badge_rounded,
              text: forTasker ? 'Khách: $person' : 'Tasker: $person',
            ),
          const Divider(height: 22),
          Row(
            children: [
              Icon(
                PaymentMethod.icon(b.paymentMethod),
                size: 18,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Text(PaymentMethod.label(b.paymentMethod), style: AppText.muted),
              const Spacer(),
              Text(
                formatMoney(forTasker ? b.taskerEarning : b.totalPrice),
                style: AppText.money,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
