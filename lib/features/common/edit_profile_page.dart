import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_picker.dart';

/// US05 – Cập nhật thông tin cá nhân. PUT /profile gửi đủ 4 field.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String? _avatarUrl;
  String _email = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await AppScope.api(context).getProfile();
      _name.text = p.fullName;
      _phone.text = p.phoneNumber ?? '';
      _address.text = p.address ?? '';
      _avatarUrl = p.avatarUrl;
      _email = p.email;
    } catch (error) {
      _error = errorMessage(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeAvatar() async {
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadPhoto(context);
      if (url != null && mounted) setState(() => _avatarUrl = url);
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AppScope.api(context).updateProfile(
        fullName: _name.text,
        phoneNumber: _phone.text,
        address: _address.text,
        avatarUrl: _avatarUrl,
      );
      if (!mounted) return;
      showSnack(context, 'Đã lưu thông tin cá nhân.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hsAppBar('Thông tin cá nhân'),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _uploading ? null : _changeAvatar,
                      child: Stack(
                        children: [
                          UserAvatar(
                            name: _name.text,
                            url: _avatarUrl,
                            size: 96,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: _uploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.photo_camera_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: Text(_email, style: AppText.muted)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.fullName,
                    decoration: appInputDecoration(
                      label: 'Họ và tên',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    validator: Validators.optionalPhone,
                    decoration: appInputDecoration(
                      label: 'Số điện thoại',
                      icon: Icons.phone_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _address,
                    maxLength: 255,
                    decoration: appInputDecoration(
                      label: 'Địa chỉ thường dùng',
                      icon: Icons.home_outlined,
                      helper: 'Sẽ được điền sẵn khi bạn đặt dịch vụ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Email và vai trò không thể thay đổi.',
                    style: AppText.small,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : BottomActionBar(
              children: [
                PrimaryButton(
                  label: 'Lưu thay đổi',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
    );
  }
}
