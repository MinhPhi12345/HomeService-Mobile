import 'package:flutter/material.dart';
import '../../models/service_category.dart';
import 'service_repository.dart';

// US12/US13 - Tạo đơn đặt dịch vụ (chọn thời gian & địa chỉ)
class BookingCreateScreen extends StatefulWidget {
  const BookingCreateScreen({super.key, required this.service});
  final ServiceCategory service;

  @override
  State<BookingCreateScreen> createState() => _BookingCreateScreenState();
}

class _BookingCreateScreenState extends State<BookingCreateScreen> {
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _scheduledTime;
  bool _loading = false;
  String? _error;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _scheduledTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (_scheduledTime == null || _addressCtrl.text.isEmpty) {
      setState(() => _error = 'Vui lòng chọn thời gian và nhập địa chỉ.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BookingRepository().createBooking(
        serviceCategoryId: widget.service.id,
        scheduledTime: _scheduledTime!,
        address: _addressCtrl.text,
        note: _noteCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đặt dịch vụ thành công!')));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Không thể tạo đơn. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Đặt: ${widget.service.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(_scheduledTime == null ? 'Chọn thời gian' : _scheduledTime.toString()),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDateTime,
            ),
            TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Địa chỉ thực hiện')),
            const SizedBox(height: 12),
            TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'Ghi chú')),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const CircularProgressIndicator() : const Text('Xác nhận đặt dịch vụ'),
            ),
          ],
        ),
      ),
    );
  }
}
