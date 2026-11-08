import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/rewards.dart';

/// FR-32, FR-33 – Ưu đãi của tôi: quà tặng riêng và mã khuyến mãi đang dùng được.
class MyVouchersPage extends StatefulWidget {
  const MyVouchersPage({super.key});

  @override
  State<MyVouchersPage> createState() => _MyVouchersPageState();
}

class _MyVouchersPageState extends State<MyVouchersPage> {
  List<MyVoucher> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = AppScope.api(context);
    setState(() => _error = null);
    try {
      final list = await api.getMyVouchers();
      if (mounted) setState(() => _items = list);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hsAppBar('Ưu đãi của tôi'),
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
                          icon: Icons.card_giftcard_rounded,
                          title: 'Chưa có ưu đãi nào',
                          message:
                              'Quà tặng sẽ xuất hiện ở đây khi bạn xác thực email, hoàn tất mỗi 5 đơn hoặc khi HomeService có chương trình khuyến mãi.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _items.length + 1,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return const Text(
                            'Mã giảm giá áp dụng cho đơn thanh toán trước (ví điện tử, thẻ). Chọn mã ở bước thanh toán khi đặt dịch vụ.',
                            style: AppText.muted,
                          );
                        }
                        final v = _items[index - 1];
                        return VoucherTile(
                          voucher: v,
                          trailing: IconButton(
                            tooltip: 'Chép mã',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: v.code));
                              showSnack(context, 'Đã chép mã ${v.code}');
                            },
                            icon: const Icon(Icons.copy_rounded, color: AppColors.primaryDark),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
