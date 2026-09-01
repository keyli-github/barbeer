class ApiConstants {
  ApiConstants._();
  static const String localBaseUrl = 'http://127.0.0.1:3001/api';

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIGURACIÓN DE URL
  //
  // OPCIÓN A — USB (más confiable, funciona siempre):
  //   1. Conecta el teléfono por USB con depuración activada
  //   2. Ejecuta en la terminal del PC:  adb reverse tcp:3001 tcp:3001
  //   3. Usa esta URL:
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: localBaseUrl,
  );
  //
  // OPCIÓN B — WiFi (ambos en la misma red):
  //   Cambia por la IP local de tu PC (ejecuta ipconfig en Windows):
  //   static const String baseUrl = 'http://192.168.X.X:3001/api';
  //
  // OPCIÓN C — Emulador Android:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001/api
  //
  // OPCIÓN D — Servidor compartido (producción/Tailscale):
  //   flutter run --dart-define=API_BASE_URL=https://hia-server.tail99b0ec.ts.net/backend-bar/api
  // ─────────────────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String changePassword = '/auth/cambiar-password';
  static const String profile = '/auth/perfil';
  static const String sessions = '/auth/sesiones';
  static String revokeSession(String id) => '/auth/sesiones/$id';

  // ── Users ────────────────────────────────────────────────────────────────
  static const String users = '/usuarios';
  static String user(String id) => '/usuarios/$id';
  static String resetUserPassword(String id) =>
      '/usuarios/$id/resetear-password';
  static String userPermissions(String id) => '/usuarios/$id/permisos';
  static String superadminPin(String id) => '/usuarios/$id/superadmin-pin';
  static const String validatePin = '/usuarios/validate-pin';
  static String productStock(String id) => '/productos/$id/stock';

  // ── Roles ────────────────────────────────────────────────────────────────
  static const String roles = '/roles';
  static String role(String id) => '/roles/$id';
  static String rolePermissions(String id) => '/roles/$id/permisos';

  // ── Permissions ──────────────────────────────────────────────────────────
  static const String permissions = '/permisos';
  static const String permissionsGrouped = '/permisos/agrupados';

  // ── Establishments ───────────────────────────────────────────────────────
  static const String establishments = '/establecimientos';
  static String establishment(String id) => '/establecimientos/$id';

  // ── Audit ────────────────────────────────────────────────────────────────
  static const String audit = '/audit';

  // ── Products ─────────────────────────────────────────────────────────────
  static const String products = '/productos';
  static const String productsResumen = '/productos/resumen';
  static String product(String id) => '/productos/$id';

  // ── Categories ───────────────────────────────────────────────────────────
  static const String categories = '/categorias';
  static String category(String id) => '/categorias/$id';

  // ── Inventory ────────────────────────────────────────────────────────────
  static const String inventory = '/inventario';
  static const String inventoryResumen = '/inventario/resumen';
  static String inventoryAdjust(String id) => '/inventario/$id/ajuste';

  // ── Kardex ───────────────────────────────────────────────────────────────
  static const String kardex = '/kardex';
  static const String kardexResumen = '/kardex/resumen';

  // ── Purchases ────────────────────────────────────────────────────────────
  static const String purchases = '/compras';
  static const String purchasesResumen = '/compras/resumen';
  static String purchase(String id) => '/compras/$id';
  static String purchaseStatus(String id) => '/compras/$id/estado';
  static const String providers = '/compras/proveedores';
  static String provider(String id) => '/compras/proveedores/$id';

  // ── Attendance ───────────────────────────────────────────────────────────
  static const String attendance = '/asistencia';
  static const String attendanceResumen = '/asistencia/resumen';
  static const String attendanceQrKiosco = '/asistencia/qr-kiosco';
  static const String attendanceMarcar = '/asistencia/marcar';
  static String attendanceById(String id) => '/asistencia/$id';

  // ── Turnos ────────────────────────────────────────────────────────────────
  static const String turnos = '/turnos';
  static String turnoById(String id) => '/turnos/$id';

  // ── Cash Register (Caja) ─────────────────────────────────────────────────
  static const String cajaActual = '/caja/actual';
  static const String cajaHistorial = '/caja/historial';
  static const String cajaApertura = '/caja/apertura';
  static String cajaById(String id) => '/caja/$id';
  static String cajaMovimientos(String id) => '/caja/$id/movimientos';
  static String cajaPrecuadre(String id) => '/caja/$id/precuadre';
  static String cajaCierre(String id) => '/caja/$id/cierre';

  // ── Ventas (NUEVO - Fase 2B) ────────────────────────────────────────────
  static const String ventas = '/ventas';
  static const String autorizarPrecio = '/ventas/autorizar-precio';
  static const String analizarComprobante = '/ventas/comprobantes/analizar';
  static String comprobanteAnalisis(String id) => '/ventas/comprobantes/$id';
  static const String misVentas = '/ventas/mias';
  static String venta(String id) => '/ventas/$id';
  static String anularVenta(String id) => '/ventas/$id/anular';
  static String conciliarVenta(String id) => '/ventas/$id/conciliacion';

  static const String recargoEstado = '/recargo-control/estado';
  static const String recargoConfiguracion = '/recargo-control/configuracion';
  static const String recargoCambiar = '/recargo-control/cambiar';

  static const String accounts = '/cuentas';
  static const String accountSelector = '/cuentas/selector';
  static String account(String id) => '/cuentas/$id';
  static String accountPayments(String id) => '/cuentas/$id/pagos';

  // ── Etiquetas (billeteras digitales) ─────────────────────────────────────
  static const String etiquetas = '/etiquetas';
  static String etiqueta(String id) => '/etiquetas/$id';
  static String etiquetaEstado(String id) => '/etiquetas/$id/estado';

  // ── Reports ──────────────────────────────────────────────────────────────
  static String reportExport(String tipo) => '/reportes/$tipo/exportar';
  static String reportCajaExport(String cajaId) =>
      '/reportes/cajas/$cajaId/ventas/exportar';
  static const String reportEmailConfig = '/reportes/email/configuration';
  static const String reportEmailTest = '/reportes/email/test';

  // ── Backups ───────────────────────────────────────────────────────────────
  static const String backupSchedule = '/backups/schedule';
  static const String backupRuns = '/backups/runs';
  static String backupArtifact(String runId, String format) =>
      '/backups/runs/$runId/artifacts/$format';

  // ── Uploads ──────────────────────────────────────────────────────────────
  static const String uploads = '/uploads';

  // ── Health ───────────────────────────────────────────────────────────────
  static const String health = '/health';
}
