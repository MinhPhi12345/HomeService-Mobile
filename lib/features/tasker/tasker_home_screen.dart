import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../customer/service_repository.dart';

// US17/US18/US20 - Tasker xem & nhận đơn, cập nhật trạng thái
class TaskerHomeScreen extends StatefulWidget {
  const TaskerHomeScreen({super.key});

  @override
  State<TaskerHomeScreen> createState() => _TaskerHomeScreenState();
}

class _TaskerHomeScreenState extends State<TaskerHomeScreen> {
  final _repo = BookingRepository();
  late Future<List<Booking>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getMyBookings();
  }

  void _reload() => setState(() => _future = _repo.getMyBookings());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn của tôi (Tasker)')),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final bookings = snapshot.data!;
          if (bookings.isEmpty) {
            return const Center(child: Text('Chưa có đơn nào được ghép nối cho bạn.'));
          }

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final b = bookings[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(b.serviceCategoryName),
                  subtitle: Text('${b.address}\n${bookingStatusLabel(b.status)}'),
                  isThreeLine: true,
                  trailing: _buildAction(b),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget? _buildAction(Booking b) {
    switch (b.status) {
      case BookingStatus.matched:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () async {
                await _repo.acceptBooking(b.id);
                _reload();
              },
              child: const Text('Nhận'),
            ),
            TextButton(
              onPressed: () async {
                await _repo.rejectBooking(b.id);
                _reload();
              },
              child: const Text('Từ chối'),
            ),
          ],
        );
      case BookingStatus.accepted:
        return TextButton(
          onPressed: () async {
            await _repo.updateStatus(b.id, BookingStatus.inProgress);
            _reload();
          },
          child: const Text('Bắt đầu'),
        );
      case BookingStatus.inProgress:
        return TextButton(
          onPressed: () async {
            await _repo.updateStatus(b.id, BookingStatus.completed);
            _reload();
          },
          child: const Text('Hoàn thành'),
        );
      default:
        return null;
    }
  }
}
