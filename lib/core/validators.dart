/// Quy tắc kiểm tra dữ liệu giống Backend (SRS 6.1) để báo lỗi ngay trên form.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _password = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,50}$');
  static final _phone = RegExp(r'^0\d{9}$');
  static final _idCard = RegExp(r'^\d{12}$');

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 2 || v.length > 100) return 'Họ tên phải từ 2 đến 100 ký tự.';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty || !_email.hasMatch(v)) return 'Email không hợp lệ.';
    return null;
  }

  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Vui lòng nhập mật khẩu.';
    return null;
  }

  static String? password(String? value) {
    if (!_password.hasMatch(value ?? '')) {
      return 'Mật khẩu phải từ 8 ký tự, gồm chữ và số.';
    }
    return null;
  }

  /// Số điện thoại không bắt buộc, nhưng nếu nhập phải đúng dạng 0xxxxxxxxx.
  static String? optionalPhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!_phone.hasMatch(v)) return 'Số điện thoại gồm 10 số, bắt đầu bằng 0.';
    return null;
  }

  static String? idCard(String? value) {
    if (!_idCard.hasMatch(value?.trim() ?? '')) {
      return 'Số CCCD phải gồm 12 chữ số.';
    }
    return null;
  }

  static String? Function(String?) minLength(int min, String message) =>
      (value) => (value?.trim().length ?? 0) < min ? message : null;
}
