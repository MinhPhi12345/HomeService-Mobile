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
import '../../widgets/motion.dart';
import '../common/public_profile_page.dart';
import 'job_detail_page.dart';
import 'tasker_profile_page.dart';
import 'wallet_page.dart';

/// US16, US17, US28 – Tasker bật nhận đơn, xem lời mời theo đợt và nhận / từ chối.
class TaskerHomePage extends StatefulWidget {
  const TaskerHomePage({super.key, required this.onOpenJobs});

  final VoidCallback onOpenJobs;

  @override
  State<TaskerHomePage> createState() => TaskerHomePageState();
}

class TaskerHomePageState extends State<TaskerHomePage> {
  TaskerProfile? _profile;
  bool _profileMissing = false;
  Wallet? _wallet;
  List<TaskerOffer> _offers = const [];
  Booking? _nextJob;
  bool _loading = true;
  bool _toggling = false;
  bool _busy = false;
  String? _error;
  final Set<int> _acting = {};
  Timer? _poll;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    reload();
    _poll = Timer.periodic(AppConfig.offerRefresh, (_) => _loadOffers());
    // Cập nhật đồng hồ đếm ngược của lời mời mỗi giây.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _offers.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    final api = AppScope.api(context);
    unawaited(api.ensureServiceImages()); // ảnh dịch vụ cho thẻ lời mời / đơn
    try {
      final profile = await api.getTaskerProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileMissing = profile == null;
        _error = null;
      });
      if (profile != null && profile.isApproved) {
        final results = await Future.wait([
          api.getWallet(),
          api.getMyBookings(upcoming: true),
        ]);
        if (!mounted) return;
        final upcoming = results[1] as List<Booking>;
        setState(() {
          _wallet = results[0] as Wallet;
          _nextJob = upcoming.isEmpty ? null : upcoming.first;
        });
        await _loadOffers();
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOffers() async {
    final profile = _profile;
    if (_busy || profile == null || !profile.isApproved || !mounted) return;
    _busy = true;
    try {
      final offers = await AppScope.api(context).getMyOffers();
      if (mounted) {
        setState(
          () => _offers = offers
              .where((o) => o.status == OfferStatus.sent)
              .toList(),
        );
      }
    } catch (_) {
      // Lần sau tự thử lại.
    } finally {
      _busy = false;
    }
  }

  /// Chưa đủ ký quỹ: nhắc nạp tiền thay vì gọi API (server cũng chặn).
  Future<void> _askDeposit({required String reason}) async {
    final wallet = _wallet;
    if (wallet == null) return;
    final go = await confirmDialog(
      context,
      title: 'Cần ký quỹ để nhận đơn',
      message:
          '$reason\n\nVí cần tối thiểu ${formatMoney(wallet.minDeposit)} khả dụng. '
          'Hiện có ${formatMoney(wallet.availableBalance)}, cần nạp thêm ${formatMoney(wallet.depositShortfall)}.',
      confirmText: 'Nạp tiền ngay',
      cancelText: 'Để sau',
    );
    if (go && mounted) await _open(WalletTopUpPage(wallet: wallet));
  }

  Future<void> _toggle(bool value) async {
    if (value && _wallet != null && !_wallet!.meetsDeposit) {
      await _askDeposit(reason: 'Bạn chưa đủ ký quỹ nên chưa thể bật nhận đơn.');
      return;
    }
    final api = AppScope.api(context);
    setState(() => _toggling = true);
    try {
      if (value) {
        // Gửi vị trí hiện tại 1 lần khi bật; quá 60 phút hệ thống dùng điểm làm việc.
        final point = await LocationService.tryCurrent();
        await api.setAvailability(
          true,
          latitude: point?.latitude,
          longitude: point?.longitude,
        );
        if (mounted) {
          showSnack(
            context,
            point == null
                ? 'Đã bật nhận đơn. Chưa lấy được GPS nên hệ thống dùng điểm làm việc trong hồ sơ.'
                : 'Đã bật nhận đơn. Lời mời mới sẽ hiện ở đây.',
          );
        }
      } else {
        await api.setAvailability(false);
      }
      await reload();
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _accept(TaskerOffer offer) async {
    if (_wallet != null && !_wallet!.meetsDeposit) {
      await _askDeposit(reason: 'Số dư ví đã xuống dưới mức ký quỹ nên chưa nhận được đơn này.');
      return;
    }
    final api = AppScope.api(context);
    final navigator = Navigator.of(context);
    setState(() => _acting.add(offer.offerId));
    try {
      await api.acceptOffer(offer.bookingId);
      if (!mounted) return;
      showSnack(context, 'Bạn đã nhận đơn #${offer.bookingId}!');
      setState(() => _offers = _offers.where((o) => o != offer).toList());
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => JobDetailPage(bookingId: offer.bookingId),
        ),
      );
      if (mounted) reload();
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
      await _loadOffers();
    } finally {
      if (mounted) setState(() => _acting.remove(offer.offerId));
    }
  }

  Future<void> _reject(TaskerOffer offer) async {
    final api = AppScope.api(context);
    setState(() => _acting.add(offer.offerId));
    try {
      await api.rejectOffer(offer.bookingId);
      if (mounted) {
        setState(() => _offers = _offers.where((o) => o != offer).toList());
      }
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
      await _loadOffers();
    } finally {
      if (mounted) setState(() => _acting.remove(offer.offerId));
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.api(context).currentUser;
    final profile = _profile;
    final approved = profile != null && profile.isApproved;
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: reload,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Tasker dùng đầu trang màu đậm để phân biệt với giao diện Khách hàng
            BrandHeader(
              colors: const [Color(0xFF134A46), AppColors.ink],
              child: FadeSlideIn(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${greeting()},',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.fullName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            approved
                                ? (profile.isAvailable
                                      ? 'Bạn đang nhận lời mời trong bán kính ${profile.serviceRadiusKm} km'
                                      : 'Bật nhận đơn để bắt đầu kiếm thu nhập')
                                : 'Tài khoản Tasker',
                            style: const TextStyle(
                              color: Color(0xFF8FF0E4),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (approved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              profile.ratingAverage > 0
                                  ? profile.ratingAverage.toStringAsFixed(1)
                                  : 'Mới',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              '★ đánh giá',
                              style: TextStyle(
                                color: Color(0xFFFFC266),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _content(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content() {
    if (_loading) {
      return const [
        SizedBox(height: 120),
        LoadingView(),
      ];
    }
    if (_error != null && _profile == null && !_profileMissing) {
      return [ErrorView(message: _error!, onRetry: reload)];
    }
    final profile = _profile;
    if (profile == null) {
      return [
        _OnboardingCard(
          icon: Icons.badge_rounded,
          color: AppColors.primary,
          title: 'Hoàn tất hồ sơ để bắt đầu nhận việc',
          message:
              'Gửi số CCCD, ảnh CCCD, kỹ năng và điểm làm việc. Quản trị viên sẽ duyệt hồ sơ của bạn.',
          action: 'Gửi hồ sơ Tasker',
          onTap: () => _open(const TaskerProfilePage()),
        ),
        const SizedBox(height: 16),
        const _HowItWorks(),
      ];
    }
    if (profile.verificationStatus == VerificationStatus.pending) {
      return [
        _OnboardingCard(
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warning,
          title: 'Hồ sơ đang chờ duyệt',
          message:
              'Quản trị viên đang kiểm tra CCCD và kỹ năng của bạn. Bạn sẽ nhận thông báo ngay khi có kết quả.',
          action: 'Xem lại hồ sơ',
          onTap: () => _open(const TaskerProfilePage()),
        ),
        const SizedBox(height: 16),
        const _HowItWorks(),
      ];
    }
    if (profile.verificationStatus == VerificationStatus.rejected) {
      return [
        _OnboardingCard(
          icon: Icons.report_gmailerrorred_rounded,
          color: AppColors.danger,
          title: 'Hồ sơ chưa được duyệt',
          message:
              'Vui lòng kiểm tra lại ảnh CCCD và thông tin, sau đó gửi lại hồ sơ.',
          action: 'Cập nhật và gửi lại',
          onTap: () => _open(const TaskerProfilePage()),
        ),
      ];
    }

    final wallet = _wallet;
    final preferential = profile.preferentialCommissionRate;
    return [
      // FR-31 – Tasker xuất sắc tháng: huy hiệu + chiết khấu ưu đãi đang hiệu lực
      if (profile.badges.isNotEmpty || preferential != null) ...[
        _AwardCard(
          badge: profile.badges.isEmpty ? null : profile.badges.first,
          rate: preferential,
          until: profile.preferentialUntil,
        ),
        const SizedBox(height: 12),
      ],
      _AvailabilityCard(
        available: profile.isAvailable,
        busy: _toggling,
        radiusKm: profile.serviceRadiusKm,
        area: profile.workingArea,
        depositOk: wallet?.meetsDeposit ?? true,
        onChanged: _toggle,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Số dư khả dụng',
              value: wallet == null ? '—' : formatMoney(wallet.availableBalance),
              onTap: () => _open(const WalletPage()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: Icons.event_available_rounded,
              label: 'Việc sắp tới',
              value: _nextJob == null
                  ? 'Chưa có'
                  : formatSchedule(_nextJob!.scheduledTime),
              onTap: _nextJob == null
                  ? widget.onOpenJobs
                  : () => _open(JobDetailPage(bookingId: _nextJob!.id)),
            ),
          ),
        ],
      ),
      if (wallet != null && !wallet.meetsDeposit) ...[
        const SizedBox(height: 12),
        NoticeBox(
          title: 'Chưa đủ ký quỹ để nhận đơn',
          message:
              'Ví cần tối thiểu ${formatMoney(wallet.minDeposit)} khả dụng thì mới bật nhận đơn và nhận được lời mời. '
              'Bạn cần nạp thêm ${formatMoney(wallet.depositShortfall)}.',
          color: AppColors.warning,
          icon: Icons.warning_amber_rounded,
          action: PrimaryButton(
            label: 'Nạp tiền ngay',
            icon: Icons.add_rounded,
            expand: false,
            color: AppColors.warning,
            onPressed: () => _open(WalletTopUpPage(wallet: wallet)),
          ),
        ),
      ],
      const SizedBox(height: 20),
      SectionHeader(
        'Lời mời đang chờ',
        trailing: _offers.isEmpty
            ? null
            : StatusChip(label: '${_offers.length}', color: AppColors.accent),
      ),
      if (!profile.isAvailable)
        EmptyView(
          icon: Icons.toggle_off_outlined,
          title: 'Bạn đang tắt nhận đơn',
          message: wallet != null && !wallet.meetsDeposit
              ? 'Nạp đủ ký quỹ ${formatMoney(wallet.minDeposit)} rồi bật "Sẵn sàng nhận đơn" để bắt đầu nhận lời mời.'
              : 'Bật "Sẵn sàng nhận đơn" để bắt đầu nhận lời mời.',
        )
      else if (_offers.isEmpty)
        const _WaitingRadar()
      else
        for (final offer in _offers) ...[
          _OfferCard(
            offer: offer,
            busy: _acting.contains(offer.offerId),
            onAccept: () => _accept(offer),
            onReject: () => _reject(offer),
            onOpenCustomer: offer.customerId == 0
                ? null
                : () => _open(
                    PublicProfilePage(userId: offer.customerId),
                  ),
          ),
          const SizedBox(height: 12),
        ],
    ];
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.available,
    required this.busy,
    required this.radiusKm,
    required this.area,
    required this.onChanged,
    this.depositOk = true,
  });

  final bool available;
  final bool busy;
  final int radiusKm;
  final String? area;
  final bool depositOk;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: available
              ? const [AppColors.primary, AppColors.primaryDark]
              : const [Color(0xFF5B6B69), Color(0xFF3E4C4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  available ? 'Đang sẵn sàng nhận đơn' : 'Đang tạm nghỉ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bán kính $radiusKm km${area == null ? '' : ' · $area'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                if (!depositOk) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Cần nạp đủ ký quỹ để bật',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          busy
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.6,
                  ),
                )
              : Switch(
                  value: available,
                  onChanged: onChanged,
                  activeTrackColor: Colors.white,
                  thumbColor: WidgetStatePropertyAll(
                    available ? AppColors.primary : Colors.white,
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(label, style: AppText.small),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    this.onOpenCustomer,
  });

  final TaskerOffer offer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  /// US26 – mở hồ sơ khách (các đánh giá chỉ hiện trong hồ sơ).
  final VoidCallback? onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final left = offer.expiresAt.difference(DateTime.now());
    final expired = left <= Duration.zero;
    final urgent = left.inSeconds <= 15;
    return AppCard(
      borderColor: urgent && !expired ? AppColors.accent : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ServiceIconBadge(name: offer.serviceCategoryName, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.serviceCategoryName,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Cách bạn ${formatKm(offer.distanceKm)} · đợt ${offer.wave}',
                      style: AppText.small,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: urgent ? AppColors.accentSoft : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: urgent ? AppColors.accent : AppColors.primaryDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      expired ? 'Hết hạn' : formatCountdown(left),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: urgent ? AppColors.accent : AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow(
            icon: Icons.event_rounded,
            text: formatSchedule(offer.scheduledTime),
          ),
          InfoRow(icon: Icons.place_rounded, text: offer.address),
          InfoRow(
            icon: Icons.format_list_numbered_rounded,
            text: 'Số lượng: ${offer.quantity}',
          ),
          if (offer.note != null)
            InfoRow(icon: Icons.sticky_note_2_outlined, text: offer.note!),
          InfoRow(
            icon: Icons.star_rounded,
            text: offer.customerRatingAverage == null
                ? 'Khách chưa có đánh giá'
                : 'Khách được đánh giá ${offer.customerRatingAverage!.toStringAsFixed(1)}★ · ${offer.customerReviewCount} lượt',
            trailing: onOpenCustomer == null
                ? null
                : InkWell(
                    onTap: onOpenCustomer,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Xem hồ sơ',
                        style: AppText.label.copyWith(color: AppColors.primaryDark),
                      ),
                    ),
                  ),
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bạn nhận được', style: AppText.small),
                    Text(formatMoney(offer.earning), style: AppText.money),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(
                    label: PaymentMethod.label(offer.paymentMethod),
                    color: offer.paymentMethod == PaymentMethod.cash
                        ? AppColors.warning
                        : AppColors.info,
                    dense: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Giá đơn ${formatMoney(offer.totalPrice)}',
                    style: AppText.small,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Bỏ qua',
                  color: AppColors.inkSoft,
                  onPressed: busy || expired ? null : onReject,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Nhận đơn',
                  icon: Icons.check_rounded,
                  loading: busy,
                  onPressed: expired ? null : onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.soft(color),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppText.title),
          const SizedBox(height: 6),
          Text(message, style: AppText.muted),
          const SizedBox(height: 16),
          PrimaryButton(label: action, onPressed: onTap),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.badge_outlined, 'Gửi hồ sơ', 'CCCD, kỹ năng, điểm làm việc và bán kính 3/5/8 km.'),
      (Icons.verified_outlined, 'Được duyệt', 'Quản trị viên kiểm tra và kích hoạt tài khoản.'),
      (Icons.toggle_on_outlined, 'Bật nhận đơn', 'Lời mời gửi theo đợt 3 → 5 → 8 km, ai nhận trước làm trước.'),
      (Icons.payments_outlined, 'Nhận tiền', 'Đơn online về ví sau khi khách xác nhận, trừ 20% phí nền tảng.'),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Làm Tasker trên HomeService', style: AppText.section),
          const SizedBox(height: 12),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(step.$1, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$2,
                          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(step.$3, style: AppText.muted),
                      ],
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

/// Radar lan tỏa khi đang chờ lời mời.
class _WaitingRadar extends StatelessWidget {
  const _WaitingRadar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Column(
        children: [
          PulseRings(
            size: 150,
            child: CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.radar_rounded, color: Colors.white, size: 30),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Đang chờ lời mời mới…',
            style: AppText.section,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            'Khi có khách gần bạn đặt đơn phù hợp kỹ năng, lời mời sẽ hiện ở đây. Mỗi lời mời chỉ có 45–60 giây.',
            style: AppText.muted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// FR-31 – thẻ "Tasker xuất sắc tháng": huy hiệu và chiết khấu ưu đãi đang hiệu lực.
class _AwardCard extends StatelessWidget {
  const _AwardCard({required this.badge, required this.rate, required this.until});

  final AwardBadge? badge;
  final double? rate;
  final DateTime? until;

  @override
  Widget build(BuildContext context) {
    final percent = rate == null ? null : (rate! * 100).toStringAsFixed(rate! * 100 % 1 == 0 ? 0 : 1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF4CC), Color(0xFFFFFBEA)]),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFFFE08A), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF8A6000)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge == null ? 'Ưu đãi Tasker xuất sắc' : '${badge!.label} · hạng ${badge!.rank}',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF6B4A00)),
                ),
                if (percent != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Chiết khấu ưu đãi $percent% cho đơn nhận${until != null ? ' đến hết ${formatDate(until!.subtract(const Duration(minutes: 1)))}' : ''}',
                    style: AppText.small.copyWith(color: const Color(0xFF6B4A00)),
                  ),
                ] else ...[
                  const SizedBox(height: 2),
                  Text(
                    'Huy hiệu hiển thị trên hồ sơ của bạn khi khách xem.',
                    style: AppText.small.copyWith(color: const Color(0xFF6B4A00)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
