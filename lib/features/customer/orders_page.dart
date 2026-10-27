import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/config.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/common.dart';
import 'booking_detail_page.dart';

/// US15 – Lịch sử đơn của Khách hàng, chia 3 tab theo trạng thái.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => OrdersPageState();
}

class OrdersPageState extends State<OrdersPage> {
  final _keys = [
    GlobalKey<_OrderListState>(),
    GlobalKey<_OrderListState>(),
    GlobalKey<_OrderListState>(),
  ];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Đơn đang xử lý thay đổi do hệ thống (ghép Tasker, hết hạn...) => tự tải lại.
    _timer = Timer.periodic(
      AppConfig.bookingRefresh,
      (_) => _keys[0].currentState?.load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void reload() {
    for (final key in _keys) {
      key.currentState?.load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: hsAppBar(
          'Đơn hàng của tôi',
          bottom: const TabBar(
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.primary,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Đang xử lý'),
              Tab(text: 'Hoàn tất'),
              Tab(text: 'Đã hủy'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrderList(
              key: _keys[0],
              statuses: BookingStatus.active,
              emptyTitle: 'Chưa có đơn nào đang xử lý',
              emptyMessage: 'Chọn một dịch vụ ở Trang chủ để đặt Tasker nhé.',
            ),
            _OrderList(
              key: _keys[1],
              statuses: BookingStatus.done,
              emptyTitle: 'Chưa có đơn hoàn tất',
              emptyMessage: 'Đơn đã thanh toán xong sẽ nằm ở đây.',
            ),
            _OrderList(
              key: _keys[2],
              statuses: BookingStatus.closed,
              emptyTitle: 'Không có đơn bị hủy',
              emptyMessage: 'Đơn bạn hủy hoặc hết hạn sẽ nằm ở đây.',
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatefulWidget {
  const _OrderList({
    super.key,
    required this.statuses,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<int> statuses;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList>
    with AutomaticKeepAliveClientMixin {
  List<Booking> _items = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (_busy) return;
    _busy = true;
    final api = AppScope.api(context);
    unawaited(api.ensureServiceImages()); // ảnh dịch vụ cho thẻ đơn
    if (!silent) setState(() => _error = null);
    try {
      final items = await api.getMyBookings(statuses: widget.statuses);
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && !silent) setState(() => _error = errorMessage(error));
    } finally {
      _busy = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Booking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingDetailPage(bookingId: booking.id)),
    );
    if (mounted) load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const LoadingView();
    if (_error != null && _items.isEmpty) {
      return ErrorView(message: _error!, onRetry: load);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: load,
      child: _items.isEmpty
          ? ListView(
              children: [
                EmptyView(
                  icon: Icons.receipt_long_rounded,
                  title: widget.emptyTitle,
                  message: widget.emptyMessage,
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) => BookingCard(
                booking: _items[index],
                onTap: () => _open(_items[index]),
              ),
            ),
    );
  }
}
