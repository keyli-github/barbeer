import 'package:intl/intl.dart';

class FormatUtils {
  FormatUtils._();

  static String currency(double amount, {String symbol = 'S/'}) =>
      '$symbol ${NumberFormat('#,##0.00').format(amount)}';

  static String date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  static String dateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} dias';
    return DateFormat('d MMM yyyy').format(date);
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String roleName(String role) {
    switch (role.toUpperCase()) {
      case 'SUPERADMIN': return 'Super Admin';
      case 'ADMIN': return 'Administrador';
      case 'CAJERO': return 'Cajero';
      case 'MOZO': return 'Mozo';
      case 'COCINA': return 'Cocina';
      case 'BARTENDER': return 'Bartender';
      default: return role;
    }
  }

  static String deviceIcon(String? type) {
    switch (type) {
      case 'android': return 'Android';
      case 'ios': return 'iOS';
      case 'web': return 'Web';
      default: return type ?? 'Dispositivo';
    }
  }
}
