import '../../core/api_client.dart';
import '../../models/service_category.dart';
import '../../models/booking.dart';

// US10 - Xem/Tìm kiếm dịch vụ
class ServiceRepository {
  Future<List<ServiceCategory>> getServices({String? keyword}) async {
    final json = await ApiClient.instance.get(
      '/servicecategories',
      query: keyword != null && keyword.isNotEmpty ? {'keyword': keyword} : null,
      auth: false,
    );
    return (json as List).map((e) => ServiceCategory.fromJson(e as Map<String, dynamic>)).toList();
  }
}

// US12/US13/US14/US15 - Đặt dịch vụ, hủy đơn, lịch sử
class BookingRepository {
  Future<Booking> createBooking({
    required int serviceCategoryId,
    required DateTime scheduledTime,
    required String address,
    String? note,
  }) async {
    final json = await ApiClient.instance.post('/bookings', body: {
      'serviceCategoryId': serviceCategoryId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'address': address,
      'note': note,
    });
    return Booking.fromJson(json as Map<String, dynamic>);
  }

  Future<List<Booking>> getMyBookings() async {
    final json = await ApiClient.instance.get('/bookings/my');
    return (json as List).map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cancelBooking(int id) => ApiClient.instance.post('/bookings/$id/cancel');

  // US17 - Tasker nhận / từ chối đơn
  Future<void> acceptBooking(int id) => ApiClient.instance.post('/bookings/$id/accept');
  Future<void> rejectBooking(int id) => ApiClient.instance.post('/bookings/$id/reject');

  // US18 - Tasker cập nhật trạng thái
  Future<void> updateStatus(int id, BookingStatus status) =>
      ApiClient.instance.put('/bookings/$id/status', body: {'status': status.index});
}
