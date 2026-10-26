import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'booking_create_page.dart';
import 'booking_detail_page.dart';

/// Trang chủ Khách hàng (US10, US11): tìm dịch vụ, bảng giá, đơn đang xử lý.
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key, required this.onOpenOrders});

  final VoidCallback onOpenOrders;

  @override
  State<CustomerHomePage> createState() => CustomerHomePageState();
}

class CustomerHomePageState extends State<CustomerHomePage> {
  List<ServiceCategory> _services = const [];
  List<Booking> _active = const [];
  Profile? _profile;
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final api = AppScope.api(context);
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        api.getCategories(),
        api.getMyBookings(statuses: BookingStatus.active),
        api.getProfile(),
      ]);
      if (!mounted) return;
      setState(() {
        _services = results[0] as List<ServiceCategory>;
        _active = results[1] as List<Booking>;
        _profile = results[2] as Profile;
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openService(ServiceCategory service) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingCreatePage(
          service: service,
          initialAddress: _profile?.address,
        ),
      ),
    );
    if (mounted) reload();
  }

  Future<void> _openBooking(Booking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingDetailPage(bookingId: booking.id)),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.api(context).currentUser;
    final name = _profile?.fullName ?? user?.fullName ?? '';
    final q = _query.trim().toLowerCase();
    final services = q.isEmpty
        ? _services
        : _services
              .where(
                (s) =>
                    s.name.toLowerCase().contains(q) ||
                    (s.description ?? '').toLowerCase().contains(q),
              )
              .toList();

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: reload,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            BrandHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FadeSlideIn(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${greeting()},',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: UserAvatar(
                          name: name,
                          url: _profile?.avatarUrl,
                          size: 44,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      'Hôm nay bạn cần giúp việc gì?',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: appInputDecoration(
                        hint: 'Tìm dọn dẹp, giặt ủi, nấu ăn…',
                        icon: Icons.search_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((_profile?.outstandingAmount ?? 0) > 0) ...[
                    NoticeBox(
                      title: 'Bạn có khoản chưa thanh toán',
                      message:
                          'Vui lòng thanh toán ${formatMoney(_profile!.outstandingAmount)} trước khi đặt đơn mới.',
                      color: AppColors.warning,
                      icon: Icons.warning_amber_rounded,
                      action: SecondaryButton(
                        label: 'Xem đơn cần thanh toán',
                        expand: false,
                        color: AppColors.warning,
                        onPressed: widget.onOpenOrders,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_active.isNotEmpty) ...[
                    SectionHeader(
                      'Đơn đang xử lý',
                      trailing: TextButton(
                        onPressed: widget.onOpenOrders,
                        child: const Text('Xem tất cả'),
                      ),
                      padding: const EdgeInsets.only(bottom: 4),
                    ),
                    for (final booking in _active.take(2)) ...[
                      FadeSlideIn(
                        child: _ActiveBookingTile(
                          booking: booking,
                          onTap: () => _openBooking(booking),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 10),
                  ],
                  SectionHeader(q.isEmpty ? 'Dịch vụ & bảng giá' : 'Kết quả tìm kiếm'),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: LoadingView(),
                    )
                  else if (_error != null && _services.isEmpty)
                    ErrorView(message: _error!, onRetry: reload)
                  else if (services.isEmpty)
                    const EmptyView(
                      icon: Icons.search_off_rounded,
                      title: 'Không tìm thấy dịch vụ phù hợp',
                      message: 'Thử từ khóa khác như "dọn dẹp", "giặt ủi"…',
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: services.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 172,
                          ),
                      itemBuilder: (context, index) => FadeSlideIn(
                        key: ValueKey('svc-${services[index].id}-$q'),
                        delay: Duration(milliseconds: 60 * (index % 6)),
                        child: PressableScale(
                          child: _ServiceTile(
                            service: services[index],
                            onTap: () => _openService(services[index]),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const SectionHeader('An tâm ở từng bước'),
                  const _TrustCarousel(),
                  const SizedBox(height: 24),
                  const SectionHeader('Đặt dịch vụ chỉ với 3 bước'),
                  const _StepsRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});

  final ServiceCategory service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ServiceIconBadge(name: service.name, size: 46),
          const SizedBox(height: 12),
          Text(
            service.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Text('Chỉ từ', style: AppText.small),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatMoney(service.basePrice),
                  style: AppText.money.copyWith(fontSize: 15),
                ),
                TextSpan(text: ' / ${service.unit}', style: AppText.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveBookingTile extends StatelessWidget {
  const _ActiveBookingTile({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = booking.isTaskerNoShow
        ? AppColors.danger
        : BookingStatus.color(booking.status);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.soft(color),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(BookingStatus.icon(booking.status), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.serviceCategoryName,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  formatSchedule(booking.scheduledTime),
                  style: AppText.small,
                ),
              ],
            ),
          ),
          StatusChip(
            label: booking.isTaskerNoShow
                ? 'Tasker chưa đến'
                : BookingStatus.label(booking.status),
            color: color,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// Dải thẻ tính năng nền tối, vuốt ngang (giống phần "An tâm ở từng bước" trên website).
class _TrustCarousel extends StatelessWidget {
  const _TrustCarousel();

  static const _items = [
    (
      Icons.lock_clock_rounded,
      'Tiền được tạm giữ',
      'Chỉ chuyển cho Tasker khi bạn xác nhận công việc đã xong.',
    ),
    (
      Icons.verified_user_rounded,
      'Tasker đã xác thực',
      'Quản trị viên duyệt CCCD, kỹ năng và khu vực của từng Tasker.',
    ),
    (
      Icons.photo_camera_rounded,
      'Ảnh trước và sau',
      'Tasker chụp ảnh lúc bắt đầu và khi xong việc để bạn đối chiếu.',
    ),
    (
      Icons.gavel_rounded,
      'Khiếu nại trong 24 giờ',
      'Gửi ảnh bằng chứng, tiền vẫn được giữ tới khi có kết quả.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          const _TrustCard(
            width: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: AnimatedRoute(dark: true, height: 110)),
                SizedBox(height: 12),
                Text('Theo dõi Tasker trên bản đồ', style: _TrustCard.title),
                SizedBox(height: 4),
                Text(
                  'Thấy Tasker đang đến và khoảng cách tới nhà bạn.',
                  style: _TrustCard.body,
                ),
              ],
            ),
          ),
          for (final item in _items) ...[
            const SizedBox(width: 12),
            _TrustCard(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8FF0E4).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.$1, color: const Color(0xFF8FF0E4)),
                  ),
                  const Spacer(),
                  Text(item.$2, style: _TrustCard.title),
                  const SizedBox(height: 4),
                  Text(item.$3, style: _TrustCard.body),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.width, required this.child});

  final double width;
  final Widget child;

  static const title = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(
    color: Color(0xFF9FBAB6),
    fontSize: 12.5,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF134A46), AppColors.ink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: child,
    );
  }
}

class _StepsRow extends StatelessWidget {
  const _StepsRow();

  static const _steps = [
    (Icons.touch_app_rounded, 'Chọn dịch vụ', 'Chọn giờ hẹn và ghim địa chỉ trên bản đồ'),
    (
      Icons.account_balance_wallet_rounded,
      'Thanh toán',
      'Ví điện tử hoặc thẻ, tiền được hệ thống tạm giữ',
    ),
    (Icons.task_alt_rounded, 'Xác nhận', 'Khi việc đã xong, tiền mới chuyển cho Tasker'),
  ];

  /// Dạng dòng thời gian dọc: mỗi bước một hàng nên luôn đều nhau,
  /// kể cả khi chữ dài hay điện thoại đặt cỡ chữ lớn.
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(_steps[i].$1, color: Colors.white, size: 21),
                      ),
                      if (i < _steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: AppColors.primarySoft,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bước ${i + 1} · ${_steps[i].$2}',
                            style: AppText.body.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(_steps[i].$3, style: AppText.muted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
