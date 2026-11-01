import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Các khối giao diện dùng chung cho cổng thanh toán MÔ PHỎNG của đồ án
/// (thanh toán đơn, trả nợ/phí hủy, Tasker nạp tiền ví). Không trừ tiền thật.

/// Mã QR giả lập (chỉ để minh họa, không quét được) – sinh ổn định theo [seed].
class FakeQr extends StatelessWidget {
  const FakeQr({super.key, required this.seed, this.size = 168});

  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.line),
      ),
      child: Semantics(
        label: 'Mã QR mô phỏng',
        image: true,
        child: CustomPaint(
          size: Size.square(size),
          painter: _QrPainter(seed),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.seed);

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 25;
    final cell = size.width / n;
    final dark = Paint()..color = AppColors.ink;
    final light = Paint()..color = Colors.white;
    final rnd = math.Random(seed * 7919 + 17);
    bool finder(int r, int c) =>
        (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (finder(r, c)) continue;
        if (rnd.nextBool()) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), dark);
        }
      }
    }
    void box(int r, int c) {
      canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, 7 * cell, 7 * cell), dark);
      canvas.drawRect(
        Rect.fromLTWH((c + 1) * cell, (r + 1) * cell, 5 * cell, 5 * cell),
        light,
      );
      canvas.drawRect(
        Rect.fromLTWH((c + 2) * cell, (r + 2) * cell, 3 * cell, 3 * cell),
        dark,
      );
    }

    box(0, 0);
    box(0, n - 7);
    box(n - 7, 0);
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.seed != seed;
}

/// Đầu cổng thanh toán: tên người bán, nội dung, số tiền.
class GatewayHeader extends StatelessWidget {
  const GatewayHeader({
    super.key,
    required this.merchant,
    required this.description,
    required this.amount,
    this.trailing,
  });

  final String merchant;
  final String description;
  final double amount;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
          Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  merchant,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
          if (trailing != null) ...[const SizedBox(height: 14), trailing!],
        ],
      ),
    );
  }
}

/// Khối quét QR bằng ứng dụng ví điện tử.
class GatewayQrPanel extends StatelessWidget {
  const GatewayQrPanel({super.key, required this.seed, required this.amount});

  final int seed;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FakeQr(seed: seed),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryDark, size: 20),
              const SizedBox(width: 6),
              Text(
                'Quét mã bằng ứng dụng ví',
                style: AppText.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mở MoMo / ZaloPay, quét mã và xác nhận thanh toán ${formatMoney(amount)}.',
            style: AppText.muted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Bản demo: bấm “Thanh toán (demo)” để giả lập ví đã xác nhận.',
            style: AppText.small,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Form thẻ ngân hàng điền sẵn thẻ thử nghiệm (chỉ đọc).
class GatewayCardPanel extends StatelessWidget {
  const GatewayCardPanel({super.key});

  @override
  Widget build(BuildContext context) {
    Widget field(String label, String value) => TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: appInputDecoration(label: label),
    );
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hình thẻ minh họa
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF26415F), Color(0xFF15302F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card_rounded, color: Colors.white),
                    Spacer(),
                    Text(
                      'DEMO CARD',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Text(
                  '4111  1111  1111  1111',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Text('NGUYEN VAN A', style: TextStyle(color: Colors.white70)),
                    Spacer(),
                    Text('12/28', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          field('Số thẻ', '4111 1111 1111 1111'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: field('Hết hạn', '12/28')),
              const SizedBox(width: 10),
              Expanded(child: field('CVV', '•••')),
            ],
          ),
          const SizedBox(height: 10),
          field('Tên in trên thẻ', 'NGUYEN VAN A'),
          const SizedBox(height: 8),
          const Text(
            'Thẻ thử nghiệm điền sẵn – không trừ tiền thật.',
            style: AppText.small,
          ),
        ],
      ),
    );
  }
}

/// Thông tin chuyển khoản ngân hàng (mô phỏng).
class GatewayBankPanel extends StatelessWidget {
  const GatewayBankPanel({super.key, required this.amount, required this.content});

  final double amount;
  final String content;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          const SummaryRow('Ngân hàng', 'HS Demo Bank'),
          const SummaryRow('Số tài khoản', '0123 456 789'),
          const SummaryRow('Chủ tài khoản', 'CONG TY HOMESERVICE'),
          SummaryRow('Số tiền', formatMoney(amount)),
          SummaryRow('Nội dung', content),
          const SizedBox(height: 4),
          const Text(
            'Bản demo: bấm “Thanh toán (demo)” để giả lập ngân hàng đã nhận tiền.',
            style: AppText.small,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Dòng cam kết "cổng mô phỏng".
class GatewaySecureNote extends StatelessWidget {
  const GatewaySecureNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Cổng thanh toán mô phỏng của đồ án · Không trừ tiền thật',
            style: AppText.small,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Màn hình "đang xử lý giao dịch".
class GatewayProcessingView extends StatelessWidget {
  const GatewayProcessingView({super.key, required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text('Đang xử lý giao dịch…', style: AppText.title),
            const SizedBox(height: 6),
            Text(
              'Đang xác nhận thanh toán ${formatMoney(amount)}. Vui lòng không tắt ứng dụng.',
              style: AppText.muted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Màn hình "thanh toán thành công" kèm biên lai.
class GatewaySuccessView extends StatelessWidget {
  const GatewaySuccessView({
    super.key,
    required this.amount,
    required this.note,
    required this.rows,
  });

  final double amount;
  final String note;

  /// Các dòng biên lai (nhãn, giá trị).
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 56,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Thanh toán thành công',
          style: AppText.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          formatMoney(amount),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(note, style: AppText.muted, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [for (final (label, value) in rows) SummaryRow(label, value)],
          ),
        ),
      ],
    );
  }
}
