import 'package:flutter/material.dart';

import 'common.dart';

/// Chọn ngày + giờ hẹn mới (thử lại đơn, đổi lịch).
/// Giờ hẹn phải sau hiện tại ít nhất 1 giờ và trong vòng 30 ngày (BR-B03).
Future<DateTime?> pickFutureDateTime(
  BuildContext context, {
  DateTime? initial,
}) async {
  final now = DateTime.now();
  final earliest = now.add(const Duration(hours: 1, minutes: 5));
  final start = (initial != null && initial.isAfter(earliest)) ? initial : earliest;
  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 29)),
    helpText: 'Chọn ngày hẹn',
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
    helpText: 'Chọn giờ hẹn',
  );
  if (time == null || !context.mounted) return null;
  final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (value.isBefore(now.add(const Duration(hours: 1)))) {
    showSnack(
      context,
      'Giờ hẹn phải sau thời điểm hiện tại ít nhất 1 giờ.',
      error: true,
    );
    return null;
  }
  return value;
}
