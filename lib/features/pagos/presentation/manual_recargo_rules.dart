import '../../../core/errors/app_exception.dart';

class ManualRecargoPeriod {
  const ManualRecargoPeriod({required this.inicio, required this.fin});

  final DateTime inicio;
  final DateTime fin;

  static ManualRecargoPeriod? tryParse(dynamic inicio, dynamic fin) {
    final start = _parseDateOnly(inicio);
    final end = _parseDateOnly(fin);
    if (start == null || end == null || end.isBefore(start)) return null;
    return ManualRecargoPeriod(inicio: start, fin: end);
  }

  String? validateDate(String? value) {
    final date = _parseDateOnly(value);
    if (date == null) return 'Selecciona una fecha válida.';
    if (date.isBefore(inicio) || date.isAfter(fin)) {
      return 'La fecha debe pertenecer al período actual.';
    }
    return null;
  }

  String initialDateKey({DateTime? now}) {
    final limaNow = (now ?? DateTime.now()).toUtc().subtract(
      const Duration(hours: 5),
    );
    final today = DateTime(limaNow.year, limaNow.month, limaNow.day);
    final selected = today.isBefore(inicio)
        ? inicio
        : today.isAfter(fin)
        ? fin
        : today;
    return dateKey(selected);
  }

  String dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDateOnly(dynamic value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}

bool manualRecargoOutcomeIsUncertain(Object error) {
  if (error is AppException &&
      error.statusCode != null &&
      error.statusCode! >= 400 &&
      error.statusCode! < 500) {
    return false;
  }
  return true;
}
