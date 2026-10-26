import 'package:flutter/material.dart';

import '../core/api_client.dart';
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
