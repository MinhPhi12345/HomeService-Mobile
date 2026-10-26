import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// US22, US23, US24 – Ví Tasker: số dư, nạp (để nhận đơn tiền mặt), rút, lịch sử.
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Wallet? _wallet;
  final _items = <WalletTransaction>[];
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

  Future<void> _load() async {
    final api = AppScope.api(context);
    try {
      final results = await Future.wait([
        api.getWallet(),
        api.getWalletTransactions(page: 1),
      ]);
      if (!mounted) return;
      final page = results[1] as Paged<WalletTransaction>;
      setState(() {
        _wallet = results[0] as Wallet;
        _items
          ..clear()
          ..addAll(page.items);
        _page = 1;
        _hasMore = page.hasMore;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final api = AppScope.api(context);
    setState(() => _loadingMore = true);
    try {
      final page = await api.getWalletTransactions(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page = page.page;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      // Kéo xuống để thử lại.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _transfer({required bool topUp}) async {
    final api = AppScope.api(context);
    final wallet = _wallet;
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _AmountSheet(
        topUp: topUp,
        available: wallet?.availableBalance ?? 0,
      ),
    );
    if (amount == null || !mounted) return;
    if (!topUp) {
      final ok = await confirmDialog(
        context,
        title: 'Rút ${formatMoney(amount)}?',
        message: 'Tiền sẽ được chuyển về tài khoản ngân hàng của bạn (mô phỏng).',
        confirmText: 'Rút tiền',
      );
      if (!ok || !mounted) return;
    }
    try {
      final updated = topUp ? await api.topUp(amount) : await api.withdraw(amount);
      if (!mounted) return;
      setState(() => _wallet = updated);
      showSnack(
        context,
        topUp
            ? 'Đã nạp ${formatMoney(amount)} vào ví.'
            : 'Đã tạo lệnh rút ${formatMoney(amount)}.',
      );
      _load();
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    return Scaffold(
      appBar: hsAppBar('Ví Tasker'),
      body: _loading
          ? const LoadingView()
          : wallet == null
          ? ErrorView(message: _error ?? 'Không tải được ví.', onRetry: _load)
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                    _loadMore();
                  }
                  return false;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _BalanceCard(wallet: wallet),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Nạp tiền',
                            icon: Icons.add_rounded,
                            onPressed: () => _transfer(topUp: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Rút tiền',
                            icon: Icons.south_rounded,
                            onPressed: () => _transfer(topUp: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const NoticeBox(
                      message:
                          'Đơn online: tiền (sau 20% phí nền tảng) vào ví khi khách xác nhận. '
                          'Đơn tiền mặt: bạn thu tiền của khách, hệ thống trừ 20% từ ví – vì vậy cần giữ đủ số dư để nhận đơn tiền mặt.',
                    ),
                    const SizedBox(height: 18),
                    const SectionHeader('Lịch sử giao dịch'),
                    if (_items.isEmpty)
                      const EmptyView(
                        icon: Icons.receipt_long_rounded,
                        title: 'Chưa có giao dịch',
                        message: 'Nạp tiền hoặc hoàn thành đơn để thấy lịch sử ví.',
                      )
                    else
                      for (final tx in _items) ...[
                        _TransactionTile(tx: tx),
                        const SizedBox(height: 8),
                      ],
                    if (_loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số dư khả dụng',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(wallet.availableBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(label: 'Tổng số dư', value: formatMoney(wallet.balance)),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Đang tạm giữ',
                  value: formatMoney(wallet.reservedAmount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final income = WalletTxType.isIncome(tx.type);
    final color = income ? AppColors.success : AppColors.danger;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.soft(color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(WalletTxType.icon(tx.type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  WalletTxType.label(tx.type),
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    if (tx.bookingId != null) 'Đơn #${tx.bookingId}',
                    formatDateTime(tx.createdAt),
                  ].join(' · '),
                  style: AppText.small,
                ),
                if (tx.note != null) Text(tx.note!, style: AppText.small),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${income ? '+' : '-'}${formatMoney(tx.amount.abs())}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              Text('Số dư ${formatMoney(tx.balanceAfter)}', style: AppText.small),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.topUp, required this.available});

  final bool topUp;
  final double available;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final _controller = TextEditingController();
  String? _error;

  static const _quick = [100000, 200000, 500000, 1000000];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.replaceAll('.', '')) ?? 0;
    String? error;
    if (widget.topUp && (value < 50000 || value > 10000000)) {
      error = 'Số tiền nạp từ 50.000 đ đến 10.000.000 đ.';
    } else if (!widget.topUp && value < 50000) {
      error = 'Số tiền rút tối thiểu 50.000 đ.';
    } else if (!widget.topUp && value > widget.available) {
      error = 'Số dư khả dụng không đủ.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.topUp ? 'Nạp tiền vào ví' : 'Rút tiền', style: AppText.title),
            const SizedBox(height: 4),
            Text(
              widget.topUp
                  ? 'Từ 50.000 đ đến 10.000.000 đ mỗi lần.'
                  : 'Có thể rút tối đa ${formatMoney(widget.available)}.',
              style: AppText.muted,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: appInputDecoration(
                label: 'Số tiền (đ)',
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in _quick)
                  ActionChip(
                    label: Text(formatMoney(value)),
                    onPressed: () => setState(() {
                      _controller.text = '$value';
                      _error = null;
                    }),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: widget.topUp ? 'Nạp tiền' : 'Rút tiền',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
