import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/otp_field.dart';
import 'auth_header.dart';

/// US01 – Nhập mã OTP gửi về email để kích hoạt tài khoản (sau khi đăng ký,
/// hoặc khi đăng nhập tài khoản chưa xác thực). Đúng mã → đăng nhập luôn.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, required this.sent, this.notice});

  final OtpSent sent;

  /// Thông báo hiện ở đầu trang (vd. "Tài khoản chưa xác thực email…").
  final String? notice;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _code = TextEditingController();
  late String _masked = widget.sent.maskedEmail;
  late String? _info = widget.notice;
  late int _wait = widget.sent.resendAfterSeconds;
  int _generation = 0;
  bool _loading = false;
  bool _sending = false;
  String? _error;

  String get _email => widget.sent.email ?? '';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify([String? value]) async {
    final code = value ?? _code.text;
    if (code.length != OtpField.length) {
      setState(() => _error = 'Vui lòng nhập đủ 6 số của mã OTP.');
      return;
    }
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Thành công: lưu phiên đăng nhập, AuthGate tự đóng các màn hình và vào app.
      await AppScope.api(context).verifyEmail(_email, code);
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
      final sent = await AppScope.api(context).resendVerification(_email);
      if (!mounted) return;
      setState(() {
        _masked = sent.maskedEmail;
        _info = 'Đã gửi mã mới tới ${sent.maskedEmail}. Mã cũ không còn dùng được.';
        _wait = sent.resendAfterSeconds;
        _generation++;
      });
      _code.clear();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(error);
        final wait = error is ApiFailure ? error.waitSeconds : null;
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
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const AuthHeader(
            title: 'Xác thực email',
            subtitle: 'Nhập mã OTP 6 số để kích hoạt tài khoản.',
            showServices: false,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: AppText.body,
                          children: [
                            const TextSpan(text: 'Mã đã được gửi tới '),
                            TextSpan(
                              text: _masked,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: '. Kiểm tra cả thư mục Spam nếu chưa thấy.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_info != null && _error == null) ...[
                  const SizedBox(height: 16),
                  NoticeBox(
                    message: _info!,
                    color: AppColors.success,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  NoticeBox(
                    message: _error!,
                    color: AppColors.danger,
                    icon: Icons.error_outline_rounded,
                  ),
                ],
                const SizedBox(height: 20),
                OtpField(
                  controller: _code,
                  hasError: _error != null,
                  enabled: !_loading,
                  onCompleted: _verify,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mã có hiệu lực 5 phút và chỉ dùng được 1 lần.',
                  style: AppText.small,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Xác thực và đăng nhập',
                  loading: _loading,
                  onPressed: () => _verify(),
                ),
                const SizedBox(height: 8),
                ResendCountdown(
                  seconds: _wait,
                  generation: _generation,
                  busy: _sending,
                  onResend: _resend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
