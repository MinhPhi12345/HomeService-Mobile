import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../tasker/tasker_profile_page.dart';
import '../tasker/wallet_page.dart';
import 'edit_profile_page.dart';
import 'payment_history_page.dart';

/// Tab "Tài khoản" dùng chung cho Khách hàng và Tasker.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Profile? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await AppScope.api(context).getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ cần đăng nhập lại để tiếp tục sử dụng.',
      confirmText: 'Đăng xuất',
      danger: true,
    );
    if (!ok || !mounted) return;
    await AppScope.api(context).logout();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.api(context);
    final user = api.currentUser;
    if (user == null) return const SizedBox.shrink();
    final profile = _profile;
    return Scaffold(
      appBar: hsAppBar('Tài khoản'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  UserAvatar(
                    name: profile?.fullName ?? user.fullName,
                    url: profile?.avatarUrl,
                    size: 60,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.fullName ?? user.fullName,
                          style: AppText.title,
                        ),
                        const SizedBox(height: 2),
                        Text(user.email, style: AppText.muted),
                        const SizedBox(height: 8),
                        StatusChip(
                          label: UserRole.label(user.role),
                          color: AppColors.primary,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null && profile == null) ...[
              const SizedBox(height: 12),
              NoticeBox(
                message: _error!,
                color: AppColors.danger,
                icon: Icons.error_outline_rounded,
              ),
            ],
            if (profile != null && profile.outstandingAmount > 0) ...[
              const SizedBox(height: 12),
              NoticeBox(
                title: 'Bạn đang có khoản cần thanh toán',
                message:
                    'Số tiền ${formatMoney(profile.outstandingAmount)}. Vào tab Đơn hàng, mở đơn '
                    '"Chưa thanh toán" hoặc đơn đã hủy còn phí để trả bằng ví/thẻ. '
                    'Bạn chưa đặt được đơn mới cho đến khi trả xong.',
                color: AppColors.warning,
                icon: Icons.warning_amber_rounded,
              ),
            ],
            if (profile != null && profile.isCashBlocked && user.isCustomer) ...[
              const SizedBox(height: 12),
              const NoticeBox(
                message:
                    'Tài khoản đang tạm chỉ hỗ trợ thanh toán online. Liên hệ quản trị viên để mở lại tiền mặt.',
                color: AppColors.info,
              ),
            ],
            const SizedBox(height: 18),
            const SectionHeader('Cá nhân'),
            _MenuGroup(
              children: [
                _MenuItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Thông tin cá nhân',
                  subtitle: 'Họ tên, số điện thoại, địa chỉ, ảnh đại diện',
                  onTap: () => _open(const EditProfilePage()),
                ),
                if (user.isTasker)
                  _MenuItem(
                    icon: Icons.badge_outlined,
                    title: 'Hồ sơ Tasker',
                    subtitle: 'CCCD, kỹ năng, khu vực và bán kính phục vụ',
                    onTap: () => _open(const TaskerProfilePage()),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const SectionHeader('Tài chính'),
            _MenuGroup(
              children: [
                if (user.isTasker)
                  _MenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Ví Tasker',
                    subtitle: 'Nạp tiền, rút tiền, lịch sử ví',
                    onTap: () => _open(const WalletPage()),
                  ),
                _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  title: user.isTasker
                      ? 'Thu nhập theo đơn'
                      : 'Lịch sử thanh toán',
                  subtitle: user.isTasker
                      ? 'Tiền nhận được từ từng đơn'
                      : 'Các khoản đã trả, đang giữ, đã hoàn',
                  onTap: () => _open(const PaymentHistoryPage()),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const SectionHeader('Khác'),
            _MenuGroup(
              children: [
                _MenuItem(
                  icon: Icons.dns_outlined,
                  title: 'Máy chủ đang kết nối',
                  subtitle: api.baseUrl,
                ),
                _MenuItem(
                  icon: Icons.logout_rounded,
                  title: 'Đăng xuất',
                  color: AppColors.danger,
                  onTap: _logout,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text('HomeService · Nhóm 15', style: AppText.small),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: color == AppColors.ink ? AppColors.primaryDark : color),
      title: Text(
        title,
        style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: color),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!, style: AppText.small),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    );
  }
}
