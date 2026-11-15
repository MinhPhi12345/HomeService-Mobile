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

  void _openReviews(PublicProfile p, {int? stars}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileReviewsPage(profile: p, initialStars: stars)),
    );
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
                          label: p.ratingAverage == null ? 'Chưa có điểm' : 'Trung bình',
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
                  SectionHeader(
                    'Đánh giá (${p.reviewCount})',
                    trailing: p.reviewCount > p.reviews.length
                        ? TextButton(onPressed: () => _openReviews(p), child: const Text('Xem tất cả'))
                        : null,
                  ),
                  if (p.reviews.isEmpty)
                    const EmptyView(
                      icon: Icons.reviews_outlined,
                      title: 'Chưa có đánh giá nào',
                      message: 'Đánh giá sẽ hiện ở đây sau khi hoàn tất các đơn.',
                    )
                  else ...[
                    if (p.ratingBreakdown.isNotEmpty) ...[
                      _RatingSummary(
                        profile: p,
                        onTapStars: (stars) => _openReviews(p, stars: stars),
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final review in p.reviews) ...[
                      _ReviewItem(review: review),
                      const SizedBox(height: 8),
                    ],
                    if (p.reviewCount > p.reviews.length)
                      SecondaryButton(
                        label: 'Xem tất cả ${p.reviewCount} đánh giá',
                        icon: Icons.reviews_outlined,
                        onPressed: () => _openReviews(p),
                      ),
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
                if (p.isTasker && (p.badges.isNotEmpty || p.currentTop != null)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // Đang trong top N tạm tính của tháng này
                      if (p.currentTop != null)
                        StatusChip(
                          label: p.currentTop!.label,
                          color: AppColors.primaryDark,
                          icon: Icons.trending_up_rounded,
                          dense: true,
                        ),
                      // Hạng chính thức các tháng đã được duyệt
                      for (final badge in p.badges.take(3))
                        AwardBadgeChip(label: 'Hạng ${badge.rank} · ${badge.label}', rank: badge.rank),
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

/// Điểm trung bình + số đánh giá theo từng mức sao; bấm một dòng để xem riêng các đánh giá mức đó.
class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.profile, required this.onTapStars});

  final PublicProfile profile;
  final ValueChanged<int> onTapStars;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final total = p.reviewCount == 0 ? 1 : p.reviewCount;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                p.ratingAverage == null ? '—' : p.ratingAverage!.toStringAsFixed(1),
                style: AppText.display,
              ),
              RatingStars(rating: p.ratingAverage ?? 0, size: 13),
              const SizedBox(height: 2),
              Text('${p.reviewCount} đánh giá', style: AppText.small),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (final s in p.ratingBreakdown)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: s.count == 0 ? null : () => onTapStars(s.stars),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 12, child: Text('${s.stars}', style: AppText.small)),
                          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF5B301)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: s.count / total,
                                minHeight: 7,
                                color: const Color(0xFFF5B301),
                                backgroundColor: AppColors.line,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 22,
                            child: Text('${s.count}', style: AppText.small, textAlign: TextAlign.right),
                          ),
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

/// Tất cả đánh giá của một người, lọc theo số sao, tải thêm khi cuộn (10 đánh giá / lần).
class ProfileReviewsPage extends StatefulWidget {
  const ProfileReviewsPage({super.key, required this.profile, this.initialStars});

  final PublicProfile profile;
  final int? initialStars;

  @override
  State<ProfileReviewsPage> createState() => _ProfileReviewsPageState();
}

class _ProfileReviewsPageState extends State<ProfileReviewsPage> {
  final _items = <Review>[];
  int? _stars;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _stars = widget.initialStars;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loadingMore || !_hasMore)) return;
    final request = ++_request; // bỏ kết quả của lần lọc cũ nếu người dùng đổi bộ lọc nhanh
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = more ? _page + 1 : 1;
      final result = await AppScope.api(context).getProfileReviews(widget.profile.userId, stars: _stars, page: page);
      if (!mounted || request != _request) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(result.items);
        _page = page;
        _total = result.totalCount;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _select(int? stars) {
    if (stars == _stars) return;
    setState(() => _stars = stars);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    int countOf(int s) => p.ratingBreakdown.where((x) => x.stars == s).fold(0, (sum, x) => sum + x.count);
    return Scaffold(
      appBar: hsAppBar('Đánh giá về ${p.displayName}'),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              children: [
                _StarChip(label: 'Tất cả (${p.reviewCount})', selected: _stars == null, onTap: () => _select(null)),
                for (var s = 5; s >= 1; s--)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _StarChip(
                      label: '$s★ (${countOf(s)})',
                      selected: _stars == s,
                      onTap: countOf(s) == 0 ? null : () => _select(s),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading && _items.isEmpty
                ? const LoadingView()
                : _error != null && _items.isEmpty
                ? ErrorView(message: _error!, onRetry: _load)
                : _items.isEmpty
                ? const EmptyView(
                    icon: Icons.reviews_outlined,
                    title: 'Không có đánh giá phù hợp',
                    message: 'Thử chọn mức sao khác.',
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) _load(more: true);
                      return false;
                    },
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _items.length + 1,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index < _items.length) return _ReviewItem(review: _items[index]);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: _loadingMore
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                                  : Text(
                                      _hasMore ? 'Kéo xuống để xem thêm' : 'Đã hiện ${_items.length}/$_total đánh giá',
                                      style: AppText.small,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StarChip extends StatelessWidget {
  const _StarChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !selected;
    return Material(
      color: selected ? AppColors.ink : AppColors.surface,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? AppColors.ink : AppColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : (disabled ? AppColors.muted : AppColors.inkSoft),
            ),
          ),
        ),
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
