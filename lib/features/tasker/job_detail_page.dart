import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/review_sheet.dart';
import 'respond_dispute_page.dart';

/// US18, US19, US26, US35, US36 – Chi tiết việc của Tasker.
class JobDetailPage extends StatefulWidget {
  const JobDetailPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  Booking? _b;
  Dispute? _dispute;
  List<Review> _reviews = const [];
  bool _loading = true;
  bool _acting = false;
  bool _busy = false;
  String? _error;
  Timer? _refreshTimer;
  Timer? _locationTimer;
  DateTime? _lastSent;
  bool _sendFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_busy) return;
    _busy = true;
    final api = AppScope.api(context);
    try {
      final b = await api.getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _b = b;
        _error = null;
      });
      _schedule(b);
      if (b.disputeId != null) {
        final dispute = await api.getDispute(b.disputeId!);
        if (mounted) setState(() => _dispute = dispute);
      }
      if (const [
        BookingStatus.completed,
        BookingStatus.paid,
        BookingStatus.refunded,
        BookingStatus.disputed,
      ].contains(b.status)) {
        final reviews = await api.getBookingReviews(b.id);
        if (mounted) setState(() => _reviews = reviews);
      }
    } catch (error) {
      if (mounted && !silent) setState(() => _error = errorMessage(error));
    } finally {
      _busy = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  void _schedule(Booking b) {
    final live = BookingStatus.isLive(b.status);
    if (live && _refreshTimer == null) {
      _refreshTimer = Timer.periodic(
        AppConfig.bookingRefresh,
        (_) => _load(silent: true),
      );
    } else if (!live) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }

    // Chỉ gửi vị trí khi đang làm đơn đã nhận (khác với ghép nối – chỉ gửi 1 lần khi bật nhận đơn).
    final sharing =
        (b.status == BookingStatus.accepted ||
            b.status == BookingStatus.inProgress) &&
        !b.isTaskerNoShow;
    if (sharing && _locationTimer == null) {
      _sendLocation();
      _locationTimer = Timer.periodic(
        AppConfig.locationSendInterval,
        (_) => _sendLocation(),
      );
    } else if (!sharing) {
      _locationTimer?.cancel();
      _locationTimer = null;
    }
  }

  Future<void> _sendLocation() async {
    final api = AppScope.api(context);
    final point = await LocationService.tryCurrent();
    if (point == null) {
      if (mounted) setState(() => _sendFailed = true);
      return;
    }
    try {
      await api.sendLocation(widget.bookingId, point.latitude, point.longitude);
      if (mounted) {
        setState(() {
          _lastSent = DateTime.now();
          _sendFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sendFailed = true);
    }
  }

  // ------------------------------------------------------------ Hành động

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _acting = true);
    try {
      await action();
      if (!mounted) return;
      if (success != null) showSnack(context, success);
      await _load(silent: true);
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
      if (error is ApiFailure && error.isConflict) await _load(silent: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _start() async {
    final api = AppScope.api(context);
    final url = await _photoStep(
      title: 'Bắt đầu làm việc',
      message: 'Chụp ảnh hiện trạng trước khi làm để làm bằng chứng nếu có khiếu nại.',
      confirm: 'Bắt đầu',
    );
    if (url == null || !mounted) return;
    await _run(
      () => api.updateBookingStatus(
        widget.bookingId,
        status: BookingStatus.inProgress,
        photoUrl: url,
      ),
      success: 'Đã bắt đầu. Chúc bạn làm việc thuận lợi!',
    );
  }

  Future<void> _complete() async {
    final api = AppScope.api(context);
    final b = _b!;
    if (b.isCash) {
      final ok = await confirmDialog(
        context,
        title: 'Đã thu đủ tiền mặt?',
        message:
            'Xác nhận bạn đã nhận ${formatMoney(b.totalPrice)} từ khách. '
            'Chiết khấu ${formatMoney(b.totalPrice * b.commissionRate)} sẽ được trừ vào ví của bạn.',
        confirmText: 'Đã thu đủ',
      );
      if (!ok || !mounted) return;
    }
    final url = await _photoStep(
      title: 'Hoàn thành công việc',
      message: 'Chụp ảnh kết quả sau khi làm để khách kiểm tra và xác nhận.',
      confirm: 'Hoàn thành',
    );
    if (url == null || !mounted) return;
    await _run(
      () => api.updateBookingStatus(
        widget.bookingId,
        status: BookingStatus.completed,
        photoUrl: url,
        cashCollected: b.isCash ? true : null,
      ),
      success: b.isCash
          ? 'Đơn đã hoàn tất và thanh toán tiền mặt.'
          : 'Đã hoàn thành. Chờ khách xác nhận để nhận tiền.',
    );
  }

  Future<void> _reportUnpaid() async {
    final api = AppScope.api(context);
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _UnpaidSheet(),
    );
    if (result == null || !mounted) return;
    await _run(
      () => api.reportUnpaid(
        widget.bookingId,
        note: result.$1,
        photoUrl: result.$2,
      ),
      success: 'Đã ghi nhận. Bạn không bị trừ chiết khấu cho đơn này.',
    );
  }

  Future<void> _respondDispute() async {
    final dispute = _dispute;
    if (dispute == null) return;
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RespondDisputePage(dispute: dispute)),
    );
    if (sent == true && mounted) _load(silent: true);
  }

  Future<void> _reviewCustomer() async {
    final api = AppScope.api(context);
    final b = _b!;
    final sent = await showReviewSheet(
      context,
      title: 'Đánh giá khách hàng',
      subtitle: 'Trải nghiệm làm việc với ${b.customerName} thế nào?',
      onSubmit: (rating, comment) => api.createReview(
        bookingId: b.id,
        revieweeId: b.customerId,
        rating: rating,
        comment: comment,
      ),
    );
    if (sent && mounted) {
      showSnack(context, 'Cảm ơn bạn đã đánh giá!');
      _load(silent: true);
    }
  }

  Future<void> _reportReview(Review review) async {
    final api = AppScope.api(context);
    final ok = await confirmDialog(
      context,
      title: 'Báo cáo đánh giá?',
      message:
          'Quản trị viên sẽ xem xét. Trong lúc chờ, đánh giá này tạm không tính vào điểm trung bình của bạn.',
      confirmText: 'Báo cáo',
    );
    if (!ok || !mounted) return;
    await _run(
      () => api.reportReview(review.id),
      success: 'Đã gửi báo cáo tới quản trị viên.',
    );
  }

  /// Bottom sheet chụp 1 ảnh, trả URL đã tải lên.
  Future<String?> _photoStep({
    required String title,
    required String message,
    required String confirm,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) =>
          _PhotoStepSheet(title: title, message: message, confirm: confirm),
    );
  }

  // ------------------------------------------------------------ Giao diện

  @override
  Widget build(BuildContext context) {
    final b = _b;
    return Scaffold(
      appBar: hsAppBar(b == null ? 'Chi tiết việc' : 'Việc #${b.id}'),
      body: _loading
          ? const LoadingView()
          : b == null
          ? ErrorView(message: _error ?? 'Không tải được đơn.', onRetry: _load)
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: _sections(b),
              ),
            ),
      bottomNavigationBar: b == null ? null : _actionBar(b),
    );
  }

  String _message(Booking b) {
    switch (b.status) {
      case BookingStatus.accepted:
        return b.isTaskerNoShow
            ? 'Đơn đã quá giờ hẹn 30 phút nên bị ghi nhận "không đến" (+1 điểm vi phạm). Khách có thể tìm Tasker khác.'
            : 'Hãy đến đúng giờ ${formatSchedule(b.scheduledTime)}. Đến nơi, chụp ảnh hiện trạng rồi bấm "Bắt đầu làm việc".';
      case BookingStatus.inProgress:
        return b.isCash
            ? 'Làm xong, thu ${formatMoney(b.totalPrice)} tiền mặt, chụp ảnh kết quả rồi bấm hoàn thành.'
            : 'Làm xong, chụp ảnh kết quả rồi bấm "Hoàn thành".';
      case BookingStatus.completed:
        return b.autoConfirmAt == null
            ? 'Đã hoàn thành, đang chờ khách xác nhận.'
            : 'Đã hoàn thành, chờ khách xác nhận (hệ thống tự xác nhận lúc ${formatDateTime(b.autoConfirmAt!)}). Tiền sẽ vào ví ngay sau đó.';
      case BookingStatus.paid:
        return 'Đơn đã hoàn tất. Thu nhập đã được ghi nhận.';
      case BookingStatus.cancelled:
        return 'Đơn đã bị hủy.';
      case BookingStatus.disputed:
        return 'Khách đã khiếu nại đơn này. Hãy phản hồi kèm ảnh trong 24 giờ để quản trị viên xem xét.';
      case BookingStatus.refunded:
        return 'Đơn đã hoàn tiền cho khách theo quyết định của quản trị viên.';
      case BookingStatus.paymentOverdue:
        return 'Bạn đã báo khách chưa thanh toán. Khoản này được ghi nợ cho khách, bạn không bị trừ chiết khấu.';
      default:
        return BookingStatus.label(b.status);
    }
  }

  List<Widget> _sections(Booking b) {
    final me = AppScope.api(context).currentUser?.userId;
    final color = b.isTaskerNoShow ? AppColors.danger : BookingStatus.color(b.status);
    final sharing =
        (b.status == BookingStatus.accepted ||
            b.status == BookingStatus.inProgress) &&
        !b.isTaskerNoShow;
    final commission = b.totalPrice * b.commissionRate;
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.soft(color),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                b.isTaskerNoShow
                    ? Icons.warning_amber_rounded
                    : BookingStatus.icon(b.status),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.isTaskerNoShow ? 'Quá giờ hẹn' : BookingStatus.label(b.status),
                    style: AppText.title.copyWith(color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(b.serviceCategoryName, style: AppText.label),
                  const SizedBox(height: 6),
                  Text(_message(b), style: AppText.body),
                ],
              ),
            ),
          ],
        ),
      ),
      if (sharing) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              _sendFailed ? Icons.location_disabled_rounded : Icons.share_location_rounded,
              size: 18,
              color: _sendFailed ? AppColors.danger : AppColors.success,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _sendFailed
                    ? 'Chưa gửi được vị trí. Hãy bật GPS để khách theo dõi được bạn.'
                    : _lastSent == null
                    ? 'Đang chia sẻ vị trí với khách…'
                    : 'Đang chia sẻ vị trí với khách · ${formatTime(_lastSent!)}',
                style: AppText.small,
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      const SectionHeader('Khách hàng'),
      AppCard(
        child: Column(
          children: [
            Row(
              children: [
                UserAvatar(name: b.customerName, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.customerName,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        b.customerPresent
                            ? 'Khách sẽ có mặt tại nhà'
                            : 'Khách có thể vắng nhà',
                        style: AppText.small,
                      ),
                    ],
                  ),
                ),
                if (b.customerPhone != null)
                  IconButton.filled(
                    onPressed: () => callPhone(context, b.customerPhone!),
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.call_rounded, color: Colors.white),
                  ),
              ],
            ),
            if (b.hasLocation) ...[
              const SizedBox(height: 12),
              PinMap(
                pins: [
                  MapPin(
                    point: GeoPoint(b.latitude!, b.longitude!),
                    label: 'Nhà khách',
                    icon: Icons.home_rounded,
                  ),
                ],
                height: 170,
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Chỉ đường bằng Google Maps',
                icon: Icons.directions_rounded,
                onPressed: () => openDirections(context, b.latitude!, b.longitude!),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      const SectionHeader('Thông tin công việc'),
      AppCard(
        child: Column(
          children: [
            InfoRow(
              icon: Icons.event_rounded,
              label: 'Giờ hẹn',
              text: formatSchedule(b.scheduledTime),
            ),
            InfoRow(icon: Icons.place_rounded, label: 'Địa chỉ', text: b.address),
            InfoRow(
              icon: Icons.format_list_numbered_rounded,
              label: 'Số lượng',
              text: '${b.quantity}',
            ),
            if (b.note != null)
              InfoRow(
                icon: Icons.sticky_note_2_outlined,
                label: 'Ghi chú của khách',
                text: b.note!,
              ),
            InfoRow(
              icon: PaymentMethod.icon(b.paymentMethod),
              label: 'Thanh toán',
              text: b.isCash
                  ? 'Tiền mặt – thu của khách khi xong việc'
                  : '${PaymentMethod.label(b.paymentMethod)} – khách đã trả trước',
            ),
          ],
        ),
      ),
      if (b.checkInPhotoUrl != null || b.checkOutPhotoUrl != null) ...[
        const SizedBox(height: 16),
        const SectionHeader('Ảnh công việc'),
        Row(
          children: [
            Expanded(
              child: NetworkPhoto(url: b.checkInPhotoUrl, caption: 'Trước khi làm'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NetworkPhoto(url: b.checkOutPhotoUrl, caption: 'Sau khi làm'),
            ),
          ],
        ),
      ],
      if (_dispute != null) ...[
        const SizedBox(height: 16),
        const SectionHeader('Khiếu nại của khách'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DisputeReason.label(_dispute!.reason),
                style: AppText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(_dispute!.description, style: AppText.muted),
              if (_dispute!.evidenceUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final url in _dispute!.evidenceUrls)
                      NetworkPhoto(url: url, height: 72, width: 72),
                  ],
                ),
              ],
              const Divider(height: 22),
              if (_dispute!.taskerResponse != null) ...[
                const Text('Phản hồi của bạn', style: AppText.label),
                const SizedBox(height: 4),
                Text(_dispute!.taskerResponse!, style: AppText.body),
              ] else if (_dispute!.isOpen)
                Text(
                  'Hạn phản hồi: ${formatDateTime(_dispute!.taskerResponseDueAt)}',
                  style: AppText.body.copyWith(color: AppColors.warning),
                ),
              if (!_dispute!.isOpen) ...[
                const SizedBox(height: 8),
                Text(
                  'Kết quả: ${DisputeResolution.label(_dispute!.resolution)}',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_dispute!.adminNote != null)
                  Text('Ghi chú: ${_dispute!.adminNote!}', style: AppText.muted),
              ],
            ],
          ),
        ),
      ],
      if (_reviews.isNotEmpty) ...[
        const SizedBox(height: 16),
        const SectionHeader('Đánh giá'),
        for (final review in _reviews) ...[
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.reviewerId == me
                            ? 'Bạn đánh giá khách'
                            : '${review.reviewerName} đánh giá bạn',
                        style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    RatingStars(rating: review.rating.toDouble(), size: 15),
                  ],
                ),
                if (review.comment != null) ...[
                  const SizedBox(height: 6),
                  Text(review.comment!, style: AppText.body),
                ],
                if (review.revieweeId == me)
                  Align(
                    alignment: Alignment.centerRight,
                    child: review.isFlagged
                        ? const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: StatusChip(
                              label: 'Đang được xem xét',
                              color: AppColors.warning,
                              dense: true,
                            ),
                          )
                        : TextButton.icon(
                            onPressed: _acting ? null : () => _reportReview(review),
                            icon: const Icon(Icons.flag_outlined, size: 16),
                            label: const Text('Báo cáo bất thường'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          children: [
            SummaryRow('Giá đơn', formatMoney(b.totalPrice)),
            SummaryRow(
              'Phí nền tảng (${(b.commissionRate * 100).round()}%)',
              '- ${formatMoney(commission)}',
            ),
            const Divider(height: 18),
            SummaryRow('Bạn nhận được', formatMoney(b.totalPrice - commission), bold: true),
          ],
        ),
      ),
    ];
  }

  Widget? _actionBar(Booking b) {
    final buttons = <Widget>[];
    switch (b.status) {
      case BookingStatus.accepted:
        if (!b.isTaskerNoShow) {
          buttons.add(
            PrimaryButton(
              label: 'Bắt đầu làm việc',
              icon: Icons.play_arrow_rounded,
              loading: _acting,
              onPressed: _start,
            ),
          );
        }
      case BookingStatus.inProgress:
        buttons.add(
          PrimaryButton(
            label: b.isCash ? 'Đã thu tiền – Hoàn thành' : 'Hoàn thành công việc',
            icon: Icons.task_alt_rounded,
            loading: _acting,
            onPressed: _complete,
          ),
        );
        if (b.isCash) {
          buttons.add(
            SecondaryButton(
              label: 'Khách chưa thanh toán',
              icon: Icons.money_off_rounded,
              color: AppColors.danger,
              onPressed: _acting ? null : _reportUnpaid,
            ),
          );
        }
      case BookingStatus.disputed:
        if (_dispute?.taskerCanRespond ?? false) {
          buttons.add(
            PrimaryButton(
              label: 'Phản hồi khiếu nại',
              icon: Icons.reply_rounded,
              loading: _acting,
              onPressed: _respondDispute,
            ),
          );
        }
      default:
        break;
    }
    if (b.canReview) {
      buttons.add(
        SecondaryButton(
          label: 'Đánh giá khách hàng',
          icon: Icons.star_outline_rounded,
          onPressed: _acting ? null : _reviewCustomer,
        ),
      );
    }
    if (buttons.isEmpty) return null;
    return BottomActionBar(children: buttons);
  }
}

class _PhotoStepSheet extends StatefulWidget {
  const _PhotoStepSheet({
    required this.title,
    required this.message,
    required this.confirm,
  });

  final String title;
  final String message;
  final String confirm;

  @override
  State<_PhotoStepSheet> createState() => _PhotoStepSheetState();
}

class _PhotoStepSheetState extends State<_PhotoStepSheet> {
  String? _url;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppText.title),
            const SizedBox(height: 6),
            Text(widget.message, style: AppText.muted),
            const SizedBox(height: 16),
            PhotoSlot(
              url: _url,
              height: 200,
              label: 'Chụp ảnh',
              onChanged: (url) => setState(() => _url = url),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: widget.confirm,
              onPressed: _url == null ? null : () => Navigator.of(context).pop(_url),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnpaidSheet extends StatefulWidget {
  const _UnpaidSheet();

  @override
  State<_UnpaidSheet> createState() => _UnpaidSheetState();
}

class _UnpaidSheetState extends State<_UnpaidSheet> {
  final _note = TextEditingController();
  String? _url;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _note.text.trim();
    if (note.length < 10) {
      setState(() => _error = 'Vui lòng mô tả tình huống (10–500 ký tự).');
      return;
    }
    if (_url == null) {
      setState(() => _error = 'Vui lòng chụp ảnh hiện trạng.');
      return;
    }
    Navigator.of(context).pop((note, _url!));
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + inset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Khách chưa thanh toán', style: AppText.title),
              const SizedBox(height: 6),
              const Text(
                'Đơn sẽ chuyển sang "Khách chưa thanh toán", bạn không bị trừ chiết khấu. '
                'Khách có 24 giờ để khiếu nại nếu cho rằng đã trả; báo sai sẽ bị +2 điểm vi phạm.',
                style: AppText.muted,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 500,
                decoration: appInputDecoration(
                  hint: 'Mô tả tình huống, ví dụ: khách hẹn chuyển khoản sau nhưng không trả…',
                ),
              ),
              PhotoSlot(
                url: _url,
                height: 150,
                label: 'Chụp ảnh hiện trạng',
                onChanged: (url) => setState(() => _url = url),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Gửi báo cáo',
                color: AppColors.danger,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
