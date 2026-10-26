import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_picker.dart';

/// US35 – Khách khiếu nại trong 24 giờ sau khi hoàn thành (kèm 1–5 ảnh).
/// Với đơn 13 (khách chưa thanh toán) dùng để báo "tôi đã trả tiền mặt".
class DisputePage extends StatefulWidget {
  const DisputePage({super.key, required this.booking});

  final Booking booking;

  @override
  State<DisputePage> createState() => _DisputePageState();
}

class _DisputePageState extends State<DisputePage> {
  final _description = TextEditingController();
  late int _reason = _isPaymentClaim ? 4 : 0;
  List<String> _photos = const [];
  bool _sending = false;

  bool get _isPaymentClaim =>
      widget.booking.status == BookingStatus.paymentOverdue;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final text = _description.text.trim();
    if (text.length < 10) {
      showSnack(context, 'Vui lòng mô tả vấn đề (ít nhất 10 ký tự).', error: true);
      return;
    }
    if (_photos.isEmpty) {
      showSnack(context, 'Vui lòng đính kèm từ 1 đến 5 ảnh.', error: true);
      return;
    }
    final api = AppScope.api(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      await api.createDispute(
        widget.booking.id,
        reason: _reason,
        description: text,
        evidenceUrls: _photos,
      );
      if (!mounted) return;
      showSnack(
        context,
        'Đã gửi khiếu nại. Quản trị viên sẽ xử lý và thông báo cho bạn.',
      );
      navigator.pop(true);
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return Scaffold(
      appBar: hsAppBar(_isPaymentClaim ? 'Tôi đã thanh toán' : 'Khiếu nại'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          AppCard(
            child: Row(
              children: [
                ServiceIconBadge(name: b.serviceCategoryName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.serviceCategoryName,
                        style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Đơn #${b.id} · ${formatMoney(b.totalPrice)}',
                        style: AppText.small,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          NoticeBox(
            message: _isPaymentClaim
                ? 'Gửi ảnh biên nhận hoặc tin nhắn chứng minh bạn đã trả tiền mặt. Nếu quản trị viên xác nhận, khoản nợ sẽ được hủy.'
                : 'Khi khiếu nại, tiền tạm giữ chưa chuyển cho Tasker. Tasker có 24 giờ để phản hồi, sau đó quản trị viên quyết định: bác, hoàn một phần, hoàn toàn bộ hoặc làm lại miễn phí.',
            icon: Icons.info_outline_rounded,
          ),
          if (!_isPaymentClaim) ...[
            const SizedBox(height: 18),
            const SectionHeader('Lý do'),
            for (final reason in DisputeReason.values) ...[
              ChoiceTile(
                title: DisputeReason.label(reason),
                selected: _reason == reason,
                onTap: () => setState(() => _reason = reason),
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 12),
          const SectionHeader('Mô tả chi tiết'),
          TextField(
            controller: _description,
            maxLines: 5,
            maxLength: 1000,
            decoration: appInputDecoration(
              hint: _isPaymentClaim
                  ? 'Ví dụ: Tôi đã trả 300.000 đ tiền mặt cho Tasker lúc 10:30…'
                  : 'Ví dụ: Phòng khách chưa được lau, kính cửa còn bẩn…',
            ),
          ),
          const SizedBox(height: 8),
          const SectionHeader('Ảnh chứng minh (1–5 ảnh)'),
          PhotoGrid(
            urls: _photos,
            onChanged: (urls) => setState(() => _photos = urls),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          PrimaryButton(
            label: 'Gửi khiếu nại',
            icon: Icons.send_rounded,
            loading: _sending,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
