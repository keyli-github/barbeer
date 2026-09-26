import 'package:intl/intl.dart';

/// Peru's business clock is UTC-05:00 throughout the year.
DateTime businessTime(DateTime instant) =>
    instant.toUtc().subtract(const Duration(hours: 5));

String businessDate([DateTime? instant]) =>
    businessTime(instant ?? DateTime.now()).toIso8601String().substring(0, 10);

/// Parses an API timestamp into a UTC value whose fields represent Lima time.
/// Zone-less legacy values are treated as business-local wall time.
DateTime? parseBusinessTime(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;

  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return null;

  final hasTimezone = RegExp(
    r'[Tt].*(?:[zZ]|[+-]\d{2}:?\d{2})$',
  ).hasMatch(normalized);
  if (hasTimezone) return businessTime(parsed);

  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

String? formatBusinessDateTime(String? value) {
  final parsed = parseBusinessTime(value);
  if (parsed == null) return null;
  return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
}

bool sameBusinessTime(String? first, String? second) {
  final parsedFirst = parseBusinessTime(first);
  final parsedSecond = parseBusinessTime(second);
  if (parsedFirst == null || parsedSecond == null) return false;
  return parsedFirst.isAtSameMomentAs(parsedSecond);
}
