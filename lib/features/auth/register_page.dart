import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'auth_header.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.initialRole = 0});

  /// 0 = Khách hàng, 1 = Tasker
  final int initialRole;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late int _role = widget.initialRole;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppScope.api(context).register(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
        phoneNumber: _phone.text,
        role: _role,
      );
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
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
              title: 'Tạo tài khoản trong 1 phút',
              subtitle: 'Một tài khoản dùng được cả trên ứng dụng và website HomeService.',
              showServices: false,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const Text('Bạn muốn dùng HomeService để…', style: AppText.section),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.home_rounded,
                      title: 'Đặt dịch vụ',
                      subtitle: 'Tôi là Khách hàng',
                      selected: _role == 0,
                      onTap: () => setState(() => _role = 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.handyman_rounded,
                      title: 'Nhận việc',
                      subtitle: 'Tôi là Tasker',
                      selected: _role == 1,
                      onTap: () => setState(() => _role = 1),
                    ),
                  ),
                ],
              ),
              if (_role == 1) ...[
                const SizedBox(height: 12),
                const NoticeBox(
                  message:
                      'Sau khi đăng ký, bạn cần gửi hồ sơ CCCD, kỹ năng và khu vực làm việc. '
                      'Khi quản trị viên duyệt xong, bạn mới bắt đầu nhận được việc.',
                ),
              ],
              const SizedBox(height: 22),
              TextFormField(
                controller: _name,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: Validators.fullName,
                decoration: appInputDecoration(
                  label: 'Họ và tên',
                  hint: 'Nhập họ và tên của bạn',
                  icon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
                decoration: appInputDecoration(
                  label: 'Email',
                  hint: 'Nhập email để đăng nhập',
                  icon: Icons.alternate_email_rounded,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: _role == 1
                    ? (v) => (v ?? '').trim().isEmpty
                          ? 'Tasker cần số điện thoại để khách liên lạc.'
                          : Validators.optionalPhone(v)
                    : Validators.optionalPhone,
                decoration: appInputDecoration(
                  label: _role == 1
                      ? 'Số điện thoại'
                      : 'Số điện thoại (không bắt buộc)',
                  hint: 'Nhập số điện thoại (10 số)',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                validator: Validators.password,
                decoration: appInputDecoration(
                  label: 'Mật khẩu',
                  hint: 'Tạo mật khẩu',
                  icon: Icons.lock_outline_rounded,
                  helper: 'Ít nhất 8 ký tự, gồm cả chữ và số',
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    v != _password.text ? 'Mật khẩu nhập lại không khớp.' : null,
                onFieldSubmitted: (_) => _submit(),
                decoration: appInputDecoration(
                  label: 'Nhập lại mật khẩu',
                  hint: 'Nhập lại mật khẩu vừa tạo',
                  icon: Icons.lock_reset_rounded,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                NoticeBox(
                  message: _error!,
                  color: AppColors.danger,
                  icon: Icons.error_outline_rounded,
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: _role == 1 ? 'Đăng ký làm Tasker' : 'Tạo tài khoản',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Đã có tài khoản?', style: AppText.muted),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    ),
                    child: const Text('Đăng nhập'),
                  ),
                ],
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderColor: selected ? AppColors.primary : AppColors.line,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppColors.inkSoft,
                ),
              ),
              const Spacer(),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          Text(subtitle, style: AppText.small),
        ],
      ),
    );
  }
}
