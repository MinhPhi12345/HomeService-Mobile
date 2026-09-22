import '../core/constants.dart';

class AuthResult {
  AuthResult({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.accessToken,
    required this.expiresAt,
  });

  final int userId;
  final String fullName;
  final String email;
  final UserRole role;
  final String accessToken;
  final DateTime expiresAt;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        userId: json['userId'] as int,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        role: userRoleFromInt(json['role'] as int),
        accessToken: json['accessToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}
