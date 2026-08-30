import 'dart:typed_data';

class FileArtifact {
  final Uint8List bytes;
  final String filename;
  final String contentType;
  final int? expectedLength;
  final String? expectedSha256;

  FileArtifact({
    required this.bytes,
    required this.filename,
    required this.contentType,
    this.expectedLength,
    this.expectedSha256,
  });
}

sealed class FileArtifactResult {
  const FileArtifactResult();
}

final class FileArtifactSaved extends FileArtifactResult {
  final String savedPath;
  const FileArtifactSaved(this.savedPath);
}

final class FileArtifactCancelled extends FileArtifactResult {
  const FileArtifactCancelled();
}

final class FileArtifactValidationFailure extends FileArtifactResult {
  final String reason;
  const FileArtifactValidationFailure(this.reason);
}

final class FileArtifactPermissionDenied extends FileArtifactResult {
  const FileArtifactPermissionDenied();
}

final class FileArtifactInsufficientSpace extends FileArtifactResult {
  const FileArtifactInsufficientSpace();
}

final class FileArtifactWriteFailure extends FileArtifactResult {
  final String reason;
  const FileArtifactWriteFailure(this.reason);
}

final class FileArtifactOpenUnsupported extends FileArtifactResult {
  const FileArtifactOpenUnsupported();
}
