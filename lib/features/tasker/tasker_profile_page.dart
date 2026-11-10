import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/geocoding_service.dart';
import '../../core/labels.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/service_detail_sheet.dart';

/// US04 – Tasker gửi hồ sơ xác thực: CCCD, kỹ năng, điểm làm việc, bán kính.
/// Khu vực hiển thị trong hồ sơ do Backend tự lấy từ địa chỉ điểm làm việc (SRS 7.9).
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
  GeoPoint? _base;
  int _radius = 5;
  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
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

  /// Lấy GPS hiện tại làm điểm làm việc và tự điền địa chỉ (vẫn sửa tay được).
  Future<void> _useCurrentLocation() async {
    final api = AppScope.api(context);
    setState(() => _locating = true);
    try {
      final point = await LocationService.tryCurrent();
      if (!mounted) return;
      if (point == null) {
        showSnack(context, 'Chưa lấy được vị trí. Hãy bật GPS hoặc chọn trên bản đồ.', error: true);
        return;
      }
      final address = await GeocodingService.reverse(api, point);
      if (!mounted) return;
      setState(() {
        _base = point;
        if (address != null) _baseAddress.text = address;
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _toggleSkill(ServiceCategory service) => setState(() {
    if (!_skills.remove(service.name)) _skills.add(service.name);
  });

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    String? problem;
    if (_idCardImage == null) {
      problem = 'Vui lòng chụp ảnh CCCD.';
    } else if (_skills.isEmpty) {
      problem = 'Vui lòng chọn ít nhất 1 kỹ năng.';
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
      SectionHeader(
        'Dịch vụ bạn nhận làm',
        trailing: Text('Đã chọn ${_skills.length}', style: AppText.small),
      ),
      const Text(
        'Chọn dịch vụ bạn làm được, hệ thống chỉ gửi lời mời cho đơn khớp. '
        'Bấm ⓘ để xem công việc cụ thể của từng dịch vụ trước khi chọn.',
        style: AppText.muted,
      ),
      const SizedBox(height: 10),
      for (final service in _services)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SkillTile(
            service: service,
            selected: _skills.contains(service.name),
            onTap: () => _toggleSkill(service),
            onInfo: () => showServiceDetail(
              context,
              service,
              forTasker: true,
              chooseLabel: _skills.contains(service.name) ? 'Bỏ chọn dịch vụ này' : 'Chọn dịch vụ này',
              onChoose: () => _toggleSkill(service),
            ),
          ),
        ),
      // Giữ lại kỹ năng cũ không còn trong danh sách dịch vụ.
      if (_skills.any((s) => !_services.any((service) => service.name == s)))
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
      const SectionHeader('Điểm làm việc'),
      AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_base != null) ...[
              PinMap(
                key: ValueKey('${_base!.latitude},${_base!.longitude},$_radius'),
                pins: [MapPin(point: _base!, label: 'Điểm làm việc')],
                height: 150,
                zoom: _radius == 3 ? 13 : (_radius == 5 ? 12 : 11),
                interactive: false,
              ),
              const SizedBox(height: 12),
            ],
            const Text('Địa chỉ', style: AppText.label),
            const SizedBox(height: 6),
            TextFormField(
              controller: _baseAddress,
              minLines: 1,
              maxLines: 3,
              validator: Validators.minLength(
                5,
                'Vui lòng nhập địa chỉ điểm làm việc (ít nhất 5 ký tự).',
              ),
              decoration: appInputDecoration(
                hint: 'Ví dụ: 12 Nguyễn Huệ, Quận 1',
                icon: Icons.home_work_outlined,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Vị trí hiện tại',
                    icon: Icons.my_location_rounded,
                    loading: _locating,
                    onPressed: _useCurrentLocation,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: _base == null ? 'Chọn trên bản đồ' : 'Đổi trên bản đồ',
                    icon: Icons.edit_location_alt_outlined,
                    onPressed: _pickBase,
                  ),
                ),
              ],
            ),
            if (_existing?.workingArea != null) ...[
              const SizedBox(height: 10),
              _HintRow(
                icon: Icons.place_outlined,
                text: 'Khu vực đang hiển thị: ${_existing!.workingArea}',
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 10),
      const _HintRow(
        icon: Icons.near_me_outlined,
        text: 'Lời mời được gửi theo khoảng cách từ điểm này đến nhà khách.',
      ),
      const _HintRow(
        icon: Icons.badge_outlined,
        text: 'Khu vực hiển thị trong hồ sơ được lấy tự động từ địa chỉ trên.',
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

/// Một dịch vụ trong danh sách kỹ năng: chạm để chọn / bỏ chọn, ⓘ để xem chi tiết.
class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.service,
    required this.selected,
    required this.onTap,
    required this.onInfo,
  });

  final ServiceCategory service;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  String get _durationNote {
    final s = service;
    if (s.unit == 'giờ') return 'theo số giờ khách đặt';
    if (s.fixedQuantity) return 'khoảng ${durationText(s.estimateMinutes(s.minQuantity))}';
    return 'khoảng ${durationText(s.minutesPerUnit)} / ${s.unit}';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderColor: selected ? AppColors.primary : AppColors.line,
      radius: AppRadius.md,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.primary : AppColors.muted,
          ),
          const SizedBox(width: 10),
          ServiceIconBadge(name: service.name, size: 40, imageUrl: service.iconUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${formatMoney(service.basePrice)} / ${service.unit} · $_durationNote',
                  style: AppText.small,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chi tiết dịch vụ ${service.name}',
            onPressed: onInfo,
            icon: const Icon(Icons.info_outline_rounded, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: AppColors.inkSoft),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.muted)),
        ],
      ),
    );
  }
}
