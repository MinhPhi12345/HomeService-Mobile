import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import '../data/api_client.dart';

const _ink = Color(0xFF18383A);
const _muted = Color(0xFF748585);
const _mint = Color(0xFF13B5A5);

String _money(num value) => '${NumberFormat('#,##0', 'vi_VN').format(value)} đ';
String _date(DateTime value) =>
    DateFormat('dd/MM/yyyy • HH:mm', 'vi').format(value);
String _errorText(Object error) => error.toString();

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.api});

  final ApiClient api;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  void _authenticated() {
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.api.isAuthenticated) {
      return HomeShell(api: widget.api, onLogout: _logout);
    }
    return WelcomePage(api: widget.api, onAuthenticated: _authenticated);
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });

  final ApiClient api;
  final VoidCallback onAuthenticated;

  void _openAuth(BuildContext context, {bool register = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthPage(
          api: api,
          onAuthenticated: onAuthenticated,
          initialRegister: register,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 156,
                height: 156,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F7F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 10),
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  size: 76,
                  color: _mint,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'HomeService',
                style: TextStyle(
                  color: _ink,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Chăm sóc ngôi nhà của bạn,\nđể bạn thảnh thơi tận hưởng.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, height: 1.5, fontSize: 15),
              ),
              const Spacer(),
              _PrimaryButton(
                label: 'Đăng nhập',
                onPressed: () => _openAuth(context),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _openAuth(context, register: true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  foregroundColor: _ink,
                  side: const BorderSide(color: Color(0xFFDDE7E3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Tạo tài khoản mới'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Dịch vụ gia đình đáng tin cậy, ngay trong tầm tay.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.api,
    required this.onAuthenticated,
    this.initialRegister = false,
  });

  final ApiClient api;
  final VoidCallback onAuthenticated;
  final bool initialRegister;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late bool _register;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  int _role = 0;

  @override
  void initState() {
    super.initState();
    _register = widget.initialRegister;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await widget.api.register(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          phoneNumber: _phone.text.trim(),
          role: _role,
        );
      } else {
        await widget.api.login(_email.text.trim(), _password.text);
      }
      widget.onAuthenticated();
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
          _busy = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _register ? 'Tạo tài khoản' : 'Chào mừng trở lại!',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _register
                      ? 'Đăng ký để đặt dịch vụ chăm sóc nhà cửa.'
                      : 'Đăng nhập để tiếp tục sử dụng HomeService.',
                  style: const TextStyle(color: _muted, height: 1.4),
                ),
                const SizedBox(height: 28),
                if (_register) ...[
                  _FieldLabel(label: 'Họ và tên'),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Nguyễn Văn An',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Vui lòng nhập họ tên.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'Loại tài khoản'),
                  DropdownButtonFormField<int>(
                    initialValue: _role,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.work_outline_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Khách hàng')),
                      DropdownMenuItem(value: 1, child: Text('Tasker')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _role = value);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                const _FieldLabel(label: 'Email'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    hintText: 'ban@email.com',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return email.contains('@') && email.contains('.')
                        ? null
                        : 'Email không hợp lệ.';
                  },
                ),
                if (_register) ...[
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'Số điện thoại (không bắt buộc)'),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '0912 345 678',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      final phone = value?.trim() ?? '';
                      if (phone.isEmpty) return null;
                      return RegExp(r'^0\d{9}$').hasMatch(phone)
                          ? null
                          : 'Số điện thoại cần có 10 chữ số.';
                    },
                  ),
                ],
                const SizedBox(height: 16),
                const _FieldLabel(label: 'Mật khẩu'),
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  autofillHints: _register
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.password],
                  decoration: InputDecoration(
                    hintText: 'Nhập mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (_register &&
                        (password.length < 8 ||
                            !RegExp(r'[A-Za-z]').hasMatch(password) ||
                            !RegExp(r'\d').hasMatch(password))) {
                      return 'Mật khẩu cần từ 8 ký tự, gồm chữ và số.';
                    }
                    return password.isEmpty ? 'Vui lòng nhập mật khẩu.' : null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBox(message: _error!),
                ],
                const SizedBox(height: 24),
                _PrimaryButton(
                  label: _register ? 'Đăng ký' : 'Đăng nhập',
                  isLoading: _busy,
                  onPressed: _busy ? null : _submit,
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                    child: Text(
                      _register
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký',
                      style: const TextStyle(
                        color: _mint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api, required this.onLogout});

  final ApiClient api;
  final Future<void> Function() onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  int _reloadKey = 0;

  void _showOrders() {
    setState(() {
      _selectedIndex = 1;
      _reloadKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTasker = widget.api.currentUser?.role == 1;
    final pages = [
      if (isTasker)
        TaskerHomeTab(api: widget.api, key: ValueKey('tasker-home-$_reloadKey'))
      else
        HomeTab(
          api: widget.api,
          onShowOrders: _showOrders,
          key: ValueKey('home-$_reloadKey'),
        ),
      OrdersTab(api: widget.api, key: ValueKey('orders-$_reloadKey')),
      NotificationsTab(
        api: widget.api,
        key: ValueKey('notifications-$_reloadKey'),
      ),
      ProfileTab(api: widget.api, onLogout: widget.onLogout),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() {
          _selectedIndex = index;
          if (index == 1 || index == 2) _reloadKey++;
        }),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE0F6F1),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: isTasker ? 'Nhận việc' : 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Đơn hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Thông báo',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.api, required this.onShowOrders});

  final ApiClient api;
  final VoidCallback onShowOrders;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<ServiceCategory>? _categories;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.api.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
          _loading = false;
        });
      }
    }
  }

  void _openCategory(ServiceCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryPage(
          api: widget.api,
          category: category,
          onShowOrders: widget.onShowOrders,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.api.currentUser;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DỊCH VỤ TẠI',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: _mint,
                            size: 18,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Thành phố Hồ Chí Minh',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down, color: _ink),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE4F7F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: _mint),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Xin chào${user?.fullName.isNotEmpty == true ? ', ${user!.fullName.split(' ').last}' : ''} 👋',
              style: const TextStyle(
                color: _ink,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Bạn cần giúp gì cho ngôi nhà hôm nay?',
              style: TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B6A5), Color(0xFF36C7AE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'ƯU ĐÃI MỚI',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nhà sạch,\ntâm an.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Đặt dịch vụ tiện lợi ngay hôm nay',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.cleaning_services_rounded,
                    color: Color(0xFFD9FFF4),
                    size: 74,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dịch vụ của chúng tôi',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(onPressed: _load, child: const Text('Làm mới')),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: _mint)),
              )
            else if (_error != null)
              _ErrorBox(message: _error!, onRetry: _load)
            else if (_categories!.isEmpty)
              const _EmptyState(
                icon: Icons.home_repair_service_outlined,
                title: 'Chưa có dịch vụ',
                detail: 'Danh mục dịch vụ sẽ hiển thị tại đây.',
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _categories!.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.28,
                ),
                itemBuilder: (context, index) {
                  final category = _categories![index];
                  final colors = [
                    const Color(0xFFE5F6F2),
                    const Color(0xFFFFF0DC),
                    const Color(0xFFF1E9FF),
                    const Color(0xFFFFE9EB),
                  ];
                  final icons = [
                    Icons.cleaning_services_rounded,
                    Icons.local_laundry_service_rounded,
                    Icons.plumbing_rounded,
                    Icons.yard_rounded,
                    Icons.restaurant_rounded,
                  ];
                  return _CategoryCard(
                    category: category,
                    color: colors[index % colors.length],
                    icon: icons[index % icons.length],
                    onTap: () => _openCategory(category),
                  );
                },
              ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: _mint, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tasker được xác thực • Hỗ trợ tận tâm',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TaskerHomeTab extends StatefulWidget {
  const TaskerHomeTab({super.key, required this.api});

  final ApiClient api;

  @override
  State<TaskerHomeTab> createState() => _TaskerHomeTabState();
}

class _TaskerHomeTabState extends State<TaskerHomeTab> {
  List<TaskerOffer> _offers = const [];
  bool _available = false;
  bool _loading = true;
  bool _availabilityBusy = false;
  int? _actingOnBooking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final availability = await widget.api.getTaskerAvailability();
      final offers = await widget.api.getMyOffers();
      if (mounted) {
        setState(() {
          _available = availability;
          _offers = offers;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _setAvailability(bool value) async {
    setState(() {
      _availabilityBusy = true;
      _error = null;
    });
    try {
      await widget.api.setTaskerAvailability(value);
      if (mounted) {
        setState(() {
          _available = value;
          _availabilityBusy = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
          _availabilityBusy = false;
        });
      }
    }
  }

  Future<void> _decide(TaskerOffer offer, {required bool accept}) async {
    setState(() => _actingOnBooking = offer.bookingId);
    try {
      if (accept) {
        await widget.api.acceptOffer(offer.bookingId);
      } else {
        await widget.api.rejectOffer(offer.bookingId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Bạn đã nhận đơn.' : 'Đã từ chối lời mời.'),
        ),
      );
      await _load();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    } finally {
      if (mounted) setState(() => _actingOnBooking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.api.currentUser;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              'Khu vực Tasker',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Xin chào${user?.fullName.isNotEmpty == true ? ', ${user!.fullName.split(' ').last}' : ''} 👋',
              style: const TextStyle(
                color: _ink,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: _available
                    ? const Color(0xFFE3F6EF)
                    : const Color(0xFFF0F3F1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _available
                          ? Colors.white
                          : const Color(0xFFE1E8E5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _available ? Icons.wifi_tethering : Icons.pause_rounded,
                      color: _available ? _mint : _muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _available ? 'Đang nhận đơn' : 'Đang ngoại tuyến',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Bật trạng thái để nhận lời mời phù hợp',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (_availabilityBusy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch.adaptive(
                      value: _available,
                      activeTrackColor: _mint,
                      onChanged: _setAvailability,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lời mời nhận đơn',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(onPressed: _load, child: const Text('Làm mới')),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              _ErrorBox(message: _error!),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(34),
                child: Center(child: CircularProgressIndicator(color: _mint)),
              )
            else if (_error == null && _offers.isEmpty)
              const _EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Chưa có lời mời mới',
                detail:
                    'Khi có đơn phù hợp với khu vực và kỹ năng của bạn, đơn sẽ hiển thị tại đây.',
              )
            else if (_error == null)
              ..._offers.map(
                (offer) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaskerOfferCard(
                    offer: offer,
                    isBusy: _actingOnBooking == offer.bookingId,
                    onAccept: () => _decide(offer, accept: true),
                    onReject: () => _decide(offer, accept: false),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Lời mời có thời hạn. Hãy kiểm tra kỹ địa chỉ và thời gian trước khi nhận.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskerOfferCard extends StatelessWidget {
  const _TaskerOfferCard({
    required this.offer,
    required this.isBusy,
    required this.onAccept,
    required this.onReject,
  });

  final TaskerOffer offer;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final timeLeft = offer.expiresAt.difference(DateTime.now());
    final expiryLabel = timeLeft.isNegative
        ? 'Đã hết hạn'
        : 'Còn ${timeLeft.inMinutes} phút';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EFEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.serviceCategoryName,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3DD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  expiryLabel,
                  style: const TextStyle(
                    color: Color(0xFFB77A19),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _IconText(
            icon: Icons.location_on_outlined,
            text:
                '${offer.address} • ${offer.distanceKm.toStringAsFixed(1)} km',
          ),
          const SizedBox(height: 7),
          _IconText(
            icon: Icons.schedule_rounded,
            text: _date(offer.scheduledTime),
          ),
          if (offer.note?.isNotEmpty == true) ...[
            const SizedBox(height: 7),
            _IconText(icon: Icons.notes_rounded, text: offer.note!),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FAF7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Giá trị đơn',
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _money(offer.totalPrice),
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Thực nhận dự kiến',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _money(offer.totalPrice - offer.estimatedCommission),
                      style: const TextStyle(
                        color: _mint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB8676C),
                    side: const BorderSide(color: Color(0xFFF0D8D9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Từ chối'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: isBusy ? null : onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: _mint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Nhận đơn'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final ServiceCategory category;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _ink, size: 21),
              ),
              const Spacer(),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Từ ${_money(category.basePrice)}/${category.unit}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryPage extends StatefulWidget {
  const CategoryPage({
    super.key,
    required this.api,
    required this.category,
    required this.onShowOrders,
  });

  final ApiClient api;
  final ServiceCategory category;
  final VoidCallback onShowOrders;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _note = TextEditingController();
  DateTime _scheduledTime = DateTime.now().add(const Duration(days: 1));
  int _quantity = 1;
  int _paymentMethod = 1;
  double? _latitude;
  double? _longitude;
  bool _locating = false;
  int? _pendingPaymentBookingId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ApiFailure('Vui lòng bật dịch vụ định vị trên thiết bị.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ApiFailure(
          'Ứng dụng cần quyền vị trí để ghép Tasker gần bạn.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on LocationServiceDisabledException {
      if (mounted) {
        setState(() => _error = 'Vui lòng bật dịch vụ định vị trên thiết bị.');
      }
    } on PermissionDeniedException {
      if (mounted) {
        setState(
          () => _error = 'Ứng dụng cần quyền vị trí để ghép Tasker gần bạn.',
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _error = 'Không lấy được vị trí. Vui lòng thử lại ngoài trời.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      setState(() {
        _error = 'Vui lòng lấy vị trí hiện tại để tìm Tasker gần bạn.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final booking = await widget.api.createBooking(
        category: widget.category,
        scheduledTime: _scheduledTime,
        address: _address.text.trim(),
        note: _note.text.trim(),
        quantity: _quantity,
        paymentMethod: _paymentMethod,
        latitude: _latitude!,
        longitude: _longitude!,
      );
      if (!mounted) return;
      if (_paymentMethod == 0) {
        _showBookingCreated(booking);
      } else {
        _pendingPaymentBookingId = booking.id;
        await _settleOnlinePayment();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = _pendingPaymentBookingId == null
              ? _errorText(error)
              : 'Đơn #$_pendingPaymentBookingId đã tạo nhưng chưa thanh toán: ${_errorText(error)}';
          _busy = false;
        });
      }
    }
  }

  Future<void> _retryOnlinePayment() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await _settleOnlinePayment();
  }

  Future<void> _settleOnlinePayment() async {
    final bookingId = _pendingPaymentBookingId;
    if (bookingId == null) return;
    try {
      var booking = await widget.api.getBooking(bookingId);
      if (booking.status == 10) {
        await widget.api.payBooking(bookingId, _paymentMethod);
        booking = await widget.api.getBooking(bookingId);
      }
      if (booking.status == 10) {
        throw const ApiFailure('Thanh toán chưa hoàn tất. Vui lòng thử lại.');
      }
      if (!mounted) return;
      _pendingPaymentBookingId = null;
      _showBookingCreated(booking);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error =
              'Đơn #$bookingId đã tạo nhưng chưa thanh toán: ${_errorText(error)}';
          _busy = false;
        });
      }
    }
  }

  void _showBookingCreated(Booking booking) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BookingCreatedPage(
          booking: booking,
          onShowOrders: widget.onShowOrders,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt dịch vụ')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F6F2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.home_repair_service_rounded,
                      color: _mint,
                      size: 34,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_money(category.basePrice)} / ${category.unit}',
                            style: const TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _FieldLabel(label: 'Thời gian thực hiện'),
              _SelectionTile(
                icon: Icons.calendar_month_outlined,
                title: _date(_scheduledTime),
                onTap: _chooseDate,
              ),
              const SizedBox(height: 18),
              const _FieldLabel(label: 'Vị trí để ghép Tasker'),
              _SelectionTile(
                icon: _latitude == null
                    ? Icons.my_location_rounded
                    : Icons.check_circle_outline_rounded,
                title: _locating
                    ? 'Đang lấy vị trí...'
                    : _latitude == null
                    ? 'Lấy vị trí hiện tại'
                    : 'Đã lấy tọa độ hiện tại',
                onTap: _locating ? null : _getCurrentLocation,
              ),
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
              const SizedBox(height: 18),
              const _FieldLabel(label: 'Địa chỉ sử dụng dịch vụ'),
              TextFormField(
                controller: _address,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Số nhà, tên đường, phường, quận...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(Icons.location_on_outlined),
                  ),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 5
                    ? 'Vui lòng nhập địa chỉ đầy đủ.'
                    : null,
              ),
              const SizedBox(height: 18),
              const _FieldLabel(label: 'Số lượng'),
              Row(
                children: [
                  _QuantityButton(
                    icon: Icons.remove,
                    onTap: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _QuantityButton(
                    icon: Icons.add,
                    onTap: _quantity < 12
                        ? () => setState(() => _quantity++)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(category.unit, style: const TextStyle(color: _muted)),
                ],
              ),
              const SizedBox(height: 18),
              const _FieldLabel(label: 'Ghi chú cho Tasker (không bắt buộc)'),
              TextFormField(
                controller: _note,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Mô tả thêm yêu cầu của bạn...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              const _FieldLabel(label: 'Phương thức thanh toán'),
              _PaymentMethodCard(
                icon: Icons.payments_outlined,
                title: 'Tiền mặt',
                subtitle: 'Thanh toán trực tiếp sau khi hoàn thành',
                selected: _paymentMethod == 0,
                onTap: () => setState(() => _paymentMethod = 0),
              ),
              const SizedBox(height: 8),
              _PaymentMethodCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Ví điện tử',
                subtitle: 'Thanh toán mô phỏng qua backend',
                selected: _paymentMethod == 1,
                onTap: () => setState(() => _paymentMethod = 1),
              ),
              const SizedBox(height: 8),
              _PaymentMethodCard(
                icon: Icons.credit_card_outlined,
                title: 'Thẻ ngân hàng',
                subtitle: 'Thanh toán mô phỏng qua backend',
                selected: _paymentMethod == 2,
                onTap: () => setState(() => _paymentMethod = 2),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8EFEC)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tạm tính',
                        style: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _money(category.basePrice * _quantity),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorBox(message: _error!),
              ],
              const SizedBox(height: 18),
              _PrimaryButton(
                label: _pendingPaymentBookingId == null
                    ? 'Tìm Tasker'
                    : 'Tiếp tục thanh toán',
                isLoading: _busy,
                onPressed: _busy
                    ? null
                    : _pendingPaymentBookingId == null
                    ? _submit
                    : _retryOnlinePayment,
                icon: Icons.arrow_forward_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingCreatedPage extends StatelessWidget {
  const BookingCreatedPage({
    super.key,
    required this.booking,
    required this.onShowOrders,
  });

  final Booking booking;
  final VoidCallback onShowOrders;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2F7F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_rounded, color: _mint, size: 56),
              ),
              const SizedBox(height: 26),
              const Text(
                'Đang tìm Tasker',
                style: TextStyle(
                  color: _ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Đơn #${booking.id} đã được gửi. Chúng tôi sẽ thông báo khi có Tasker nhận đơn.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.5),
              ),
              const SizedBox(height: 28),
              _PrimaryButton(
                label: 'Theo dõi đơn hàng',
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  onShowOrders();
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key, required this.api});

  final ApiClient api;

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  static const _filters = [
    'Tất cả',
    'Sắp tới',
    'Đang làm',
    'Hoàn tất',
    'Đã hủy',
  ];
  int _selectedFilter = 0;
  bool _loading = true;
  String? _error;
  List<Booking> _bookings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookings = await widget.api.getMyBookings();
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
          _loading = false;
        });
      }
    }
  }

  List<Booking> get _filteredBookings {
    return _bookings.where((booking) {
      switch (_selectedFilter) {
        case 1:
          return booking.status == 0 ||
              booking.status == 1 ||
              booking.status == 2;
        case 2:
          return booking.status == 3 || booking.status == 4;
        case 3:
          return booking.status == 5;
        case 4:
          return booking.status == 6 ||
              booking.status == 8 ||
              booking.status == 9;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Đơn của tôi',
              style: TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ChoiceChip(
                label: Text(_filters[index]),
                selected: _selectedFilter == index,
                onSelected: (_) => setState(() => _selectedFilter = index),
                selectedColor: _mint,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: _selectedFilter == index ? Colors.white : _ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: _selectedFilter == index
                      ? _mint
                      : const Color(0xFFE6ECE9),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _mint))
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _ErrorBox(message: _error!, onRetry: _load),
                    ),
                  )
                : _filteredBookings.isEmpty
                ? const _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Chưa có đơn hàng',
                    detail: 'Các đơn dịch vụ bạn đặt sẽ hiển thị tại đây.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: _filteredBookings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _BookingCard(booking: _filteredBookings[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (booking.status) {
      0 || 1 => ('Đang tìm Tasker', _mint, const Color(0xFFE5F6F2)),
      2 => ('Đã nhận đơn', const Color(0xFF3680C2), const Color(0xFFE8F2FC)),
      3 => ('Đang thực hiện', const Color(0xFFE39A21), const Color(0xFFFFF3DD)),
      4 => ('Chờ xác nhận', const Color(0xFFE39A21), const Color(0xFFFFF3DD)),
      5 => ('Hoàn tất', _mint, const Color(0xFFE5F6F2)),
      6 ||
      8 ||
      9 => ('Đã hủy', const Color(0xFFCE6470), const Color(0xFFFFE9EB)),
      _ => ('Đang xử lý', _muted, const Color(0xFFF0F3F1)),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EFEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F6F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: _mint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  booking.serviceCategoryName,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _IconText(
            icon: Icons.schedule_rounded,
            text: _date(booking.scheduledTime),
          ),
          const SizedBox(height: 7),
          _IconText(icon: Icons.location_on_outlined, text: booking.address),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEFF2F0)),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.taskerName == null
                      ? 'Đơn #${booking.id}'
                      : 'Tasker: ${booking.taskerName}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ),
              Text(
                _money(booking.totalPrice),
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key, required this.api});

  final ApiClient api;

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  bool _loading = true;
  String? _error;
  NotificationBatch? _batch;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final batch = await widget.api.getNotifications();
      if (mounted) {
        setState(() {
          _batch = batch;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.api.markAllNotificationsRead();
      await _load();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    try {
      await widget.api.markNotificationRead(item.id);
      await _load();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Thông báo',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if ((_batch?.unreadCount ?? 0) > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text('Đọc tất cả'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _mint))
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _ErrorBox(message: _error!, onRetry: _load),
                    ),
                  )
                : _batch!.items.isEmpty
                ? const _EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'Chưa có thông báo',
                    detail: 'Thông tin về đơn hàng sẽ xuất hiện ở đây.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: _batch!.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _batch!.items[index];
                        return InkWell(
                          onTap: () => _markRead(item),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: item.isRead
                                  ? Colors.white
                                  : const Color(0xFFEAF8F4),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD5F1E9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.notifications_active_outlined,
                                    color: _mint,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          color: _ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.message,
                                        style: const TextStyle(
                                          color: _muted,
                                          height: 1.35,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        DateFormat(
                                          'dd/MM • HH:mm',
                                          'vi',
                                        ).format(item.createdAt),
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!item.isRead)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 5),
                                    child: CircleAvatar(
                                      radius: 4,
                                      backgroundColor: _mint,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.api, required this.onLogout});

  final ApiClient api;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final user = api.currentUser;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          const Text(
            'Tài khoản',
            style: TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EFEC)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFE5F6F2),
                  child: Icon(Icons.person_rounded, color: _mint, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'Khách hàng',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _ProfileOption(
            icon: Icons.location_on_outlined,
            label: 'Địa chỉ đã lưu',
          ),
          const _ProfileOption(
            icon: Icons.help_outline_rounded,
            label: 'Trung tâm hỗ trợ',
          ),
          const _ProfileOption(
            icon: Icons.description_outlined,
            label: 'Điều khoản sử dụng',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await onLogout();
              } on Object catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(_errorText(error))));
                }
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD36B70),
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: Color(0xFFF2D7D8)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: _muted),
      title: Text(
        label,
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5ECE9)),
          ),
          child: Row(
            children: [
              Icon(icon, color: _mint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _mint : const Color(0xFFE5ECE9),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? _mint : _muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? _mint : _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      style: IconButton.styleFrom(
        foregroundColor: _mint,
        backgroundColor: const Color(0xFFE5F6F2),
        disabledForegroundColor: const Color(0xFFAACBC3),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _mint,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 19),
                ],
              ],
            ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFD36B70),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9C4A50),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 22),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFB6C8C2), size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
