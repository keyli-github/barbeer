/// Peru's business clock is UTC-05:00 throughout the year.
DateTime businessTime(DateTime instant) =>
    instant.toUtc().subtract(const Duration(hours: 5));
String businessDate([DateTime? instant]) =>
    businessTime(instant ?? DateTime.now()).toIso8601String().substring(0, 10);
