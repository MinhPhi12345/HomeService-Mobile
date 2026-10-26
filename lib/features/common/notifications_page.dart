import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Thông báo (US28, US29) – có phân trang, lọc chưa đọc, đánh dấu đã đọc.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.onUnreadChanged});

  final ValueChanged<int>? onUnreadChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _items = <NotificationItem>[];
  bool _unreadOnly = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  int _unread = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final api = AppScope.api(context);
    if (more) {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = _items.isEmpty;
        _error = null;
      });
    }
    try {
      final page = more ? _page + 1 : 1;
      final result = await api.getNotifications(
        page: page,
        unreadOnly: _unreadOnly,
      );
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(result.items);
        _page = page;
        _hasMore = _items.length < result.totalCount;
        _unread = result.unreadCount;
      });
      widget.onUnreadChanged?.call(_unread);
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

  Future<void> _markRead(int index) async {
    final item = _items[index];
    if (item.isRead) return;
    setState(() {
      _items[index] = item.markRead();
      _unread = (_unread - 1).clamp(0, 1 << 30);
    });
    widget.onUnreadChanged?.call(_unread);
    try {
      await AppScope.api(context).markNotificationRead(item.id);
    } catch (_) {
      // Lần tải sau sẽ đồng bộ lại.
    }
  }

  Future<void> _markAll() async {
    try {
      await AppScope.api(context).markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].markRead();
        }
        _unread = 0;
      });
      widget.onUnreadChanged?.call(0);
      if (_unreadOnly) _load();
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hsAppBar(
        'Thông báo',
        actions: [
          if (_unread > 0)
            TextButton.icon(
              onPressed: _markAll,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Đọc hết'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  selected: !_unreadOnly,
                  onTap: () {
                    setState(() => _unreadOnly = false);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: _unread > 0 ? 'Chưa đọc ($_unread)' : 'Chưa đọc',
                  selected: _unreadOnly,
                  onTap: () {
                    setState(() => _unreadOnly = true);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const LoadingView();
    if (_error != null && _items.isEmpty) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              children: [
                EmptyView(
                  icon: Icons.notifications_none_rounded,
                  title: _unreadOnly
                      ? 'Bạn đã đọc hết thông báo'
                      : 'Chưa có thông báo nào',
                  message:
                      'Cập nhật về đơn hàng, thanh toán và nhắc lịch sẽ hiện ở đây.',
                ),
              ],
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                  _load(more: true);
                }
                return false;
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _items.length + (_hasMore ? 1 : 0),
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final item = _items[index];
                  return _NotificationTile(
                    item: item,
                    onTap: () => _markRead(index),
                  );
                },
              ),
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.surface,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  IconData get _icon {
    final t = item.title.toLowerCase();
    if (t.contains('thanh toán') || t.contains('nợ')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (t.contains('hủy') || t.contains('hết hạn')) return Icons.block_rounded;
    if (t.contains('khiếu nại')) return Icons.gavel_rounded;
    if (t.contains('nhắc')) return Icons.alarm_rounded;
    if (t.contains('đánh giá')) return Icons.star_rounded;
    if (t.contains('lời mời') || t.contains('đơn mới')) {
      return Icons.work_outline_rounded;
    }
    if (t.contains('hoàn thành') || t.contains('xác nhận')) {
      return Icons.task_alt_rounded;
    }
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: item.isRead ? AppColors.surface : AppColors.primarySoft,
      borderColor: item.isRead ? AppColors.line : AppColors.primarySoft,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.isRead ? AppColors.bg : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: AppColors.primaryDark, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppText.body.copyWith(
                          fontWeight: item.isRead
                              ? FontWeight.w600
                              : FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!item.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.message, style: AppText.muted),
                const SizedBox(height: 6),
                Text(formatRelative(item.createdAt), style: AppText.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
