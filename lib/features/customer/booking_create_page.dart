import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/format.dart';
import '../../core/geocoding_service.dart';
import '../../core/labels.dart';
import '../../core/location_service.dart';
import '../../core/models.dart';
import '../../core/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/schedule_picker.dart';
import 'booking_detail_page.dart';
import 'payment_page.dart';

/// US12, US13 – Tạo đơn: số lượng, giờ hẹn, địa chỉ + vị trí bản đồ, phương thức thanh toán.
class BookingCreatePage extends StatefulWidget {
  const BookingCreatePage({
    super.key,
    required this.service,
    this.initialAddress,
    this.initialLocation,
    this.initialQuantity,
    this.initialNote,
  });

  final ServiceCategory service;
  final String? initialAddress;
  final GeoPoint? initialLocation;
  final int? initialQuantity;
  final String? initialNote;

  @override
  State<BookingCreatePage> createState() => _BookingCreatePageState();
}

class _BookingCreatePageState extends State<BookingCreatePage> {
  static const _cashMaxOrder = 1000000;
  static const _cashMinPaidOrders = 3;

  late final _address = TextEditingController(text: widget.initialAddress ?? '');
  late final _note = TextEditingController(text: widget.initialNote ?? '');
  final _phone = TextEditingController();
  Profile? _profile;
  bool _geocoding = false;
  bool _saveToProfile = false;
  late int _quantity = (widget.initialQuantity ?? 1).clamp(1, 12);
  late GeoPoint? _location = widget.initialLocation;
  late DateTime _day = _dateOnly(DateTime.now());
  TimeOfDay? _time;
  int _method = PaymentMethod.eWallet;
  bool _present = true;
  bool _locating = false;
  bool _submitting = false;

  // Điều kiện tiền mặt (BR-P06)
  int _paidOrders = 0;
  bool _cashBlocked = false;
  double _outstanding = 0;

  double get _total => widget.service.basePrice * _quantity;

  bool get _cashAllowed =>
      _paidOrders >= _cashMinPaidOrders &&
      !_cashBlocked &&
      _total <= _cashMaxOrder;

  DateTime? get _scheduled => _time == null
      ? null
      : DateTime(_day.year, _day.month, _day.day, _time!.hour, _time!.minute);

  @override
  void initState() {
    super.initState();
    _pickEarliestSlot();
    _loadEligibility();
  }

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    _phone.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Giờ hẹn phải sau hiện tại ít nhất 1 giờ và trong vòng 30 ngày.
  static bool _isValidSlot(DateTime value) {
    final now = DateTime.now();
    return value.isAfter(now.add(const Duration(minutes: 65))) &&
        value.isBefore(now.add(const Duration(days: 30)));
  }

  static List<TimeOfDay> get _slots => [
    for (var minutes = 7 * 60; minutes <= 20 * 60; minutes += 30)
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
  ];

  DateTime _at(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  void _pickEarliestSlot() {
    for (var offset = 0; offset < 3; offset++) {
      final day = _dateOnly(DateTime.now().add(Duration(days: offset)));
      for (final slot in _slots) {
        if (_isValidSlot(_at(day, slot))) {
          _day = day;
          _time = slot;
          return;
        }
      }
    }
  }

  Future<void> _loadEligibility() async {
    final api = AppScope.api(context);
    try {
      final results = await Future.wait([
        api.getProfile(),
        api.getMyBookings(statuses: const [BookingStatus.paid]),
      ]);
      if (!mounted) return;
      final profile = results[0] as Profile;
      setState(() {
        _profile = profile;
        _paidOrders = (results[1] as List<Booking>).length;
        _cashBlocked = profile.isCashBlocked;
        _outstanding = profile.outstandingAmount;
        // Gợi ý sẵn SĐT và địa chỉ trong hồ sơ; khách vẫn sửa được.
        if (_phone.text.isEmpty && profile.phoneNumber != null) {
          _phone.text = profile.phoneNumber!;
        }
        if (_address.text.isEmpty && profile.address != null) {
          _address.text = profile.address!;
        }
        _saveToProfile = profile.phoneNumber == null || profile.address == null;
      });
    } catch (_) {
      // Không chặn đặt đơn nếu chưa tải được – Backend vẫn kiểm tra lại.
    }
    if (!mounted || _location != null) return;
    // Chưa có toạ độ: có địa chỉ => tìm trên bản đồ; không có => lấy GPS và tự điền địa chỉ.
    if (_address.text.trim().length >= 5) {
      final found = await _locateTypedAddress(silent: true);
      if (!found && mounted) await _useMyLocation(silent: true, fillAddress: false);
    } else {
      await _useMyLocation(silent: true);
    }
  }

  /// GPS => ghim vị trí => tra địa chỉ và điền vào ô nhập.
  Future<void> _useMyLocation({bool silent = false, bool fillAddress = true}) async {
    setState(() => _locating = true);
    try {
      final point = await LocationService.current();
      if (!mounted) return;
      setState(() => _location = point);
      if (fillAddress) await _fillAddressFrom(point, silent: silent);
    } catch (error) {
      if (!silent && mounted) {
        showSnack(context, errorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _fillAddressFrom(GeoPoint point, {bool silent = false}) async {
    setState(() => _geocoding = true);
    final address = await GeocodingService.reverse(AppScope.api(context), point);
    if (!mounted) return;
    setState(() {
      _geocoding = false;
      if (address != null) _address.text = address;
    });
    if (!silent) {
      showSnack(
        context,
        address == null
            ? 'Đã ghim vị trí nhưng chưa tra được địa chỉ, bạn hãy tự nhập.'
            : 'Đã điền địa chỉ theo vị trí. Bạn có thể sửa lại số nhà nếu cần.',
      );
    }
  }

  /// Địa chỉ đang nhập => toạ độ trên bản đồ.
  Future<bool> _locateTypedAddress({bool silent = false}) async {
    FocusScope.of(context).unfocus();
    final text = _address.text.trim();
    if (text.length < 5) {
      if (!silent) showSnack(context, 'Nhập địa chỉ cụ thể hơn để tìm trên bản đồ.', error: true);
      return false;
    }
    setState(() => _geocoding = true);
    final point = await GeocodingService.locate(AppScope.api(context), text);
    if (!mounted) return false;
    setState(() {
      _geocoding = false;
      if (point != null) _location = point;
    });
    if (!silent) {
      showSnack(
        context,
        point == null
            ? 'Không tìm thấy địa chỉ trên bản đồ. Hãy bấm "Mở bản đồ" để ghim tay.'
            : 'Đã ghim vị trí theo địa chỉ. Kiểm tra lại trên bản đồ nhé.',
        error: point == null,
      );
    }
    return point != null;
  }

  Future<void> _pickOnMap() async {
    final picked = await LocationPickerPage.open(
      context,
      initial: _location,
      initialAddress: _address.text.trim().isEmpty ? null : _address.text.trim(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _location = picked.point;
      if (picked.address != null) _address.text = picked.address!;
    });
  }

  Future<void> _useSavedAddress(String address) async {
    setState(() => _address.text = address);
    await _locateTypedAddress();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final scheduled = _scheduled;
    String? problem;
    if (scheduled == null || !_isValidSlot(scheduled)) {
      problem = 'Vui lòng chọn giờ hẹn sau thời điểm hiện tại ít nhất 1 giờ.';
    } else if (_phone.text.trim().isEmpty ||
        Validators.optionalPhone(_phone.text) != null) {
      problem = 'Vui lòng nhập số điện thoại liên hệ (10 số, bắt đầu bằng 0).';
    } else if (_address.text.trim().length < 5) {
      problem = 'Vui lòng nhập địa chỉ cụ thể (số nhà, đường, phường).';
    } else if (_location == null) {
      problem = 'Vui lòng ghim vị trí trên bản đồ để hệ thống tìm Tasker gần bạn.';
    } else if (_method == PaymentMethod.cash && !_present) {
      problem = 'Thanh toán tiền mặt yêu cầu bạn có mặt khi Tasker làm việc.';
    }
    if (problem != null) {
      showSnack(context, problem, error: true);
      return;
    }

    final api = AppScope.api(context);
    final navigator = Navigator.of(context);
    setState(() => _submitting = true);
    try {
      final booking = await api.createBooking(
        serviceCategoryId: widget.service.id,
        scheduledTime: scheduled!,
        address: _address.text,
        latitude: _location!.latitude,
        longitude: _location!.longitude,
        quantity: _quantity,
        paymentMethod: _method,
        customerPresent: _present,
        note: _note.text,
        contactPhone: _phone.text.trim(),
      );
      await _saveContactToProfile(api);
      if (!mounted) return;
      if (booking.status == BookingStatus.awaitingPayment) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => PaymentPage(booking: booking)),
        );
      } else {
        showSnack(context, 'Đặt đơn thành công! Hệ thống đang tìm Tasker cho bạn.');
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingDetailPage(bookingId: booking.id),
          ),
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Lưu SĐT + địa chỉ vừa dùng vào hồ sơ để lần sau được điền sẵn (không chặn đặt đơn nếu lỗi).
  Future<void> _saveContactToProfile(ApiClient api) async {
    final profile = _profile;
    if (!_saveToProfile || profile == null) return;
    try {
      await api.updateProfile(
        fullName: profile.fullName,
        phoneNumber: _phone.text.trim(),
        address: _address.text.trim(),
        avatarUrl: profile.avatarUrl,
      );
    } catch (_) {}
  }

  String get _quantityLabel => switch (widget.service.unit) {
    'giờ' => 'Số giờ làm việc',
    'lần' => 'Số lần',
    'buổi' => 'Số buổi',
    'm²' => 'Số đơn vị (m²)',
    _ => 'Số lượng',
  };

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return Scaffold(
      appBar: hsAppBar('Đặt dịch vụ'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ServiceIconBadge(name: service.name, size: 56, imageUrl: service.iconUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name, style: AppText.title),
                      const SizedBox(height: 4),
                      Text(
                        '${formatMoney(service.basePrice)} / ${service.unit}',
                        style: AppText.money,
                      ),
                      if (service.description != null) ...[
                        const SizedBox(height: 6),
                        Text(service.description!, style: AppText.muted),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_outstanding > 0) ...[
            const SizedBox(height: 12),
            NoticeBox(
              message:
                  'Bạn còn khoản nợ ${formatMoney(_outstanding)}. Hãy thanh toán trước khi đặt đơn mới.',
              color: AppColors.warning,
              icon: Icons.warning_amber_rounded,
            ),
          ],
          const SizedBox(height: 20),
          SectionHeader(_quantityLabel),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$_quantity ${service.unit}',
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onTap: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$_quantity',
                    textAlign: TextAlign.center,
                    style: AppText.title,
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onTap: _quantity < 12
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Thời gian', padding: EdgeInsets.only(bottom: 8)),
          SchedulePicker(
            day: _day,
            time: _time,
            durationHours: service.unit == 'giờ' ? _quantity : null,
            onChanged: (day, time) => setState(() {
              _day = day;
              _time = time;
            }),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Địa chỉ làm việc'),
          TextField(
            controller: _address,
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _locateTypedAddress(),
            decoration: appInputDecoration(
              hint: 'Số nhà, tên đường, phường, quận',
              icon: Icons.home_work_outlined,
              suffix: _geocoding
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Tìm địa chỉ này trên bản đồ',
                      onPressed: _locateTypedAddress,
                      icon: const Icon(Icons.travel_explore_rounded),
                    ),
            ),
          ),
          if (_profile?.address != null &&
              _profile!.address!.trim() != _address.text.trim()) ...[
            const SizedBox(height: 8),
            _SuggestionChip(
              icon: Icons.bookmark_outline_rounded,
              label: 'Địa chỉ đã lưu: ${_profile!.address!}',
              onTap: () => _useSavedAddress(_profile!.address!),
            ),
          ],
          const SizedBox(height: 12),
          if (_location != null)
            Stack(
              children: [
                PinMap(
                  key: ValueKey('${_location!.latitude},${_location!.longitude}'),
                  pins: [MapPin(point: _location!, label: 'Nhà bạn')],
                  height: 150,
                  interactive: false,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: StatusChip(
                    label: 'Đã ghim vị trí',
                    color: AppColors.success,
                    icon: Icons.check_circle_rounded,
                    dense: true,
                  ),
                ),
              ],
            )
          else
            const NoticeBox(
              message:
                  'Cần vị trí trên bản đồ để hệ thống tìm Tasker trong bán kính 3–8 km quanh bạn.',
              icon: Icons.location_searching_rounded,
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Vị trí hiện tại',
                  icon: Icons.my_location_rounded,
                  loading: _locating,
                  onPressed: _useMyLocation,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: 'Mở bản đồ',
                  icon: Icons.map_outlined,
                  onPressed: _pickOnMap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader('Số điện thoại liên hệ'),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            onChanged: (_) => setState(() {}),
            decoration: appInputDecoration(
              hint: 'Ví dụ: 0901234567',
              icon: Icons.phone_outlined,
              helper: 'Tasker sẽ gọi số này khi đến nơi hoặc cần hỏi thêm',
            ),
          ),
          if (_profile?.phoneNumber != null &&
              _profile!.phoneNumber != _phone.text.trim()) ...[
            _SuggestionChip(
              icon: Icons.contact_phone_outlined,
              label: 'Số trong hồ sơ: ${_profile!.phoneNumber!}',
              onTap: () => setState(() => _phone.text = _profile!.phoneNumber!),
            ),
            const SizedBox(height: 4),
          ],
          if (_profile != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _saveToProfile,
              onChanged: (value) => setState(() => _saveToProfile = value ?? false),
              title: const Text(
                'Lưu số điện thoại và địa chỉ này vào hồ sơ',
                style: AppText.body,
              ),
              subtitle: const Text(
                'Lần sau đặt dịch vụ sẽ được điền sẵn',
                style: AppText.small,
              ),
            ),
          const SizedBox(height: 20),
          const SectionHeader('Ghi chú cho Tasker'),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 500,
            decoration: appInputDecoration(
              hint: 'Ví dụ: nhà có thú cưng, cần mang theo máy hút bụi…',
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader('Phương thức thanh toán'),
          ChoiceTile(
            icon: PaymentMethod.icon(PaymentMethod.eWallet),
            title: 'Ví điện tử',
            subtitle: 'Trả trước – tiền được giữ an toàn đến khi bạn xác nhận',
            selected: _method == PaymentMethod.eWallet,
            onTap: () => setState(() => _method = PaymentMethod.eWallet),
          ),
          const SizedBox(height: 8),
          ChoiceTile(
            icon: PaymentMethod.icon(PaymentMethod.card),
            title: 'Thẻ ngân hàng',
            subtitle: 'Trả trước bằng thẻ ATM / Visa / Mastercard',
            selected: _method == PaymentMethod.card,
            onTap: () => setState(() => _method = PaymentMethod.card),
          ),
          const SizedBox(height: 8),
          ChoiceTile(
            icon: PaymentMethod.icon(PaymentMethod.cash),
            title: 'Tiền mặt',
            subtitle: _cashAllowed
                ? 'Trả trực tiếp cho Tasker khi hoàn thành'
                : _cashBlocked
                ? 'Tài khoản đang tạm chỉ hỗ trợ thanh toán online'
                : _total > _cashMaxOrder
                ? 'Chỉ áp dụng cho đơn từ 1.000.000 đ trở xuống'
                : 'Mở sau khi bạn hoàn tất $_cashMinPaidOrders đơn (đã có $_paidOrders)',
            enabled: _cashAllowed,
            selected: _method == PaymentMethod.cash,
            onTap: () => setState(() => _method = PaymentMethod.cash),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _present,
            onChanged: (value) => setState(() => _present = value),
            title: const Text(
              'Tôi sẽ có mặt khi Tasker làm việc',
              style: AppText.body,
            ),
            subtitle: const Text(
              'Bắt buộc nếu thanh toán tiền mặt',
              style: AppText.small,
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                SummaryRow(
                  'Đơn giá',
                  '${formatMoney(service.basePrice)} / ${service.unit}',
                ),
                SummaryRow('Số lượng', '× $_quantity'),
                if (_scheduled != null)
                  SummaryRow('Giờ hẹn', formatSchedule(_scheduled!)),
                const Divider(height: 18),
                SummaryRow('Tổng thanh toán', formatMoney(_total), bold: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          PrimaryButton(
            label: _method == PaymentMethod.cash
                ? 'Đặt dịch vụ · ${formatMoney(_total)}'
                : 'Tiếp tục thanh toán · ${formatMoney(_total)}',
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppColors.bg : AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: onTap == null ? AppColors.muted : AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(color: AppColors.primaryDark),
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
