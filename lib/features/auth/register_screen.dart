import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../../core/constants.dart';
import '../customer/customer_home_screen.dart';
import '../tasker/tasker_home_screen.dart';

// US01 - Đăng ký tài khoản (chọn vai trò Khách hàng / Tasker)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  UserRole _role = UserRole.customer;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      await auth.register(
        fullName: _fullNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        phoneNumber: _phoneCtrl.text.trim(),
        role: _role,
      );
      if (!mounted) return;
      final target = _role == UserRole.tasker ? const TaskerHomeScreen() : const CustomerHomeScreen();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => target));
    } catch (e) {
      setState(() => _error = 'Không thể đăng ký. Email có thể đã được sử dụng.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _fullNameCtrl, decoration: const InputDecoration(labelText: 'Họ và tên')),
            const SizedBox(height: 12),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Số điện thoại')),
            const SizedBox(height: 12),
            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(value: UserRole.customer, label: Text('Khách hàng')),
                ButtonSegment(value: UserRole.tasker, label: Text('Tasker')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const CircularProgressIndicator() : const Text('Đăng ký'),
            ),
          ],
        ),
      ),
    );
  }
}
