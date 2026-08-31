// Focused tests for Scenarios 43 and 44 (Remediation #7 Sub-Blocker C)
//
// Scenario 43: exportCajaReport notifier method exists and fires correctly.
// Scenario 44: authorized action is reachable with the correct caja session id.

import 'dart:typed_data';

import 'package:barbeer/core/async/operation_state.dart';
import 'package:barbeer/core/constants/api_constants.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/reportes/data/models/reporte_models.dart';
import 'package:barbeer/features/reportes/data/reportes_repository.dart';
import 'package:barbeer/features/reportes/presentation/providers/reportes_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Scenario 43: notifier method exists and routes to canonical endpoint ────

  group('Scenario 43 — exportCajaReport notifier caller exists', () {
    test(
        'authorized exportCajaReport calls the canonical caja export endpoint',
        () async {
      const sessionId = 'session-caja-abc';
      final capturedPaths = <String>[];
      final repo = ReportesRepository(
        ApiClient.instance,
        bytesRequest: (path, _) async {
          capturedPaths.add(path);
          return ReporteExportado(
            bytes: Uint8List(0),
            contentType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            filename: 'caja.xlsx',
          );
        },
      );

      final notifier = ReportesNotifier(repo, authorized: true);
      await notifier.exportCajaReport(sessionId, formato: 'XLSX');

      // Must hit the canonical caja export path
      expect(capturedPaths.single, ApiConstants.reportCajaExport(sessionId));
    });

    test('unauthorized exportCajaReport sets 403 error state without transport call',
        () async {
      var transportCalled = false;
      final repo = ReportesRepository(
        ApiClient.instance,
        bytesRequest: (_, __) async {
          transportCalled = true;
          return ReporteExportado(
            bytes: Uint8List(0),
            contentType: 'application/octet-stream',
            filename: 'x.xlsx',
          );
        },
      );

      final notifier = ReportesNotifier(repo, authorized: false);
      await notifier.exportCajaReport('s-1', formato: 'XLSX');

      expect(transportCalled, isFalse,
          reason: 'transport must not be called when unauthorized');
      final exportState = notifier.state.exportState;
      expect(exportState, isA<OperationRecoverableError<ReporteExportado>>());
      final error =
          (exportState as OperationRecoverableError<ReporteExportado>).error;
      expect(error.statusCode, 403);
    });
  });

  // ── Scenario 44: authorized caller is reachable from caja session ──────────

  group('Scenario 44 — export is reachable from caja session detail', () {
    test(
        'exportCajaReport returns ReporteExportado with server-provided filename',
        () async {
      const sessionId = 'caja-session-xyz';
      final repo = ReportesRepository(
        ApiClient.instance,
        bytesRequest: (path, _) async {
          expect(path, ApiConstants.reportCajaExport(sessionId));
          return ReporteExportado(
            bytes: Uint8List.fromList([1, 2, 3]),
            contentType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            filename: 'turno-$sessionId.xlsx',
          );
        },
      );

      final notifier = ReportesNotifier(repo, authorized: true);
      await notifier.exportCajaReport(sessionId, formato: 'XLSX');

      expect(notifier.state.exportBusy, isFalse);
      final exportState = notifier.state.exportState;
      expect(exportState, isA<OperationContent<ReporteExportado>>());
      final data =
          (exportState as OperationContent<ReporteExportado>).data;
      expect(data.filename, 'turno-$sessionId.xlsx');
      expect(data.bytes.length, 3);
    });
  });
}
