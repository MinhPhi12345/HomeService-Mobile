import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const _gold = Color(0xFF8A6000);
const _goldSoft = Color(0xFFFFF4CC);
const _goldLine = Color(0xFFFFE08A);

/// Điểm thang 100 dạng "82,5".
String rankingPoints(double v) {
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  return s.replaceAll('.', ',');
}

String _percent(double rate) {
  final p = rate * 100;
  return '${p.toStringAsFixed(p % 1 == 0 ? 0 : 1).replaceAll('.', ',')}%';
}

/// Phần thưởng của một bậc hạng, vd "1.000.000 đ · chiết khấu 10% tháng sau · quà tặng".
String awardTierReward(AwardTier t) {
  final parts = <String>[
    if (t.bonus > 0) formatMoney(t.bonus),
    if (t.commissionRate != null) 'chiết khấu ${_percent(t.commissionRate!)} cả tháng sau',
    if (t.gift) 'quà tặng hiện vật',
  ];
  return parts.isEmpty ? 'Huy hiệu Tasker xuất sắc trên hồ sơ' : '${parts.join(' · ')} + huy hiệu';
}

/// Một dòng tóm tắt hạng dùng ở thẻ trang chủ Tasker.
String rankingSummary(MyRanking r) {
  if (!r.eligible) {
    return r.missingConditions.isEmpty ? 'Chưa đủ điều kiện xét tháng này' : r.missingConditions.first;
  }
  final head = 'Hạng ${r.rank} tạm tính · ${rankingPoints(r.score)} điểm';
  if (r.inTop) return '$head · đang trong top ${r.rules.topCount}';
  return '$head · cần thêm ${rankingPoints(r.pointsToTop ?? 0)} điểm để vào top ${r.rules.topCount}';
}

/// FR-31 – Tasker xem hạng tạm tính tháng này, điều kiện còn thiếu, điểm từng tiêu chí,
/// top N, quy tắc tham gia, phần thưởng và các tháng đã nhận thưởng.
class TaskerRankingPage extends StatefulWidget {
  const TaskerRankingPage({super.key, this.initial});

  final MyRanking? initial;

  @override
  State<TaskerRankingPage> createState() => _TaskerRankingPageState();
}

class _TaskerRankingPageState extends State<TaskerRankingPage> {
  MyRanking? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = widget.initial;
    _loading = _data == null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final data = await AppScope.api(context).getMyRanking();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _data;
    return Scaffold(
      appBar: hsAppBar('Tasker xuất sắc tháng'),
      body: _loading && r == null
          ? const LoadingView()
          : r == null
          ? ErrorView(message: _error ?? 'Không tải được xếp hạng.', onRetry: _load)
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _HeroCard(data: r),
                  if (!r.eligible) ...[
                    const SizedBox(height: 12),
                    _ConditionsCard(data: r),
                  ],
                  const SectionHeader('Điểm của bạn', padding: EdgeInsets.fromLTRB(0, 20, 0, 10)),
                  _ScoreCard(data: r),
                  SectionHeader('Top ${r.rules.topCount} tháng ${r.monthLabel}', padding: const EdgeInsets.fromLTRB(0, 20, 0, 10)),
                  _Leaderboard(data: r),
                  const SectionHeader('Phần thưởng', padding: EdgeInsets.fromLTRB(0, 20, 0, 10)),
                  _RewardsCard(rules: r.rules, myRank: r.inTop ? r.rank : null),
                  const SectionHeader('Quy tắc tham gia', padding: EdgeInsets.fromLTRB(0, 20, 0, 10)),
                  _RulesCard(rules: r.rules),
                  const SectionHeader('Các tháng đã nhận thưởng', padding: EdgeInsets.fromLTRB(0, 20, 0, 10)),
                  _HistoryCard(history: r.history),
                ],
              ),
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.data});

  final MyRanking data;

  @override
  Widget build(BuildContext context) {
    final r = data;
    final top = r.inTop;
    final fg = top ? const Color(0xFF6B4A00) : AppColors.primaryDark;
    final lines = <String>[
      if (r.eligible && r.inTop) 'Bạn đang trong top ${r.rules.topCount} của tháng.',
      if (r.eligible && !r.inTop && r.pointsToTop != null)
        'Cần thêm ${rankingPoints(r.pointsToTop!)} điểm để vào top ${r.rules.topCount}.',
      if (!r.eligible && r.pointsToTop == 0)
        'Hiện chưa đủ ${r.rules.topCount} Tasker đủ điều kiện – chỉ cần đạt điều kiện là vào top.',
      if (r.eligible && r.pointsBehindPrevious != null && r.rank != null)
        'Cần thêm ${rankingPoints(r.pointsBehindPrevious!)} điểm để vượt hạng ${r.rank! - 1}.',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: top ? const [_goldSoft, Color(0xFFFFFBEA)] : const [AppColors.primarySoft, Color(0xFFF6FCFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: top ? _goldLine : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: fg, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tháng ${r.monthLabel} · còn ${r.daysLeft} ngày',
                  style: AppText.label.copyWith(color: fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.eligible ? 'Hạng ${r.rank}' : 'Chưa đủ điều kiện',
                      style: AppText.display.copyWith(color: fg, fontSize: r.eligible ? 34.0 : 24.0),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.eligible
                          ? 'Tạm tính trong ${r.eligibleCount} Tasker đủ điều kiện'
                          : 'Xem điều kiện còn thiếu bên dưới',
                      style: AppText.muted,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(rankingPoints(r.score), style: AppText.title.copyWith(color: fg, fontSize: 24)),
                  const Text('điểm / 100', style: AppText.small),
                ],
              ),
            ],
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.trending_up_rounded, size: 16, color: fg),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(line, style: AppText.body.copyWith(color: AppColors.ink))),
                  ],
                ),
              ),
          ],
          if (r.currentReward != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Giữ hạng này đến hết tháng: ', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: awardTierReward(r.currentReward!)),
                  ],
                ),
                style: AppText.body.copyWith(color: const Color(0xFF6B4A00)),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Hạng tạm tính, cập nhật lúc ${formatTime(r.updatedAt)}. Kết quả chính thức được chốt sau khi hết tháng và quản trị viên duyệt.',
            style: AppText.small,
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.label, required this.value, required this.target});

  final String label;
  final int value;
  final int target;

  @override
  Widget build(BuildContext context) {
    final done = value >= target;
    final color = done ? AppColors.success : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppText.body)),
              Text('$value/$target', style: AppText.body.copyWith(fontWeight: FontWeight.w800, color: color)),
              if (done) ...[const SizedBox(width: 4), const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success)],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: target == 0 ? 1 : (value / target).clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.line,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionsCard extends StatelessWidget {
  const _ConditionsCard({required this.data});

  final MyRanking data;

  @override
  Widget build(BuildContext context) {
    final r = data;
    final others = r.missingConditions.where((m) => !m.startsWith('Cần thêm')).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Điều kiện để được xét', style: AppText.section),
          const SizedBox(height: 12),
          _ProgressLine(label: 'Đơn hoàn tất trong tháng', value: r.completedBookings, target: r.rules.minCompletedBookings),
          _ProgressLine(label: 'Đánh giá hợp lệ trong tháng', value: r.reviewCount, target: r.rules.minReviews),
          for (final m in others)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: NoticeBox(message: m, color: AppColors.danger, icon: Icons.error_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.data});

  final MyRanking data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (final p in data.scoreParts)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('${p.label} (${_percent(p.weight)})', style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      Text(
                        '${rankingPoints(p.points)}/${rankingPoints(p.weight * 100)}',
                        style: AppText.body.copyWith(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: p.value.clamp(0, 1).toDouble(),
                      minHeight: 8,
                      color: AppColors.primary,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(p.detail, style: AppText.small),
                ],
              ),
            ),
          Row(
            children: [
              const Expanded(child: Text('Tổng điểm', style: AppText.section)),
              Text('${rankingPoints(data.score)} / 100', style: AppText.money),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankMedal extends StatelessWidget {
  const _RankMedal(this.rank);

  final int rank;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (rank) {
      1 => (const Color(0xFFFFE08A), _gold),
      2 => (const Color(0xFFE3E8ED), const Color(0xFF55626B)),
      3 => (const Color(0xFFF6D3B8), const Color(0xFF9A4F1C)),
      _ => (AppColors.bg, AppColors.inkSoft),
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text('$rank', style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.data});

  final MyRanking data;

  @override
  Widget build(BuildContext context) {
    if (data.leaderboard.isEmpty) {
      return const AppCard(
        child: Text(
          'Chưa có Tasker nào đủ điều kiện trong tháng này. Hoàn tất đủ đơn và đánh giá để là người đầu tiên lên bảng!',
          style: AppText.muted,
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        children: [
          for (final e in data.leaderboard)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: e.isMe ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  _RankMedal(e.rank),
                  const SizedBox(width: 10),
                  UserAvatar(name: e.displayName, url: e.avatarUrl, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.isMe ? '${e.displayName} (bạn)' : e.displayName,
                          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${e.completedBookings} đơn · ${rankingPoints(e.ratingAverage)}★',
                          style: AppText.small,
                        ),
                      ],
                    ),
                  ),
                  Text(rankingPoints(e.score), style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          if (data.eligible && !data.inTop && data.rank != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Text(
                'Bạn đang ở hạng ${data.rank} với ${rankingPoints(data.score)} điểm.',
                style: AppText.muted,
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardsCard extends StatelessWidget {
  const _RewardsCard({required this.rules, this.myRank});

  final AwardRules rules;
  final int? myRank;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in rules.tiers)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: myRank != null && myRank! >= t.fromRank && myRank! <= t.toRank ? _goldSoft : AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: myRank != null && myRank! >= t.fromRank && myRank! <= t.toRank ? _goldLine : Colors.transparent,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(t.rankLabel, style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Expanded(child: Text(awardTierReward(t), style: AppText.body)),
                ],
              ),
            ),
          Text(
            'Chiết khấu nền tảng thông thường là ${_percent(rules.defaultCommissionRate)}. Tiền thưởng được cộng vào ví sau khi quản trị viên duyệt; '
            'huy hiệu "Tasker xuất sắc tháng" hiện trên hồ sơ khi khách xem.',
            style: AppText.small,
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.rules});

  final AwardRules rules;

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      'Trong tháng (theo giờ Việt Nam) hoàn tất ít nhất ${rules.minCompletedBookings} đơn và có ít nhất ${rules.minReviews} đánh giá hợp lệ.',
      'Không có lần không đến, không có khiếu nại bị xử lý bất lợi và tài khoản đang hoạt động.',
      'Điểm = Đánh giá ${_percent(rules.ratingWeight)} + Số đơn hoàn tất ${_percent(rules.completedWeight)} (so với người nhiều đơn nhất) '
          '+ Nhận lời mời ${_percent(rules.acceptanceWeight)} + Bắt đầu đúng giờ ${_percent(rules.onTimeWeight)} '
          '(trễ không quá ${rules.onTimeGraceMinutes} phút) + Không bị khiếu nại ${_percent(rules.noDisputeWeight)}.',
      'Điểm đánh giá tính theo trung bình có trọng số, nên vài đánh giá 5★ đầu tiên không đẩy điểm lên quá cao.',
      'Bằng điểm thì xếp theo số đơn hoàn tất, rồi đến điểm sao trung bình.',
      'Hết tháng, hệ thống chốt top ${rules.topCount}; quản trị viên kiểm tra rồi duyệt và trao thưởng. Tasker vi phạm có thể bị loại kèm lý do.',
    ];
    return AppCard(
      child: Column(
        children: [
          for (final (i, text) in items.indexed)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: AppText.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final List<MyAwardHistory> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const AppCard(
        child: Text('Bạn chưa nhận thưởng tháng nào. Cố gắng lọt top để nhận huy hiệu và tiền thưởng nhé!', style: AppText.muted),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (final h in history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _RankMedal(h.rank),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tháng ${h.month.toString().padLeft(2, '0')}/${h.year} · Hạng ${h.rank}',
                          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          [
                            if (h.bonusAmount > 0) formatMoney(h.bonusAmount),
                            if (h.preferentialRate != null) 'chiết khấu ${_percent(h.preferentialRate!)}',
                            if (h.hasGift) h.giftDescription ?? 'quà tặng',
                            'huy hiệu',
                          ].join(' · '),
                          style: AppText.small,
                        ),
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
