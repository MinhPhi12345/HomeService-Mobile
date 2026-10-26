import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// US24 – Lịch sử thanh toán (Khách hàng) / thu nhập theo đơn (Tasker).
class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final _items = <PaymentItem>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final api = AppScope.api(context);
    if (more && (_loadingMore || !_hasMore)) return;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _error = null;
      }
    });
    try {
      final page = more ? _page + 1 : 1;
      final result = await api.getMyPayments(page: page);
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(result.items);
        _page = page;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTasker = AppScope.api(context).currentUser?.isTasker ?? false;
    return Scaffold(
      appBar: hsAppBar(isTasker ? 'Thu nhập theo đơn' : 'Lịch sử thanh toán'),
      body: _loading
          ? const LoadingView()
          : _error != null && _items.isEmpty
          ? ErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        EmptyView(
                          icon: Icons.receipt_long_rounded,
                          title: 'Chưa có giao dịch nào',
                          message:
                              'Các khoản thanh toán của đơn hàng sẽ hiện ở đây.',
                        ),
                      ],
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >
                            n.metrics.maxScrollExtent - 200) {
                          _load(more: true);
                        }
                        return false;
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _PaymentTile(item: _items[index], isTasker: isTasker),
                      ),
                    ),
            ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.item, required this.isTasker});

  final PaymentItem item;
  final bool isTasker;

  Color get _statusColor => switch (item.status) {
    1 || 4 => AppColors.success,
    3 => AppColors.info,
    5 || 6 => AppColors.inkSoft,
    2 => AppColors.danger,
    _ => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final amount = isTasker ? item.taskerAmount : item.amount;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ServiceIconBadge(name: item.serviceCategoryName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.serviceCategoryName,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Đơn #${item.bookingId} · ${formatDateTime(item.paidAt ?? item.createdAt)}',
                      style: AppText.small,
                    ),
                  ],
                ),
              ),
              Text(formatMoney(amount), style: AppText.money),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatusChip(
                label: PaymentStatus.label(item.status),
                color: _statusColor,
                dense: true,
              ),
              const SizedBox(width: 8),
              Text(PaymentMethod.label(item.method), style: AppText.small),
              const Spacer(),
              if (isTasker && item.commissionAmount > 0)
                Text(
                  'Phí nền tảng ${formatMoney(item.commissionAmount)}',
                  style: AppText.small,
                ),
              if (!isTasker && item.refundedAmount > 0)
                Text(
                  'Đã hoàn ${formatMoney(item.refundedAmount)}',
                  style: AppText.small.copyWith(color: AppColors.success),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
