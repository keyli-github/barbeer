import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:barbeer/features/respaldos/data/models/respaldo_models.dart';
import 'package:barbeer/features/respaldos/data/respaldos_repository.dart';

void main() {
  // ── DTO mapping ──────────────────────────────────────────────────────────
  group('BackupSchedule DTO', () {
    test('parses full schedule', () {
      final j = {
        'enabled': true,
        'frequency': 'DAILY',
        'formats': ['XLSX', 'JSON'],
        'timezone': 'America/Argentina/Buenos_Aires',
        'nextRunAt': '2026-09-01T03:00:00Z',
        'lastRunAt': '2026-08-31T03:00:00Z',
      };
      final s = BackupSchedule.fromJson(j);
      expect(s.enabled, true);
      expect(s.frequency, 'DAILY');
      expect(s.formats, ['XLSX', 'JSON']);
      expect(s.timezone, 'America/Argentina/Buenos_Aires');
      expect(s.nextRunAt, '2026-09-01T03:00:00Z');
      expect(s.lastRunAt, '2026-08-31T03:00:00Z');
    });

    test('parses empty/default schedule', () {
      final j = {
        'enabled': false,
        'frequency': 'WEEKLY',
        'formats': ['TXT'],
        'timezone': 'UTC',
        'nextRunAt': null,
        'lastRunAt': null,
      };
      final s = BackupSchedule.fromJson(j);
      expect(s.enabled, false);
      expect(s.nextRunAt, isNull);
      expect(s.lastRunAt, isNull);
    });

    test('serializes update payload', () {
      const s = BackupSchedule(
        enabled: true, frequency: 'MONTHLY', formats: ['XLSX'],
        timezone: 'UTC', nextRunAt: null, lastRunAt: null);
      final payload = s.toUpdateJson();
      expect(payload.keys, containsAll(['enabled', 'frequency', 'formats']));
      expect(payload.containsKey('timezone'), false);
      expect(payload.containsKey('nextRunAt'), false);
    });
  });

  group('BackupRun DTO', () {
    test('parses succeeded run with artifact', () {
      final j = {
        'id': 'run-1',
        'status': 'SUCCEEDED',
        'attempts': 1,
        'startedAt': '2026-08-31T03:00:00Z',
        'completedAt': '2026-08-31T03:02:00Z',
        'lastError': null,
        'totalArtifacts': 1,
        'artifacts': [
          {'format': 'XLSX', 'sizeBytes': 2048, 'sha256': 'abc123'},
        ],
      };
      final r = BackupRun.fromJson(j);
      expect(r.id, 'run-1');
      expect(r.status, 'SUCCEEDED');
      expect(r.artifacts.length, 1);
      expect(r.artifacts.first.format, 'XLSX');
      expect(r.artifacts.first.sha256, 'abc123');
    });

    test('parses failed run', () {
      final j = {
        'id': 'run-2',
        'status': 'FAILED',
        'attempts': 3,
        'startedAt': '2026-08-30T03:00:00Z',
        'completedAt': '2026-08-30T03:01:00Z',
        'lastError': 'Storage unavailable',
        'totalArtifacts': 0,
        'artifacts': [],
      };
      final r = BackupRun.fromJson(j);
      expect(r.status, 'FAILED');
      expect(r.lastError, 'Storage unavailable');
      expect(r.artifacts, isEmpty);
    });

    test('parses runs page', () {
      final page = BackupRunsPage.fromJson({
        'data': [
          {'id': 'run-1', 'status': 'SUCCEEDED', 'attempts': 1,
           'startedAt': 's', 'completedAt': 'c', 'lastError': null,
           'totalArtifacts': 0, 'artifacts': []},
        ],
        'total': 1, 'page': 1, 'limit': 20, 'totalPages': 1,
      });
      expect(page.data.length, 1);
      expect(page.total, 1);
      expect(page.totalPages, 1);
    });
  });

  // ── Repository transport ─────────────────────────────────────────────────
  group('RespaldosRepository', () {
    test('getSchedule passes path and returns model', () async {
      final repo = RespaldosRepository(
        null,
        getRequest: (path) async => {
          'enabled': false, 'frequency': 'DAILY', 'formats': ['JSON'],
          'timezone': 'UTC', 'nextRunAt': null, 'lastRunAt': null,
        },
      );
      final s = await repo.getSchedule();
      expect(s.frequency, 'DAILY');
    });

    test('updateSchedule sends only allowed fields', () async {
      Map<String, dynamic>? captured;
      final repo = RespaldosRepository(
        null,
        putRequest: (path, body) async {
          captured = body;
          return {'enabled': true, 'frequency': 'WEEKLY', 'formats': ['XLSX'],
                  'timezone': 'UTC', 'nextRunAt': null, 'lastRunAt': null};
        },
      );
      const s = BackupSchedule(
          enabled: true, frequency: 'WEEKLY', formats: ['XLSX'],
          timezone: 'UTC', nextRunAt: null, lastRunAt: null);
      await repo.updateSchedule(s);
      expect(captured!.containsKey('timezone'), false);
      expect(captured!['frequency'], 'WEEKLY');
    });

    test('listRuns passes page and limit', () async {
      Map<String, dynamic>? captured;
      final repo = RespaldosRepository(
        null,
        getWithQueryRequest: (path, query) async {
          captured = query;
          return {'data': [], 'total': 0, 'page': 1, 'limit': 10, 'totalPages': 0};
        },
      );
      await repo.listRuns(page: 2, limit: 10);
      expect(captured!['page'], 2);
      expect(captured!['limit'], 10);
    });

    test('downloadArtifact returns BackupDownloadResult with metadata', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      final repo = RespaldosRepository(
        null,
        bytesRequest: (path) async => fakeBytes,
      );
      // sha256 of [1,2,3,4] is well-known; pass wrong hash → should throw
      expect(
        () => repo.downloadArtifact('run-1', 'XLSX', expectedSha256: 'wrong'),
        throwsA(isA<BackupIntegrityException>()),
      );
    });

    test('downloadArtifact returns result with filename and contentType', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3]);
      final repo = RespaldosRepository(
        null,
        bytesRequest: (path) async => fakeBytes,
      );
      final result = await repo.downloadArtifact('run-1', 'JSON');
      expect(result.bytes, fakeBytes);
      expect(result.filename, contains('run-1'));
      expect(result.contentType, 'application/json');
    });

    test('downloadArtifact xlsx gets correct MIME in result', () async {
      final repo = RespaldosRepository(
        null,
        bytesRequest: (path) async => Uint8List.fromList([1]),
      );
      final result = await repo.downloadArtifact('run-abc123', 'XLSX');
      expect(result.filename, 'respaldo-run-abc1.xlsx');
      expect(result.contentType,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    });
  });

  // ── Blocker 6: Independent schedule and runs errors ─────────────────────
  group('independent error isolation', () {
    test('schedule error does not prevent runs from loading', () async {
      final repo = RespaldosRepository(
        null,
        getRequest: (_) async => throw Exception('schedule API down'),
        getWithQueryRequest: (_, __) async => {
          'data': [], 'total': 0, 'page': 1, 'limit': 20, 'totalPages': 0,
        },
      );
      await expectLater(() => repo.getSchedule(), throwsException);
      final runs = await repo.listRuns();
      expect(runs.total, 0);
    });

    test('runs error does not prevent schedule from loading', () async {
      final repo = RespaldosRepository(
        null,
        getRequest: (_) async => {
          'enabled': false, 'frequency': 'DAILY', 'formats': ['JSON'],
          'timezone': 'UTC', 'nextRunAt': null, 'lastRunAt': null,
        },
        getWithQueryRequest: (_, __) async =>
            throw Exception('runs API down'),
      );
      final schedule = await repo.getSchedule();
      expect(schedule.frequency, 'DAILY');
      await expectLater(() => repo.listRuns(), throwsException);
    });
  });
}
