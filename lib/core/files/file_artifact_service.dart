import 'dart:typed_data';
import 'file_artifact.dart';

typedef FileSaveBridge = Future<String?> Function(String filename, Uint8List bytes);
typedef FileOpenBridge = Future<void> Function(String path, String mimeType);

abstract class FileArtifactService {
  Future<FileArtifactResult> save(FileArtifact artifact);
  Future<FileArtifactResult> open(String savedPath);
}

const Set<String> kAllowedFileExtensions = {'xlsx', 'json', 'txt'};

const Set<String> _kBlockedFilenames = {'requirements.txt', 'cmakelists.txt'};

const Map<String, String> _kExtensionMimeTypes = {
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'json': 'application/json',
  'txt': 'text/plain',
};

/// Returns null if valid; returns a rejection reason if invalid.
String? validateArtifact(FileArtifact artifact) {
  final name = artifact.filename;
  if (name.contains('/') || name.contains(r'\') ||
      name.codeUnits.any((c) => c < 32)) {
    return 'Filename contains invalid characters';
  }
  final lower = name.toLowerCase();
  final dotIdx = lower.lastIndexOf('.');
  if (dotIdx < 0 || dotIdx == lower.length - 1) {
    return 'Filename has no extension';
  }
  final ext = lower.substring(dotIdx + 1);
  if (!kAllowedFileExtensions.contains(ext)) {
    return 'Extension .$ext is not allowed';
  }
  if (_kBlockedFilenames.contains(lower)) {
    return 'Filename $name is not allowed';
  }
  final expectedMime = _kExtensionMimeTypes[ext];
  if (expectedMime != null &&
      !artifact.contentType.toLowerCase().startsWith(expectedMime)) {
    return 'Content type ${artifact.contentType} does not match extension .$ext';
  }
  return null;
}

String mimeTypeForFilename(String filename) {
  final ext = filename.toLowerCase().split('.').last;
  return _kExtensionMimeTypes[ext] ?? 'application/octet-stream';
}
