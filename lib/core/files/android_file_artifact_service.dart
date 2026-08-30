import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'file_artifact.dart';
import 'file_artifact_service.dart';

class AndroidFileArtifactService implements FileArtifactService {
  static const _channel = MethodChannel('com.barbeer.barbeer/files');

  final FileSaveBridge? saveBridge;
  final FileOpenBridge? openBridge;

  AndroidFileArtifactService({this.saveBridge, this.openBridge});

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
    } on FileSystemException {
      return const FileArtifactPermissionDenied();
    } catch (e) {
      return FileArtifactWriteFailure(e.toString());
    }
  }

  @override
  Future<FileArtifactResult> open(String savedPath) async {
    try {
      final mimeType = mimeTypeForFilename(savedPath);
      if (openBridge != null) {
        await openBridge!(savedPath, mimeType);
      } else {
        await _channel.invokeMethod<void>(
            'openFile', {'path': savedPath, 'mimeType': mimeType});
      }
      return FileArtifactSaved(savedPath);
    } on PlatformException catch (e) {
      if (e.code == 'OPEN_FAILED') return const FileArtifactOpenUnsupported();
      return FileArtifactWriteFailure(e.message ?? 'open failed');
    } catch (_) {
      return const FileArtifactOpenUnsupported();
    }
  }
}
