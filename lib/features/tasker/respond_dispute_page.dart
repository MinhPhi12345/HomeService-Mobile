import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_picker.dart';

/// US35 – Tasker phản hồi khiếu nại trong 24 giờ, kèm tối đa 5 ảnh.
class RespondDisputePage extends StatefulWidget {
  const RespondDisputePage({super.key, required this.dispute});

  final Dispute dispute;

  @override
  State<RespondDisputePage> createState() => _RespondDisputePageState();
}

class _RespondDisputePageState extends State<RespondDisputePage> {
  final _response = TextEditingController();
  List<String> _photos = const [];
  bool _sending = false;

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final text = _response.text.trim();
    if (text.length < 10) {
      showSnack(context, 'Vui lòng nhập phản hồi (ít nhất 10 ký tự).', error: true);
      return;
    }
    final api = AppScope.api(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      await api.respondDispute(
        widget.dispute.id,
        response: text,
        evidenceUrls: _photos,
      );
      if (!mounted) return;
      showSnack(context, 'Đã gửi phản hồi tới quản trị viên.');
      navigator.pop(true);
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispute;
    return Scaffold(
      appBar: hsAppBar('Phản hồi khiếu nại'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Khách: ${d.customerName}', style: AppText.label),
                const SizedBox(height: 6),
                Text(
                  DisputeReason.label(d.reason),
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(d.description, style: AppText.muted),
                if (d.evidenceUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final url in d.evidenceUrls)
                        NetworkPhoto(url: url, height: 72, width: 72),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          NoticeBox(
            message:
                'Hạn phản hồi: ${formatDateTime(d.taskerResponseDueAt)}. Hãy trình bày rõ ràng, lịch sự và gửi ảnh chứng minh nếu có.',
            color: AppColors.warning,
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 16),
          const SectionHeader('Phản hồi của bạn'),
          TextField(
            controller: _response,
            maxLines: 5,
            maxLength: 1000,
            decoration: appInputDecoration(
              hint: 'Ví dụ: Tôi đã lau toàn bộ phòng khách, ảnh sau khi làm cho thấy…',
            ),
          ),
          const SectionHeader('Ảnh chứng minh (không bắt buộc, tối đa 5)'),
          PhotoGrid(
            urls: _photos,
            onChanged: (urls) => setState(() => _photos = urls),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          PrimaryButton(
            label: 'Gửi phản hồi',
            icon: Icons.send_rounded,
            loading: _sending,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
