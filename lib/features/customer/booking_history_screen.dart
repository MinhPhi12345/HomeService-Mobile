import 'package:flutter/material.dart';
import '../../models/booking.dart';
import 'service_repository.dart';

// US15 - Xem lịch sử đặt dịch vụ / US14 - Hủy đơn
class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
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
      appBar: AppBar(title: const Text('Đơn của tôi')),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final bookings = snapshot.data!;
          if (bookings.isEmpty) return const Center(child: Text('Bạn chưa có đơn đặt dịch vụ nào.'));

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
                  trailing: b.status == BookingStatus.pending || b.status == BookingStatus.matched
                      ? TextButton(
                          onPressed: () async {
                            await _repo.cancelBooking(b.id);
                            _reload();
                          },
                          child: const Text('Hủy'),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
