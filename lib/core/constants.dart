/// Cấu hình chung cho toàn app.
/// Trỏ tới HomeService-Backend (repo riêng, chạy local hoặc qua docker-compose).
class AppConfig {
  // Android emulator dùng 10.0.2.2 để trỏ về localhost của máy host.
  // Đổi thành IP LAN hoặc domain thật khi deploy.
  static const String apiBaseUrl = 'http://localhost:8080/api';
}

/// Khớp với Enums/UserRole.cs ở backend.
enum UserRole { customer, tasker, admin }

UserRole userRoleFromInt(int value) => UserRole.values[value];
