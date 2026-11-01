import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/otp_field.dart';

/// Đổi mật khẩu khi đã đăng nhập: mật khẩu hiện tại + mã OTP gửi về email + mật khẩu mới.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  bool _obscure = true;
  bool _sending = false;
  bool _saving = false;
  String? _sentTo;
  int _wait = 0;
  int _generation = 0;
  String? _error;

  @override
  void dispose() {
    for (final c in [_current, _password, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent = await AppScope.api(context).sendChangePasswordOtp();
      if (!mounted) return;
      setState(() {
        _sentTo = sent.maskedEmail;
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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (_code.text.length != OtpField.length) {
      setState(() => _error = 'Vui lòng nhập đủ 6 số của mã OTP.');
      return;
    }
    final api = AppScope.api(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await api.changePassword(
        currentPassword: _current.text,
        code: _code.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      showSnack(context, 'Đổi mật khẩu thành công.');
      navigator.pop();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eye = IconButton(
      onPressed: () => setState(() => _obscure = !_obscure),
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
    );
    return Scaffold(
      appBar: hsAppBar('Đổi mật khẩu'),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const NoticeBox(
              message:
                  'Để bảo vệ tài khoản, đổi mật khẩu cần mật khẩu hiện tại và mã OTP gửi về email đăng nhập của bạn.',
              icon: Icons.shield_outlined,
              color: AppColors.primaryDark,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              NoticeBox(
                message: _error!,
                color: AppColors.danger,
                icon: Icons.error_outline_rounded,
              ),
            ],
            const SizedBox(height: 18),
            TextFormField(
              controller: _current,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              validator: Validators.loginPassword,
              decoration: appInputDecoration(
                label: 'Mật khẩu hiện tại',
                icon: Icons.lock_outline_rounded,
                suffix: eye,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) =>
                  Validators.password(v) ??
                  (v == _current.text ? 'Mật khẩu mới phải khác mật khẩu hiện tại.' : null),
              decoration: appInputDecoration(
                label: 'Mật khẩu mới',
                hint: 'Từ 8 ký tự, có chữ và số',
                icon: Icons.lock_reset_rounded,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              validator: (v) => v == _password.text ? null : 'Mật khẩu xác nhận không khớp.',
              decoration: appInputDecoration(
                label: 'Nhập lại mật khẩu mới',
                icon: Icons.lock_reset_rounded,
              ),
            ),
            if (_sentTo != null) ...[
              const SizedBox(height: 22),
              Text('Mã OTP đã gửi tới $_sentTo', style: AppText.label),
              const SizedBox(height: 8),
              OtpField(controller: _code, enabled: !_saving),
              const SizedBox(height: 6),
              ResendCountdown(
                seconds: _wait,
                generation: _generation,
                busy: _sending,
                onResend: _sendCode,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          _sentTo == null
              ? PrimaryButton(
                  label: 'Gửi mã OTP về email',
                  icon: Icons.mark_email_unread_outlined,
                  loading: _sending,
                  onPressed: _sendCode,
                )
              : PrimaryButton(
                  label: 'Đổi mật khẩu',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: _save,
                ),
        ],
      ),
    );
  }
}
