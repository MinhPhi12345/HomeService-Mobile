import 'package:flutter/material.dart';
import 'service_repository.dart';
import '../../models/service_category.dart';
import 'booking_create_screen.dart';
import 'booking_history_screen.dart';

// US10 - Xem/Tìm kiếm dịch vụ (màn hình chính của Khách hàng)
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _repo = ServiceRepository();
  late Future<List<ServiceCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getServices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dịch vụ tại nhà'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingHistoryScreen())),
          ),
        ],
      ),
      body: FutureBuilder<List<ServiceCategory>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final services = snapshot.data!;
          if (services.isEmpty) return const Center(child: Text('Chưa có dịch vụ nào.'));

          return ListView.builder(
            itemCount: services.length,
            itemBuilder: (context, index) {
              final s = services[index];
              return ListTile(
                title: Text(s.name),
                subtitle: Text('${s.basePrice.toStringAsFixed(0)}đ / ${s.unit}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BookingCreateScreen(service: s)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
