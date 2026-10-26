import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat('#,##0', 'vi_VN');

/// 450000 => "450.000 đ" (SRS 8.5)
String formatMoney(num value) => '${_money.format(value)} đ';

/// dd/MM/yyyy HH:mm theo giờ máy (SRS 8.5)
String formatDateTime(DateTime value) =>
    DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());

String formatDate(DateTime value) =>
    DateFormat('dd/MM/yyyy').format(value.toLocal());

String formatTime(DateTime value) => DateFormat('HH:mm').format(value.toLocal());

/// "Thứ Hai, 26/10 · 08:00"
String formatSchedule(DateTime value) {
  final local = value.toLocal();
  final weekday = DateFormat('EEEE', 'vi').format(local);
  final capitalized = weekday.isEmpty
      ? weekday
      : weekday[0].toUpperCase() + weekday.substring(1);
  return '$capitalized, ${DateFormat('dd/MM').format(local)} · ${formatTime(local)}';
}

/// "5 phút trước", "Hôm qua"...
String formatRelative(DateTime value) {
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays == 1) return 'Hôm qua';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return formatDate(value);
}

/// 754 giây => "12:34"
String formatCountdown(Duration value) {
  if (value.isNegative) return '00:00';
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (value.inHours > 0) return '${value.inHours}:$minutes:$seconds';
  return '$minutes:$seconds';
}

String formatKm(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

/// Lời chào theo giờ trong ngày.
String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'Chào buổi sáng';
  if (hour < 14) return 'Chào buổi trưa';
  if (hour < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}

/// Chữ cái đầu của tên cuối, dùng cho ảnh đại diện mặc định.
String initials(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  return String.fromCharCode(parts.last.runes.first).toUpperCase();
}
