/// API Configuration
/// Thay đổi baseUrl tùy theo môi trường:
/// - Android Emulator: http://10.0.2.2:3000
/// - iOS Simulator: http://localhost:3000
/// - Thiết bị thật (cùng Wi-Fi): http://<IP_máy_tính>:3000
/// - Production: https://api.yourdomain.com
class ApiConfig {
  // Render Cloud Deployment
  static const String baseUrl = 'https://onemorecoin.onrender.com';

  // Auth endpoints
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String profile = '$baseUrl/auth/profile';
  static const String changePassword = '$baseUrl/auth/change-password';
  static const String refreshToken = '$baseUrl/auth/refresh';
  static const String logout = '$baseUrl/auth/logout';

  // Data endpoints
  static const String wallets = '$baseUrl/wallets';
  static const String groups = '$baseUrl/groups';
  static const String groupsInit = '$baseUrl/groups/init';
  static const String transactions = '$baseUrl/transactions';
  static const String transactionsSync = '$baseUrl/transactions/sync';
  static const String budgets = '$baseUrl/budgets';
  static const String loans = '$baseUrl/loans';
  static const String reminders = '$baseUrl/reminders';

  // Sync endpoints
  static const String syncUpload = '$baseUrl/sync/upload';
  static const String syncDownload = '$baseUrl/sync/download';

  // Health check
  static const String health = '$baseUrl/health';
}
