import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/otp_field.dart';
import '../../widgets/payment_gateway.dart';

/// US22, US23, US24 – Ví Tasker: số dư, ký quỹ, nạp (qua cổng mô phỏng), rút, lịch sử.
///
/// Tasker cần giữ tối thiểu [Wallet.minDeposit] khả dụng (ký quỹ) để bật nhận đơn
/// và nhận đơn; đơn tiền mặt cần thêm đủ tiền để trừ chiết khấu.
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

  Future<void> _openTopUp() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WalletTopUpPage(wallet: _wallet)),
    );
    if (done == true && mounted) _load();
  }

  Future<void> _transfer({required bool topUp}) async {
    if (topUp) return _openTopUp();
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
        minDeposit: wallet?.minDeposit ?? 0,
      ),
    );
    if (amount == null || !mounted) return;
    // Bước 1: kiểm tra số tiền và gửi mã OTP xác nhận về email
    OtpSent sent;
    try {
      sent = await api.sendWithdrawOtp(amount);
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
      return;
    }
    if (!mounted) return;
    // Bước 2: nhập mã OTP để hoàn tất lệnh rút
    final updated = await showModalBottomSheet<Wallet>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _WithdrawOtpSheet(amount: amount, sent: sent),
    );
    if (updated == null || !mounted) return;
    setState(() => _wallet = updated);
    showSnack(context, 'Đã rút ${formatMoney(amount)} về tài khoản ngân hàng (mô phỏng).');
    _load();
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
                    if (!wallet.meetsDeposit) ...[
                      NoticeBox(
                        title: 'Chưa đủ ký quỹ để nhận đơn',
                        message:
                            'Ví cần tối thiểu ${formatMoney(wallet.minDeposit)} khả dụng để bật nhận đơn và nhận đơn. '
                            'Bạn cần nạp thêm ${formatMoney(wallet.depositShortfall)}.',
                        color: AppColors.warning,
                        icon: Icons.warning_amber_rounded,
                        action: PrimaryButton(
                          label: 'Nạp ${formatMoney(_suggestTopUp(wallet))} ngay',
                          icon: Icons.add_rounded,
                          expand: false,
                          color: AppColors.warning,
                          onPressed: _openTopUp,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    NoticeBox(
                      message:
                          'Ký quỹ: luôn giữ tối thiểu ${formatMoney(wallet.minDeposit)} khả dụng để được nhận đơn (không bị trừ, rút được khi tắt nhận đơn). '
                          'Đơn online: tiền (sau phí nền tảng) vào ví khi khách xác nhận. '
                          'Đơn tiền mặt: bạn thu tiền của khách, hệ thống trừ chiết khấu từ ví.',
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

/// Số tiền gợi ý nạp để đạt ký quỹ (tối thiểu 50.000 đ, làm tròn lên 10.000 đ).
double _suggestTopUp(Wallet wallet) {
  final need = wallet.depositShortfall;
  if (need <= 50000) return 50000;
  return (need / 10000).ceil() * 10000.0;
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
          if (wallet.minDeposit > 0) ...[
            const SizedBox(height: 14),
            _DepositBar(wallet: wallet),
          ],
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
  const _AmountSheet({
    required this.topUp,
    required this.available,
    this.minDeposit = 0,
  });

  final bool topUp;
  final double available;
  final double minDeposit;

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
            if (!widget.topUp && widget.minDeposit > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Khi đang bật nhận đơn, ví phải giữ lại ${formatMoney(widget.minDeposit)} ký quỹ. Tắt nhận đơn để rút hết.',
                style: AppText.small,
              ),
            ],
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

/// Thanh tiến độ ký quỹ trong thẻ số dư.
class _DepositBar extends StatelessWidget {
  const _DepositBar({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final ratio = wallet.minDeposit <= 0
        ? 1.0
        : (wallet.availableBalance / wallet.minDeposit).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                wallet.meetsDeposit ? Icons.verified_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  wallet.meetsDeposit
                      ? 'Đã đủ ký quỹ ${formatMoney(wallet.minDeposit)} · được nhận đơn'
                      : 'Ký quỹ ${formatMoney(wallet.minDeposit)} · còn thiếu ${formatMoney(wallet.depositShortfall)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              color: wallet.meetsDeposit ? Colors.white : AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

enum _TopUpStep { form, processing, success }

/// Kênh nạp tiền mô phỏng (giá trị gửi lên API: EWallet | Card | BankTransfer).
class _Channel {
  const _Channel(this.code, this.title, this.subtitle, this.icon);

  final String code;
  final String title;
  final String subtitle;
  final IconData icon;
}

const _channels = [
  _Channel('EWallet', 'Ví điện tử', 'MoMo, ZaloPay…', Icons.account_balance_wallet_rounded),
  _Channel('Card', 'Thẻ ngân hàng', 'Visa, Mastercard, Napas', Icons.credit_card_rounded),
  _Channel('BankTransfer', 'Chuyển khoản', 'Chuyển khoản ngân hàng', Icons.account_balance_rounded),
];

/// US22 – Nạp tiền vào ví Tasker qua cổng thanh toán MÔ PHỎNG (không trừ tiền thật).
/// Trả về true khi nạp thành công.
class WalletTopUpPage extends StatefulWidget {
  const WalletTopUpPage({super.key, this.wallet});

  final Wallet? wallet;

  @override
  State<WalletTopUpPage> createState() => _WalletTopUpPageState();
}

class _WalletTopUpPageState extends State<WalletTopUpPage> {
  late final _controller = TextEditingController(
    text: widget.wallet == null || widget.wallet!.meetsDeposit
        ? '100000'
        : _suggestTopUp(widget.wallet!).toStringAsFixed(0),
  );
  _Channel _channel = _channels.first;
  _TopUpStep _step = _TopUpStep.form;
  String? _error;
  Wallet? _after;
  DateTime? _at;

  static const _quick = [100000, 200000, 500000, 1000000];

  double get _amount => double.tryParse(_controller.text.replaceAll('.', '')) ?? 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final amount = _amount;
    if (amount < 50000 || amount > 10000000) {
      setState(() => _error = 'Số tiền nạp từ 50.000 đ đến 10.000.000 đ.');
      return;
    }
    FocusScope.of(context).unfocus();
    final api = AppScope.api(context);
    setState(() {
      _error = null;
      _step = _TopUpStep.processing;
    });
    final started = DateTime.now();
    try {
      final updated = await api.topUp(amount, channel: _channel.code);
      final spent = DateTime.now().difference(started);
      const minimum = Duration(milliseconds: 1200);
      if (spent < minimum) await Future<void>.delayed(minimum - spent);
      if (!mounted) return;
      setState(() {
        _after = updated;
        _at = DateTime.now();
        _step = _TopUpStep.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _step = _TopUpStep.form);
      showSnack(context, errorMessage(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final after = _after;
    return PopScope(
      canPop: _step == _TopUpStep.form,
      onPopInvokedWithResult: (didPop, _) {
        // Đã nạp xong mà người dùng bấm Back: vẫn báo về để trang ví tải lại.
        if (!didPop && _step == _TopUpStep.success) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: hsAppBar(_step == _TopUpStep.success ? 'Biên lai nạp tiền' : 'Nạp tiền vào ví'),
        body: switch (_step) {
          _TopUpStep.processing => GatewayProcessingView(amount: _amount),
          _TopUpStep.success => GatewaySuccessView(
            amount: _amount,
            note: after != null && after.meetsDeposit
                ? 'Tiền đã vào ví. Bạn đã đủ ký quỹ và có thể bật nhận đơn.'
                : after != null
                ? 'Tiền đã vào ví. Bạn cần nạp thêm ${formatMoney(after.depositShortfall)} để đủ ký quỹ nhận đơn.'
                : 'Tiền đã vào ví.',
            rows: [
              ('Kênh nạp', '${_channel.title} (mô phỏng)'),
              ('Thời gian', formatDateTime(_at ?? DateTime.now())),
              if (after != null) ('Số dư khả dụng', formatMoney(after.availableBalance)),
              if (after != null)
                ('Ký quỹ', after.meetsDeposit ? 'Đã đủ' : 'Còn thiếu ${formatMoney(after.depositShortfall)}'),
            ],
          ),
          _TopUpStep.form => _form(),
        },
        bottomNavigationBar: switch (_step) {
          _TopUpStep.processing => null,
          _TopUpStep.success => BottomActionBar(
            children: [
              PrimaryButton(
                label: 'Xong',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
          _TopUpStep.form => BottomActionBar(
            children: [
              PrimaryButton(
                label: 'Thanh toán (demo) ${formatMoney(_amount)}',
                icon: Icons.lock_rounded,
                onPressed: _amount > 0 ? _pay : null,
              ),
            ],
          ),
        },
      ),
    );
  }

  Widget _form() {
    final wallet = widget.wallet;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GatewayHeader(
          merchant: 'HomeService · Nạp ví Tasker',
          description: wallet == null
              ? 'Nạp tiền vào ví'
              : 'Số dư khả dụng hiện tại ${formatMoney(wallet.availableBalance)}',
          amount: _amount,
        ),
        const SizedBox(height: 14),
        if (wallet != null && !wallet.meetsDeposit) ...[
          NoticeBox(
            message:
                'Cần tối thiểu ${formatMoney(wallet.minDeposit)} khả dụng (ký quỹ) để nhận đơn. '
                'Nạp thêm ít nhất ${formatMoney(wallet.depositShortfall)}.',
            color: AppColors.warning,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 14),
        ],
        const SectionHeader('Số tiền nạp'),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() => _error = null),
          decoration: appInputDecoration(
            label: 'Số tiền (đ)',
            icon: Icons.payments_outlined,
            helper: 'Từ 50.000 đ đến 10.000.000 đ mỗi lần.',
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in _quick)
              ChoiceChip(
                label: Text(formatMoney(value)),
                selected: _amount == value,
                onSelected: (_) => setState(() {
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
        const SizedBox(height: 18),
        const SectionHeader('Kênh thanh toán'),
        for (final c in _channels) ...[
          ChoiceTile(
            icon: c.icon,
            title: c.title,
            subtitle: c.subtitle,
            selected: _channel == c,
            onTap: () => setState(() => _channel = c),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        switch (_channel.code) {
          'Card' => const GatewayCardPanel(),
          'BankTransfer' => GatewayBankPanel(
            amount: _amount,
            content: 'NAPVI ${AppScope.api(context).currentUser?.userId ?? ''}'.trim(),
          ),
          _ => GatewayQrPanel(seed: _amount.toInt() + 7, amount: _amount),
        },
        const SizedBox(height: 14),
        const GatewaySecureNote(),
      ],
    );
  }
}

/// Xác nhận rút tiền bằng mã OTP gửi về email (mã chỉ dùng cho đúng số tiền này).
class _WithdrawOtpSheet extends StatefulWidget {
  const _WithdrawOtpSheet({required this.amount, required this.sent});

  final double amount;
  final OtpSent sent;

  @override
  State<_WithdrawOtpSheet> createState() => _WithdrawOtpSheetState();
}

class _WithdrawOtpSheetState extends State<_WithdrawOtpSheet> {
  final _code = TextEditingController();
  late String _masked = widget.sent.maskedEmail;
  late int _wait = widget.sent.resendAfterSeconds;
  int _generation = 0;
  bool _loading = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm([String? value]) async {
    final code = value ?? _code.text;
    if (code.length != OtpField.length) {
      setState(() => _error = 'Vui lòng nhập đủ 6 số của mã OTP.');
      return;
    }
    if (_loading) return;
    final api = AppScope.api(context);
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallet = await api.withdraw(widget.amount, code);
      navigator.pop(wallet);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorMessage(error));
      _code.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent = await AppScope.api(context).sendWithdrawOtp(widget.amount);
      if (!mounted) return;
      setState(() {
        _masked = sent.maskedEmail;
        _wait = sent.resendAfterSeconds;
        _generation++;
      });
      _code.clear();
    } catch (error) {
      if (!mounted) return;
      final wait = error is ApiFailure ? error.waitSeconds : null;
      setState(() {
        _error = errorMessage(error);
        if (wait != null) {
          _wait = wait;
          _generation++;
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 12 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Xác nhận rút ${formatMoney(widget.amount)}', style: AppText.title),
            const SizedBox(height: 6),
            Text(
              'Nhập mã OTP 6 số đã gửi tới $_masked để xác nhận lệnh rút tiền.',
              style: AppText.muted,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              NoticeBox(
                message: _error!,
                color: AppColors.danger,
                icon: Icons.error_outline_rounded,
              ),
            ],
            const SizedBox(height: 16),
            OtpField(
              controller: _code,
              hasError: _error != null,
              enabled: !_loading,
              onCompleted: _confirm,
            ),
            const SizedBox(height: 6),
            ResendCountdown(
              seconds: _wait,
              generation: _generation,
              busy: _sending,
              onResend: _resend,
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Xác nhận rút tiền',
              icon: Icons.lock_rounded,
              loading: _loading,
              onPressed: () => _confirm(),
            ),
          ],
        ),
      ),
    );
  }
}
