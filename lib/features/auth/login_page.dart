import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'account_appeal_page.dart';
import 'auth_header.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'verify_email_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  /// US48 – body 403 ACCOUNT_LOCKED (lý do, chi tiết, thời điểm khóa).
  Map<String, dynamic>? _locked;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _locked = null;
    });
    try {
      // Đăng nhập thành công: AuthGate tự chuyển sang màn hình theo vai trò.
      await AppScope.api(context).login(_email.text, _password.text);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiFailure && error.isEmailNotVerified) {
        // Tài khoản chưa xác thực email: server đã gửi mã OTP → mở màn nhập mã
        final body = error.body!;
        final email = body['email'] as String? ?? _email.text.trim().toLowerCase();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyEmailPage(
              sent: OtpSent(
                email: email,
                maskedEmail: body['maskedEmail'] as String? ?? email,
                resendAfterSeconds: (body['resendAfterSeconds'] as num?)?.toInt() ?? 0,
              ),
              notice: 'Tài khoản chưa xác thực email. Nhập mã OTP để kích hoạt rồi đăng nhập.',
            ),
          ),
        );
      } else if (error is ApiFailure && error.isAccountLocked) {
        // US48 – tài khoản bị khóa: hiện lý do và nút gửi yêu cầu mở khóa
        setState(() => _locked = error.body);
      } else {
        setState(() => _error = errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAppeal() {
    final email = _locked?['email'] as String? ?? _email.text.trim().toLowerCase();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AccountAppealPage(initialEmail: email)),
    );
  }

  Widget _lockedBox(Map<String, dynamic> body) {
    final reason = body['lockReasonText'] as String?;
    final detail = body['lockDetail'] as String?;
    final lockedAtRaw = body['lockedAt'] as String?;
    final lockedAt = lockedAtRaw == null ? null : DateTime.tryParse(lockedAtRaw)?.toLocal();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tài khoản của bạn đã bị khóa',
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (reason != null) InfoRow(icon: Icons.report_outlined, label: 'Lý do', text: reason),
          if (detail != null) InfoRow(icon: Icons.notes_rounded, label: 'Chi tiết', text: detail),
          if (lockedAt != null)
            InfoRow(icon: Icons.schedule_rounded, label: 'Thời điểm', text: formatDateTime(lockedAt)),
          const SizedBox(height: 6),
          const Text(
            'Nếu bạn cho rằng đây là nhầm lẫn hoặc đã khắc phục, hãy gửi yêu cầu mở khóa kèm giải trình.',
            style: AppText.muted,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Gửi yêu cầu mở khóa',
            color: AppColors.danger,
            onPressed: _openAppeal,
          ),
        ],
      ),
    );
  }

  Future<void> _forgot() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(initialEmail: _email.text.trim()),
      ),
    );
    if (email != null && mounted) {
      setState(() {
        _email.text = email;
        _password.clear();
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const AuthHeader(
              title: 'Chào mừng trở lại',
              subtitle: 'Đăng nhập để đặt dịch vụ, theo dõi Tasker hoặc nhận việc.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 220),
                    child: TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: Validators.email,
                      decoration: appInputDecoration(
                        label: 'Email',
                        hint: 'Nhập email tài khoản',
                        icon: Icons.alternate_email_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 280),
                    child: TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: Validators.loginPassword,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: appInputDecoration(
                        label: 'Mật khẩu',
                        hint: 'Nhập mật khẩu',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _forgot,
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                  if (_locked != null) ...[
                    const SizedBox(height: 4),
                    _lockedBox(_locked!),
                    const SizedBox(height: 4),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    NoticeBox(
                      message: _error!,
                      color: AppColors.danger,
                      icon: Icons.error_outline_rounded,
                    ),
                  ],
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 340),
                    child: PrimaryButton(
                      label: 'Đăng nhập',
                      loading: _loading,
                      onPressed: _submit,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('hoặc', style: AppText.small),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SecondaryButton(
                    label: 'Tạo tài khoản mới',
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
