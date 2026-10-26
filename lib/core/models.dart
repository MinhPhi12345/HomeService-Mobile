// Model ánh xạ JSON trả về từ HomeService-Backend (SRS mục 9).
// Tiền/toạ độ có thể về dạng int (450000) nên luôn đọc qua `num`.

typedef Json = Map<String, dynamic>;

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _in(dynamic v) => (v as num?)?.toInt();
String _s(dynamic v) => v as String? ?? '';
String? _sn(dynamic v) {
  final s = v as String?;
  return (s == null || s.isEmpty) ? null : s;
}

bool _b(dynamic v) => v as bool? ?? false;
DateTime _dt(dynamic v) =>
    v == null ? DateTime.now() : DateTime.parse(v as String).toLocal();
DateTime? _dtn(dynamic v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();
List<String> _strings(dynamic v) =>
    (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
List<T> _list<T>(dynamic v, T Function(Json) parse) =>
    (v as List<dynamic>? ?? const []).map((e) => parse(e as Json)).toList();

class UserSession {
  const UserSession({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final int userId;
  final String fullName;
  final String email;
  final int role;

  bool get isCustomer => role == 0;
  bool get isTasker => role == 1;

  UserSession copyWith({String? fullName}) => UserSession(
    userId: userId,
    fullName: fullName ?? this.fullName,
    email: email,
    role: role,
  );
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.unit,
    this.iconUrl,
  });

  final int id;
  final String name;
  final String? description;
  final double basePrice;
  final String unit;
  final String? iconUrl;

  factory ServiceCategory.fromJson(Json json) => ServiceCategory(
    id: _i(json['id']),
    name: _s(json['name']),
    description: _sn(json['description']),
    basePrice: _d(json['basePrice']),
    unit: _s(json['unit']),
    iconUrl: _sn(json['iconUrl']),
  );
}

class Booking {
  const Booking({
    required this.id,
    required this.serviceCategoryId,
    required this.serviceCategoryName,
    required this.customerId,
    required this.customerName,
    required this.taskerId,
    required this.taskerName,
    required this.scheduledTime,
    required this.address,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.commissionRate,
    required this.paymentMethod,
    required this.customerPresent,
    required this.paymentStatus,
    required this.paymentDueAt,
    required this.completedAt,
    required this.autoConfirmAt,
    required this.checkInPhotoUrl,
    required this.checkOutPhotoUrl,
    required this.isTaskerNoShow,
    required this.canDispute,
    required this.canReview,
    required this.note,
    required this.quantity,
    required this.latitude,
    required this.longitude,
    required this.matchRound,
    required this.currentWave,
    required this.cancellationFee,
    required this.disputeId,
    required this.customerPhone,
    required this.taskerPhone,
    required this.contactPhone,
  });

  final int id;
  final int serviceCategoryId;
  final String serviceCategoryName;
  final int customerId;
  final String customerName;
  final int? taskerId;
  final String? taskerName;
  final DateTime scheduledTime;
  final String address;
  final double totalPrice;
  final int status;
  final DateTime createdAt;
  final double commissionRate;
  final int paymentMethod;
  final bool customerPresent;
  final int? paymentStatus;
  final DateTime? paymentDueAt;
  final DateTime? completedAt;
  final DateTime? autoConfirmAt;
  final String? checkInPhotoUrl;
  final String? checkOutPhotoUrl;
  final bool isTaskerNoShow;
  final bool canDispute;
  final bool canReview;
  final String? note;
  final int quantity;
  final double? latitude;
  final double? longitude;
  final int matchRound;
  final int currentWave;
  final double cancellationFee;
  final int? disputeId;
  final String? customerPhone;
  final String? taskerPhone;

  /// SĐT liên hệ khách nhập khi đặt đơn (khách luôn thấy; Tasker thấy khi đơn 2/3).
  final String? contactPhone;

  bool get isCash => paymentMethod == 0;
  bool get hasLocation => latitude != null && longitude != null;

  /// Thu nhập dự kiến của Tasker sau chiết khấu.
  double get taskerEarning => totalPrice * (1 - commissionRate);

  factory Booking.fromJson(Json json) => Booking(
    id: _i(json['id']),
    serviceCategoryId: _i(json['serviceCategoryId']),
    serviceCategoryName: _s(json['serviceCategoryName']),
    customerId: _i(json['customerId']),
    customerName: _s(json['customerName']),
    taskerId: _in(json['taskerId']),
    taskerName: _sn(json['taskerName']),
    scheduledTime: _dt(json['scheduledTime']),
    address: _s(json['address']),
    totalPrice: _d(json['totalPrice']),
    status: _i(json['status']),
    createdAt: _dt(json['createdAt']),
    commissionRate: _d(json['commissionRate']),
    paymentMethod: _i(json['paymentMethod']),
    customerPresent: _b(json['customerPresent']),
    paymentStatus: _in(json['paymentStatus']),
    paymentDueAt: _dtn(json['paymentDueAt']),
    completedAt: _dtn(json['completedAt']),
    autoConfirmAt: _dtn(json['autoConfirmAt']),
    checkInPhotoUrl: _sn(json['checkInPhotoUrl']),
    checkOutPhotoUrl: _sn(json['checkOutPhotoUrl']),
    isTaskerNoShow: _b(json['isTaskerNoShow']),
    canDispute: _b(json['canDispute']),
    canReview: _b(json['canReview']),
    note: _sn(json['note']),
    quantity: _in(json['quantity']) ?? 1,
    latitude: _dn(json['latitude']),
    longitude: _dn(json['longitude']),
    matchRound: _i(json['matchRound']),
    currentWave: _i(json['currentWave']),
    cancellationFee: _d(json['cancellationFee']),
    disputeId: _in(json['disputeId']),
    customerPhone: _sn(json['customerPhone']),
    taskerPhone: _sn(json['taskerPhone']),
    contactPhone: _sn(json['contactPhone']),
  );
}

class TaskerOffer {
  const TaskerOffer({
    required this.offerId,
    required this.bookingId,
    required this.serviceCategoryName,
    required this.address,
    required this.scheduledTime,
    required this.distanceKm,
    required this.totalPrice,
    required this.paymentMethod,
    required this.estimatedCommission,
    required this.expiresAt,
    required this.status,
    required this.wave,
    required this.quantity,
    this.note,
    this.customerRatingAverage,
  });

  final int offerId;
  final int bookingId;
  final String serviceCategoryName;
  final String address;
  final DateTime scheduledTime;
  final double distanceKm;
  final double totalPrice;
  final int paymentMethod;
  final double estimatedCommission;
  final DateTime expiresAt;
  final int status;
  final int wave;
  final int quantity;
  final String? note;
  final double? customerRatingAverage;

  double get earning => totalPrice - estimatedCommission;

  factory TaskerOffer.fromJson(Json json) => TaskerOffer(
    offerId: _i(json['offerId']),
    bookingId: _i(json['bookingId']),
    serviceCategoryName: _s(json['serviceCategoryName']),
    address: _s(json['address']),
    scheduledTime: _dt(json['scheduledTime']),
    distanceKm: _d(json['distanceKm']),
    totalPrice: _d(json['totalPrice']),
    paymentMethod: _i(json['paymentMethod']),
    estimatedCommission: _d(json['estimatedCommission']),
    expiresAt: _dt(json['expiresAt']),
    status: _i(json['status']),
    wave: _i(json['wave']),
    quantity: _in(json['quantity']) ?? 1,
    note: _sn(json['note']),
    customerRatingAverage: _dn(json['customerRatingAverage']),
  );
}

class CancellationFee {
  const CancellationFee({
    required this.fee,
    required this.refundAmount,
    required this.reason,
  });

  final double fee;
  final double refundAmount;
  final String reason;

  factory CancellationFee.fromJson(Json json) => CancellationFee(
    fee: _d(json['cancellationFee']),
    refundAmount: _d(json['refundAmount']),
    reason: _s(json['reason']),
  );
}

class TaskerLocation {
  const TaskerLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.distanceKm,
  });

  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final double? distanceKm;

  factory TaskerLocation.fromJson(Json json) => TaskerLocation(
    latitude: _d(json['latitude']),
    longitude: _d(json['longitude']),
    updatedAt: _dt(json['updatedAt']),
    distanceKm: _dn(json['distanceKm']),
  );
}

class Dispute {
  const Dispute({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.paymentMethod,
    required this.customerName,
    required this.taskerName,
    required this.reason,
    required this.description,
    required this.evidenceUrls,
    required this.taskerResponse,
    required this.taskerEvidenceUrls,
    required this.status,
    required this.resolution,
    required this.refundAmount,
    required this.adminNote,
    required this.createdAt,
    required this.resolvedAt,
    required this.redoScheduledTime,
    required this.taskerResponseDueAt,
  });

  final int id;
  final int bookingId;
  final double amount;
  final int paymentMethod;
  final String customerName;
  final String taskerName;
  final int reason;
  final String description;
  final List<String> evidenceUrls;
  final String? taskerResponse;
  final List<String> taskerEvidenceUrls;
  final int status;
  final int? resolution;
  final double? refundAmount;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime? redoScheduledTime;
  final DateTime taskerResponseDueAt;

  bool get isOpen => status == 0;
  bool get taskerCanRespond =>
      isOpen &&
      taskerResponse == null &&
      DateTime.now().isBefore(taskerResponseDueAt);

  factory Dispute.fromJson(Json json) => Dispute(
    id: _i(json['id']),
    bookingId: _i(json['bookingId']),
    amount: _d(json['amount']),
    paymentMethod: _i(json['paymentMethod']),
    customerName: _s(json['customerName']),
    taskerName: _s(json['taskerName']),
    reason: _i(json['reason']),
    description: _s(json['description']),
    evidenceUrls: _strings(json['evidenceUrls']),
    taskerResponse: _sn(json['taskerResponse']),
    taskerEvidenceUrls: _strings(json['taskerEvidenceUrls']),
    status: _i(json['status']),
    resolution: _in(json['resolution']),
    refundAmount: _dn(json['refundAmount']),
    adminNote: _sn(json['adminNote']),
    createdAt: _dt(json['createdAt']),
    resolvedAt: _dtn(json['resolvedAt']),
    redoScheduledTime: _dtn(json['redoScheduledTime']),
    taskerResponseDueAt: _dt(json['taskerResponseDueAt']),
  );
}

class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.reviewerName,
    required this.revieweeId,
    required this.revieweeName,
    required this.rating,
    required this.comment,
    required this.isFlagged,
    required this.createdAt,
  });

  final int id;
  final int bookingId;
  final int reviewerId;
  final String reviewerName;
  final int revieweeId;
  final String revieweeName;
  final int rating;
  final String? comment;
  final bool isFlagged;
  final DateTime createdAt;

  factory Review.fromJson(Json json) => Review(
    id: _i(json['id']),
    bookingId: _i(json['bookingId']),
    reviewerId: _i(json['reviewerId']),
    reviewerName: _s(json['reviewerName']),
    revieweeId: _i(json['revieweeId']),
    revieweeName: _s(json['revieweeName']),
    rating: _i(json['rating']),
    comment: _sn(json['comment']),
    isFlagged: _b(json['isFlagged']),
    createdAt: _dt(json['createdAt']),
  );
}

class ReviewSummary {
  const ReviewSummary({
    required this.reviewCount,
    required this.ratingAverage,
    required this.reviews,
  });

  final int reviewCount;
  final double? ratingAverage;
  final List<Review> reviews;

  factory ReviewSummary.fromJson(Json json) => ReviewSummary(
    reviewCount: _i(json['reviewCount']),
    ratingAverage: _dn(json['ratingAverage']),
    reviews: _list(json['reviews'], Review.fromJson),
  );
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem markRead() => NotificationItem(
    id: id,
    title: title,
    message: message,
    isRead: true,
    createdAt: createdAt,
  );

  factory NotificationItem.fromJson(Json json) => NotificationItem(
    id: _i(json['id']),
    title: _s(json['title']),
    message: _s(json['message']),
    isRead: _b(json['isRead']),
    createdAt: _dt(json['createdAt']),
  );
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.totalCount,
    required this.unreadCount,
  });

  final List<NotificationItem> items;
  final int page;
  final int totalCount;
  final int unreadCount;

  factory NotificationPage.fromJson(Json json) => NotificationPage(
    items: _list(json['items'], NotificationItem.fromJson),
    page: _i(json['page']),
    totalCount: _i(json['totalCount']),
    unreadCount: _i(json['unreadCount']),
  );
}

class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;

  bool get hasMore => page * pageSize < totalCount;

  factory Paged.fromJson(Json json, T Function(Json) parse) => Paged(
    items: _list(json['items'], parse),
    page: _i(json['page']),
    pageSize: _i(json['pageSize']),
    totalCount: _i(json['totalCount']),
  );
}

class PaymentItem {
  const PaymentItem({
    required this.id,
    required this.bookingId,
    required this.serviceCategoryName,
    required this.amount,
    required this.commissionAmount,
    required this.method,
    required this.status,
    required this.paidAt,
    required this.createdAt,
    required this.taskerAmount,
    required this.refundedAmount,
  });

  final int id;
  final int bookingId;
  final String serviceCategoryName;
  final double amount;
  final double commissionAmount;
  final int method;
  final int status;
  final DateTime? paidAt;
  final DateTime createdAt;
  final double taskerAmount;
  final double refundedAmount;

  factory PaymentItem.fromJson(Json json) => PaymentItem(
    id: _i(json['id']),
    bookingId: _i(json['bookingId']),
    serviceCategoryName: _s(json['serviceCategoryName']),
    amount: _d(json['amount']),
    commissionAmount: _d(json['commissionAmount']),
    method: _i(json['method']),
    status: _i(json['status']),
    paidAt: _dtn(json['paidAt']),
    createdAt: _dt(json['createdAt']),
    taskerAmount: _d(json['taskerAmount']),
    refundedAmount: _d(json['refundedAmount']),
  );
}

class Wallet {
  const Wallet({
    required this.balance,
    required this.reservedAmount,
    required this.availableBalance,
  });

  final double balance;
  final double reservedAmount;
  final double availableBalance;

  factory Wallet.fromJson(Json json) => Wallet(
    balance: _d(json['balance']),
    reservedAmount: _d(json['reservedAmount']),
    availableBalance: _d(json['availableBalance']),
  );
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.bookingId,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final int type;
  final double amount;
  final double balanceAfter;
  final int? bookingId;
  final String? note;
  final DateTime createdAt;

  factory WalletTransaction.fromJson(Json json) => WalletTransaction(
    id: _i(json['id']),
    type: _i(json['type']),
    amount: _d(json['amount']),
    balanceAfter: _d(json['balanceAfter']),
    bookingId: _in(json['bookingId']),
    note: _sn(json['note']),
    createdAt: _dt(json['createdAt']),
  );
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.avatarUrl,
    required this.role,
    required this.outstandingAmount,
    required this.isCashBlocked,
    required this.createdAt,
  });

  final int id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? address;
  final String? avatarUrl;
  final int role;
  final double outstandingAmount;
  final bool isCashBlocked;
  final DateTime createdAt;

  factory Profile.fromJson(Json json) => Profile(
    id: _i(json['id']),
    fullName: _s(json['fullName']),
    email: _s(json['email']),
    phoneNumber: _sn(json['phoneNumber']),
    address: _sn(json['address']),
    avatarUrl: _sn(json['avatarUrl']),
    role: _i(json['role']),
    outstandingAmount: _d(json['outstandingAmount']),
    isCashBlocked: _b(json['isCashBlocked']),
    createdAt: _dt(json['createdAt']),
  );
}

class TaskerProfile {
  const TaskerProfile({
    required this.id,
    required this.idCardNumber,
    required this.idCardImageUrl,
    required this.skills,
    required this.workingArea,
    required this.verificationStatus,
    required this.ratingAverage,
    required this.isAvailable,
    required this.baseAddress,
    required this.baseLatitude,
    required this.baseLongitude,
    required this.serviceRadiusKm,
  });

  final int id;
  final String idCardNumber;
  final String? idCardImageUrl;
  final String? skills;
  final String? workingArea;
  final int verificationStatus;
  final double ratingAverage;
  final bool isAvailable;
  final String baseAddress;
  final double baseLatitude;
  final double baseLongitude;
  final int serviceRadiusKm;

  bool get isApproved => verificationStatus == 1;

  List<String> get skillList => (skills ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  factory TaskerProfile.fromJson(Json json) => TaskerProfile(
    id: _i(json['id']),
    idCardNumber: _s(json['idCardNumber']),
    idCardImageUrl: _sn(json['idCardImageUrl']),
    skills: _sn(json['skills']),
    workingArea: _sn(json['workingArea']),
    verificationStatus: _i(json['verificationStatus']),
    ratingAverage: _d(json['ratingAverage']),
    isAvailable: _b(json['isAvailable']),
    baseAddress: _s(json['baseAddress']),
    baseLatitude: _d(json['baseLatitude']),
    baseLongitude: _d(json['baseLongitude']),
    serviceRadiusKm: _in(json['serviceRadiusKm']) ?? 5,
  );
}
