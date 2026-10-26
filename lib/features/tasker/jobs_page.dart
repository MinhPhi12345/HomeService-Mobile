import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/common.dart';
import 'job_detail_page.dart';

/// US20 – Danh sách đơn Tasker đã nhận: lịch sắp làm và lịch sử.
class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => JobsPageState();
}

class JobsPageState extends State<JobsPage> {
  final _upcomingKey = GlobalKey<_JobListState>();
  final _historyKey = GlobalKey<_JobListState>();

  void reload() {
    _upcomingKey.currentState?.load(silent: true);
    _historyKey.currentState?.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: hsAppBar(
          'Lịch làm việc',
          bottom: const TabBar(
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.primary,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Sắp làm'),
              Tab(text: 'Tất cả đơn'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _JobList(key: _upcomingKey, upcoming: true),
            _JobList(key: _historyKey, upcoming: false),
          ],
        ),
      ),
    );
  }
}

class _JobList extends StatefulWidget {
  const _JobList({super.key, required this.upcoming});

  final bool upcoming;

  @override
  State<_JobList> createState() => _JobListState();
}

class _JobListState extends State<_JobList> with AutomaticKeepAliveClientMixin {
  List<Booking> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool silent = false}) async {
    final api = AppScope.api(context);
    try {
      final items = await api.getMyBookings(upcoming: widget.upcoming);
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && !silent) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Booking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JobDetailPage(bookingId: booking.id)),
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
                  icon: Icons.event_busy_rounded,
                  title: widget.upcoming
                      ? 'Chưa có lịch làm sắp tới'
                      : 'Bạn chưa nhận đơn nào',
                  message: 'Bật nhận đơn ở tab "Nhận việc" để nhận lời mời mới.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) => BookingCard(
                booking: _items[index],
                forTasker: true,
                onTap: () => _open(_items[index]),
              ),
            ),
    );
  }
}
