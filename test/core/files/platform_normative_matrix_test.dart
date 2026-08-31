// test/core/files/platform_normative_matrix_test.dart
//
// Normative platform matrix for Scenarios 6 (Android SAF) and 7 (Windows file
// dialog), plus a source-conflict test that proves graceful fallback when
// neither platform bridge nor channel handler is present.
//
// Design note: production code uses FileSaveBridge / FileOpenBridge for DI.
// Android open() falls back to MethodChannel('com.barbeer.barbeer/files')
// (SAF). Windows open() falls back to Process.run('cmd'). Tests intercept
// at the DI seam or via TestDefaultBinaryMessengerBinding as appropriate.

import 'dart:typed_data';
import 'package:barbeer/core/files/file_artifact.dart';
import 'package:barbeer/core/files/file_artifact_service.dart';
import 'package:barbeer/core/files/android_file_artifact_service.dart';
import 'package:barbeer/core/files/windows_file_artifact_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

// Channel name must match AndroidFileArtifactService._channel.
const _safChannel = MethodChannel('com.barbeer.barbeer/files');

FileArtifact _art({
  String name = 'data.json',
  String mime = 'application/json',
}) =>
    FileArtifact(
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: name,
      contentType: mime,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Scenario 6: Android SAF normative matrix ──────────────────────────────
  group('Scenario 6 – Android SAF dispatch normative matrix', () {
    tearDown(() {
      // Always clear the mock handler so tests don't bleed into each other.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_safChannel, null);
    });

    test(
        'JSON open: dispatches to SAF MethodChannel with correct path and MIME',
        () async {
      late MethodCall captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_safChannel, (call) async {
        captured = call;
        return null; // null = SAF accepted the intent
      });

      final service = AndroidFileArtifactService(); // no bridge → channel path
      final result = await service.open('content://downloads/ventas.json');

      expect(result, isA<FileArtifactSaved>());
      expect(captured.method, 'openFile',
          reason:
              'Android open must invoke "openFile" on the SAF platform channel');
      expect(captured.arguments['path'], 'content://downloads/ventas.json');
      expect(captured.arguments['mimeType'], 'application/json',
          reason: 'SAF call must carry the JSON MIME type derived from the path');
    });

    test('.sh save: validation blocks file before SAF channel is reached',
        () async {
      bool channelInvoked = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_safChannel, (call) async {
        channelInvoked = true;
        return null;
      });

      bool bridgeInvoked = false;
      final service = AndroidFileArtifactService(
        saveBridge: (_, __) async {
          bridgeInvoked = true;
          return '/file';
        },
      );
      final result = await service.save(_art(name: 'setup.sh', mime: 'text/plain'));

      expect(result, isA<FileArtifactValidationFailure>(),
          reason: '.sh must be rejected by validation before any I/O dispatch');
      expect(bridgeInvoked, isFalse,
          reason: 'save bridge must never be called for a blocked filename');
      expect(channelInvoked, isFalse,
          reason: 'SAF channel must never be invoked for a blocked filename');
    });

    test('XLSX save: dispatches through SAF bridge and returns content:// URI',
        () async {
      final service = AndroidFileArtifactService(
        saveBridge: (n, _) async =>
            'content://com.android.providers.downloads/documents/$n',
      );
      final result = await service.save(_art(name: 'reporte.xlsx', mime: _xlsxMime));

      expect(result, isA<FileArtifactSaved>(),
          reason: 'XLSX save must succeed through SAF bridge');
      final saved = result as FileArtifactSaved;
      expect(saved.savedPath, startsWith('content://'),
          reason:
              'Android SAF save must use content:// URI — not a direct file path');
      expect(saved.savedPath, endsWith('reporte.xlsx'));
    });
  });

  // ── Scenario 7: Windows file dialog normative matrix ─────────────────────
  group('Scenario 7 – Windows file dialog normative matrix', () {
    test('XLSX open: dispatches through native openBridge with correct MIME',
        () async {
      String? capturedPath;
      String? capturedMime;
      final service = WindowsFileArtifactService(
        openBridge: (p, m) async {
          capturedPath = p;
          capturedMime = m;
        },
      );

      final result = await service.open(r'C:\Downloads\reporte.xlsx');

      expect(result, isA<FileArtifactSaved>(),
          reason: 'Windows XLSX open must succeed through native file dialog');
      expect(capturedPath, r'C:\Downloads\reporte.xlsx');
      expect(capturedMime, _xlsxMime,
          reason:
              'Windows open must forward the exact XLSX MIME to the file dialog');
    });

    test(
        'XLSX save: dispatches through saveBridge and returns Windows drive-letter path',
        () async {
      String? capturedName;
      final service = WindowsFileArtifactService(
        saveBridge: (n, _) async {
          capturedName = n;
          return r'C:\Users\u\Downloads\' + n;
        },
      );

      final result = await service.save(_art(name: 'export.xlsx', mime: _xlsxMime));

      expect(result, isA<FileArtifactSaved>(),
          reason: 'Windows XLSX save must succeed through native dialog');
      final saved = result as FileArtifactSaved;
      expect(capturedName, 'export.xlsx');
      expect(saved.savedPath, startsWith(r'C:\'),
          reason:
              'Windows save path must use drive-letter path — not content:// URI');
    });
  });

  // ── Source conflict: graceful fallback when no platform handler is active ─
  group('Source conflict – no platform handler (Linux/macOS/web fallback)',
      () {
    setUp(() {
      // Explicitly clear any mock — simulates a non-Android environment where
      // the SAF channel has no registered platform implementation.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_safChannel, null);
    });

    test(
        'Android open with no bridge and no channel handler returns '
        'FileArtifactOpenUnsupported rather than throwing', () async {
      final service = AndroidFileArtifactService(); // no bridge, no channel handler
      final result = await service.open('content://downloads/data.json');

      // MissingPluginException from the unregistered channel is caught by
      // catch(_) in AndroidFileArtifactService.open() and mapped to the
      // graceful FileArtifactOpenUnsupported result.
      expect(result, isA<FileArtifactOpenUnsupported>(),
          reason:
              'Non-Android fallback must return FileArtifactOpenUnsupported, not crash');
    });

    test(
        'Windows open with a failing openBridge returns '
        'FileArtifactOpenUnsupported rather than throwing', () async {
      final service = WindowsFileArtifactService(
        openBridge: (_, __) async =>
            throw Exception('no Windows shell available'),
      );
      final result = await service.open(r'C:\Downloads\report.xlsx');

      expect(result, isA<FileArtifactOpenUnsupported>(),
          reason:
              'Windows open must catch bridge exceptions and return graceful fallback');
    });
  });
}
