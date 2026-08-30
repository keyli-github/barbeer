import 'dart:typed_data';
import 'package:barbeer/core/files/file_artifact.dart';
import 'package:barbeer/core/files/file_artifact_service.dart';
import 'package:barbeer/core/files/android_file_artifact_service.dart';
import 'package:barbeer/core/files/windows_file_artifact_service.dart';
import 'package:flutter_test/flutter_test.dart';

FileArtifact _art({
  String name = 'data.json',
  String mime = 'application/json',
}) =>
    FileArtifact(bytes: Uint8List.fromList([1, 2, 3]), filename: name, contentType: mime);

void main() {
  group('validateArtifact', () {
    test('allows xlsx with matching content type', () => expect(
        validateArtifact(_art(
            name: 'report.xlsx',
            mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')),
        isNull));

    test('allows json with matching content type',
        () => expect(validateArtifact(_art()), isNull));

    test('allows notes.txt with text/plain',
        () => expect(validateArtifact(_art(name: 'notes.txt', mime: 'text/plain')), isNull));

    test('rejects README.sh — .sh not in allowlist', () =>
        expect(validateArtifact(_art(name: 'README.sh', mime: 'text/plain')),
            contains('.sh is not allowed')));

    test('rejects executable.md — .md not in allowlist', () =>
        expect(validateArtifact(_art(name: 'executable.md', mime: 'text/plain')),
            contains('.md is not allowed')));

    test('rejects executable.mdx — .mdx not in allowlist', () =>
        expect(validateArtifact(_art(name: 'executable.mdx', mime: 'text/plain')),
            contains('.mdx is not allowed')));

    test('rejects requirements.txt — blocked script-like filename', () =>
        expect(validateArtifact(_art(name: 'requirements.txt', mime: 'text/plain')),
            contains('requirements.txt is not allowed')));

    test('rejects CMakeLists.txt — blocked build-system filename', () =>
        expect(validateArtifact(_art(name: 'CMakeLists.txt', mime: 'text/plain')),
            contains('CMakeLists.txt is not allowed')));

    test('rejects filename with path separator', () =>
        expect(validateArtifact(_art(name: 'dir/report.json')), contains('invalid characters')));

    test('rejects content type mismatch — json file with text/plain', () =>
        expect(validateArtifact(_art(name: 'data.json', mime: 'text/plain')),
            contains('does not match')));
  });

  group('AndroidFileArtifactService', () {
    test('save allowed artifact calls bridge and returns saved path', () async {
      String? capName;
      final service = AndroidFileArtifactService(
        saveBridge: (n, b) async {
          capName = n;
          return 'content://downloads/data.json';
        },
      );
      final result = await service.save(_art());
      expect(result, isA<FileArtifactSaved>());
      expect((result as FileArtifactSaved).savedPath, 'content://downloads/data.json');
      expect(capName, 'data.json');
    });

    test('save returns cancelled when bridge returns null', () async {
      final service = AndroidFileArtifactService(saveBridge: (_, __) async => null);
      expect(await service.save(_art()), isA<FileArtifactCancelled>());
    });

    test('save blocked filename returns validation failure; bridge not called', () async {
      bool called = false;
      final service = AndroidFileArtifactService(
        saveBridge: (_, __) async {
          called = true;
          return '/file';
        },
      );
      final result = await service.save(_art(name: 'requirements.txt', mime: 'text/plain'));
      expect(result, isA<FileArtifactValidationFailure>());
      expect(called, isFalse);
    });
  });

  group('WindowsFileArtifactService', () {
    test('save allowed artifact calls bridge and returns saved path', () async {
      String? capName;
      final service = WindowsFileArtifactService(
        saveBridge: (n, b) async {
          capName = n;
          return r'C:\Users\u\Downloads\data.json';
        },
      );
      final result = await service.save(_art());
      expect(result, isA<FileArtifactSaved>());
      expect((result as FileArtifactSaved).savedPath, r'C:\Users\u\Downloads\data.json');
      expect(capName, 'data.json');
    });

    test('save returns cancelled when bridge returns null', () async {
      final service = WindowsFileArtifactService(saveBridge: (_, __) async => null);
      expect(await service.save(_art()), isA<FileArtifactCancelled>());
    });

    test('save blocked filename returns validation failure; bridge not called', () async {
      bool called = false;
      final service = WindowsFileArtifactService(
        saveBridge: (_, __) async {
          called = true;
          return r'C:\file';
        },
      );
      final result = await service.save(_art(name: 'CMakeLists.txt', mime: 'text/plain'));
      expect(result, isA<FileArtifactValidationFailure>());
      expect(called, isFalse);
    });
  });

  group('Platform harness', () {
    test('Android: allowed JSON save and open succeed end-to-end', () async {
      final saved = <String>[];
      final opened = <String>[];
      final service = AndroidFileArtifactService(
        saveBridge: (n, b) async {
          final p = 'content://downloads/$n';
          saved.add(p);
          return p;
        },
        openBridge: (p, _) async { opened.add(p); },
      );
      final r1 = await service.save(_art(name: 'ventas.json'));
      expect(r1, isA<FileArtifactSaved>());
      final path = (r1 as FileArtifactSaved).savedPath;
      final r2 = await service.open(path);
      expect(r2, isA<FileArtifactSaved>());
      expect(saved, hasLength(1));
      expect(opened, [path]);
    });

    test('Android: .sh file rejected before reaching save bridge', () async {
      bool called = false;
      final service = AndroidFileArtifactService(
        saveBridge: (_, __) async {
          called = true;
          return '/file';
        },
      );
      expect(await service.save(_art(name: 'setup.sh', mime: 'text/plain')),
          isA<FileArtifactValidationFailure>());
      expect(called, isFalse);
    });

    test('Windows: allowed XLSX save and open succeed end-to-end', () async {
      final service = WindowsFileArtifactService(
        saveBridge: (n, b) async => 'C:\\Downloads\\' + n,
        openBridge: (_, __) async {},
      );
      const xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      final r = await service.save(_art(name: 'reporte.xlsx', mime: xlsxMime));
      expect(r, isA<FileArtifactSaved>());
      final open = await service.open((r as FileArtifactSaved).savedPath);
      expect(open, isA<FileArtifactSaved>());
    });
  });
}
