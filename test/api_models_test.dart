import 'package:flutter_test/flutter_test.dart';
import 'package:home_service_mobile/data/api_client.dart';

void main() {
  group('API response models', () {
    test('parses service categories returned by the backend', () {
      final category = ServiceCategory.fromJson({
        'id': 7,
        'name': 'Dọn dẹp nhà',
        'description': 'Vệ sinh nhà theo giờ.',
        'basePrice': 150000,
        'unit': 'giờ',
        'iconUrl': null,
        'isActive': true,
      });

      expect(category.id, 7);
      expect(category.name, 'Dọn dẹp nhà');
      expect(category.basePrice, 150000);
      expect(category.unit, 'giờ');
    });

    test('parses booking status and converts schedule to local time', () {
      final booking = Booking.fromJson({
        'id': 12,
        'serviceCategoryName': 'Giặt ủi',
        'scheduledTime': '2026-10-25T02:00:00Z',
        'address': '12 Nguyễn Huệ, Quận 1',
        'totalPrice': 80000,
        'status': 0,
        'taskerName': null,
      });

      expect(booking.id, 12);
      expect(booking.status, 0);
      expect(booking.totalPrice, 80000);
      expect(booking.scheduledTime.isUtc, isFalse);
    });

    test('parses notification page and unread count', () {
      final batch = NotificationBatch.fromJson({
        'items': [
          {
            'id': 3,
            'title': 'Đơn hàng mới',
            'message': 'Đang tìm Tasker cho bạn.',
            'isRead': false,
            'createdAt': '2026-10-24T06:30:00Z',
          },
        ],
        'page': 1,
        'pageSize': 20,
        'totalCount': 1,
        'unreadCount': 1,
      });

      expect(batch.items, hasLength(1));
      expect(batch.items.single.title, 'Đơn hàng mới');
      expect(batch.unreadCount, 1);
    });

    test('parses Tasker offers returned by the backend', () {
      final offer = TaskerOffer.fromJson({
        'offerId': 5,
        'bookingId': 12,
        'serviceCategoryName': 'Dọn dẹp nhà',
        'address': '12 Nguyễn Huệ, Quận 1',
        'scheduledTime': '2026-10-25T02:00:00Z',
        'distanceKm': 3.5,
        'totalPrice': 300000,
        'paymentMethod': 0,
        'estimatedCommission': 30000,
        'expiresAt': '2026-10-24T07:30:00Z',
        'status': 0,
        'wave': 1,
        'note': null,
        'quantity': 2,
        'customerRatingAverage': 4.8,
      });

      expect(offer.bookingId, 12);
      expect(offer.distanceKm, 3.5);
      expect(offer.totalPrice - offer.estimatedCommission, 270000);
      expect(offer.customerRatingAverage, 4.8);
    });
  });
}
