// EP03 + EP04 - US12-US20: đơn đặt dịch vụ & theo dõi
enum BookingStatus { pending, matched, accepted, inProgress, completed, paid, cancelled, rejected }

BookingStatus bookingStatusFromInt(int value) => BookingStatus.values[value];

String bookingStatusLabel(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return 'Chờ ghép nối';
    case BookingStatus.matched:
      return 'Đã ghép nối';
    case BookingStatus.accepted:
      return 'Tasker đã nhận đơn';
    case BookingStatus.inProgress:
      return 'Đang thực hiện';
    case BookingStatus.completed:
      return 'Hoàn thành';
    case BookingStatus.paid:
      return 'Đã thanh toán';
    case BookingStatus.cancelled:
      return 'Đã hủy';
    case BookingStatus.rejected:
      return 'Tasker từ chối';
  }
}

class Booking {
  Booking({
    required this.id,
    required this.serviceCategoryName,
    required this.customerId,
    required this.customerName,
    this.taskerId,
    this.taskerName,
    required this.scheduledTime,
    required this.address,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String serviceCategoryName;
  final int customerId;
  final String customerName;
  final int? taskerId;
  final String? taskerName;
  final DateTime scheduledTime;
  final String address;
  final double totalPrice;
  final BookingStatus status;
  final DateTime createdAt;

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as int,
        serviceCategoryName: json['serviceCategoryName'] as String,
        customerId: json['customerId'] as int,
        customerName: json['customerName'] as String,
        taskerId: json['taskerId'] as int?,
        taskerName: json['taskerName'] as String?,
        scheduledTime: DateTime.parse(json['scheduledTime'] as String),
        address: json['address'] as String,
        totalPrice: (json['totalPrice'] as num).toDouble(),
        status: bookingStatusFromInt(json['status'] as int),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
