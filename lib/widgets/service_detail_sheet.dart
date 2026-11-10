import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// SRS v1.8 – nút ⓘ "Chi tiết dịch vụ": công việc bao gồm / không bao gồm / khách chuẩn bị / lưu ý,
/// đơn giá, cách tính số lượng và thời lượng.
Future<void> showServiceDetail(
  BuildContext context,
  ServiceCategory service, {
  VoidCallback? onChoose,
  String chooseLabel = 'Đặt dịch vụ này',
  bool forTasker = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => _ServiceDetailBody(
        service: service,
        controller: controller,
        onChoose: onChoose,
        chooseLabel: chooseLabel,
        forTasker: forTasker,
      ),
    ),
  );
}

class _ServiceDetailBody extends StatelessWidget {
  const _ServiceDetailBody({
    required this.service,
    required this.controller,
    required this.onChoose,
    required this.chooseLabel,
    required this.forTasker,
  });

  final ServiceCategory service;
  final ScrollController controller;
  final VoidCallback? onChoose;
  final String chooseLabel;

  /// Tasker xem trước khi chọn kỹ năng: đổi tiêu đề các mục theo góc nhìn người làm.
  final bool forTasker;

  String get _quantityText => service.fixedQuantity
      ? '${service.minQuantity} ${service.unit} mỗi đơn'
      : '${service.minQuantity}–${service.maxQuantity} ${service.unit} mỗi đơn';

  String get _durationText {
    if (service.unit == 'giờ') return 'Theo số giờ bạn chọn';
    if (service.fixedQuantity) {
      return 'Khoảng ${durationText(service.estimateMinutes(service.minQuantity))}';
    }
    return 'Khoảng ${durationText(service.minutesPerUnit)} / ${service.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final s = service;
    final sections = <(String, String?, IconData, Color)>[
      (
        forTasker ? 'Công việc bạn sẽ làm' : 'Công việc bao gồm',
        s.includes,
        Icons.check_rounded,
        AppColors.success,
      ),
      (
        forTasker ? 'Ngoài phạm vi (được từ chối nếu khách yêu cầu)' : 'Không bao gồm',
        s.excludes,
        Icons.close_rounded,
        AppColors.danger,
      ),
      (
        forTasker ? 'Khách tự chuẩn bị' : 'Bạn cần chuẩn bị',
        s.customerPrepares,
        Icons.inventory_2_outlined,
        AppColors.accent,
      ),
      ('Lưu ý', s.notes, Icons.info_outline_rounded, AppColors.info),
    ];
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ServiceIconBadge(name: s.name, size: 52, imageUrl: s.iconUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: AppText.title),
                        if (s.description != null) ...[
                          const SizedBox(height: 4),
                          Text(s.description!, style: AppText.muted),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Fact(
                icon: Icons.sell_outlined,
                label: forTasker ? 'Giá khách trả' : 'Đơn giá',
                value: '${formatMoney(s.basePrice)} / ${s.unit}',
              ),
              _Fact(icon: Icons.format_list_numbered_rounded, label: 'Số lượng', value: _quantityText),
              _Fact(icon: Icons.schedule_rounded, label: 'Thời lượng', value: _durationText),
              if (s.quantityHint != null) ...[
                const SizedBox(height: 2),
                Text(s.quantityHint!, style: AppText.small),
              ],
              if (forTasker) ...[
                const SizedBox(height: 12),
                NoticeBox(
                  icon: Icons.photo_camera_outlined,
                  message: s.requiresItemList
                      ? 'Khách ghi sẵn từng hạng mục khi đặt. Lúc bắt đầu và lúc hoàn thành, bạn chụp 1–3 ảnh cho mỗi hạng mục. '
                            'Thu nhập = giá khách trả trừ chiết khấu nền tảng; số tiền bạn nhận hiện sẵn trên từng lời mời.'
                      : 'Lúc bắt đầu và lúc hoàn thành, bạn chụp 1–5 ảnh hiện trạng. '
                            'Thu nhập = giá khách trả trừ chiết khấu nền tảng; số tiền bạn nhận hiện sẵn trên từng lời mời.',
                ),
              ] else if (s.requiresItemList) ...[
                const SizedBox(height: 12),
                const NoticeBox(
                  icon: Icons.checklist_rounded,
                  message:
                      'Khi đặt, bạn ghi rõ từng hạng mục cần làm. Tasker chụp ảnh trước và sau theo từng hạng mục để bạn đối chiếu.',
                ),
              ],
              for (final (title, text, icon, color) in sections)
                if (splitLines(text).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(title, style: AppText.section),
                  const SizedBox(height: 8),
                  for (final line in splitLines(text))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(icon, size: 17, color: color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(line, style: AppText.body)),
                        ],
                      ),
                    ),
                ],
            ],
          ),
        ),
        if (onChoose != null)
          BottomActionBar(
            children: [
              PrimaryButton(
                label: chooseLabel,
                onPressed: () {
                  Navigator.of(context).pop();
                  onChoose!();
                },
              ),
            ],
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Text(label, style: AppText.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
