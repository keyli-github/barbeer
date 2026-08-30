import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'file_artifact.dart';
import 'file_artifact_service.dart';

class WindowsFileArtifactService implements FileArtifactService {
  final FileSaveBridge? saveBridge;
  final FileOpenBridge? openBridge;

  WindowsFileArtifactService({this.saveBridge, this.openBridge});

  @override
  Future<FileArtifactResult> save(FileArtifact artifact) async {
    final error = validateArtifact(artifact);
    if (error != null) return FileArtifactValidationFailure(error);
    try {
      final savedPath = saveBridge != null
          ? await saveBridge!(artifact.filename, artifact.bytes)
          : await FilePicker.platform.saveFile(
              fileName: artifact.filename, bytes: artifact.bytes);
      if (savedPath == null) return const FileArtifactCancelled();
      return FileArtifactSaved(savedPath);
    } on FileSystemException catch (e) {
      if (e.osError?.errorCode == 28) return const FileArtifactInsufficientSpace();
      return const FileArtifactPermissionDenied();
    } catch (e) {
      return FileArtifactWriteFailure(e.toString());
    }
  }

  @override
  Future<FileArtifactResult> open(String savedPath) async {
    try {
      if (openBridge != null) {
        final mimeType = mimeTypeForFilename(savedPath);
        await openBridge!(savedPath, mimeType);
      } else {
        final result = await Process.run('cmd', ['/c', 'start', '', savedPath]);
        if (result.exitCode != 0) return const FileArtifactOpenUnsupported();
      }
      return FileArtifactSaved(savedPath);
    } catch (_) {
      return const FileArtifactOpenUnsupported();
    }
  }
}
