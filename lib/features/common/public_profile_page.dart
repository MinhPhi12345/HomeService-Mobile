import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/rewards.dart';

/// US26 – Hồ sơ của bên còn lại trong đơn (Tasker ↔ khách hàng) cùng các đánh giá
/// người đó đã nhận. Người viết đánh giá chỉ hiện tên gọi (vd. "Lan").
class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    super.key,
    required this.userId,
    this.fallbackName,
    this.isTasker = false,
  });

  final int userId;

  /// Tên hiển thị tạm trong lúc tải.
  final String? fallbackName;
  final bool isTasker;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  PublicProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await AppScope.api(context).getPublicProfile(widget.userId);
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final isTasker = p?.isTasker ?? widget.isTasker;
    return Scaffold(
      appBar: hsAppBar(isTasker ? 'Hồ sơ Tasker' : 'Hồ sơ khách hàng'),
      body: _loading && p == null
          ? const LoadingView()
          : p == null
          ? ErrorView(message: _error ?? 'Không tải được hồ sơ.', onRetry: _load)
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _Header(profile: p),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: p.ratingAverage == null
                              ? '—'
                              : p.ratingAverage!.toStringAsFixed(1),
                          label: p.ratingAverage == null ? 'Chưa có điểm' : 'Điểm trung bình',
                          icon: Icons.star_rounded,
                          color: const Color(0xFFF5B301),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '${p.reviewCount}',
                          label: 'Đánh giá',
                          icon: Icons.reviews_rounded,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          value: '${p.completedBookings}',
                          label: 'Đơn hoàn tất',
                          icon: Icons.task_alt_rounded,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  if (p.isTasker && (p.workingArea != null || p.skills != null)) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Column(
                        children: [
                          if (p.workingArea != null)
                            InfoRow(
                              icon: Icons.map_outlined,
                              label: 'Khu vực làm việc',
                              text: p.workingArea!,
                            ),
                          if (p.skills != null)
                            InfoRow(
                              icon: Icons.handyman_outlined,
                              label: 'Kỹ năng',
                              text: p.skills!,
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SectionHeader('Đánh giá (${p.reviewCount})'),
                  if (p.reviews.isEmpty)
                    const EmptyView(
                      icon: Icons.reviews_outlined,
                      title: 'Chưa có đánh giá nào',
                      message: 'Đánh giá sẽ hiện ở đây sau khi hoàn tất các đơn.',
                    )
                  else
                    for (final review in p.reviews) ...[
                      _ReviewItem(review: review),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          UserAvatar(name: p.displayName, url: p.avatarUrl, size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.displayName, style: AppText.title),
                const SizedBox(height: 2),
                Text(
                  '${p.isTasker ? 'Tasker' : 'Khách hàng'} · Tham gia từ ${formatDate(p.memberSince).substring(3)}',
                  style: AppText.muted,
                ),
                if (p.isTasker && p.isVerified == true) ...[
                  const SizedBox(height: 8),
                  const StatusChip(
                    label: 'Đã xác thực danh tính',
                    color: AppColors.success,
                    icon: Icons.verified_rounded,
                    dense: true,
                  ),
                ],
                if (p.isTasker && p.badges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final badge in p.badges.take(3))
                        AwardBadgeChip(label: badge.label, rank: badge.rank),
                    ],
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: AppText.title),
          Text(
            label,
            style: AppText.small,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: review.reviewerName, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.reviewerName,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              RatingStars(rating: review.rating.toDouble(), size: 15),
            ],
          ),
          const SizedBox(height: 6),
          Text(review.comment ?? 'Không có nhận xét', style: AppText.body),
          const SizedBox(height: 4),
          Text(formatRelative(review.createdAt), style: AppText.small),
        ],
      ),
    );
  }
}
