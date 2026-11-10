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
import '../../widgets/booking_photos.dart';
import '../../widgets/common.dart';
import '../../widgets/date_time_pick.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/review_sheet.dart';
import '../../widgets/rewards.dart';
import '../common/public_profile_page.dart';
import 'booking_create_page.dart';
import 'dispute_page.dart';
import 'payment_page.dart';

/// Chi tiết đơn của Khách hàng: trạng thái, theo dõi Tasker, ảnh trước/sau,
/// và các nút theo trạng thái (Hướng dẫn FE mục 5.5 và mục 8).
class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  Booking? _b;
  TaskerLocation? _location;
  bool _locationLoaded = false;
  ReviewSummary? _taskerReviews;
  Dispute? _dispute;
  List<Review> _reviews = const [];
  bool _loading = true;
  bool _acting = false;
  bool _busy = false;
  String? _error;
  Timer? _refreshTimer;
  Timer? _trackTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _trackTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ Tải dữ liệu

  Future<void> _load({bool silent = false}) async {
    if (_busy) return;
    _busy = true;
    final api = AppScope.api(context);
    try {
      final booking = await api.getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _b = booking;
        _error = null;
      });
      _schedulePolling(booking);
      await _loadExtras(api, booking);
    } catch (error) {
      if (mounted && !silent) setState(() => _error = errorMessage(error));
    } finally {
      _busy = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadExtras(ApiClient api, Booking b) async {
    try {
      final taskerId = b.taskerId;
      if (taskerId != null && _taskerReviews == null) {
        final summary = await api.getUserReviews(taskerId);
        if (mounted) setState(() => _taskerReviews = summary);
      }
      final disputeId = b.disputeId;
      if (disputeId != null) {
        final dispute = await api.getDispute(disputeId);
        if (mounted) setState(() => _dispute = dispute);
      }
      if (const [
        BookingStatus.paid,
        BookingStatus.refunded,
        BookingStatus.disputed,
      ].contains(b.status)) {
        final reviews = await api.getBookingReviews(b.id);
        if (mounted) setState(() => _reviews = reviews);
      }
    } catch (_) {
      // Phần phụ: lỗi không chặn trang chính.
    }
  }

  void _schedulePolling(Booking b) {
    final live = BookingStatus.isLive(b.status) || b.isTaskerNoShow;
    if (live && _refreshTimer == null) {
      _refreshTimer = Timer.periodic(
        AppConfig.bookingRefresh,
        (_) => _load(silent: true),
      );
    } else if (!live) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }

    final tracking =
        (b.status == BookingStatus.accepted ||
            b.status == BookingStatus.inProgress) &&
        !b.isTaskerNoShow;
    if (tracking && _trackTimer == null) {
      _loadLocation();
      _trackTimer = Timer.periodic(
        AppConfig.trackingRefresh,
        (_) => _loadLocation(),
      );
    } else if (!tracking) {
      _trackTimer?.cancel();
      _trackTimer = null;
    }
  }

  Future<void> _loadLocation() async {
    try {
      final location = await AppScope.api(
        context,
      ).getTaskerLocation(widget.bookingId);
      if (mounted) {
        setState(() {
          _location = location;
          _locationLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoaded = true);
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

  Future<void> _pay() async {
    final b = _b!;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentPage(booking: b, openDetailAfter: false),
      ),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _cancel() async {
    final api = AppScope.api(context);
    setState(() => _acting = true);
    CancellationFee fee;
    try {
      fee = await api.getCancellationFee(widget.bookingId);
    } catch (error) {
      if (mounted) {
        showSnack(context, errorMessage(error), error: true);
        setState(() => _acting = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _acting = false);
    final b = _b!;
    final lines = <String>[
      fee.reason,
      '',
      'Phí hủy: ${formatMoney(fee.fee)}',
      if (!b.isCash || b.paymentStatus != null)
        'Hoàn lại cho bạn: ${formatMoney(fee.refundAmount)}',
      if (b.isCash && fee.fee > 0)
        'Phí hủy đơn tiền mặt sẽ được ghi thành khoản cần thanh toán.',
    ];
    final ok = await confirmDialog(
      context,
      title: 'Hủy đơn #${b.id}?',
      message: lines.join('\n'),
      confirmText: 'Hủy đơn',
      cancelText: 'Giữ đơn',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(() => api.cancelBooking(b.id), success: 'Đã hủy đơn.');
  }

  Future<void> _retry() async {
    final api = AppScope.api(context);
    final b = _b!;
    final keepValid = b.scheduledTime.isAfter(
      DateTime.now().add(const Duration(hours: 1, minutes: 5)),
    );
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                b.isTaskerNoShow ? 'Tìm Tasker khác' : 'Tìm Tasker lại',
                style: AppText.title,
              ),
              const SizedBox(height: 6),
              Text(
                keepValid
                    ? 'Bạn muốn giữ giờ hẹn cũ hay chọn giờ mới?'
                    : 'Giờ hẹn cũ đã qua. Chọn giờ mới, hoặc để hệ thống tự đặt sau 1 giờ nữa.',
                style: AppText.muted,
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: keepValid
                    ? 'Giữ giờ ${formatSchedule(b.scheduledTime)}'
                    : 'Đặt sau 1 giờ nữa',
                onPressed: () => Navigator.of(sheet).pop('keep'),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Chọn giờ khác',
                icon: Icons.schedule_rounded,
                onPressed: () => Navigator.of(sheet).pop('new'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    DateTime? newTime;
    if (choice == 'new') {
      newTime = await pickFutureDateTime(context, initial: b.scheduledTime);
      if (newTime == null || !mounted) return;
    }
    await _run(
      () => api.retryBooking(b.id, scheduledTime: newTime),
      success: 'Đã gửi lại yêu cầu tìm Tasker.',
    );
  }

  /// Đơn online đã xong việc: tiền khách trả trước đang được HomeService tạm giữ.
  /// Khách kiểm tra rồi bấm "Xác nhận & chuyển" để giải ngân cho Tasker.
  Future<void> _confirm() async {
    final api = AppScope.api(context);
    final b = _b!;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _ReleaseSheet(booking: b),
    );
    if (!mounted) return;
    if (action == 'dispute') {
      await _openDispute();
      return;
    }
    if (action != 'confirm') return;
    await _run(
      () => api.confirmBooking(b.id),
      success: 'Đã xác nhận. ${formatMoney(b.totalPrice)} đã được chuyển cho Tasker.',
    );
    if (mounted && (_b?.canReview ?? false)) await _review();
  }

  Future<void> _openDispute() async {
    final b = _b!;
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DisputePage(booking: b)),
    );
    if (sent == true && mounted) _load(silent: true);
  }

  Future<void> _review() async {
    final b = _b!;
    final taskerId = b.taskerId;
    if (taskerId == null) return;
    final api = AppScope.api(context);
    final sent = await showReviewSheet(
      context,
      title: 'Đánh giá Tasker',
      subtitle: 'Bạn thấy ${b.taskerName ?? 'Tasker'} làm việc thế nào?',
      onSubmit: (rating, comment) => api.createReview(
        bookingId: b.id,
        revieweeId: taskerId,
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
    final sent = await showReportReviewSheet(
      context,
      review: review,
      onSubmit: (reason) => api.reportReview(review.id, reason),
    );
    if (!sent || !mounted) return;
    showSnack(context, 'Đã gửi báo cáo kèm lý do tới quản trị viên.');
    await _load(silent: true);
  }

  Future<void> _reorder() async {
    final api = AppScope.api(context);
    final navigator = Navigator.of(context);
    final b = _b!;
    setState(() => _acting = true);
    try {
      final services = await api.getCategories();
      final matches = services.where((s) => s.id == b.serviceCategoryId);
      if (!mounted) return;
      if (matches.isEmpty) {
        showSnack(context, 'Dịch vụ này hiện không còn cung cấp.', error: true);
        return;
      }
      navigator.push(
        MaterialPageRoute(
          builder: (_) => BookingCreatePage(
            service: matches.first,
            initialAddress: b.address,
            initialLocation: b.hasLocation
                ? GeoPoint(b.latitude!, b.longitude!)
                : null,
            initialQuantity: b.quantity,
            initialNote: b.note,
            initialItems: [for (final it in b.items) it.description],
          ),
        ),
      );
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  // ------------------------------------------------------------ Giao diện

  @override
  Widget build(BuildContext context) {
    final b = _b;
    return Scaffold(
      appBar: hsAppBar(b == null ? 'Chi tiết đơn' : 'Đơn #${b.id}'),
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

  List<Widget> _sections(Booking b) {
    final me = AppScope.api(context).currentUser?.userId;
    final tracking =
        (b.status == BookingStatus.accepted ||
            b.status == BookingStatus.inProgress) &&
        !b.isTaskerNoShow;
    return [
      _StatusHeader(booking: b),
      if (!const [
        BookingStatus.cancelled,
        BookingStatus.expired,
        BookingStatus.rejected,
      ].contains(b.status)) ...[
        const SizedBox(height: 12),
        _ProgressSteps(status: b.status),
      ],
      if (_PaymentStatusCard.applies(b)) ...[
        const SizedBox(height: 12),
        _PaymentStatusCard(booking: b),
      ],
      if (tracking) ...[
        const SizedBox(height: 16),
        const SectionHeader('Vị trí Tasker'),
        _TrackingCard(
          booking: b,
          location: _location,
          loaded: _locationLoaded,
        ),
      ],
      if (b.taskerId != null) ...[
        const SizedBox(height: 16),
        const SectionHeader('Tasker phụ trách'),
        _TaskerCard(
          booking: b,
          reviews: _taskerReviews,
          onCall: b.taskerPhone == null
              ? null
              : () => callPhone(context, b.taskerPhone!),
          onOpenProfile: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PublicProfilePage(
                userId: b.taskerId!,
                fallbackName: b.taskerName,
                isTasker: true,
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      const SectionHeader('Thông tin đơn'),
      AppCard(
        child: Column(
          children: [
            InfoRow(
              icon: Icons.event_rounded,
              label: 'Giờ hẹn',
              text: formatSchedule(b.scheduledTime),
            ),
            InfoRow(
              icon: Icons.place_rounded,
              label: 'Địa chỉ',
              text: b.address,
            ),
            if (b.contactPhone != null)
              InfoRow(
                icon: Icons.phone_outlined,
                label: 'SĐT liên hệ',
                text: b.contactPhone!,
              ),
            InfoRow(
              icon: Icons.format_list_numbered_rounded,
              label: 'Số lượng',
              text: b.quantityText,
            ),
            if (b.estimatedMinutes > 0)
              InfoRow(
                icon: Icons.timelapse_rounded,
                label: 'Thời lượng dự kiến',
                text: durationText(b.estimatedMinutes),
              ),
            if (b.note != null)
              InfoRow(
                icon: Icons.sticky_note_2_outlined,
                label: 'Ghi chú',
                text: b.note!,
              ),
            InfoRow(
              icon: PaymentMethod.icon(b.paymentMethod),
              label: 'Thanh toán',
              text:
                  '${PaymentMethod.label(b.paymentMethod)} · ${PaymentStatus.label(b.paymentStatus)}',
            ),
            InfoRow(
              icon: Icons.schedule_rounded,
              label: 'Đặt lúc',
              text: formatDateTime(b.createdAt),
            ),
          ],
        ),
      ),
      if (b.items.isNotEmpty && b.photos.isEmpty) ...[
        const SizedBox(height: 16),
        SectionHeader('Hạng mục cần làm (${b.items.length})'),
        AppCard(child: BookingItemList(items: b.items)),
      ],
      if (b.photos.isNotEmpty) ...[
        const SizedBox(height: 16),
        SectionHeader(b.items.isEmpty ? 'Ảnh trước và sau khi làm' : 'Hạng mục & ảnh trước / sau'),
        AppCard(child: BookingPhotoCompare(items: b.items, photos: b.photos)),
      ] else if (b.checkInPhotoUrl != null || b.checkOutPhotoUrl != null) ...[
        const SizedBox(height: 16),
        const SectionHeader('Ảnh công việc'),
        Row(
          children: [
            Expanded(
              child: NetworkPhoto(
                url: b.checkInPhotoUrl,
                caption: 'Trước khi làm',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NetworkPhoto(
                url: b.checkOutPhotoUrl,
                caption: 'Sau khi làm',
              ),
            ),
          ],
        ),
      ],
      if (_dispute != null) ...[
        const SizedBox(height: 16),
        const SectionHeader('Khiếu nại'),
        _DisputeCard(dispute: _dispute!),
      ],
      if (_reviews.isNotEmpty) ...[
        const SizedBox(height: 16),
        const SectionHeader('Đánh giá'),
        for (final review in _reviews) ...[
          _ReviewTile(
            review: review,
            onReport:
                review.revieweeId == me && !review.isFlagged && !review.isModerated
                ? () => _reportReview(review)
                : null,
            showModeration: review.revieweeId == me,
          ),
          const SizedBox(height: 8),
        ],
      ],
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          children: [
            SummaryRow('Tổng tiền dịch vụ', formatMoney(b.totalPrice)),
            if (b.hasDiscount)
              SummaryRow(
                'Mã giảm giá${b.voucherCode != null ? ' ${b.voucherCode}' : ''}',
                '−${formatMoney(b.discountAmount)}',
                valueColor: AppColors.success,
              ),
            if (b.cancellationFee > 0)
              SummaryRow(
                'Phí hủy',
                formatMoney(b.cancellationFee),
                valueColor: AppColors.danger,
              ),
            const Divider(height: 18),
            SummaryRow(
              b.status == BookingStatus.cancelled ? 'Cần thanh toán' : 'Thành tiền',
              formatMoney(
                b.status == BookingStatus.cancelled
                    ? b.cancellationFee
                    : b.payable,
              ),
              bold: true,
            ),
          ],
        ),
      ),
    ];
  }

  Widget? _actionBar(Booking b) {
    final buttons = <Widget>[];
    void primary(String label, VoidCallback onTap, {IconData? icon, Color? color}) {
      buttons.add(
        PrimaryButton(
          label: label,
          icon: icon,
          color: color,
          loading: _acting,
          onPressed: onTap,
        ),
      );
    }

    void secondary(String label, VoidCallback onTap, {IconData? icon, Color? color}) {
      buttons.add(
        SecondaryButton(
          label: label,
          icon: icon,
          color: color,
          onPressed: _acting ? null : onTap,
        ),
      );
    }

    final unpaidCancelFee =
        b.status == BookingStatus.cancelled &&
        b.isCash &&
        b.cancellationFee > 0 &&
        b.paymentStatus == null;

    switch (b.status) {
      case BookingStatus.awaitingPayment:
        primary('Thanh toán ngay', _pay, icon: Icons.lock_rounded);
        secondary('Hủy đơn', _cancel, color: AppColors.danger);
      case BookingStatus.pending:
      case BookingStatus.matched:
        if (b.stillSearching) {
          // BR-M07: khách tự bấm tìm lại, không phải chờ lượt quét tự động
          final wait = b.searchNowWaitMinutes();
          final sending = b.status == BookingStatus.matched;
          buttons.add(
            PrimaryButton(
              label: sending
                  ? 'Đang tìm…'
                  : wait > 0
                  ? 'Tìm lại sau $wait phút'
                  : 'Tìm lại ngay',
              icon: Icons.person_search_rounded,
              loading: _acting,
              onPressed: sending || wait > 0
                  ? null
                  : () => _run(
                      () => AppScope.api(context).searchNow(b.id),
                      success: 'Đang tìm lại Tasker gần bạn.',
                    ),
            ),
          );
        }
        secondary('Hủy đơn', _cancel, color: AppColors.danger);
      case BookingStatus.accepted:
        if (b.isTaskerNoShow) {
          primary('Tìm Tasker khác', _retry, icon: Icons.person_search_rounded);
          secondary('Hủy và hoàn 100%', _cancel, color: AppColors.danger);
        } else {
          secondary('Hủy đơn', _cancel, color: AppColors.danger);
        }
      case BookingStatus.noTaskerFound:
        primary('Tìm Tasker lại', _retry, icon: Icons.refresh_rounded);
        secondary('Hủy đơn', _cancel, color: AppColors.danger);
      case BookingStatus.completed:
        primary(
          'Xác nhận & thanh toán cho Tasker',
          _confirm,
          icon: Icons.task_alt_rounded,
        );
        if (b.canDispute) {
          secondary('Khiếu nại', _openDispute, icon: Icons.gavel_rounded);
        }
      case BookingStatus.paid:
        if (b.canReview) {
          primary('Đánh giá Tasker', _review, icon: Icons.star_rounded);
        }
        if (b.canDispute) {
          secondary('Khiếu nại', _openDispute, icon: Icons.gavel_rounded);
        }
        if (!b.canReview) {
          primary('Đặt lại dịch vụ này', _reorder, icon: Icons.replay_rounded);
        }
      case BookingStatus.paymentOverdue:
        primary(
          'Thanh toán ${formatMoney(b.totalPrice)}',
          _pay,
          icon: Icons.payments_rounded,
          color: AppColors.warning,
        );
        if (b.canDispute) {
          secondary('Tôi đã trả tiền mặt – Khiếu nại', _openDispute);
        }
      case BookingStatus.cancelled:
        if (unpaidCancelFee) {
          primary(
            'Thanh toán phí hủy ${formatMoney(b.cancellationFee)}',
            _pay,
            color: AppColors.warning,
          );
        }
        secondary('Đặt lại dịch vụ này', _reorder, icon: Icons.replay_rounded);
      case BookingStatus.expired:
      case BookingStatus.refunded:
        primary('Đặt lại dịch vụ này', _reorder, icon: Icons.replay_rounded);
      default:
        break;
    }
    if (buttons.isEmpty) return null;
    return BottomActionBar(children: buttons);
  }
}

// ------------------------------------------------------------------ Thành phần

/// Tóm tắt dòng tiền của đơn: đã trả gì, tiền đang ở đâu, bao giờ chuyển cho Tasker.
class _PaymentStatusCard extends StatefulWidget {
  const _PaymentStatusCard({required this.booking});

  final Booking booking;

  static bool applies(Booking b) => _PaymentStatusCardState.content(b) != null;

  @override
  State<_PaymentStatusCard> createState() => _PaymentStatusCardState();
}

class _PayContent {
  const _PayContent(this.color, this.icon, this.title, this.text, [this.timerLabel, this.timerAt]);

  final Color color;
  final IconData icon;
  final String title;
  final String text;
  final String? timerLabel;
  final DateTime? timerAt;
}

class _PaymentStatusCardState extends State<_PaymentStatusCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (content(widget.booking)?.timerAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static _PayContent? content(Booking b) {
    final total = formatMoney(b.payable); // số tiền khách thực trả (đã trừ mã giảm giá)
    final method = PaymentMethod.label(b.paymentMethod).toLowerCase();
    switch (b.status) {
      case BookingStatus.awaitingPayment:
        return _PayContent(
          AppColors.warning,
          Icons.schedule_rounded,
          'Chưa thanh toán · $total',
          b.paymentDueAt == null
              ? 'Thanh toán qua $method để hệ thống bắt đầu tìm Tasker. Bấm “Thanh toán ngay”.'
              : 'Thanh toán qua $method trước ${formatTime(b.paymentDueAt!)} để hệ thống bắt đầu tìm Tasker. Quá hạn đơn sẽ tự hủy.',
          'Còn',
          b.paymentDueAt,
        );
      case BookingStatus.pending:
      case BookingStatus.matched:
      case BookingStatus.accepted:
      case BookingStatus.inProgress:
      case BookingStatus.noTaskerFound:
        return b.isCash
            ? _PayContent(
                AppColors.info,
                Icons.payments_rounded,
                'Trả tiền mặt cho Tasker · $total',
                'Chuẩn bị sẵn tiền mặt và trả trực tiếp cho Tasker khi công việc hoàn thành. Tasker sẽ xác nhận đã nhận tiền trên ứng dụng.',
              )
            : _PayContent(
                AppColors.primaryDark,
                Icons.lock_rounded,
                'Đã thanh toán trước · $total',
                'Bạn đã trả qua $method. HomeService đang tạm giữ, chỉ chuyển cho Tasker khi bạn xác nhận hoàn thành.',
              );
      case BookingStatus.completed:
        return _PayContent(
          AppColors.warning,
          Icons.task_alt_rounded,
          'Tasker đã xong việc · chờ bạn xác nhận thanh toán',
          'Kiểm tra ảnh trước/sau rồi bấm “Xác nhận & thanh toán cho Tasker” để chuyển $total đang tạm giữ.'
              '${b.autoConfirmAt == null ? '' : ' Hệ thống tự chuyển lúc ${formatDateTime(b.autoConfirmAt!)} nếu bạn không phản hồi.'}',
          'Tự chuyển sau',
          b.autoConfirmAt,
        );
      case BookingStatus.paid:
        return _PayContent(
          AppColors.success,
          Icons.check_circle_rounded,
          'Đã thanh toán xong',
          b.isCash
              ? 'Bạn đã trả $total tiền mặt cho Tasker.'
              : '$total đã được chuyển cho Tasker. Cảm ơn bạn!',
        );
      case BookingStatus.disputed:
        return _PayContent(
          AppColors.warning,
          Icons.gpp_maybe_rounded,
          'Tiền đang được giữ để xử lý khiếu nại',
          b.isCash
              ? 'Quản trị viên đang xem xét khiếu nại của bạn.'
              : '$total vẫn được HomeService tạm giữ cho đến khi có kết quả khiếu nại.',
        );
      case BookingStatus.paymentOverdue:
        return _PayContent(
          AppColors.danger,
          Icons.payments_rounded,
          'Cần thanh toán · $total',
          'Tasker báo bạn chưa trả tiền mặt. Bấm “Thanh toán” để trả online, hoặc khiếu nại nếu bạn đã trả.',
        );
      case BookingStatus.cancelled:
      case BookingStatus.expired:
      case BookingStatus.refunded:
        if (b.isCash && b.cancellationFee > 0 && b.paymentStatus == null) {
          return _PayContent(
            AppColors.danger,
            Icons.payments_rounded,
            'Cần trả phí hủy · ${formatMoney(b.cancellationFee)}',
            'Bấm “Thanh toán phí hủy” để trả bằng ví điện tử hoặc thẻ.',
          );
        }
        if (b.paymentStatus == 5 || b.paymentStatus == 6) {
          return _PayContent(
            AppColors.info,
            Icons.replay_rounded,
            b.paymentStatus == 5 ? 'Đã hoàn tiền toàn bộ' : 'Đã hoàn tiền một phần',
            'Tiền được hoàn về phương thức bạn đã thanh toán.',
          );
        }
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = content(widget.booking);
    if (c == null) return const SizedBox.shrink();
    final left = c.timerAt?.difference(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.soft(c.color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(c.icon, color: c.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(c.text, style: AppText.muted),
              ],
            ),
          ),
          if (left != null && c.timerLabel != null) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(c.timerLabel!, style: AppText.small),
                const SizedBox(height: 2),
                Text(
                  left <= Duration.zero ? '00:00' : formatCountdown(left),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: c.color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bảng xác nhận hoàn thành & chuyển tiền đang tạm giữ cho Tasker.
/// Trả về 'confirm' | 'dispute' | null.
class _ReleaseSheet extends StatefulWidget {
  const _ReleaseSheet({required this.booking});

  final Booking booking;

  @override
  State<_ReleaseSheet> createState() => _ReleaseSheetState();
}

class _ReleaseSheetState extends State<_ReleaseSheet> {
  bool _agree = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final total = formatMoney(b.payable);
    Widget step(IconData icon, String label, String value, {bool highlight = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: highlight ? AppColors.primaryDark : AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: highlight
                  ? AppText.body.copyWith(fontWeight: FontWeight.w700)
                  : AppText.muted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primaryDark : AppColors.ink,
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Xác nhận & thanh toán cho Tasker', style: AppText.title),
            const SizedBox(height: 6),
            Text(
              'Tiền bạn trả trước đang được HomeService tạm giữ. Khi bạn xác nhận, khoản này được chuyển cho ${b.taskerName ?? 'Tasker'}.',
              style: AppText.muted,
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  step(Icons.account_balance_wallet_outlined, 'Bạn đã thanh toán trước', total),
                  step(Icons.lock_outline_rounded, 'HomeService đang tạm giữ', total),
                  if (b.hasDiscount)
                    step(
                      Icons.card_giftcard_rounded,
                      'HomeService bù phần giảm giá${b.voucherCode != null ? ' (mã ${b.voucherCode})' : ''}',
                      '+${formatMoney(b.discountAmount)}',
                    ),
                  const Divider(height: 8),
                  step(
                    Icons.send_rounded,
                    'Chuyển cho Tasker khi bạn xác nhận',
                    formatMoney(b.totalPrice),
                    highlight: true,
                  ),
                ],
              ),
            ),
            if (b.autoConfirmAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Nếu bạn không xác nhận, hệ thống tự chuyển tiền lúc ${formatDateTime(b.autoConfirmAt!)}.',
                style: AppText.small,
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              title: const Text(
                'Tôi đã kiểm tra ảnh trước/sau và hài lòng với công việc.',
                style: AppText.body,
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Xác nhận & chuyển $total',
              icon: Icons.task_alt_rounded,
              onPressed: _agree ? () => Navigator.of(context).pop('confirm') : null,
            ),
            if (b.canDispute) ...[
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Chưa hài lòng – Khiếu nại',
                icon: Icons.gavel_rounded,
                color: AppColors.danger,
                onPressed: () => Navigator.of(context).pop('dispute'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.booking});

  final Booking booking;

  String get _message {
    final b = booking;
    const radius = [3, 5, 8];
    switch (b.status) {
      case BookingStatus.awaitingPayment:
        return b.paymentDueAt == null
            ? 'Vui lòng thanh toán để hệ thống bắt đầu tìm Tasker.'
            : 'Vui lòng thanh toán trước ${formatTime(b.paymentDueAt!)} để hệ thống bắt đầu tìm Tasker.';
      case BookingStatus.pending:
        if (b.stillSearching) {
          final next = b.nextSearchAt == null ? '' : ' Lần tìm tiếp theo lúc ${formatTime(b.nextSearchAt!)}.';
          final stop = b.searchStopsAt == null
              ? ''
              : ' Hệ thống dừng tìm lúc ${formatTime(b.searchStopsAt!)} nếu vẫn chưa có Tasker.';
          return 'Chưa có Tasker nhận đơn, hệ thống vẫn đang tìm tiếp.$next$stop';
        }
        return 'Hệ thống đang tìm Tasker phù hợp ở gần bạn.';
      case BookingStatus.matched:
        final wave = b.currentWave.clamp(1, 3);
        return 'Đã gửi lời mời cho Tasker trong bán kính ${radius[wave - 1]} km (đợt $wave/3). Người nhận đầu tiên sẽ phụ trách đơn.';
      case BookingStatus.accepted:
        return b.isTaskerNoShow
            ? 'Tasker chưa đến sau 30 phút so với giờ hẹn. Bạn có thể tìm Tasker khác, hoặc hủy và được hoàn 100%.'
            : '${b.taskerName ?? 'Tasker'} sẽ đến lúc ${formatSchedule(b.scheduledTime)}.';
      case BookingStatus.inProgress:
        return '${b.taskerName ?? 'Tasker'} đang làm việc tại nhà bạn.';
      case BookingStatus.completed:
        return b.autoConfirmAt == null
            ? 'Tasker đã hoàn thành. Hãy kiểm tra ảnh và xác nhận.'
            : 'Tasker đã hoàn thành. Hãy kiểm tra ảnh và xác nhận trước ${formatDateTime(b.autoConfirmAt!)}; sau thời điểm đó hệ thống tự xác nhận.';
      case BookingStatus.paid:
        return 'Đơn đã hoàn tất. Cảm ơn bạn đã sử dụng HomeService!';
      case BookingStatus.cancelled:
        return b.cancellationFee > 0
            ? 'Đơn đã hủy, phí hủy ${formatMoney(b.cancellationFee)}.'
            : 'Đơn đã hủy.';
      case BookingStatus.noTaskerFound:
        return 'Đã gần giờ hẹn mà chưa có Tasker nhận đơn. Bạn có thể thử lại (có thể đổi giờ) hoặc hủy để được hoàn tiền.';
      case BookingStatus.expired:
        return 'Đơn đã hết hạn vì không có Tasker nhận. Tiền trả trước đã được hoàn 100%.';
      case BookingStatus.disputed:
        return 'Khiếu nại của bạn đang được quản trị viên xử lý.';
      case BookingStatus.refunded:
        return 'Đơn đã được hoàn tiền.';
      case BookingStatus.paymentOverdue:
        return 'Tasker báo bạn chưa thanh toán ${formatMoney(b.totalPrice)}. Vui lòng thanh toán, hoặc khiếu nại nếu bạn đã trả.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final color = b.isTaskerNoShow
        ? AppColors.danger
        : BookingStatus.color(b.status);
    return Container(
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
                  b.isTaskerNoShow
                      ? 'Tasker chưa đến'
                      : BookingStatus.label(b.status),
                  style: AppText.title.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(b.serviceCategoryName, style: AppText.label),
                const SizedBox(height: 6),
                Text(_message, style: AppText.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.status});

  final int status;

  int get _step => switch (status) {
    BookingStatus.awaitingPayment ||
    BookingStatus.pending ||
    BookingStatus.matched ||
    BookingStatus.noTaskerFound => 0,
    BookingStatus.accepted => 1,
    BookingStatus.inProgress => 2,
    _ => 3,
  };

  @override
  Widget build(BuildContext context) {
    const labels = ['Đặt đơn', 'Có Tasker', 'Đang làm', 'Hoàn thành'];
    final step = _step;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : i <= step
                            ? AppColors.primary
                            : AppColors.line,
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: i <= step ? AppColors.primary : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i <= step ? AppColors.primary : AppColors.line,
                          width: 2,
                        ),
                      ),
                      child: i < step
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == labels.length - 1
                            ? Colors.transparent
                            : i < step
                            ? AppColors.primary
                            : AppColors.line,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: i == step ? FontWeight.w800 : FontWeight.w500,
                    color: i <= step ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({
    required this.booking,
    required this.location,
    required this.loaded,
  });

  final Booking booking;
  final TaskerLocation? location;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final loc = location;
    if (!b.hasLocation) return const SizedBox.shrink();
    final home = GeoPoint(b.latitude!, b.longitude!);
    final pins = <MapPin>[
      MapPin(point: home, label: 'Nhà bạn', icon: Icons.home_rounded),
      if (loc != null)
        MapPin(
          point: GeoPoint(loc.latitude, loc.longitude),
          label: b.taskerName ?? 'Tasker',
          icon: Icons.delivery_dining_rounded,
          color: AppColors.primaryDark,
        ),
    ];
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          PinMap(
            // Dựng lại bản đồ khi Tasker di chuyển để căn giữa vị trí mới.
            key: ValueKey(loc?.updatedAt.millisecondsSinceEpoch ?? 0),
            pins: loc == null ? pins : pins.reversed.toList(),
            height: 210,
            zoom: 15,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.near_me_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc == null
                      ? (loaded
                            ? 'Tasker chưa chia sẻ vị trí.'
                            : 'Đang tải vị trí Tasker…')
                      : loc.distanceKm == null
                      ? 'Cập nhật ${formatRelative(loc.updatedAt)}'
                      : 'Cách nhà bạn ${formatKm(loc.distanceKm!)} · cập nhật ${formatRelative(loc.updatedAt)}',
                  style: AppText.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskerCard extends StatelessWidget {
  const _TaskerCard({
    required this.booking,
    required this.reviews,
    required this.onCall,
    required this.onOpenProfile,
  });

  final Booking booking;
  final ReviewSummary? reviews;
  final VoidCallback? onCall;

  /// US26 – mở hồ sơ Tasker (các đánh giá chỉ hiện trong hồ sơ, không hiện trong đơn).
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final name = booking.taskerName ?? 'Tasker';
    final rating = reviews?.ratingAverage;
    return AppCard(
      onTap: onOpenProfile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(name: name, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (booking.taskerBadges.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      AwardBadgeChip(label: booking.taskerBadges.first),
                    ],
                    const SizedBox(height: 4),
                    if (rating != null)
                      Row(
                        children: [
                          RatingStars(rating: rating, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            '${rating.toStringAsFixed(1)} · ${reviews!.reviewCount} đánh giá',
                            style: AppText.small,
                          ),
                        ],
                      )
                    else
                      const Text('Tasker mới', style: AppText.small),
                  ],
                ),
              ),
              if (onCall != null)
                IconButton.filled(
                  onPressed: onCall,
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.call_rounded, color: Colors.white),
                ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Icon(Icons.person_search_rounded, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Xem hồ sơ & đánh giá của Tasker',
                  style: AppText.label.copyWith(color: AppColors.primaryDark),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ],
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.dispute});

  final Dispute dispute;

  @override
  Widget build(BuildContext context) {
    final d = dispute;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DisputeReason.label(d.reason),
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                label: d.isOpen ? 'Đang xử lý' : 'Đã xử lý',
                color: d.isOpen ? AppColors.warning : AppColors.success,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(d.description, style: AppText.muted),
          if (d.evidenceUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: d.evidenceUrls.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) => NetworkPhoto(
                  url: d.evidenceUrls[index],
                  height: 72,
                  width: 72,
                ),
              ),
            ),
          ],
          if (d.taskerResponse != null) ...[
            const Divider(height: 22),
            const Text('Phản hồi của Tasker', style: AppText.label),
            const SizedBox(height: 4),
            Text(d.taskerResponse!, style: AppText.body),
          ],
          if (!d.isOpen) ...[
            const Divider(height: 22),
            const Text('Kết quả', style: AppText.label),
            const SizedBox(height: 4),
            Text(
              DisputeResolution.label(d.resolution),
              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            ),
            if (d.refundAmount != null && d.refundAmount! > 0)
              Text(
                'Hoàn lại ${formatMoney(d.refundAmount!)}',
                style: AppText.body.copyWith(color: AppColors.success),
              ),
            if (d.redoScheduledTime != null)
              Text(
                'Làm lại lúc ${formatSchedule(d.redoScheduledTime!)}',
                style: AppText.body,
              ),
            if (d.adminNote != null) ...[
              const SizedBox(height: 4),
              Text('Ghi chú: ${d.adminNote!}', style: AppText.muted),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    this.onReport,
    this.showModeration = false,
  });

  final Review review;
  final VoidCallback? onReport;

  /// Chỉ người được đánh giá (người có quyền báo cáo) mới thấy lý do báo cáo / kết quả kiểm duyệt.
  final bool showModeration;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${review.reviewerName} → ${review.revieweeName}',
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
          const SizedBox(height: 6),
          Row(
            children: [
              Text(formatRelative(review.createdAt), style: AppText.small),
              const Spacer(),
              if (review.isFlagged)
                const StatusChip(
                  label: 'Đang được xem xét',
                  color: AppColors.warning,
                  dense: true,
                )
              else if (onReport != null)
                TextButton.icon(
                  onPressed: onReport,
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('Báo cáo'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          if (showModeration) ReviewModerationInfo(review: review),
        ],
      ),
    );
  }
}
