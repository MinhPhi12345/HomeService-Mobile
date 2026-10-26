import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// Chọn ngày + giờ bắt đầu khi tạo đơn.
/// - Dải 14 ngày tới (cuộn ngang) + nút chọn ngày khác (tối đa 30 ngày).
/// - Giờ chia theo buổi Sáng / Chiều / Tối, mỗi buổi chỉ hiện vài mốc 30 phút.
/// - "Giờ khác" để chọn chính xác từng phút.
/// - Dòng tóm tắt cho biết giờ bắt đầu – kết thúc dự kiến.
/// Quy tắc (BR-B03): sau hiện tại ít nhất 1 giờ và trong vòng 30 ngày.
class SchedulePicker extends StatefulWidget {
  const SchedulePicker({
    super.key,
    required this.day,
    required this.time,
    required this.onChanged,
    this.durationHours,
  });

  final DateTime day;
  final TimeOfDay? time;

  /// Thời lượng (giờ) để hiện giờ kết thúc dự kiến; null nếu dịch vụ không tính theo giờ.
  final int? durationHours;
  final void Function(DateTime day, TimeOfDay? time) onChanged;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isValid(DateTime value) {
    final now = DateTime.now();
    return value.isAfter(now.add(const Duration(minutes: 65))) &&
        value.isBefore(now.add(const Duration(days: 30)));
  }

  @override
  State<SchedulePicker> createState() => _SchedulePickerState();
}

class _Period {
  const _Period(this.label, this.range, this.icon, this.from, this.to);

  final String label;
  final String range;
  final IconData icon;

  /// Phút trong ngày [from, to] (mốc 30 phút).
  final int from;
  final int to;

  List<TimeOfDay> get slots => [
    for (var m = from; m <= to; m += 30)
      TimeOfDay(hour: m ~/ 60, minute: m % 60),
  ];

  bool contains(TimeOfDay t) {
    final m = t.hour * 60 + t.minute;
    return m >= from - 30 && m <= to + 29;
  }
}

class _SchedulePickerState extends State<SchedulePicker> {
  static const _periods = [
    _Period('Sáng', '7h – 11h30', Icons.wb_twilight_rounded, 7 * 60, 11 * 60 + 30),
    _Period('Chiều', '12h – 17h30', Icons.wb_sunny_rounded, 12 * 60, 17 * 60 + 30),
    _Period('Tối', '18h – 20h', Icons.nights_stay_rounded, 18 * 60, 20 * 60),
  ];
  static const _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _weekdayFull = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];
  static const _stripDays = 14;

  late int _period = _initialPeriod();

  DateTime get _today => SchedulePicker.dateOnly(DateTime.now());

  DateTime _at(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  bool _periodAvailable(DateTime day, _Period p) =>
      p.slots.any((s) => SchedulePicker.isValid(_at(day, s)));

  int _initialPeriod() {
    final time = widget.time;
    if (time != null) {
      final i = _periods.indexWhere((p) => p.contains(time));
      if (i >= 0) return i;
      return time.hour < 12 ? 0 : (time.hour < 18 ? 1 : 2);
    }
    final i = _periods.indexWhere((p) => _periodAvailable(widget.day, p));
    return i < 0 ? 0 : i;
  }

  /// Đổi ngày: giữ giờ nếu vẫn hợp lệ, không thì chọn mốc sớm nhất còn trống.
  void _selectDay(DateTime day) {
    var time = widget.time;
    if (time != null && !SchedulePicker.isValid(_at(day, time))) time = null;
    if (time == null) {
      for (var i = 0; i < _periods.length && time == null; i++) {
        for (final slot in _periods[i].slots) {
          if (SchedulePicker.isValid(_at(day, slot))) {
            time = slot;
            _period = i;
            break;
          }
        }
      }
    }
    setState(() {});
    widget.onChanged(day, time);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.day,
      firstDate: _today,
      lastDate: now.add(const Duration(days: 29)),
      helpText: 'Chọn ngày làm việc',
    );
    if (picked == null || !mounted) return;
    _selectDay(SchedulePicker.dateOnly(picked));
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: widget.time ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Chọn giờ bắt đầu',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    if (!SchedulePicker.isValid(_at(widget.day, picked))) {
      showSnack(
        context,
        'Giờ hẹn phải sau thời điểm hiện tại ít nhất 1 giờ.',
        error: true,
      );
      return;
    }
    setState(() {
      final i = _periods.indexWhere((p) => p.contains(picked));
      _period = i >= 0 ? i : (picked.hour < 12 ? 0 : (picked.hour < 18 ? 1 : 2));
    });
    widget.onChanged(widget.day, picked);
  }

  static String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _dayLabel(DateTime day) {
    final diff = day.difference(_today).inDays;
    final name = diff == 0
        ? 'Hôm nay'
        : diff == 1
        ? 'Ngày mai'
        : _weekdayFull[day.weekday - 1];
    return '$name, ${day.day}/${day.month}';
  }

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var i = 0; i < _stripDays; i++)
        SchedulePicker.dateOnly(_today.add(Duration(days: i))),
    ];
    // Ngày chọn từ lịch nằm ngoài dải 14 ngày => thêm vào đầu dải
    if (!days.contains(widget.day)) days.insert(0, widget.day);
    final period = _periods[_period];
    final time = widget.time;
    // Giờ tự chọn (không trùng mốc 30 phút nào) hiện thay chữ "Giờ khác"
    final customTime =
        time != null && !_periods.any((p) => p.slots.contains(time))
        ? time
        : null;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Ngày', style: AppText.label),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('Chọn ngày khác'),
              ),
            ],
          ),
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = days[index];
                final diff = day.difference(_today).inDays;
                return _DayPill(
                  top: diff == 0
                      ? 'Hôm nay'
                      : diff == 1
                      ? 'Mai'
                      : _weekdayShort[day.weekday - 1],
                  day: '${day.day}',
                  month: 'Th${day.month}',
                  selected: day == widget.day,
                  onTap: () => _selectDay(day),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          const Text('Giờ bắt đầu', style: AppText.label),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _periods.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _PeriodTab(
                    period: _periods[i],
                    selected: i == _period,
                    available: _periodAvailable(widget.day, _periods[i]),
                    onTap: () => setState(() => _period = i),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: LayoutBuilder(
              key: ValueKey('${widget.day}-$_period'),
              builder: (context, constraints) {
                const gap = 8.0;
                final width = (constraints.maxWidth - gap * 3) / 4;
                final slots = period.slots;
                final anyValid = slots.any(
                  (s) => SchedulePicker.isValid(_at(widget.day, s)),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final slot in slots)
                          _SlotChip(
                            width: width,
                            text: _hm(slot),
                            selected: slot == time,
                            enabled: SchedulePicker.isValid(
                              _at(widget.day, slot),
                            ),
                            onTap: () => widget.onChanged(widget.day, slot),
                          ),
                        _SlotChip(
                          width: width,
                          text: customTime == null
                              ? 'Giờ khác'
                              : _hm(customTime),
                          icon: customTime == null
                              ? Icons.more_time_rounded
                              : null,
                          selected: customTime != null,
                          enabled: true,
                          onTap: _pickCustomTime,
                        ),
                      ],
                    ),
                    if (!anyValid) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Buổi ${period.label.toLowerCase()} hôm nay đã qua giờ đặt. Chọn buổi khác hoặc ngày khác.',
                        style: AppText.small,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: time == null ? AppColors.warningSoft : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  time == null ? Icons.schedule_rounded : Icons.event_available_rounded,
                  color: time == null ? AppColors.warning : AppColors.primaryDark,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dayLabel(widget.day),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        time == null
                            ? 'Chọn giờ bắt đầu'
                            : _rangeText(time),
                        style: AppText.muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Đặt trước ít nhất 1 giờ và tối đa 30 ngày.',
            style: AppText.small,
          ),
        ],
      ),
    );
  }

  String _rangeText(TimeOfDay start) {
    final hours = widget.durationHours;
    if (hours == null) return 'Bắt đầu lúc ${_hm(start)}';
    final end = _at(widget.day, start).add(Duration(hours: hours));
    final endText =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    final nextDay = SchedulePicker.dateOnly(end) != widget.day ? ' hôm sau' : '';
    return '${_hm(start)} – $endText$nextDay · khoảng $hours giờ';
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.top,
    required this.day,
    required this.month,
    required this.selected,
    required this.onTap,
  });

  final String top;
  final String day;
  final String month;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    final soft = selected ? Colors.white.withValues(alpha: 0.85) : AppColors.inkSoft;
    return Material(
      color: selected ? AppColors.primary : AppColors.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                top,
                maxLines: 1,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: soft),
              ),
              Text(
                day,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              Text(month, style: TextStyle(fontSize: 10.5, color: soft)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.period,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final _Period period;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primaryDark
        : available
        ? AppColors.ink
        : AppColors.muted;
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(period.icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                period.label,
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
              Text(
                period.range,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.width,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.icon,
  });

  final double width;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? Colors.white
        : enabled
        ? AppColors.ink
        : AppColors.muted.withValues(alpha: 0.6);
    return SizedBox(
      width: width,
      child: Material(
        color: selected
            ? AppColors.primary
            : enabled
            ? AppColors.surface
            : AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.line,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: fg),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: fg,
                        decoration: enabled ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
