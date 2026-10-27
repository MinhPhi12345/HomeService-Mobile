import 'package:flutter_test/flutter_test.dart';
import 'package:home_service_mobile/core/config.dart';
import 'package:home_service_mobile/core/format.dart';
import 'package:home_service_mobile/core/labels.dart';
import 'package:home_service_mobile/core/models.dart';
import 'package:home_service_mobile/core/validators.dart';

void main() {
  group('Model JSON từ Backend', () {
    test('ServiceCategory đọc giá dạng số nguyên', () {
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
      expect(category.basePrice, 150000);
      expect(category.unit, 'giờ');
    });

    test('Booking đọc đủ cờ và đổi giờ UTC sang giờ máy', () {
      final booking = Booking.fromJson({
        'id': 12,
        'serviceCategoryId': 1,
        'serviceCategoryName': 'Giặt ủi',
        'customerId': 3,
        'customerName': 'Minh',
        'taskerId': null,
        'taskerName': null,
        'scheduledTime': '2026-10-25T02:00:00Z',
        'address': '12 Nguyễn Huệ, Quận 1',
        'totalPrice': 300000,
        'status': 4,
        'createdAt': '2026-10-24T02:00:00Z',
        'commissionRate': 0.2,
        'paymentMethod': 1,
        'customerPresent': true,
        'paymentStatus': 3,
        'paymentDueAt': null,
        'completedAt': '2026-10-25T04:00:00Z',
        'autoConfirmAt': '2026-10-26T04:00:00Z',
        'checkInPhotoUrl': 'http://localhost:8080/uploads/a.jpg',
        'checkOutPhotoUrl': null,
        'isTaskerNoShow': false,
        'canDispute': true,
        'quantity': 2,
        'latitude': 10.77,
        'longitude': 106.7,
        'cancellationFee': 0,
        'disputeId': null,
        'canReview': true,
      });
      expect(booking.status, BookingStatus.completed);
      expect(booking.scheduledTime.isUtc, isFalse);
      expect(booking.canDispute, isTrue);
      expect(booking.taskerEarning, 240000);
      expect(booking.hasLocation, isTrue);
    });

    test('NotificationPage đọc unreadCount', () {
      final page = NotificationPage.fromJson({
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
      expect(page.items.single.title, 'Đơn hàng mới');
      expect(page.unreadCount, 1);
      expect(page.items.single.markRead().isRead, isTrue);
    });

    test('TaskerOffer tính thu nhập sau chiết khấu', () {
      final offer = TaskerOffer.fromJson({
        'offerId': 5,
        'bookingId': 12,
        'serviceCategoryName': 'Dọn dẹp nhà',
        'address': '12 Nguyễn Huệ, Quận 1',
        'scheduledTime': '2026-10-25T02:00:00Z',
        'distanceKm': 3.5,
        'totalPrice': 300000,
        'paymentMethod': 0,
        'estimatedCommission': 60000,
        'expiresAt': '2026-10-24T07:30:00Z',
        'status': 0,
        'wave': 1,
        'note': null,
        'quantity': 2,
        'customerRatingAverage': 4.8,
      });
      expect(offer.earning, 240000);
      expect(offer.paymentMethod, PaymentMethod.cash);
    });

    test('Paged và TaskerProfile', () {
      final paged = Paged.fromJson({
        'items': [
          {
            'id': 1,
            'type': 0,
            'amount': 100000,
            'balanceAfter': 100000,
            'bookingId': null,
            'note': null,
            'createdAt': '2026-10-24T06:30:00Z',
          },
        ],
        'page': 1,
        'pageSize': 20,
        'totalCount': 21,
      }, WalletTransaction.fromJson);
      expect(paged.hasMore, isTrue);
      expect(WalletTxType.isIncome(paged.items.single.type), isTrue);

      final profile = TaskerProfile.fromJson({
        'id': 2,
        'userId': 5,
        'idCardNumber': '012345678901',
        'skills': 'Dọn dẹp nhà, Giặt ủi',
        'workingArea': 'Quận 1',
        'verificationStatus': 1,
        'ratingAverage': 0,
        'isAvailable': true,
        'baseAddress': '12 Nguyễn Huệ',
        'baseLatitude': 10.77,
        'baseLongitude': 106.7,
        'serviceRadiusKm': 5,
      });
      expect(profile.isApproved, isTrue);
      expect(profile.skillList, ['Dọn dẹp nhà', 'Giặt ủi']);
    });
  });

  group('Định dạng và kiểm tra dữ liệu', () {
    test('Tiền hiển thị theo SRS 8.5', () {
      expect(formatMoney(450000), '450.000 đ');
      expect(formatCountdown(const Duration(minutes: 14, seconds: 5)), '14:05');
      expect(formatKm(0.35), '350 m');
    });

    test('Validators khớp quy tắc Backend', () {
      expect(Validators.password('abc12345'), isNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.optionalPhone(''), isNull);
      expect(Validators.optionalPhone('0901234567'), isNull);
      expect(Validators.optionalPhone('901234567'), isNotNull);
      expect(Validators.idCard('012345678901'), isNull);
      expect(Validators.email('a@b.vn'), isNull);
    });

    test('Ảnh localhost được đổi sang host của API', () {
      final url = AppConfig.mediaUrl('http://localhost:8080/uploads/a.jpg');
      expect(url, isNotNull);
      expect(Uri.parse(url!).path, '/uploads/a.jpg');
      expect(AppConfig.mediaUrl(null), isNull);
    });

    test('Ảnh dạng tương đối /uploads/… được ghép địa chỉ Backend', () {
      final url = AppConfig.mediaUrl('/uploads/202610/b.png');
      expect(url, '${AppConfig.mediaOrigin}/uploads/202610/b.png');
      expect(Uri.parse(url!).hasScheme, isTrue);
      expect(AppConfig.mediaUrl('https://cdn.example.com/x.png'), 'https://cdn.example.com/x.png');
    });

    test('Nhãn trạng thái đơn', () {
      expect(BookingStatus.label(BookingStatus.awaitingPayment), 'Chờ thanh toán');
      expect(BookingStatus.active.contains(BookingStatus.paymentOverdue), isTrue);
      expect(BookingStatus.isLive(BookingStatus.paid), isFalse);
    });
  });
}
