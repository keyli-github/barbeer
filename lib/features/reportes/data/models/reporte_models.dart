typedef Json = Map<String, dynamic>;
class ReporteExportado {
  final List<int> bytes;
  final String contentType;
  final String filename;
  const ReporteExportado({required this.bytes, required this.contentType, required this.filename});
}
class ReporteEmailConfig {
  final List<String> recipients;
  final bool smtpConfigured;
  final String? updatedAt;
  const ReporteEmailConfig({required this.recipients, required this.smtpConfigured, this.updatedAt});
  factory ReporteEmailConfig.fromJson(Json j) => ReporteEmailConfig(
    recipients: List<String>.from(j['recipients'] as List? ?? []),
    smtpConfigured: j['smtpConfigured'] as bool? ?? false,
    updatedAt: j['updatedAt'] as String?);
  Json toJson() => {'recipients': recipients};
}
class ReporteEmailTestResult {
  final bool delivered;
  final String? messageId;
  const ReporteEmailTestResult({required this.delivered, this.messageId});
  factory ReporteEmailTestResult.fromJson(Json j) => ReporteEmailTestResult(
    delivered: j['delivered'] as bool,
    messageId: j['messageId'] as String?);
}
