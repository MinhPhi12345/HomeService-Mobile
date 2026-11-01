import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Bottom sheet chấm sao + nhận xét. Trả true nếu đã gửi thành công.
Future<bool> showReviewSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Future<void> Function(int rating, String comment) onSubmit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) =>
        _ReviewSheet(title: title, subtitle: subtitle, onSubmit: onSubmit),
  );
  return result ?? false;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.title,
    required this.subtitle,
    required this.onSubmit,
  });

  final String title;
  final String subtitle;
  final Future<void> Function(int rating, String comment) onSubmit;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _sending = false;
  String? _error;

  static const _hints = ['', 'Rất tệ', 'Chưa tốt', 'Bình thường', 'Tốt', 'Tuyệt vời'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_rating, _comment.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(widget.title, style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: AppText.muted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF5B301),
                  ),
                ),
            ],
          ),
          Text(
            _hints[_rating],
            textAlign: TextAlign.center,
            style: AppText.label,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 500,
            decoration: appInputDecoration(
              hint: 'Chia sẻ thêm trải nghiệm của bạn (không bắt buộc)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Gửi đánh giá',
            icon: Icons.send_rounded,
            loading: _sending,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// US27 – Bottom sheet báo cáo đánh giá: bắt buộc nêu lý do (10–500 ký tự) để
/// quản trị viên có căn cứ phân xử. Trả true nếu đã gửi thành công.
Future<bool> showReportReviewSheet(
  BuildContext context, {
  required Review review,
  required Future<void> Function(String reason) onSubmit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _ReportReviewSheet(review: review, onSubmit: onSubmit),
  );
  return result ?? false;
}

class _ReportReviewSheet extends StatefulWidget {
  const _ReportReviewSheet({required this.review, required this.onSubmit});

  final Review review;
  final Future<void> Function(String reason) onSubmit;

  @override
  State<_ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends State<_ReportReviewSheet> {
  final _reason = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _reason.text.trim();
    if (text.length < 10) {
      setState(() => _error = 'Vui lòng nêu lý do cụ thể (ít nhất 10 ký tự).');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final review = widget.review;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Báo cáo đánh giá',
            style: AppText.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Quản trị viên sẽ đối chiếu với chi tiết đơn rồi quyết định giữ lại hoặc gỡ đánh giá, và gửi lý do cho bạn.',
            style: AppText.muted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.reviewerName,
                        style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    RatingStars(rating: review.rating.toDouble(), size: 15),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  review.comment == null ? 'Không có nhận xét' : '“${review.comment}”',
                  style: AppText.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            maxLines: 4,
            maxLength: 500,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: appInputDecoration(
              label: 'Lý do báo cáo',
              hint: 'Vì sao đánh giá này sai sự thật hoặc không phù hợp?',
              helper: 'Tối thiểu 10 ký tự',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Gửi báo cáo',
            icon: Icons.flag_rounded,
            color: AppColors.danger,
            loading: _sending,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// US27 – dòng trạng thái dưới một đánh giá: lý do mình đã báo cáo (đang chờ xử lý)
/// hoặc lý do quản trị viên giữ lại đánh giá. Không có gì để hiện → khoảng trống.
class ReviewModerationInfo extends StatelessWidget {
  const ReviewModerationInfo({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String? detail;
    final Color color;
    if (review.isFlagged && review.reportReason != null) {
      title = 'Đã báo cáo, chờ quản trị viên xử lý';
      detail = 'Lý do: ${review.reportReason}';
      color = AppColors.warning;
    } else if (review.isModerated) {
      title = 'Quản trị viên đã xem xét và giữ lại đánh giá';
      detail = review.moderationNote == null ? null : 'Lý do: ${review.moderationNote}';
      color = AppColors.info;
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.small.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(detail, style: AppText.muted),
          ],
        ],
      ),
    );
  }
}
