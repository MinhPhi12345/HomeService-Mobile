import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/otp_field.dart';
import 'auth_header.dart';

/// Quên mật khẩu: nhập email → nhận mã OTP qua email → nhập mã + mật khẩu mới.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeStep = false;
  bool _obscure = true;
  bool _loading = false;
  String _masked = '';
  int _wait = 0;
  int _generation = 0;
  String? _info;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_codeStep && !_emailForm.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sent = await AppScope.api(context).forgotPassword(_email.text);
      if (!mounted) return;
      setState(() {
        _codeStep = true;
        _masked = sent.maskedEmail;
        _info = 'Nếu email đã đăng ký, mã OTP đã được gửi tới ${sent.maskedEmail}. Mã có hiệu lực 5 phút.';
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
          _codeStep = true;
          _wait = wait;
          _generation++;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    if (_code.text.length != OtpField.length) {
      setState(() => _error = 'Vui lòng nhập đủ 6 số của mã OTP.');
      return;
    }
    if (!_resetForm.currentState!.validate()) return;
    final api = AppScope.api(context);
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.resetPassword(_email.text, _code.text, _password.text);
      if (!mounted) return;
      showSnack(context, 'Đặt lại mật khẩu thành công. Hãy đăng nhập bằng mật khẩu mới.');
      navigator.pop(_email.text.trim().toLowerCase());
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AuthHeader(
            title: _codeStep ? 'Đặt mật khẩu mới' : 'Quên mật khẩu',
            subtitle: _codeStep
                ? 'Nhập mã đã gửi tới ${_masked.isEmpty ? _email.text : _masked} và mật khẩu mới.'
                : 'Nhập email tài khoản, chúng tôi sẽ gửi mã OTP để đặt lại mật khẩu.',
            showServices: false,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: _codeStep ? _resetStep() : _emailStep(),
          ),
        ],
      ),
    );
  }

  List<Widget> _messages() => [
    if (_info != null && _error == null) ...[
      NoticeBox(
        message: _info!,
        color: AppColors.success,
        icon: Icons.check_circle_outline_rounded,
      ),
      const SizedBox(height: 16),
    ],
    if (_error != null) ...[
      NoticeBox(
        message: _error!,
        color: AppColors.danger,
        icon: Icons.error_outline_rounded,
      ),
      const SizedBox(height: 16),
    ],
  ];

  Widget _emailStep() {
    return Form(
      key: _emailForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._messages(),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
            onFieldSubmitted: (_) => _send(),
            decoration: appInputDecoration(
              label: 'Email',
              hint: 'Nhập email tài khoản',
              icon: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(label: 'Gửi mã OTP', loading: _loading, onPressed: _send),
        ],
      ),
    );
  }

  Widget _resetStep() {
    return Form(
      key: _resetForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._messages(),
          const Text('Mã OTP', style: AppText.label),
          const SizedBox(height: 8),
          OtpField(controller: _code, hasError: _error != null && _code.text.isEmpty),
          const SizedBox(height: 18),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            validator: Validators.password,
            decoration: appInputDecoration(
              label: 'Mật khẩu mới',
              hint: 'Từ 8 ký tự, có chữ và số',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirm,
            obscureText: _obscure,
            validator: (v) => v == _password.text ? null : 'Mật khẩu xác nhận không khớp.',
            decoration: appInputDecoration(
              label: 'Nhập lại mật khẩu mới',
              icon: Icons.lock_outline_rounded,
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(label: 'Đặt lại mật khẩu', loading: _loading, onPressed: _reset),
          const SizedBox(height: 8),
          ResendCountdown(
            seconds: _wait,
            generation: _generation,
            busy: _loading,
            onResend: _send,
          ),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                    _codeStep = false;
                    _error = null;
                    _info = null;
                  }),
            child: const Text('Đổi email khác'),
          ),
        ],
      ),
    );
  }
}
