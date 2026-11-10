import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// SRS v1.8 – danh sách hạng mục khách ghi khi đặt đơn.
class BookingItemList extends StatelessWidget {
  const BookingItemList({super.key, required this.items});

  final List<BookingItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ItemNoBadge(it.itemNo),
                const SizedBox(width: 10),
                Expanded(child: Text(it.description, style: AppText.body)),
              ],
            ),
          ),
      ],
    );
  }
}

class ItemNoBadge extends StatelessWidget {
  const ItemNoBadge(this.no, {super.key});

  final int no;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
      child: Text(
        '$no',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
      ),
    );
  }
}

/// SRS v1.8 – ảnh trước (lúc bắt đầu) và sau (lúc hoàn thành) đặt cạnh nhau,
/// theo từng hạng mục nếu đơn có hạng mục.
class BookingPhotoCompare extends StatelessWidget {
  const BookingPhotoCompare({super.key, required this.items, required this.photos});

  final List<BookingItem> items;
  final List<BookingPhoto> photos;

  List<BookingPhoto> _pick(int stage, int? itemNo) =>
      photos.where((p) => p.stage == stage && p.itemNo == itemNo).toList();

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _Pair(
        before: photos.where((p) => p.stage == 0).toList(),
        after: photos.where((p) => p.stage == 1).toList(),
      );
    }
    final otherBefore = _pick(0, null);
    final otherAfter = _pick(1, null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ItemNoBadge(items[i].itemNo),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  items[i].description,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Pair(before: _pick(0, items[i].itemNo), after: _pick(1, items[i].itemNo)),
        ],
        if (otherBefore.isNotEmpty || otherAfter.isNotEmpty) ...[
          const Divider(height: 24),
          Text('Ảnh chung', style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _Pair(before: otherBefore, after: otherAfter),
        ],
      ],
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.before, required this.after});

  final List<BookingPhoto> before;
  final List<BookingPhoto> after;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Column(label: 'Trước', color: AppColors.warning, list: before)),
        const SizedBox(width: 10),
        Expanded(child: _Column(label: 'Sau', color: AppColors.success, list: after)),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.label, required this.color, required this.list});

  final String label;
  final Color color;
  final List<BookingPhoto> list;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.soft(color),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const SizedBox(height: 6),
        if (list.isEmpty)
          Container(
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text('Chưa có ảnh', style: AppText.small),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 4 / 3,
            children: [
              for (final p in list)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: GestureDetector(
                    onTap: () {
                      final url = AppConfig.mediaUrl(p.url);
                      if (url != null) showPhotoViewer(context, url);
                    },
                    child: Image.network(
                      AppConfig.mediaUrl(p.url) ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: AppColors.primarySoft,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, color: AppColors.muted),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
