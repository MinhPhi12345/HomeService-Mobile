import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/payment_gateway.dart';
import 'booking_detail_page.dart';

/// US21 – Thanh toán trước (đơn ở trạng thái 10, hạn 15 phút)
/// và US36 / BR-C01 – trả nợ (đơn 13) hoặc phí hủy đơn tiền mặt (đơn 6).
///
/// Giao diện là một cổng thanh toán MÔ PHỎNG: QR ví điện tử / thẻ thử nghiệm,
/// nút "Thanh toán (demo)" → màn hình xử lý → biên lai thành công. Không trừ tiền thật.
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.booking, this.openDetailAfter = true});

  final Booking booking;

  /// true: thanh toán xong mở trang chi tiết đơn (luồng vừa đặt đơn).
  /// false: chỉ quay lại trang trước (đang ở chi tiết đơn).
  final bool openDetailAfter;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

enum _Step { form, processing, success }

class _PaymentPageState extends State<PaymentPage> {
  late int _method = _isDebt
      ? PaymentMethod.eWallet
      : widget.booking.paymentMethod;
  Timer? _ticker;
  Duration _left = Duration.zero;
  _Step _step = _Step.form;
  int? _paymentId;
  DateTime? _paidAt;

  Booking get _b => widget.booking;

  bool get _isDebt =>
      _b.status == BookingStatus.paymentOverdue ||
      _b.status == BookingStatus.cancelled;

  double get _amount =>
      _b.status == BookingStatus.cancelled ? _b.cancellationFee : _b.payable;

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
    setState(() => _step = _Step.processing);
    final started = DateTime.now();
    try {
      final id = await api.pay(_b.id, _method);
      // Giữ màn hình "đang xử lý" tối thiểu 1,2 giây cho giống cổng thật.
      final spent = DateTime.now().difference(started);
      const minimum = Duration(milliseconds: 1200);
      if (spent < minimum) await Future<void>.delayed(minimum - spent);
      if (!mounted) return;
      _ticker?.cancel();
      setState(() {
        _paymentId = id;
        _paidAt = DateTime.now();
        _step = _Step.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _step = _Step.form);
      showSnack(context, errorMessage(error), error: true);
    }
  }

  void _finish() {
    final navigator = Navigator.of(context);
    if (widget.openDetailAfter) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => BookingDetailPage(bookingId: _b.id)),
      );
    } else {
      navigator.pop(true);
    }
  }

  Future<bool> _confirmCancel() async {
    if (_step == _Step.processing) return false;
    if (_step == _Step.success) {
      _finish();
      return false;
    }
    if (_isDebt || _expired) return true;
    return confirmDialog(
      context,
      title: 'Hủy giao dịch?',
      message:
          'Đơn chỉ được tìm Tasker sau khi bạn thanh toán. Bạn có thể thanh toán lại trong chi tiết đơn trước khi hết hạn.',
      confirmText: 'Thoát',
      cancelText: 'Tiếp tục thanh toán',
    );
  }

  String get _title => _isDebt
      ? (_b.status == BookingStatus.cancelled
            ? 'Thanh toán phí hủy'
            : 'Thanh toán khoản nợ')
      : 'Thanh toán đơn hàng';

  String get _successNote => _isDebt
      ? 'Cảm ơn bạn! Khoản thanh toán đã được ghi nhận và chuyển cho Tasker.'
      : 'HomeService đang tạm giữ khoản tiền này. Hệ thống bắt đầu tìm Tasker cho bạn; tiền chỉ được chuyển cho Tasker sau khi bạn xác nhận hoàn thành.';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmCancel() && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: hsAppBar(_step == _Step.success ? 'Biên lai thanh toán' : _title),
        body: switch (_step) {
          _Step.processing => GatewayProcessingView(amount: _amount),
          _Step.success => GatewaySuccessView(
            amount: _amount,
            note: _successNote,
            rows: [
              ('Đơn hàng', '#${_b.id} · ${_b.serviceCategoryName}'),
              ('Phương thức', PaymentMethod.label(_method)),
              if (_paymentId != null) ('Mã thanh toán', '#$_paymentId'),
              ('Thời gian', formatDateTime(_paidAt ?? DateTime.now())),
              (
                'Trạng thái',
                _isDebt ? 'Đã thanh toán' : 'HomeService đang tạm giữ',
              ),
            ],
          ),
          _Step.form => _form(),
        },
        bottomNavigationBar: switch (_step) {
          _Step.processing => null,
          _Step.success => BottomActionBar(
            children: [
              PrimaryButton(
                label: widget.openDetailAfter ? 'Xem đơn hàng' : 'Xong',
                icon: Icons.check_rounded,
                onPressed: _finish,
              ),
            ],
          ),
          _Step.form => BottomActionBar(
            children: [
              PrimaryButton(
                label: 'Thanh toán (demo) ${formatMoney(_amount)}',
                icon: Icons.lock_rounded,
                onPressed: _expired ? null : _pay,
              ),
              SecondaryButton(
                label: 'Hủy giao dịch',
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  if (await _confirmCancel() && mounted) navigator.pop();
                },
              ),
            ],
          ),
        },
      ),
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GatewayHeader(
          merchant: 'HomeService · Đơn #${_b.id}',
          description: '${_b.serviceCategoryName} · ${formatSchedule(_b.scheduledTime)}',
          amount: _amount,
          trailing: !_isDebt && _b.paymentDueAt != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
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
                )
              : null,
        ),
        const SizedBox(height: 16),
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
            title: 'Tiền được HomeService tạm giữ',
            message:
                'Bạn trả trước → HomeService giữ hộ → Tasker làm xong, bạn bấm “Xác nhận & thanh toán cho Tasker” thì tiền mới được chuyển (hoặc tự chuyển sau 24 giờ nếu bạn không phản hồi).',
            icon: Icons.shield_outlined,
            color: AppColors.success,
          ),
        const SizedBox(height: 18),
        const SectionHeader('Phương thức'),
        if (_isDebt) ...[
          ChoiceTile(
            icon: PaymentMethod.icon(PaymentMethod.eWallet),
            title: 'Ví điện tử',
            subtitle: 'MoMo, ZaloPay…',
            selected: _method == PaymentMethod.eWallet,
            onTap: () => setState(() => _method = PaymentMethod.eWallet),
          ),
          const SizedBox(height: 8),
          ChoiceTile(
            icon: PaymentMethod.icon(PaymentMethod.card),
            title: 'Thẻ ngân hàng',
            subtitle: 'Visa, Mastercard, Napas',
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
        const SizedBox(height: 14),
        if (!_expired)
          _method == PaymentMethod.card
              ? const GatewayCardPanel()
              : GatewayQrPanel(seed: _b.id, amount: _amount),
        const SizedBox(height: 14),
        const GatewaySecureNote(),
      ],
    );
  }
}
