class ApiConstants {
  ApiConstants._();
  // ─────────────────────────────────────────────────────────────────────────
  // CONFIGURACIÓN DE URL
  //
  // OPCIÓN A — USB (más confiable, funciona siempre):
  //   1. Conecta el teléfono por USB con depuración activada
  //   2. Ejecuta en la terminal del PC:  adb reverse tcp:3001 tcp:3001
  //   3. Usa esta URL:
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3001/api',
  );
  //
  // OPCIÓN B — WiFi (ambos en la misma red):
  //   Cambia por la IP local de tu PC (ejecuta ipconfig en Windows):
  //   static const String baseUrl = 'http://192.168.X.X:3001/api';
  //
  // OPCIÓN C — Emulador Android:
  //   static const String baseUrl = 'http://10.0.2.2:3001/api';
  // ─────────────────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Auth
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String changePassword = '/auth/cambiar-password';
  static const String profile = '/auth/perfil';
  static const String sessions = '/auth/sesiones';
  static String revokeSession(String id) => '/auth/sesiones/$id';

  // Users
  static const String users = '/usuarios';
  static String user(String id) => '/usuarios/$id';
  static String resetUserPassword(String id) =>
      '/usuarios/$id/resetear-password';

  // Roles
  static const String roles = '/roles';
  static String role(String id) => '/roles/$id';
  static String rolePermissions(String id) => '/roles/$id/permisos';

  // Permissions
  static const String permissions = '/permisos';
  static const String permissionsGrouped = '/permisos/agrupados';

  // Establishments
  static const String establishments = '/establecimientos';
  static String establishment(String id) => '/establecimientos/$id';

  // Audit
  static const String audit = '/audit';

  // Health
  static const String health = '/health';
}
