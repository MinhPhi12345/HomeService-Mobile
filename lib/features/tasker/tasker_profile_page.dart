import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/config.dart';
import '../../core/geocoding_service.dart';
import '../../core/labels.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/photo_picker.dart';

/// US04 – Tasker gửi hồ sơ xác thực: CCCD, kỹ năng, khu vực, điểm làm việc, bán kính.
class TaskerProfilePage extends StatefulWidget {
  const TaskerProfilePage({super.key});

  @override
  State<TaskerProfilePage> createState() => _TaskerProfilePageState();
}

class _TaskerProfilePageState extends State<TaskerProfilePage> {
  final _form = GlobalKey<FormState>();
  final _idCard = TextEditingController();
  final _baseAddress = TextEditingController();
  TaskerProfile? _existing;
  List<ServiceCategory> _services = const [];
  final Set<String> _skills = {};
  String? _idCardImage;
  String? _area;
  GeoPoint? _base;
  int _radius = 5;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _idCard.dispose();
    _baseAddress.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.api(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.getTaskerProfile(),
        api.getCategories(),
      ]);
      final profile = results[0] as TaskerProfile?;
      _services = results[1] as List<ServiceCategory>;
      _existing = profile;
      if (profile != null) {
        _idCard.text = profile.idCardNumber;
        _idCardImage = profile.idCardImageUrl;
        _skills
          ..clear()
          ..addAll(profile.skillList);
        _area = kWorkingAreas.contains(profile.workingArea)
            ? profile.workingArea
            : null;
        _baseAddress.text = profile.baseAddress;
        _base = GeoPoint(profile.baseLatitude, profile.baseLongitude);
        _radius = kServiceRadiusKm.contains(profile.serviceRadiusKm)
            ? profile.serviceRadiusKm
            : 5;
      } else {
        final point = await LocationService.tryCurrent();
        _base = point;
        if (point != null) {
          // Tự điền địa chỉ điểm làm việc theo GPS (vẫn sửa được).
          final address = await GeocodingService.reverse(api, point);
          if (address != null && _baseAddress.text.isEmpty) {
            _baseAddress.text = address;
          }
        }
      }
    } catch (error) {
      _error = errorMessage(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickBase() async {
    final picked = await LocationPickerPage.open(
      context,
      initial: _base,
      initialAddress: _baseAddress.text.trim().isEmpty
          ? null
          : _baseAddress.text.trim(),
      title: 'Chọn điểm làm việc',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _base = picked.point;
      if (picked.address != null) _baseAddress.text = picked.address!;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    String? problem;
    if (_idCardImage == null) {
      problem = 'Vui lòng chụp ảnh CCCD.';
    } else if (_skills.isEmpty) {
      problem = 'Vui lòng chọn ít nhất 1 kỹ năng.';
    } else if (_area == null) {
      problem = 'Vui lòng chọn khu vực làm việc.';
    } else if (_base == null) {
      problem = 'Vui lòng chọn điểm làm việc trên bản đồ.';
    }
    if (problem != null) {
      showSnack(context, problem, error: true);
      return;
    }
    final api = AppScope.api(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final profile = await api.submitTaskerProfile(
        idCardNumber: _idCard.text,
        idCardImageUrl: _idCardImage!,
        skills: _skills.join(', '),
        workingArea: _area!,
        baseAddress: _baseAddress.text,
        baseLatitude: _base!.latitude,
        baseLongitude: _base!.longitude,
        serviceRadiusKm: _radius,
      );
      if (!mounted) return;
      showSnack(
        context,
        profile.isApproved
            ? 'Đã cập nhật hồ sơ.'
            : 'Đã gửi hồ sơ. Vui lòng chờ quản trị viên duyệt.',
      );
      navigator.pop(true);
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hsAppBar('Hồ sơ Tasker'),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: _fields(),
              ),
            ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : BottomActionBar(
              children: [
                PrimaryButton(
                  label: _existing == null ? 'Gửi hồ sơ' : 'Cập nhật hồ sơ',
                  icon: Icons.send_rounded,
                  loading: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
    );
  }

  List<Widget> _fields() {
    final existing = _existing;
    final status = existing?.verificationStatus ?? -1;
    return [
      NoticeBox(
        title: VerificationStatus.label(status),
        message: switch (status) {
          VerificationStatus.pending =>
            'Hồ sơ đã gửi, đang chờ quản trị viên duyệt.',
          VerificationStatus.approved =>
            'Hồ sơ đã được xác thực. Đổi điểm làm việc hoặc bán kính không cần duyệt lại nếu CCCD không đổi.',
          VerificationStatus.rejected =>
            'Hồ sơ bị từ chối. Kiểm tra lại ảnh CCCD và thông tin rồi gửi lại.',
          _ => 'Điền đầy đủ thông tin bên dưới để quản trị viên xác thực tài khoản của bạn.',
        },
        color: existing == null ? AppColors.info : VerificationStatus.color(status),
        icon: Icons.verified_user_outlined,
      ),
      const SizedBox(height: 18),
      const SectionHeader('Căn cước công dân'),
      TextFormField(
        controller: _idCard,
        keyboardType: TextInputType.number,
        maxLength: 12,
        validator: Validators.idCard,
        decoration: appInputDecoration(
          label: 'Số CCCD (12 chữ số)',
          icon: Icons.credit_card_rounded,
        ),
      ),
      PhotoSlot(
        url: _idCardImage,
        height: 170,
        label: 'Chụp mặt trước CCCD',
        onChanged: (url) => setState(() => _idCardImage = url),
      ),
      const SizedBox(height: 20),
      const SectionHeader('Kỹ năng'),
      const Text(
        'Chọn dịch vụ bạn làm được. Hệ thống chỉ gửi lời mời cho đơn khớp kỹ năng.',
        style: AppText.muted,
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final service in _services)
            FilterChip(
              label: Text(service.name),
              selected: _skills.contains(service.name),
              selectedColor: AppColors.primarySoft,
              checkmarkColor: AppColors.primaryDark,
              side: BorderSide(
                color: _skills.contains(service.name)
                    ? AppColors.primary
                    : AppColors.line,
              ),
              onSelected: (on) => setState(() {
                if (on) {
                  _skills.add(service.name);
                } else {
                  _skills.remove(service.name);
                }
              }),
            ),
          // Giữ lại kỹ năng cũ không còn trong danh sách dịch vụ.
          for (final skill in _skills.where(
            (s) => !_services.any((service) => service.name == s),
          ))
            InputChip(
              label: Text(skill),
              onDeleted: () => setState(() => _skills.remove(skill)),
            ),
        ],
      ),
      const SizedBox(height: 20),
      const SectionHeader('Khu vực làm việc'),
      DropdownButtonFormField<String>(
        initialValue: _area,
        items: [
          for (final area in kWorkingAreas)
            DropdownMenuItem(value: area, child: Text(area)),
        ],
        onChanged: (value) => setState(() => _area = value),
        decoration: appInputDecoration(
          label: 'Quận / khu vực',
          icon: Icons.map_outlined,
        ),
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _baseAddress,
        validator: Validators.minLength(
          5,
          'Vui lòng nhập địa chỉ điểm làm việc (ít nhất 5 ký tự).',
        ),
        decoration: appInputDecoration(
          label: 'Địa chỉ điểm làm việc',
          hint: 'Ví dụ: 12 Nguyễn Huệ, Quận 1',
          icon: Icons.home_work_outlined,
        ),
      ),
      const SizedBox(height: 12),
      if (_base != null)
        PinMap(
          key: ValueKey('${_base!.latitude},${_base!.longitude},$_radius'),
          pins: [MapPin(point: _base!, label: 'Điểm làm việc')],
          height: 160,
          zoom: _radius == 3 ? 13 : (_radius == 5 ? 12 : 11),
          interactive: false,
        ),
      const SizedBox(height: 10),
      SecondaryButton(
        label: _base == null ? 'Chọn điểm làm việc trên bản đồ' : 'Đổi điểm làm việc',
        icon: Icons.edit_location_alt_outlined,
        onPressed: _pickBase,
      ),
      const SizedBox(height: 20),
      const SectionHeader('Bán kính phục vụ'),
      Row(
        children: [
          for (final km in kServiceRadiusKm) ...[
            if (km != kServiceRadiusKm.first) const SizedBox(width: 8),
            Expanded(
              child: ChoiceTile(
                title: '$km km',
                selected: _radius == km,
                onTap: () => setState(() => _radius = km),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Lời mời gửi theo đợt 3 → 5 → 8 km, nhưng chỉ tới Tasker có bán kính phủ được địa chỉ khách.',
        style: AppText.small,
      ),
    ];
  }
}
