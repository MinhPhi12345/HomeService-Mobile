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
    this.discountAmount = 0,
    this.voucherCode,
    this.taskerBadges = const [],
    this.searchExhaustedAt,
    this.nextSearchAt,
    this.searchStopsAt,
    this.searchNowAvailableAt,
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

  /// FR-32 – mã giảm giá: totalPrice là giá gốc, khách trả [payable].
  final double discountAmount;
  final String? voucherCode;

  /// FR-31 – huy hiệu Tasker xuất sắc tháng của Tasker phụ trách (chỉ có ở chi tiết đơn).
  final List<String> taskerBadges;

  /// BR-M05/M07 – đơn đã quét hết mà chưa ai nhận, hệ thống vẫn đang tìm tiếp.
  final DateTime? searchExhaustedAt;
  final DateTime? nextSearchAt;
  final DateTime? searchStopsAt;
  final DateTime? searchNowAvailableAt;

  bool get stillSearching => searchExhaustedAt != null;

  /// Số phút còn phải chờ để bấm "Tìm lại ngay" (0 = bấm được).
  int searchNowWaitMinutes([DateTime? now]) {
    final at = searchNowAvailableAt;
    if (at == null) return 0;
    final ms = at.difference(now ?? DateTime.now()).inMilliseconds;
    return ms > 0 ? (ms / 60000).ceil() : 0;
  }

  double get payable => totalPrice - discountAmount;
  bool get hasDiscount => discountAmount > 0;

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
    discountAmount: _d(json['discountAmount']),
    voucherCode: _sn(json['voucherCode']),
    taskerBadges: (json['taskerBadges'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    searchExhaustedAt: _dtn(json['searchExhaustedAt']),
    nextSearchAt: _dtn(json['nextSearchAt']),
    searchStopsAt: _dtn(json['searchStopsAt']),
    searchNowAvailableAt: _dtn(json['searchNowAvailableAt']),
  );
}

/// FR-31 – huy hiệu Tasker xuất sắc tháng.
class AwardBadge {
  const AwardBadge({required this.year, required this.month, required this.rank, required this.label});

  final int year;
  final int month;
  final int rank;
  final String label;

  factory AwardBadge.fromJson(Json json) => AwardBadge(
    year: _i(json['year']),
    month: _i(json['month']),
    rank: _i(json['rank']),
    label: _s(json['label']),
  );
}

/// FR-32, FR-33 – ưu đãi khách dùng được (quà riêng hoặc chương trình công khai).
class MyVoucher {
  const MyVoucher({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.maxDiscount,
    required this.minOrderValue,
    required this.serviceNames,
    required this.endsAt,
    required this.source,
    required this.isGift,
    required this.remainingUses,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final int discountType; // 0 %, 1 số tiền
  final double discountValue;
  final double? maxDiscount;
  final double minOrderValue;
  final List<String> serviceNames;
  final DateTime endsAt;
  final int source; // 0 khuyến mãi, 1 chào mừng, 2 thân thiết, 3 xin lỗi
  final bool isGift;
  final int remainingUses;

  bool get isPercent => discountType == 0;

  /// Tiền giảm ước tính (giống Backend) – dùng gợi ý mã tốt nhất.
  double estimate(double order, {double minPayable = 10000}) {
    if (order < minOrderValue) return 0;
    var d = isPercent ? (order * discountValue / 100).roundToDouble() : discountValue;
    if (isPercent && maxDiscount != null && maxDiscount! > 0 && d > maxDiscount!) d = maxDiscount!;
    final cap = order - minPayable;
    if (d > cap) d = cap;
    return d < 0 ? 0 : d;
  }

  factory MyVoucher.fromJson(Json json) => MyVoucher(
    id: _i(json['id']),
    code: _s(json['code']),
    name: _s(json['name']),
    description: _sn(json['description']),
    discountType: _i(json['discountType']),
    discountValue: _d(json['discountValue']),
    maxDiscount: _dn(json['maxDiscount']),
    minOrderValue: _d(json['minOrderValue']),
    serviceNames: (json['serviceNames'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    endsAt: _dt(json['endsAt']),
    source: _i(json['source']),
    isGift: _b(json['isGift']),
    remainingUses: _i(json['remainingUses']),
  );
}

/// FR-32 – kết quả kiểm tra mã giảm giá cho đơn sắp đặt.
class VoucherCheck {
  const VoucherCheck({
    required this.code,
    required this.name,
    required this.originalPrice,
    required this.discountAmount,
    required this.payableAmount,
    required this.message,
  });

  final String code;
  final String name;
  final double originalPrice;
  final double discountAmount;
  final double payableAmount;
  final String message;

  factory VoucherCheck.fromJson(Json json) => VoucherCheck(
    code: _s(json['code']),
    name: _s(json['name']),
    originalPrice: _d(json['originalPrice']),
    discountAmount: _d(json['discountAmount']),
    payableAmount: _d(json['payableAmount']),
    message: _s(json['message']),
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
    this.customerId = 0,
    this.customerReviewCount = 0,
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

  /// US26 – để mở hồ sơ khách (kèm đánh giá) từ lời mời.
  final int customerId;
  final int customerReviewCount;

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
    customerId: _i(json['customerId']),
    customerReviewCount: _i(json['customerReviewCount']),
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
    this.reportReason,
    this.moderationNote,
    this.moderatedAt,
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

  /// US27 – lý do người trong đơn báo cáo (chỉ Backend trả cho người trong đơn).
  final String? reportReason;

  /// US27 – ghi chú của quản trị viên khi giữ lại đánh giá bị báo cáo.
  final String? moderationNote;
  final DateTime? moderatedAt;

  /// Quản trị viên đã xem xét và giữ lại → không báo cáo lại được.
  bool get isModerated => moderatedAt != null;

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
    reportReason: _sn(json['reportReason']),
    moderationNote: _sn(json['moderationNote']),
    moderatedAt: _dtn(json['moderatedAt']),
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

/// US26 – GET /api/public-profiles/{userId}: hồ sơ của bên còn lại trong đơn kèm
/// các đánh giá đã nhận (người viết đánh giá chỉ hiện tên gọi).
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.memberSince,
    required this.completedBookings,
    required this.reviewCount,
    required this.reviews,
    this.avatarUrl,
    this.ratingAverage,
    this.isVerified,
    this.workingArea,
    this.skills,
    this.badges = const [],
  });

  final int userId;
  final String displayName;
  final int role;
  final String? avatarUrl;
  final DateTime memberSince;
  final int completedBookings;
  final int reviewCount;
  final double? ratingAverage;
  final bool? isVerified;
  final String? workingArea;
  final String? skills;
  final List<Review> reviews;

  /// FR-31 – huy hiệu Tasker xuất sắc tháng.
  final List<AwardBadge> badges;

  bool get isTasker => role == 1;

  factory PublicProfile.fromJson(Json json) => PublicProfile(
    userId: _i(json['userId']),
    displayName: _s(json['displayName']),
    role: _i(json['role']),
    avatarUrl: _sn(json['avatarUrl']),
    memberSince: _dt(json['memberSince']),
    completedBookings: _i(json['completedBookings']),
    reviewCount: _i(json['reviewCount']),
    ratingAverage: _dn(json['ratingAverage']),
    isVerified: json['isVerified'] as bool?,
    workingArea: _sn(json['workingArea']),
    skills: _sn(json['skills']),
    reviews: _list(json['reviews'], Review.fromJson),
    badges: _list(json['badges'], AwardBadge.fromJson),
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
    this.minDeposit = 0,
    this.meetsDeposit = true,
  });

  final double balance;
  final double reservedAmount;
  final double availableBalance;

  /// Mức ký quỹ tối thiểu (số dư khả dụng) để Tasker bật nhận đơn / nhận đơn.
  final double minDeposit;
  final bool meetsDeposit;

  /// Số tiền còn thiếu để đạt mức ký quỹ.
  double get depositShortfall =>
      meetsDeposit ? 0 : (minDeposit - availableBalance).clamp(0, double.infinity).toDouble();

  factory Wallet.fromJson(Json json) => Wallet(
    balance: _d(json['balance']),
    reservedAmount: _d(json['reservedAmount']),
    availableBalance: _d(json['availableBalance']),
    minDeposit: _d(json['minDeposit']),
    meetsDeposit: json['meetsDeposit'] is bool ? json['meetsDeposit'] as bool : true,
  );
}

/// Kết quả gửi mã OTP qua email.
class OtpSent {
  const OtpSent({
    required this.maskedEmail,
    required this.resendAfterSeconds,
    this.email,
    this.expiresAt,
  });

  /// Email đã che bớt, vd. mi*****@demo.vn
  final String maskedEmail;
  final int resendAfterSeconds;

  /// Email đầy đủ (khi đăng ký / quên mật khẩu) để gửi kèm lúc nhập mã.
  final String? email;
  final DateTime? expiresAt;

  factory OtpSent.fromJson(Json json, {String? email}) => OtpSent(
    maskedEmail: _sn(json['maskedEmail']) ?? email ?? '',
    resendAfterSeconds: _i(json['resendAfterSeconds']),
    email: _sn(json['email']) ?? email,
    expiresAt: _dtn(json['expiresAt']),
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
    this.commissionRate,
    this.preferentialCommissionRate,
    this.preferentialUntil,
    this.badges = const [],
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

  /// FR-31 – tỷ lệ chiết khấu áp cho đơn nhận lúc này; mức ưu đãi Tasker xuất sắc tháng (nếu có).
  final double? commissionRate;
  final double? preferentialCommissionRate;
  final DateTime? preferentialUntil;
  final List<AwardBadge> badges;

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
    commissionRate: _dn(json['commissionRate']),
    preferentialCommissionRate: _dn(json['preferentialCommissionRate']),
    preferentialUntil: _dtn(json['preferentialUntil']),
    badges: _list(json['badges'], AwardBadge.fromJson),
  );
}
