import 'dart:typed_data';
import 'package:crypto/crypto.dart';

typedef Json = Map<String, dynamic>;

class BackupSchedule {
  final bool enabled;
  final String frequency;
  final List<String> formats;
  final String timezone;
  final String? nextRunAt;
  final String? lastRunAt;

  const BackupSchedule({
    required this.enabled,
    required this.frequency,
    required this.formats,
    required this.timezone,
    this.nextRunAt,
    this.lastRunAt,
  });

  factory BackupSchedule.fromJson(Json j) => BackupSchedule(
        enabled: j['enabled'] as bool? ?? false,
        frequency: j['frequency'] as String? ?? 'DAILY',
        formats: List<String>.from(j['formats'] as List? ?? []),
        timezone: j['timezone'] as String? ?? 'UTC',
        nextRunAt: j['nextRunAt'] as String?,
        lastRunAt: j['lastRunAt'] as String?,
      );

  Json toUpdateJson() => {
        'enabled': enabled,
        'frequency': frequency,
        'formats': formats,
      };
}

class BackupArtifact {
  final String format;
  final int sizeBytes;
  final String? sha256;

  const BackupArtifact({
    required this.format,
    required this.sizeBytes,
    this.sha256,
  });

  factory BackupArtifact.fromJson(Json j) => BackupArtifact(
        format: j['format'] as String,
        sizeBytes: j['sizeBytes'] as int? ?? 0,
        sha256: j['sha256'] as String?,
      );
}

class BackupRun {
  final String id;
  final String status;
  final int attempts;
  final String? startedAt;
  final String? completedAt;
  final String? lastError;
  final int totalArtifacts;
  final List<BackupArtifact> artifacts;

  const BackupRun({
    required this.id,
    required this.status,
    required this.attempts,
    this.startedAt,
    this.completedAt,
    this.lastError,
    required this.totalArtifacts,
    required this.artifacts,
  });

  factory BackupRun.fromJson(Json j) => BackupRun(
        id: j['id'] as String,
        status: j['status'] as String,
        attempts: j['attempts'] as int? ?? 0,
        startedAt: j['startedAt'] as String?,
        completedAt: j['completedAt'] as String?,
        lastError: j['lastError'] as String?,
        totalArtifacts: j['totalArtifacts'] as int? ?? 0,
        artifacts: (j['artifacts'] as List? ?? [])
            .map((e) => BackupArtifact.fromJson(e as Json))
            .toList(),
      );
}

class BackupRunsPage {
  final List<BackupRun> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const BackupRunsPage({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory BackupRunsPage.fromJson(Json j) => BackupRunsPage(
        data: (j['data'] as List? ?? [])
            .map((e) => BackupRun.fromJson(e as Json))
            .toList(),
        total: j['total'] as int? ?? 0,
        page: j['page'] as int? ?? 1,
        limit: j['limit'] as int? ?? 20,
        totalPages: j['totalPages'] as int? ?? 0,
      );
}

class BackupIntegrityException implements Exception {
  final String message;
  const BackupIntegrityException(this.message);
  @override
  String toString() => 'BackupIntegrityException: $message';
}

/// Server-sourced download metadata for backup artifacts.
class BackupDownloadResult {
  final Uint8List bytes;
  final String filename;
  final String contentType;
  const BackupDownloadResult({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });
}

String sha256HexOf(Uint8List bytes) {
  final digest = sha256.convert(bytes);
  return digest.toString();
}
