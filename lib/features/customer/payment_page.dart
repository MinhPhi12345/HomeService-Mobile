import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'booking_detail_page.dart';

/// US21 – Thanh toán trước (đơn ở trạng thái 10, hạn 15 phút)
/// và US36 / BR-C01 – trả nợ (đơn 13) hoặc phí hủy đơn tiền mặt (đơn 6).
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.booking, this.openDetailAfter = true});

  final Booking booking;

  /// true: thanh toán xong mở trang chi tiết đơn (luồng vừa đặt đơn).
  /// false: chỉ quay lại trang trước (đang ở chi tiết đơn).
  final bool openDetailAfter;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late int _method = _isDebt
      ? PaymentMethod.eWallet
      : widget.booking.paymentMethod;
  Timer? _ticker;
  Duration _left = Duration.zero;
  bool _paying = false;

  Booking get _b => widget.booking;

  bool get _isDebt =>
      _b.status == BookingStatus.paymentOverdue ||
      _b.status == BookingStatus.cancelled;

  double get _amount =>
      _b.status == BookingStatus.cancelled ? _b.cancellationFee : _b.totalPrice;

  bool get _expired =>
      !_isDebt && _b.paymentDueAt != null && _left <= Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!_isDebt && _b.paymentDueAt != null) {
      _tick();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final left = _b.paymentDueAt!.difference(DateTime.now());
    setState(() => _left = left);
    if (left <= Duration.zero) _ticker?.cancel();
  }

  Future<void> _pay() async {
    final api = AppScope.api(context);
    final navigator = Navigator.of(context);
    setState(() => _paying = true);
    try {
      await api.pay(_b.id, _method);
      if (!mounted) return;
      showSnack(
        context,
        _isDebt
            ? 'Đã thanh toán ${formatMoney(_amount)}. Cảm ơn bạn!'
            : 'Thanh toán thành công! Hệ thống đang tìm Tasker cho bạn.',
      );
      if (widget.openDetailAfter) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => BookingDetailPage(bookingId: _b.id)),
        );
      } else {
        navigator.pop(true);
      }
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isDebt
        ? (_b.status == BookingStatus.cancelled
              ? 'Thanh toán phí hủy'
              : 'Thanh toán khoản nợ')
        : 'Thanh toán đơn hàng';
    return Scaffold(
      appBar: hsAppBar(title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _b.serviceCategoryName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatMoney(_amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mã đơn #${_b.id} · ${formatSchedule(_b.scheduledTime)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
                if (!_isDebt && _b.paymentDueAt != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _expired
                              ? 'Đã hết hạn thanh toán'
                              : 'Thanh toán trong ${formatCountdown(_left)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_expired)
            const NoticeBox(
              message:
                  'Đơn đã quá 15 phút chưa thanh toán nên sẽ tự hủy. Bạn có thể đặt lại đơn mới.',
              color: AppColors.danger,
              icon: Icons.timer_off_outlined,
            )
          else if (_isDebt)
            NoticeBox(
              message: _b.status == BookingStatus.cancelled
                  ? 'Phí hủy đơn tiền mặt được chuyển toàn bộ cho Tasker. Bạn cần thanh toán trước khi đặt đơn mới.'
                  : 'Tasker báo bạn chưa thanh toán tiền mặt. Nếu bạn đã trả, hãy quay lại và gửi khiếu nại trong 24 giờ.',
              color: AppColors.warning,
              icon: Icons.info_outline_rounded,
            )
          else
            const NoticeBox(
              message:
                  'HomeService giữ tiền hộ bạn. Tasker chỉ nhận được tiền sau khi bạn xác nhận hoàn thành (hoặc sau 24 giờ).',
              icon: Icons.shield_outlined,
              color: AppColors.success,
            ),
          const SizedBox(height: 18),
          const SectionHeader('Phương thức'),
          if (_isDebt) ...[
            ChoiceTile(
              icon: PaymentMethod.icon(PaymentMethod.eWallet),
              title: 'Ví điện tử',
              selected: _method == PaymentMethod.eWallet,
              onTap: () => setState(() => _method = PaymentMethod.eWallet),
            ),
            const SizedBox(height: 8),
            ChoiceTile(
              icon: PaymentMethod.icon(PaymentMethod.card),
              title: 'Thẻ ngân hàng',
              selected: _method == PaymentMethod.card,
              onTap: () => setState(() => _method = PaymentMethod.card),
            ),
          ] else
            ChoiceTile(
              icon: PaymentMethod.icon(_method),
              title: PaymentMethod.label(_method),
              subtitle: 'Đã chọn khi đặt đơn',
              selected: true,
              onTap: () {},
            ),
          const SizedBox(height: 18),
          const Text(
            'Đây là cổng thanh toán mô phỏng của đồ án: bấm xác nhận là giao dịch thành công, không trừ tiền thật.',
            style: AppText.small,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          PrimaryButton(
            label: 'Xác nhận thanh toán ${formatMoney(_amount)}',
            icon: Icons.lock_rounded,
            loading: _paying,
            onPressed: _expired ? null : _pay,
          ),
        ],
      ),
    );
  }
}
