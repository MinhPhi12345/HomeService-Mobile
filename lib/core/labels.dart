import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Giá trị enum gửi/nhận dạng SỐ, khớp 100% với Backend (SRS 7.8).
class BookingStatus {
  BookingStatus._();

  static const pending = 0; // Đang tìm Tasker
  static const matched = 1; // Đã gửi lời mời
  static const accepted = 2; // Tasker đã nhận
  static const inProgress = 3; // Đang thực hiện
  static const completed = 4; // Hoàn thành – chờ xác nhận
  static const paid = 5; // Đã thanh toán
  static const cancelled = 6; // Đã hủy
  static const rejected = 7; // Không dùng
  static const noTaskerFound = 8; // Chưa có Tasker nhận
  static const expired = 9; // Hết hạn
  static const awaitingPayment = 10; // Chờ thanh toán
  static const disputed = 11; // Đang khiếu nại
  static const refunded = 12; // Đã hoàn tiền
  static const paymentOverdue = 13; // Khách chưa thanh toán

  /// Nhóm tab trên màn hình đơn hàng.
  static const active = [
    awaitingPayment,
    pending,
    matched,
    accepted,
    inProgress,
    completed,
    noTaskerFound,
    disputed,
    paymentOverdue,
  ];
  static const done = [paid, refunded];
  static const closed = [cancelled, expired, rejected];

  static String label(int status) => switch (status) {
    pending => 'Đang tìm Tasker',
    matched => 'Đã gửi lời mời',
    accepted => 'Tasker đã nhận',
    inProgress => 'Đang thực hiện',
    completed => 'Chờ xác nhận',
    paid => 'Đã hoàn tất',
    cancelled => 'Đã hủy',
    rejected => 'Đã từ chối',
    noTaskerFound => 'Chưa có Tasker',
    expired => 'Hết hạn',
    awaitingPayment => 'Chờ thanh toán',
    disputed => 'Đang khiếu nại',
    refunded => 'Đã hoàn tiền',
    paymentOverdue => 'Chưa thanh toán',
    _ => 'Không xác định',
  };

  static Color color(int status) => switch (status) {
    pending || matched => AppColors.info,
    accepted || inProgress => AppColors.primary,
    completed => AppColors.accent,
    paid => AppColors.success,
    awaitingPayment || noTaskerFound || disputed || paymentOverdue =>
      AppColors.warning,
    refunded => AppColors.inkSoft,
    _ => AppColors.muted,
  };

  static IconData icon(int status) => switch (status) {
    pending || matched => Icons.radar_rounded,
    accepted => Icons.how_to_reg_rounded,
    inProgress => Icons.cleaning_services_rounded,
    completed => Icons.fact_check_rounded,
    paid => Icons.verified_rounded,
    cancelled || rejected || expired => Icons.block_rounded,
    awaitingPayment => Icons.account_balance_wallet_rounded,
    noTaskerFound => Icons.person_search_rounded,
    disputed => Icons.gavel_rounded,
    refunded => Icons.currency_exchange_rounded,
    paymentOverdue => Icons.money_off_rounded,
    _ => Icons.help_outline_rounded,
  };

  /// Đơn còn đang chạy => nên tự tải lại.
  static bool isLive(int status) => const [
    awaitingPayment,
    pending,
    matched,
    accepted,
    inProgress,
    completed,
    disputed,
  ].contains(status);
}

class PaymentMethod {
  PaymentMethod._();

  static const cash = 0;
  static const eWallet = 1;
  static const card = 2;

  static String label(int method) => switch (method) {
    cash => 'Tiền mặt',
    eWallet => 'Ví điện tử',
    card => 'Thẻ ngân hàng',
    _ => 'Khác',
  };

  static IconData icon(int method) => switch (method) {
    cash => Icons.payments_rounded,
    eWallet => Icons.account_balance_wallet_rounded,
    card => Icons.credit_card_rounded,
    _ => Icons.payment_rounded,
  };
}

class PaymentStatus {
  PaymentStatus._();

  static String label(int? status) => switch (status) {
    0 => 'Chờ thanh toán',
    1 => 'Đã thu tiền mặt',
    2 => 'Thất bại',
    3 => 'Đang tạm giữ',
    4 => 'Đã giải ngân',
    5 => 'Đã hoàn toàn bộ',
    6 => 'Đã hoàn một phần',
    _ => 'Chưa thanh toán',
  };
}

class UserRole {
  UserRole._();

  static const customer = 0;
  static const tasker = 1;
  static const admin = 2;

  static String label(int role) => switch (role) {
    customer => 'Khách hàng',
    tasker => 'Tasker',
    admin => 'Quản trị viên',
    _ => 'Người dùng',
  };
}

class VerificationStatus {
  VerificationStatus._();

  static const pending = 0;
  static const approved = 1;
  static const rejected = 2;

  static String label(int status) => switch (status) {
    pending => 'Đang chờ duyệt',
    approved => 'Đã xác thực',
    rejected => 'Bị từ chối',
    _ => 'Chưa gửi hồ sơ',
  };

  static Color color(int status) => switch (status) {
    pending => AppColors.warning,
    approved => AppColors.success,
    rejected => AppColors.danger,
    _ => AppColors.muted,
  };
}

class DisputeReason {
  DisputeReason._();

  static const values = [0, 1, 2, 3, 4];

  static String label(int reason) => switch (reason) {
    0 => 'Làm không đạt yêu cầu',
    1 => 'Làm chưa xong / thiếu hạng mục',
    2 => 'Làm hư hỏng tài sản',
    3 => 'Thái độ không phù hợp',
    4 => 'Lý do khác',
    _ => 'Khác',
  };
}

class DisputeResolution {
  DisputeResolution._();

  static String label(int? resolution) => switch (resolution) {
    0 => 'Bác khiếu nại – giải ngân đủ cho Tasker',
    1 => 'Hoàn tiền một phần',
    2 => 'Hoàn toàn bộ / hủy khoản nợ',
    3 => 'Làm lại miễn phí',
    _ => 'Đang chờ xử lý',
  };
}

class OfferStatus {
  OfferStatus._();

  static const sent = 0;

  static String label(int status) => switch (status) {
    0 => 'Đang chờ',
    1 => 'Đã nhận',
    2 => 'Đã từ chối',
    3 => 'Hết hạn',
    4 => 'Đã đóng',
    _ => 'Khác',
  };
}

class WalletTxType {
  WalletTxType._();

  static String label(int type) => switch (type) {
    0 => 'Nạp tiền',
    1 => 'Trừ hoa hồng đơn tiền mặt',
    2 => 'Thu nhập đơn online',
    3 => 'Rút tiền',
    4 => 'Nhận phí hủy đơn',
    _ => 'Giao dịch',
  };

  static IconData icon(int type) => switch (type) {
    0 => Icons.add_card_rounded,
    1 => Icons.percent_rounded,
    2 => Icons.trending_up_rounded,
    3 => Icons.account_balance_rounded,
    4 => Icons.receipt_long_rounded,
    _ => Icons.swap_horiz_rounded,
  };

  /// Loại giao dịch làm tăng số dư.
  static bool isIncome(int type) => type == 0 || type == 2 || type == 4;
}
